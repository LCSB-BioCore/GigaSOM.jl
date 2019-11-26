
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

for i in R
    println(i[1])
end

rmprocs(workers())

using Distributed

p = addprocs(2)

@everywhere function getRefBack(data)

    myRef = Ref{Int}(data)
    
end

@everywhere function addMe(m, n)
    return m+n
end

data = 3

R1 = @spawnat p[1] getRefBack(data)

x = fetch(R1)

m = 2

R2 = @spawnat p[1] addMe(m, x.x)

y = fetch(R2)
