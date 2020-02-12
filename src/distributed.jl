"""
    save_at(worker, sym, val)

Saves value `val` to symbol `sym` at `worker`. `sym` should be quoted (or
contain a symbol). `val` gets unquoted in the processing and evaluated at the
worker, quote it if you want to pass exact command to the worker.

This is loosely based on the package ParallelDataTransfers, but made slightly
more flexible by omitting/delaying the explicit fetches etc. In particular,
`save_at` is roughly the same as `ParallelDataTransfers.sendto`, and
`get_val_from` works very much like `ParallelDataTransfers.getfrom`.

# Return value

A future with Nothing that can be fetched to see that the operation has
finished.

Examples:
    addprocs(1)
    save_at(2,:x,123)       # saves 123
    save_at(2,:x,myid())    # saves 1
    save_at(2,:x,:(myid())) # saves 2
    save_at(2,:x,:(:x))     # saves the symbol :x (just :x won't work because of unquoting)
"""
function save_at(worker, sym::Symbol, val)
    remotecall(()->eval(:(begin; $sym = $val; nothing; end)), worker)
end

"""
    get_from(worker,val)

Get a value `val` from a remote `worker`; quoting of `val` works just as with
`save_at`. Returns a future with the requested value.
"""
function get_from(worker, val)
    remotecall(()->eval(:($val)), worker)
end

"""
    get_val_from(worker,val)

Shortcut for instantly fetching the future from `get_from`.
"""
function get_val_from(worker, val)
    fetch(get_from(worker, val))
end

"""
    remove_from(worker,sym)

Sets symbol `sym` on `worker` to `nothing`, effectively freeing the data.
"""
function remove_from(worker, sym::Symbol)
    save_at(worker, sym, nothing)
end

"""
    distribute(sym, dd::DArray)

Distribute the distributed array parts from `dd` into worker-local variable
`sym`.

Requires @everywhere import DistributedArrays.

Returns the `LoadedDataInfo` structure for the distributed data.
"""
function distribute_darray(sym::Symbol, dd::DArray)
    for f in [save_at(pid, sym, :(DistributedArrays.localpart($dd)))
            for pid in dd.pids]
        fetch(f)
    end
    return LoadedDataInfo(sym, dd.pids)
end

"""
Load filenames to each referenced worker.

This is called transparently from `loadData`, but can be used to load and
distribute any list of file slices.

Long-term TODO:
reduce the arguments a bit (we have `distributed_transform` now!)
"""
function distribute_jls_data(sym::Symbol, fns::Array{String}, workers;
    panel=Nothing(), method="asinh", cofactor=5, reduce=false, sort=false, transform=false)
    for f in [save_at(pid, sym, :(
            loadDataFile($(fns[i]),
                         $panel, $method, $cofactor,
                         $reduce, $sort, $transform)))
            for (i, pid) in enumerate(workers)]
        fetch(f)
    end
end

"""
    undistribute_data(sym, workers)

Remove the loaded data from workers.
"""
function undistribute(sym::Symbol, workers)
    for f in [remove_from(pid,sym) for pid in workers]
        fetch(f)
    end
end

"""
    undistribute_data(dInfo::LoadedDataInfo)

Remove the loaded data described by `dInfo` from the corresponding workers.
"""
function undistribute(dInfo::LoadedDataInfo)
    undistribute(dInfo.val, dInfo.workers)
end

"""
    distributed_transform(sym::Symbol, fn::Function, workers)

Transform the worker-local distributed data stored as `sym` on `workers`
in-place, by a function `fn`.

# Example
    
    # multiply all saved data by 2
    distributed_transform(:myData, (d)->(2*d), workers())
"""
function distributed_transform(sym::Symbol, fn, workers)
    for f in [ save_at(pid, sym, :($fn($sym))) for pid in workers ]
        fetch(f)
    end
end

"""
    distributed_transform(dInfo::LoadedDataInfo, fn)

Distributed transformation of distributed data described by `dInfo`.
"""
function distributed_transform(dInfo::LoadedDataInfo, fn)
    for f in [ save_at(pid, sym, :($fn($sym))) for pid in workers ]
        fetch(f)
    end
end

"""
    distributed_mapreduce(val, map, fold, workers)

Run `map`s (non-modifying transforms on the data) and `fold`s (2-to-1
reductions) on the worker-local data (in `val`s) distributed on `workers` and
return the final reduced result.

It is assumed that the fold operation is associative, but not commutative (as
in semigroups). If there are no workers, operation returns `nothing` (we don't
have a monoid to magically conjure zero elements :[ ).

In current version, the reduce step is a sequential left fold, executed in the
main process.

# Example
    # compute the mean of all distributed data
    sum,len = distributed_mapreduce(:myData,
        (d) -> (sum(d),length(d)),
        ((s1, l1), (s2, l2)) -> (s1+s2, l1+l2),
        workers())
    println(sum/len)
"""
function distributed_mapreduce(val, map, fold, workers)
    if isempty(workers)
        return nothing
    end

    futures = [get_from(pid, :($map($val))) for pid in workers ]
    res = fetch(futures[1])
    for i in 2:length(futures)
        res = fold(res, fetch(futures[i]))
    end
    res
end

"""
    distributed_mapreduce(dInfo::LoadedDataInfo, map, fold)

Distributed map/reduce (just as the other overload of `distributed_mapreduce`)
that works with `LoadedDataInfo`.
"""
function distributed_mapreduce(dInfo::LoadedDataInfo, map, fold)
    distributed_mapreduce(dInfo.val, map, fold, dInfo.workers)
end
