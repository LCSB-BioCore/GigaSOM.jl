
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
@everywhere using GigaSOM, FCSFiles, FileIO


@everywhere begin
    function initRemoteData()
        return Ref{Array{Float64, 2}}()
    end
end


@everywhere begin
    function loadDataPmap(fn)

        fcsRaw = readSingleFlowFrame(fn)
        fcsRawMatrix = GigaSOM.convertTrainingData(fcsRaw)
        fcsData = Ref{Array{Float64, 2}}(fcsRawMatrix)
        # if !@isdefined(fcsData)
        #     # fcsData = Ref{Array{Float64, 2}}(fcsRawMatrix)
        #     println("not defined")
        #     return 0
        # else
        #     fcsData.x = vcat(fcsData.x, fcsRawMatrix)
        # end
        return fcsData, myid()
    end
end

fn = md.file_name
# loadDataPmap(fn, md,panel; method = "asinh", cofactor = 5, reduce = true, sort = true)
# wp = CachingPool(workers())
wp = WorkerPool(workers())
# pmap(md -> loadDataPmap(md),wp, fn)

# for name in fn
#     remotecall(loadDataPmap, wp, name)
#     println(name, wp)
# end
n = nworkers()
# refs = pmap(initRemoteData, 1:n)
fcsData = pmap(loadDataPmap, wp, fn)

@everywhere begin
    function mergeData(fcsData, md, panel)
        dfall = []
        for i in 1:size(fcsData, 1)
            # check if the data ref belongs to the worker id
            if fcsData[i][2] == myid()
                dfall = vcat(dfall, fcsData[i][1].x)
            end
        end
        return Ref{Array{Float64, 2}}(dfall)
        
    end
end

Rmerged = Vector{Any}(undef,nworkers())
@time @sync for (idx, pid) in enumerate(workers())
    @async Rmerged[idx] = fetch(@spawnat pid begin mergeData(fcsData, md, panel) end)
end


@info "processes added"

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
