
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
    colIdxs = indexin(selectColnames, currentColnames)
    if any(colIdxs.==nothing)
        @error "Some columns were not found"
        error("unknown column")
    end
    dselect(dInfo, Vector{Int}(colIdxs), tgt)
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
    dstat_buckets(dInfo::LoadedDataInfo, nbuckets::Int, buckets::LoadedDataInfo, columns::Vector{Int})

A version of `dstat` that works with bucketing information (e.g. clusters).
"""
function dstat_buckets(dInfo::LoadedDataInfo, nbuckets::Int, buckets::LoadedDataInfo, columns::Vector{Int})
    (sums, sqsums, ns) = distributed_mapreduce([dInfo, buckets],
        (d,b)->(catmapbuckets((_,x) -> sum(x), d[:,columns], nbuckets, b),
            catmapbuckets((_,x)->sum(x.^2), d[:,columns], nbuckets, b),
            catmapbuckets((_,x)->length(x), d[:,columns], nbuckets, b)),
        ((s1, sqs1, n1), (s2, sqs2, n2)) ->
            (s1.+s2, sqs1.+sqs2, n1.+n2))
    return (sums./ns, sqrt.(sqsums./ns - (sums./ns).^2))
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

"""
    mapbuckets(a::Array, nbuckets::Int, buckets::Vector{Int}, map; bucketdim::Int=1, slicedims=1)

Apply the function `map` over array `a` so that it processes the data by
buckets defined by `buckets` (that contains integers in range `1:nbuckets`).

The buckets are sliced out in dimension specified by `bucketdim`.
"""
function mapbuckets(map, a::Array, nbuckets::Int, buckets::Vector{Int}; bucketdim::Int=1, slicedims=1)
    ndims = length(size(a))
    sx = [ i == bucketdim ? (0 .== buckets) : (1:size(a,i)) for i in 1:ndims]
    [begin
        sx[bucketdim] = bucket.==buckets
        mapslices(x -> map(bucket, x), a[sx...], dims=slicedims)
    end for bucket in 1:nbuckets]
end

function catmapbuckets(map, a::Array, nbuckets::Int, buckets::Vector{Int}; bucketdim::Int=1)
    cat(mapbuckets(map, a, nbuckets, buckets, bucketdim=bucketdim, slicedims=bucketdim)..., dims=bucketdim)
end

"""
    dmedian(dInfo::LoadedDataInfo, columns::Vector{Int})

Compute a median in a distributed fashion, avoiding data transfer and memory
capacity that is required to compute the median in the classical way by
sorting. All data must be finite and defined. If the median is just between 2
values, the lower one is chosen.

The algorithm is approximative, searching for a good median by halving interval
and counting how many values are below the threshold. `iters` can be increased
to improve precision, each value adds roughly 1 bit to the precision. The
default value is 20, which corresponds to precision 10e-6 times the data range.
"""
function dmedian(dInfo::LoadedDataInfo, columns::Vector{Int}; iters=20)
    target = distributed_mapreduce(dInfo, d -> size(d,1), +) ./ 2
    lims = distributed_mapreduce(dInfo,
        d -> mapslices(extrema, d[:,columns], dims=1),
        (ex1, ex2) -> (((a,b),(c,d)) -> (min(a,c), max(b,d))).(ex1,ex2))
    lims=cat(lims..., dims=1)
    for iter in 1:iters
        mids = sum.(lims) ./ 2
        counts = distributed_mapreduce(dInfo,
            d -> [count(x -> x<mids[i], d[:,c])
                for (i,c) in enumerate(columns)], +)
        lims = ((cnt, target, lim, mid) -> cnt>=target ? (lim[1],mid) : (mid,lim[2])).(counts,target,lims,mids)
    end

    sum.(lims) ./ 2
end

"""
    dmedian_buckets(dInfo::LoadedDataInfo, nbuckets::Int, buckets::LoadedDataInfo, columns::Vector{Int}; iters=20)

A version of `dmedian` that works with the bucketing information (i.e.
clusters) from `nbuckets` and `buckets`.
"""
function dmedian_buckets(dInfo::LoadedDataInfo, nbuckets::Int, buckets::LoadedDataInfo, columns::Vector{Int}; iters=20)
    targets = distributed_mapreduce([dInfo, buckets],
        (d,b) -> catmapbuckets((_,x) -> size(x,1), d[:,columns], nbuckets, b), +) ./ 2
    lims = distributed_mapreduce([dInfo, buckets],
        (d,b) -> catmapbuckets((_,x) -> length(x)>0 ? extrema(x) : (Inf, -Inf), d[:,columns], nbuckets, b),
        (ex1, ex2) -> (((a,b),(c,d)) -> (min(a,c), max(b,d))).(ex1,ex2))

    for iter in 1:iters
        mids = sum.(lims) ./ 2
        counts = distributed_mapreduce([dInfo, buckets],
            (d, b) -> vcat(
                mapbuckets((bid, d) -> [count(x -> x<mids[bid,cid], d[:,cid])
                             for (cid,c) in enumerate(columns)]',
                            d, nbuckets, b, slicedims=(1,2))...), +)
        lims = ((cnt, target, lim, mid) -> cnt>=target ? (lim[1],mid) : (mid,lim[2])).(counts,targets,lims,mids)
    end

    sum.(lims) ./ 2
end
