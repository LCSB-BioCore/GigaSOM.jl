
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

@info "processes added"

R = Vector{Any}(undef,nworkers())

N = convert(Int64, (length(md.file_name)/nWorkers))

@time @sync for (idx, pid) in enumerate(workers())
    @async R[idx] = fetch(@spawnat pid begin loadData(md.file_name[(idx-1)*N+1:idx*N],md, panel) end)
end

# Simulate the concatenation of return samples for testing only
# init codes: size is 10x10 x number of params
# each code contains vector of params -> 100 x length(lineageMarkers)
allRand = rand(100, length(lineageMarkers))

som = initGigaSOM(allRand, 10, 10)

#------ trainGigaSOM() -------------------------
# define the columns to be used for som training
cc = map(Symbol, lineageMarkers)
# R holds the reference to the dataset for each worker
@time som = trainGigaSOM(som, R, cc) 

rmprocs(workers())
