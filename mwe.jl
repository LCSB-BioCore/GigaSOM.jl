using Distributed, FileIO

# prepare the workers
nWorkers = 4
addprocs(nWorkers)
@everywhere using FileIO

# define a custom load function
@everywhere function loadData(id, fileNames)
    for fn in fileNames
        in = load(fn)
    end
    return ones(id, id)
end

R = Vector{Any}(undef,nworkers())
content = readdir("csv")

# load files in parallel
N = convert(Int64, length(content)/nWorkers)
@time begin
    @sync for (idx, pid) in enumerate(workers())
        @async R[idx] = fetch(@spawnat pid loadData(idx, content[(idx-1)*N+1:idx*N]))
    end
end

R

rmprocs(workers())

