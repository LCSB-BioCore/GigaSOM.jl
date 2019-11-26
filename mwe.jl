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
addprocs(nWorkers, topology=:master_worker)
@everywhere using FileIO, FCSFiles
#@everywhere import Pkg
#@everywhere Pkg.activate("FileIO")

@info "Number of workers: $nWorkers"

# define a custom load function
@everywhere function loadData(id, fn, type)
    @time in = FileIO.load(type*"/"*fn[1])
    return ones(id, id)
end

R = Vector{Any}(undef,nworkers())
content = readdir(type)

# load files in parallel
N = convert(Int64, length(content)/nWorkers)

@info "Benchmarking ..."

@time begin
    #=
    @time @sync begin
        @async R[1] = fetch(@spawnat 2 loadData(2, content[1:1], type, true))
        @async R[2] = fetch(@spawnat 3 loadData(3, content[2:2], type, true))
    end
    @info "preloading done"
    =#
    # load files in parallel
@sync for (idx, pid) in enumerate(workers())
   #@async begin
       @async for k in (idx-1)*N+1:idx*N
            #remotecall_fetch(loadData, pid, pid, content[k:k], type)
            R[idx] = fetch(@spawnat pid loadData(idx, content[k:k], type) )
        end
    #end
end

end
# fetch
@info R

rmprocs(workers())

