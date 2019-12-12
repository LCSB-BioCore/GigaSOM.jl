
using GigaSOM, DataFrames, XLSX, CSV, Test, Random, Distributed, SHA, JSON

checkDir()
cwd = pwd()

# dataPath = "/Users/ohunewald/work/data_felD1/"
dataPath = "/Users/ohunewald/work/artificial_data_cytof/"
cd(dataPath)
md = DataFrame(XLSX.readtable("metadata.xlsx", "Sheet1", infer_eltypes=true)...)
panel = DataFrame(XLSX.readtable("panel.xlsx", "Sheet1", infer_eltypes=true)...)

lineageMarkers, functionalMarkers = getMarkers(panel)

nWorkers = 2
addprocs(nWorkers, topology=:master_worker)
@everywhere using GigaSOM, FCSFiles

R = Vector{Any}(undef,nworkers())

function distributed_channel_load(fileload_func, filenames, md, panel, R; ctype=Any, csize=2^10)
    Channel(ctype=ctype, csize=csize) do local_ch
        remote_ch = RemoteChannel(()->local_ch)

        c_pool = CachingPool(workers())
        file_dones = map(filenames) do filename
            #@show filename
            R = remotecall(fileload_func, c_pool, remote_ch, [filename], md, panel)
        end

        # Wait till all the all files are done
        for file_done in file_dones
            wait(file_done)
        end
        clear!(c_pool)
    end
end

function test_loading(channel_load, md, panel, R)
    inchannel = channel_load(loadDataChannel, md.file_name, md ,panel, R; ctype=Any)
    take!(inchannel)
end

@everywhere function loadDataChannel(ch, fn, md, panel)
    fcsRaw = readFlowset(fn)
    println(keys(fcsRaw))
    cleanNames!(fcsRaw)

    # extract lineage markers
    lineageMarkers, functionalMarkers = getMarkers(panel)

    cc = map(Symbol, vcat(lineageMarkers, functionalMarkers))
    # markers can be lineage and functional at tthe same time
    # therefore make cc unique
    unique!(cc)

    transformData(fcsRaw, method, cofactor)

    dfall = []
    colnames = []

    for (k, v) in fcsRaw
        
        df = v
        df = sortReduce(df, cc, reduce, sort)

        insertcols!(df, 1, sample_id = string(k))
        push!(dfall,df)
        # collect the column names of each file for order check
        push!(colnames, names(df))
    end

    # # check if all the column names are in the same order
    if !(all(y->y==colnames[1], colnames))
        throw(UndefVarError(:TheColumnOrderIsNotEqual))
    end

    dfall = vcat(dfall...)

    # return a reference to dfall to be used by trainGigaSOM
    dfallRefMatrix = convertTrainingData(dfall[:, cc])
    dfallRef = Ref{Array{Float64, 2}}(dfallRefMatrix)
    # return random samples for init Grid
    gridSize = 100
    nSamples = convert(Int64, floor(gridSize/nworkers()))

    # return (dfall[rand(1:nSamples, 2), :], dfallRef)
    return (dfallRef)
end

@time test_loading(distributed_channel_load, md, panel, R)
# @time test_loading(distributed_channel_load)


rmprocs(workers())






R = Vector{Any}(undef,nworkers())

N = convert(Int64, (length(md.file_name)/nWorkers))

@time @sync for (idx, pid) in enumerate(workers())
    @async R[idx] = fetch(@spawnat pid begin loadData(md.file_name[(idx-1)*N+1:idx*N],md, panel) end)
end

# Get n random samples from m workers in R:
samplesPerWorker = Int(length(R))
# sampleList defines wich data in R ref has to return one random sample
# TODO: put this into core.jl
sampleList = rand(1:samplesPerWorker, 100)
X = zeros(100, length(lineageMarkers))

for i in 1:length(sampleList)
    element = sampleList[i]
    # dereference and get one random sample from matrix
    Y = R[element].x[rand(1:size(R[element].x, 1), 1),:]
    # convert Y into vector
    X[i, :] = vec(Y)
end

som = initGigaSOM(X, 10, 10)

#------ trainGigaSOM() -------------------------
# define the columns to be used for som training
cc = map(Symbol, lineageMarkers)
# R holds the reference to the dataset for each worker
@time som = trainGigaSOM(som, R, cc) 

rmprocs(workers())
