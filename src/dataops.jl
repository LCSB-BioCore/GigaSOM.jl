
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

`fn` gets _2_ parameters:
- a data vector for (the whole column saved at one worker)
- index of the column in the `columns` array (i.e. a number from
  `1:length(columns)`)
"""
function dapply_cols(dInfo::LoadedDataInfo, fn, columns::Vector{Int})
    transform_columns = x ->
        for (idx,c) in enumerate(columns)
            x[:,c]=fn(x[:,c], idx)
        end

    distributed_exec(dInfo, transform_columns)
end

"""
    dapply_rows(dInfo::LoadedDataInfo, fn)

Apply a function `fn` over rows of a distributed dataset.

`fn` gets a single vector parameter for each row to transform.
"""
function dapply_rows(dInfo::LoadedDataInfo, fn)
    transform_rows = x ->
        for i in 1:size(x,1)
            x[i,:]=fn(x[i,:])
        end

    distributed_exec(dInfo, transform_rows)
end

"""
    combine_stats((s1, sqs1, n1), (s2, sqs2, n2))

Helper for `dstat`-style functions that just adds up elements in triplets of
vectors.
"""
function combine_stats((s1, sqs1, n1), (s2, sqs2, n2))
    return (s1.+s2, sqs1.+sqs2, n1.+n2)
end

"""
    dstat(dInfo::LoadedDataInfo, columns::Vector{Int})

Compute mean and standard deviation of the columns in dataset. Returns a tuple
with a vector of means in `columns`, and a vector of corresponding sdevs.
"""
function dstat(dInfo::LoadedDataInfo, columns::Vector{Int})

    sum_squares = x -> sum(x.^2)

    # extraction of the statistics from individual dataset slices
    get_stats = d -> (
        mapslices(sum,         d[:,columns], dims=1),
        mapslices(sum_squares, d[:,columns], dims=1),
        mapslices(length,      d[:,columns], dims=1)
    )

    # extract the stats
    (sums, sqsums, ns) =
        distributed_mapreduce(dInfo, get_stats, combine_stats)

    return (
        sums./ns, #means
        sqrt.(sqsums./ns - (sums./ns).^2) #sdevs
    )
end

"""
    dstat_buckets(dInfo::LoadedDataInfo, nbuckets::Int, buckets::LoadedDataInfo, columns::Vector{Int})

A version of `dstat` that works with bucketing information (e.g. clusters).
"""
function dstat_buckets(dInfo::LoadedDataInfo, nbuckets::Int, buckets::LoadedDataInfo, columns::Vector{Int})
    # this produces a triplet of matrices (1 row per each bucket)
    get_bucketed_stats = (d, b) -> (
        catmapbuckets((_,x) -> sum(x),    d[:,columns], nbuckets, b), # sums
        catmapbuckets((_,x) -> sum(x.^2), d[:,columns], nbuckets, b), # squared sums
        catmapbuckets((_,x) -> length(x), d[:,columns], nbuckets, b)  # data sizes
    )

    # extract the bucketed stats
    (sums, sqsums, ns) =
        distributed_mapreduce([dInfo, buckets],
                              get_bucketed_stats,
                              combine_stats)

    return (
        sums./ns, #means
        sqrt.(sqsums./ns - (sums./ns).^2) #sdevs
    )
end

"""
    dscale(dInfo::LoadedDataInfo, columns::Vector{Int})

Scale the columns in the dataset to have mean 0 and sdev 1.

Prevents creation of NaNs by avoiding division by zero sdevs.
"""
function dscale(dInfo::LoadedDataInfo, columns::Vector{Int})
    mean, sd = dstat(dInfo, columns)
    sd[sd.==0] .= 1 # prevent division by zero

    normalize = (coldata,idx) ->
        (coldata.-mean[idx])./sd[idx]

    dapply_cols(dInfo, normalize, columns)
end

"""
    dtransform_asinh(dInfo::LoadedDataInfo, columns::Vector{Int}, cofactor=5)

Transform columns of the dataset by asinh transformation with `cofactor`.
"""
function dtransform_asinh(dInfo::LoadedDataInfo, columns::Vector{Int}, cofactor=5)
    dapply_cols(dInfo,
        (v,_) -> asinh.(v./cofactor),
        columns)
end

"""
    mapbuckets(fn, a::Array, nbuckets::Int, buckets::Vector{Int}; bucketdim::Int=1, slicedims=bucketdim)

Apply the function `fn` over array `a` so that it processes the data by
buckets defined by `buckets` (that contains integers in range `1:nbuckets`).

The buckets are sliced out in dimension specified by `bucketdim`.
"""
function mapbuckets(fn, a::Array, nbuckets::Int, buckets::Vector{Int}; bucketdim::Int=1, slicedims=bucketdim)
    ndims = length(size(a))

    # precompute the range of the array
    extent = [ i == bucketdim ? (0 .== buckets) : (1:size(a,i)) for i in 1:ndims]

    # return a list of reduced dataset for each bucket
    return [ begin
            # replace the bucketing dimension in the extent by the filter for current bucket
            extent[bucketdim] = bucket.==buckets
            # reduce the array and run the operation
            mapslices(x -> fn(bucket, x), a[extent...], dims=slicedims)
        end for bucket in 1:nbuckets]
end

"""
    catmapbuckets(fn, a::Array, nbuckets::Int, buckets::Vector{Int}; bucketdim::Int=1)

Same as `mapbuckets`, except concatenates the bucketing results in the
bucketing dimension, thus creating a slightly neater matrix. `slicedims` is
therefore fixed to `bucketdim`.
"""
function catmapbuckets(fn, a::Array, nbuckets::Int, buckets::Vector{Int}; bucketdim::Int=1)
    cat(mapbuckets(fn, a, nbuckets, buckets, bucketdim=bucketdim, slicedims=bucketdim)...,
        dims=bucketdim)
end


"""
    collect_extrema(ex1, ex2)

Helper for collecting the minimums and maximums of the data. `ex1`, `ex2` are
arrays of pairs (min,max), this function combines the arrays element-wise and
finds combined minima and maxima.
"""
function collect_extrema(ex1, ex2)
    broadcast(
        ((a,b),(c,d)) -> (min(a,c), max(b,d)),
        ex1, ex2)
end

"""
    update_extrema(counts, target, lim, mid)

Helper for distributed median computation -- returns updated extrema in `lims`
depending on whether the item count in `counts` of values less than `mids` is
less or higher than `targets`.
"""
function update_extrema(counts, targets, lims, mids)
    broadcast(
        (cnt, target, lim, mid) ->
            cnt >= target ? # if the count is too high,
                (lim[1],mid) : # median is going to be in the lower half
                (mid,lim[2]),  # otherwise in the higher half
        counts,
        targets,
        lims,
        mids)
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
    # how many items in the dataset should be smaller than the median (roughly size/2)
    target = distributed_mapreduce(dInfo,
                                   d -> size(d,1),
                                   +) ./ 2

    # current estimation range for the median (tuples of min, max)
    lims = distributed_mapreduce(dInfo,
        d -> mapslices(extrema, d[:,columns], dims=1),
        collect_extrema)

    # convert the limits to a simple vector
    lims=cat(lims..., dims=1)

    for iter in 1:iters
        mids = sum.(lims) ./ 2

        count_smaller_than_mids = d -> [
            count(x -> x<mids[i], d[:,c])
            for (i,c) in enumerate(columns)
        ]

        # compute the total number of elements smaller than `mids`
        counts = distributed_mapreduce(dInfo, count_smaller_than_mids, +)

        # update lims into lower/upper half depending on whether the count was
        # lower or higher than target
        lims = update_extrema(counts, target, lims, mids)
    end

    return sum.(lims) ./ 2
end

"""
    dmedian_buckets(dInfo::LoadedDataInfo, nbuckets::Int, buckets::LoadedDataInfo, columns::Vector{Int}; iters=20)

A version of `dmedian` that works with the bucketing information (i.e.
clusters) from `nbuckets` and `buckets`.
"""
function dmedian_buckets(dInfo::LoadedDataInfo, nbuckets::Int, buckets::LoadedDataInfo, columns::Vector{Int}; iters=20)
    # count things in the buckets (produces a matrix with one row per bucket,
    # one column for `columns`)
    targets = distributed_mapreduce([dInfo, buckets],
        (d,b) -> catmapbuckets((_,x) -> size(x,1), d[:,columns], nbuckets, b),
        +) ./ 2

    # measure the minima and maxima of the datasets. In case the bucket is not
    # present in the data partition, `extrema()` fails, so we replace it with
    # `(Inf, -Inf)` which will eventually get coalesced with other numbers to
    # normal values.
    get_bucket_extrema = (d, b) ->
        catmapbuckets(
            (_,x) -> length(x)>0 ? # if there are some elements
                extrema(x) : # just take the extrema
                (Inf, -Inf), # if not, use backup values
            d[:,columns],
            nbuckets, b)

    # collect the extrema
    lims = distributed_mapreduce([dInfo, buckets],
        get_bucket_extrema, collect_extrema)

    for iter in 1:iters
        mids = sum.(lims) ./ 2

        # this counts the elements smaller than mids in buckets
        # (both mids and elements are bucketed and column-sliced into matrices)
        bucketed_count_smaller_than_mids = (d, b) ->
            vcat(mapbuckets(
                (bucketID, d) ->
                    [count(x -> x<mids[bucketID,colID], d[:,colID])
                     for (colID,c) in enumerate(columns)]',
                d, nbuckets, b, slicedims=(1,2))...)

        # collect the counts
        counts = distributed_mapreduce([dInfo, buckets],
            bucketed_count_smaller_than_mids, +)

        lims = update_extrema(counts, targets, lims, mids)
    end

    return sum.(lims) ./ 2
end
