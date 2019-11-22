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
nWorkers = 4
type = "fcs"
addprocs(nWorkers)
@everywhere using FileIO

# define a custom load function
@everywhere function loadData(id, fileNames, type)
    for fn in fileNames
        in = load(type*"/"*fn)
    end
    return ones(id, id)
end

R = Vector{Any}(undef,nworkers())
content = readdir(type)

# load files in parallel
N = convert(Int64, length(content)/nWorkers)
@time begin
    @sync for (idx, pid) in enumerate(workers())
        @async R[idx] = fetch(@spawnat pid loadData(idx, content[(idx-1)*N+1:idx*N], type))
    end
end

@info R

rmprocs(workers())

