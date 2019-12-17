
using GigaSOM, DataFrames, XLSX, Test, Random, Distributed, SHA, JSON

checkDir()
cwd = pwd()

dataPath = "/Users/ohunewald/work/artificial_data_cytof"
# dataPath = "artificial_data_cytof/"
cd(dataPath)
md = DataFrame(XLSX.readtable("metadata.xlsx", "Sheet1", infer_eltypes=true)...)
panel = DataFrame(XLSX.readtable("panel.xlsx", "Sheet1", infer_eltypes=true)...)

lineageMarkers, functionalMarkers = getMarkers(panel)


nWorkers = 2
addprocs(nWorkers, topology=:master_worker)
@everywhere using GigaSOM, FCSFiles

@info "processes added"

# read directory
content = md.file_name
L = length(content)

R =  Vector{Any}(undef,L)

N = convert(Int64, (length(md.file_name)/nWorkers))

#R[1] = loadData(1, content[1], md, panel)

@time @sync for (idx, pid) in enumerate(workers())
    @async for k in (idx-1)*N+1:idx*N
         R[k] = fetch(@spawnat pid loadData(idx, content[k], md, panel))
    end
end

# Now sample from all refences randomly for the som grid
# initialization
# Get n random samples from m workers in R:
samplesPerWorker = Int(length(R))
# sampleList defines wich data in R ref has to return one random sample
# TODO: put this into core.jl
sampleList = rand(1:samplesPerWorker, 100)
X = zeros(100, length(lineageMarkers))

for i in 1:length(sampleList)
    element = sampleList[i]
    # dereference and get one random sample from matrix
    # R is a tuple (Ref, myid)
    Y = R[element][1].x[rand(1:size(R[element][1].x, 1), 1),:]
    # convert Y into vector
    X[i, :] = vec(Y)
end

som = initGigaSOM(X, 10, 10)

# Merge the list of references into an Array grouped by
# worker ID
workerIDs = workers()
Rc = [Ref[] for i=1:nWorkers]

# Collect all references into an array of Ref Data
for k in 1:L
    id = R[k][2]
    localID = findall(isequal(id), workerIDs)
    push!(Rc[localID[1]], R[k][1])
end

# try to merge from master on workers
# for i in 1:length(Rc[1])
#     Rc[1][1].x = vcat(Rc[1][1].x , Rc[1][i].x)
# end
# Rc[1][1].x = vcat(Rc[1][1].x , Rc[1][2].x)

# -----------------------------------------
# merge data on worker from master
# SLOW ! (2-3 seconds)
# alternative: not merge and loop in the 
# function doEpoch
# -----------------------------------------
@everywhere function mergeData(refWorker)
    for i in 2:length(refWorker)
        # merge the single df into the first one and return the Ref
        refWorker[1].x = vcat(refWorker[1].x, refWorker[i].x)
    end
    return refWorker[1]
end

# merging can be done in parallel by each worker
Rmerged = Vector{Any}(undef,nworkers())
@time @sync for (idx, pid) in enumerate(workers())
    @async begin
         Rmerged[idx] = fetch(@spawnat pid mergeData(Rc[idx]))
    end
end


# call trainGigaSOM with the list of references per worker
#------ trainGigaSOM() -------------------------
# define the columns to be used for som training
cc = map(Symbol, lineageMarkers)
@time som = trainGigaSOM(som, Rmerged, cc)

rmprocs(workers())

