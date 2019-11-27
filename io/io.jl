
using GigaSOM, DataFrames, XLSX, CSV, Test, Random, Distributed, SHA, JSON

checkDir()
#create genData and data folder and change dir to dataPath
cwd = pwd()
#
dataPath = "/Users/ohunewald/work/data_felD1/"
cd(dataPath)
md = DataFrame(XLSX.readtable("metadata.xlsx", "Sheet1", infer_eltypes=true)...)
panel = DataFrame(XLSX.readtable("panel.xlsx", "Sheet1", infer_eltypes=true)...)
#
lineageMarkers, functionalMarkers = getMarkers(panel)

nWorkers = 2
addprocs(nWorkers)
@everywhere using GigaSOM, FCSFiles

@info "processes added"

R = Vector{Any}(undef,nworkers())

@info "loop started"
# load files in parallel
N = convert(Int64, length(md.file_name)/nWorkers)

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
Rsom = Vector{Any}(undef,nworkers())
@time @sync for (idx, pid) in enumerate(workers())
    @async Rsom[idx] = fetch(@spawnat pid begin trainGigaSOM(som, R[idx][2], cc) end) 
end

rmprocs(workers())

# using Distributed

# p = addprocs(2)

# @everywhere function getRefBack(data)

#     myRef = Ref{Int}(data)
    
# end

# @everywhere function addMe(m, n)
#     return m+n
# end

# data = 3

# R1 = @spawnat p[1] getRefBack(data)

# x = fetch(R1)

# m = 2

# R2 = @spawnat p[1] addMe(m, x.x)

# y = fetch(R2)
