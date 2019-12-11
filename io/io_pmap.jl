
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


@everywhere begin
    function loadDataPmap(fn, md,panel; method = "asinh", cofactor = 5, 
                            reduce = true, sort = true)
        
        fcsRaw = readFlowFrame(fn)
        cleanNamesPmap!(fcsRaw)
        return 1
    end
end

@everywhere begin
    function cleanNamesPmap!(myFile)
        # replace chritical characters
        # put "_" in front of colname in case it starts with a number
        # println(typeof(mydata))
        for j in eachindex(myFile)
            myFile[j] = replace(myFile[j], "-"=>"_")
            if isnumeric(first(myFile[j]))
                myFile[j] = "_" * myFile[j]
            end
        end
    end
end

@everywhere begin

    function readFlowFrame(filename)

        flowrun = FileIO.load(filename) # FCS file

        # get metadata
        # FCSFiles returns a dict with coumn names as key
        # As the dict is not in order, use the name column form meta
        # to sort the Dataframe after cast.
        meta = getMetaData(flowrun)
        markers = meta[:,1]
        markersIsotope = meta[:,5]
        flowDF = DataFrame(flowrun.data)
        # sort the DF according to the marker list
        flowDF = flowDF[:, Symbol.(markersIsotope)]
        cleanNamesPmap!(markers)
        names!(flowDF, Symbol.(markers), makeunique=true)

        return flowDF
    end
end





determinants = pmap(rand_det, 1:10)

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
