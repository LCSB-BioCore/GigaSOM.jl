"""
    defaultFiles(s, pids)

Make a good set of filenames for saving a dataset.
"""
function defaultFiles(s, pids)
    return [String(s)*"-$i.slice" for i in eachindex(pids)]
end

"""
    distributed_export(sym::Symbol, pids, files=defaultFiles(sym,pids))

Export the content of symbol `sym` by each worker specified by `pids` to a
corresponding filename in `files`.
"""
function distributed_export(sym::Symbol, pids, files=defaultFiles(sym,pids))
    distributed_foreach(files,
        (fn)->Base.eval(Main,
            :(begin
                open(f->$serialize(f, $sym), $fn, "w")
                nothing
            end)), pids)
    nothing
end

"""
    distributed_export(dInfo::LoadedDataInfo, files=defaultFiles(dInfo.val, dInfo.workers))

Overloaded functionality for `LoadedDataInfo`.
"""
function distributed_export(dInfo::LoadedDataInfo, files=defaultFiles(dInfo.val, dInfo.workers))
    distributed_export(dInfo.val, dInfo.workers, files)
end

"""
    distributed_import(sym::Symbol, pids, files=defaultFiles(sym,pids))

Import the content of symbol `sym` by each worker specified by `pids` from the
corresponding filename in `files`.
"""
function distributed_import(sym::Symbol, pids, files=defaultFiles(sym,pids))
    distributed_foreach(files,
        (fn)->Base.eval(Main,
            :(begin
                $sym = open($deserialize, $fn)
                nothing
            end)), pids)
    return LoadedDataInfo(sym, pids)
end

"""
    distributed_import(dInfo::LoadedDataInfo, files=defaultFiles(dInfo.val, dInfo.workers))

Overloaded functionality for `LoadedDataInfo`.
"""
function distributed_import(dInfo::LoadedDataInfo, files=defaultFiles(dInfo.val, dInfo.workers))
    distributed_import(dInfo.val, dInfo.workers, files)
end

"""
    distributed_unlink(sym::Symbol, pids, files=defaultFiles(sym,pids))

Remove the files created by `distributed_export` with the same parameters.
"""
function distributed_unlink(sym::Symbol, pids, files=defaultFiles(sym,pids))
    distributed_foreach(files, (fn)->rm(fn), pids)
    nothing
end

"""
    distributed_unlink(dInfo::LoadedDataInfo, files=defaultFiles(dInfo.val, dInfo.workers))

Overloaded functionality for `LoadedDataInfo`.
"""
function distributed_unlink(dInfo::LoadedDataInfo, files=defaultFiles(dInfo.val, dInfo.workers))
    distributed_unlink(dInfo.val, dInfo.workers, files)
end
