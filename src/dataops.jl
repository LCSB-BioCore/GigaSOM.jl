
"""
    dcopy(dInfo::LoadedDataInfo, newName::Symbol)

Copy the dataset into a new place.
"""
function dcopy(dInfo::LoadedDataInfo, newName::Symbol)::LoadedDataInfo
    distributed_transform(dInfo, x->x, newName)
end

"""
    dselect(dInfo::LoadedDataInfo, columns::Vector{Int}; tgt=dInfo.val)

Reduce dataset to selected columns, optionally save it under a different name.
"""
function dselect(dInfo::LoadedDataInfo, columns::Vector{Int}, tgt::Symbol=dInfo.val)::LoadedDataInfo
    distributed_transform(dInfo, mtx->mtx[:,columns], tgt)
end

"""
    function dselect(dInfo::LoadedDataInfo,
        currentColnames::Vector{String}, selectColnames::Vector{String};
        tgt=dInfo.val)::LoadedDataInfo

Convenience overload of `dselect` that works with column names.
"""
function dselect(dInfo::LoadedDataInfo,
    currentColnames::Vector{String}, selectColnames::Vector{String},
    tgt=dInfo.val)::LoadedDataInfo
    dselect(dInfo, colnameIndexes(currentColnames, selectColnames), tgt)
end

"""
    colnameIndexes(colnames::Vector{String}, query::Vector{String})

Return indexes of `query` items in `colnames`; returns `0` if the query item
was not found.

Useful for getting the column indexes for functions like `dapply_cols` by
names.
"""
function colnameIndexes(colnames::Vector{String}, query::Vector{String})::Vector{Int}
    [begin
        idx = findfirst(x -> x==q, colnames)
        if idx == nothing
            idx = 0
        end
        idx
    end for q in query ]
end

"""
    dapply_cols(dInfo::LoadedDataInfo, fn, columns::Vector{Int})

Apply a function `fn` over columns of a distributed dataset.

`fn` gets 2 parameters:
- a data vector for (the whole column saved at one worker)
- index of the column in the `columns` array (i.e. a number from
  `1:length(columns)`)
"""
function dapply_cols(dInfo::LoadedDataInfo, fn, columns::Vector{Int})
    distributed_mapreduce(dInfo,
        x -> (
            for (idx,c) in enumerate(columns)
                x[:,c]=fn(x[:,c], idx)
            end
        ), (_,_) -> nothing)
end

"""
    dapply_rows(dInfo::LoadedDataInfo, fn)

Apply a function `fn` over rows of a distributed dataset.

`fn` gets a single vector parameter for each row to transform.
"""
function dapply_rows(dInfo::LoadedDataInfo, fn)
    distributed_mapreduce(dInfo,
        x -> (
            for i in 1:size(x,1)
                x[i,:]=fn(x[i,:])
            end
        ), (_,_) -> nothing)
end

"""
    dstat(dInfo::LoadedDataInfo, columns::Vector{Int})

Compute mean and standard deviation of the columns in dataset. Returns a tuple
with a vector of means in `columns`, and a vector of corresponding sdevs.
"""
function dstat(dInfo::LoadedDataInfo, columns::Vector{Int})
    (s, sqs, n) = distributed_mapreduce(dInfo,
        d->(mapslices(sum, d[:,columns], dims=1),
            mapslices((x)->sum(x.^2), d[:,columns], dims=1),
            mapslices(x->length(x), d[:,columns], dims=1)),
        ((s1, sqs1, n1), (s2, sqs2, n2)) ->
            (s1.+s2, sqs1.+sqs2, n1.+n2))
    return (s./n, sqrt.(sqs./n - (s./n).^2))
end

"""
    dscale(dInfo::LoadedDataInfo, columns::Vector{Int})

Scale the columns in the dataset to have mean 0 and sdev 1.

Prevents creation of NaNs by avoiding division by zero sdevs.
"""
function dscale(dInfo::LoadedDataInfo, columns::Vector{Int})
    mean, sd = dstat(dInfo, columns)
    for i in 1:length(sd)
        if sd[i]==0
            sd[i]=1
        end
    end
    dapply_cols(dInfo, (v,idx) -> (v.-mean[idx])./sd[idx], columns)
end

"""
    dtransform_asinh(dInfo::LoadedDataInfo, columns::Vector{Int}, cofactor=5)

Transform columns of the dataset by asinh transformation with `cofactor`.
"""
function dtransform_asinh(dInfo::LoadedDataInfo, columns::Vector{Int}, cofactor=5)
    dapply_cols(dInfo, (v,_) -> asinh.(v./cofactor), columns)
end
