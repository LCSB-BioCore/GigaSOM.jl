try
    using Distributed
    using FileIO
    using CSVFiles
    using FCSFiles
catch
    import Pkg;
    Pkg.add("Distributed")
    Pkg.add("FileIO")
    Pkg.add("CSVFiles")
    Pkg.add("FCSFiles")
end

# prepare the workers
using Distributed
nWorkers = 2
type = "fcs" #csv
addprocs(nWorkers, topology=:master_worker)
@everywhere using FileIO

# information about workers
@info "Number of workers: $nWorkers"

# define a custom load function
@everywhere function loadData(id, fn, type)
    @time in = FileIO.load(type*"/"*fn)
    return id
end

# get the files
content = readdir(type)
L = length(content)

# define an array of references
R = Vector{Any}(undef, L)

# load files in parallel
N = convert(Int64, L/nWorkers)

@info "Benchmarking ..."

@time @sync for (idx, pid) in enumerate(workers())
    @async for k in (idx-1)*N+1:idx*N
        R[k] = fetch(@spawnat pid loadData(idx, content[k], type) )
    end
end

# fetch
@info R

rmprocs(workers())

