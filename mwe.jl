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
type = "csv"
addprocs(nWorkers, topology=:master_worker)
@everywhere import FileIO

@info "Number of workers: $nWorkers"

# define a custom load function
@everywhere function loadData(id, fileNames, type, precompileFlag)
    if precompileFlag
        for fn in fileNames
        @show fn
        @time in = FileIO.load(type*"/"*fn)
        end
    end
    return ones(id, id)
end

R = Vector{Any}(undef,nworkers())
content = readdir(type)

# load files in parallel
N = convert(Int64, length(content)/nWorkers)

@info "Benchmarking ..."

@time begin
# load files in parallel
    @sync for (idx, pid) in enumerate(workers())
        @async R[idx] = fetch(@spawnat pid loadData(idx, content[(idx-1)*N+1:idx*N], type, true))
    end
end

# fetch
@info R

rmprocs(workers())

