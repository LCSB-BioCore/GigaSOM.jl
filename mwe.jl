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


using Distributed, FileIO

# prepare the workers
nWorkers = 2
type = "fcs"
addprocs(nWorkers) #, topology=:master_worker)
@everywhere using FileIO #, FCSFiles

@info "Number of workers: $nWorkers"

# define a custom load function
@everywhere function loadData(id, fn, type)
    @time in = FileIO.load(type*"/"*fn)
    return ones(id, id)
end

R = Vector{Any}(undef,nworkers())
content = readdir(type)

# load files in parallel
N = convert(Int64, length(content)/nWorkers)

@info "Benchmarking ..."

@time @sync for (idx, pid) in enumerate(workers())
    @async for k in (idx-1)*N+1:idx*N
        R[idx] = fetch(@spawnat pid loadData(idx, content[k], type) )
    end
end

# fetch
@info R

rmprocs(workers())

