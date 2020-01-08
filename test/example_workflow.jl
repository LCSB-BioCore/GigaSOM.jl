using XLSX, CSV, Test, Random, Distributed, SHA, JSON
using GigaSOM, FileIO, Test, Serialization, FCSFiles, DataFrames

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

generateIO(dataPath, md, nWorkers, true, 1, true)

R =  Vector{Any}(undef,nWorkers)

@time @sync for (idx, pid) in enumerate(workers())
    @async R[idx] = fetch(@spawnat pid loadData(idx, "input-$idx.jls", md, panel))
end

randWorkers = rand(1:nworkers(), 100)
X = zeros(100, length(lineageMarkers))

for i in 1:length(randWorkers)
    element = randWorkers[i]
    # dereference and get one random sample from matrix
    Y = R[element].x[rand(1:size(R[element].x, 1), 1),:]
    # convert Y into vector
    X[i, :] = vec(Y)
end

som = initGigaSOM(X, 10, 10)

cc = map(Symbol, vcat(lineageMarkers, functionalMarkers))

@time som = trainGigaSOM(som, R, cc)

rmprocs(workers())
cd(cwd)