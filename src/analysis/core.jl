"""
    initGigaSOM(data, args...)

Initializes a SOM by random selection from the training data. A generic
overload that works for matrices and DataFrames that can be coerced to
`Matrix{Float64}`. Other arguments are passed to the data-independent
`initGigaSOM`.

Arguments:
- `data`: matrix of data for running the initialization
"""
function initGigaSOM(data::Union{Matrix,DataFrame}, args...; kwargs...)

    d = Matrix{Float64}(data)

    (n, ncol) = size(d)
    means = [sum(d[:, i]) / n for i = 1:ncol]
    sdevs = [sqrt(sum((d[:, i] .- means[i]) .^ 2.0) / n) for i = 1:ncol]

    return initGigaSOM(ncol, means, sdevs, args...; kwargs...)
end

"""
    function initGigaSOM(data::LoadedDataInfo,
                         xdim::Int64, ydim::Int64 = xdim;
                         seed=rand(Int), rng=StableRNG(seed))

`initGigaSOM` overload for working with distributed-style `LoadedDataInfo`
data. The rest of the arguments is passed to the data-independent
`initGigaSOM`.

Arguments:
- `data`: a `LoadedDataInfo` object with the distributed dataset matrix
"""
function initGigaSOM(data::LoadedDataInfo, args...; kwargs...)
    ncol = get_val_from(data.workers[1], :(size($(data.val))[2]))
    (means, sdevs) = dstat(data, Vector(1:ncol))

    initGigaSOM(ncol, means, sdevs, args...; kwargs...)
end

"""
    function initGigaSOM(ncol::Int64,
                         means::Vector{Float64}, sdevs::Vector{Float64},
                         xdim::Int64, ydim::Int64 = xdim;
                         seed = rand(Int), rng = StableRNG(seed))

Generate a stable random initial SOM with the random distribution that matches the parameters.

Arguments:
- `ncol`: number of desired data columns
- `means`, `sdevs`: vectors that describe the data distribution, both of size `ncol`
- `xdim`, `ydim`: Size of the SOM
- `seed`: a seed (defaults to random seed from the current default random generator
- `rng`: a random number generator to be used (defaults to a `StableRNG` initialized with the `seed`)

Returns: a new `Som` structure
"""
function initGigaSOM(
    ncol::Int64,
    means::Vector{Float64},
    sdevs::Vector{Float64},
    xdim::Int64,
    ydim::Int64 = xdim;
    seed = rand(UInt),
    rng = StableRNG(seed),
)

    numCodes = xdim * ydim
    grid = gridRectangular(xdim, ydim)

    # Initialize with an unbiased random gaussian with same mean/sd as the data
    # in each dimension
    codes = randn(rng, (numCodes, ncol))
    for col = 1:ncol
        codes[:, col] .*= sdevs[col]
        codes[:, col] .+= means[col]
    end

    return Som(codes = codes, xdim = xdim, ydim = ydim, grid = grid)
end


"""
    trainGigaSOM(
        som::Som,
        dInfo::LoadedDataInfo;
        kernelFun::Function = gaussianKernel,
        metric = Euclidean(),
        somDistFun = distMatrix(Chebyshev()),
        knnTreeFun = BruteTree,
        rStart = 0.0,
        rFinal = 0.1,
        radiusFun = expRadius(-5.0),
        epochs = 20,
        eachEpoch = (e, r, codes) -> nothing,
    )

# Arguments:
- `som`: object of type Som with an initialised som
- `dInfo`: `LoadedDataInfo` object that describes a loaded dataset
- `kernelFun::function`: optional distance kernel; one of (`bubbleKernel, gaussianKernel`)
            default is `gaussianKernel`
- `metric`: Passed as metric argument to the KNN-tree constructor
- `somDistFun`: Function for computing the distances in the SOM map
- `knnTreeFun`: Constructor of the KNN-tree (e.g. from NearestNeighbors package)
- `rStart`: optional training radius. If zero (default), it is computed from the SOM grid size.
- `rFinal`: target radius at the last epoch, defaults to 0.1
- `radiusFun`: Function that generates radius decay, e.g. `linearRadius` or `expRadius(10.0)`
- `epochs`: number of SOM training iterations (default 10)
- `eachEpoch`: a function to call back after each epoch, accepting arguments
  `(epochNumber, radius, codes)`. For simplicity, this gets additionally called
  once before the first epoch, with `epochNumber` set to zero.
"""
function trainGigaSOM(
    som::Som,
    dInfo::LoadedDataInfo;
    kernelFun::Function = gaussianKernel,
    metric = Euclidean(),
    somDistFun = distMatrix(Chebyshev()),
    knnTreeFun = BruteTree,
    rStart = 0.0,
    rFinal = 0.1,
    radiusFun = expRadius(-5.0),
    epochs = 20,
    eachEpoch = (e, r, codes) -> nothing,
)

    # set the default radius
    if rStart == 0.0
        rStart = (som.xdim + som.ydim) / 2
        @debug "The radius has been determined automatically." rStart rFinal
    end

    # get the SOM neighborhood distances
    dm = somDistFun(som.grid)

    codes = som.codes

    eachEpoch(0, rStart, codes)

    for j = 1:epochs
        @debug "Epoch $j..."

        numerator, denominator = distributedEpoch(
            dInfo,
            codes,
            knnTreeFun(Array{Float64,2}(transpose(codes)), metric),
        )

        r = radiusFun(rStart, rFinal, j, epochs)
        @debug "radius: $r"
        if r <= 0
            @error "Sanity check failed: radius must be positive"
            error("Radius check")
        end

        wEpoch = kernelFun(dm, r)
        codes = (wEpoch * numerator) ./ (wEpoch * denominator)

        eachEpoch(epoch, r, codes)
    end

    som.codes = copy(codes)

    return som
end

"""
    trainGigaSOM(som::Som, train;
                 kwargs...)

Overload of `trainGigaSOM` for simple DataFrames and matrices. This slices the
data, distributes them to the workers, and runs normal `trainGigaSOM`. Data is
`undistribute`d after the computation.
"""
function trainGigaSOM(som::Som, train; kwargs...)

    train = Matrix{Float64}(train)

    #this slices the data into parts and and sends them to workers
    dInfo = distribute_array(:GigaSOMtrainDataVar, train, workers())
    som_res = trainGigaSOM(som, dInfo; kwargs...)
    undistribute(dInfo)
    return som_res
end


"""
    doEpoch(x::Array{Float64, 2}, codes::Array{Float64, 2}, tree)

vectors and the adjustment in radius after each epoch.

# Arguments:
- `x`: training Data
- `codes`: Codebook
- `tree`: knn-compatible tree built upon the codes
"""
function doEpoch(x::Array{Float64,2}, codes::Array{Float64,2}, tree)

    # initialise numerator and denominator with 0's
    sumNumerator = zeros(Float64, size(codes))
    sumDenominator = zeros(Float64, size(codes)[1])

    # for each sample in dataset / trainingsset
    for s = 1:size(x, 1)
        (bmuIdx, bmuDist) = knn(tree, x[s, :], 1)

        target = bmuIdx[1]

        sumNumerator[target, :] .+= x[s, :]
        sumDenominator[target] += 1
    end

    return sumNumerator, sumDenominator
end

"""
    distributedEpoch(dInfo::LoadedDataInfo, codes::Matrix{Float64}, tree)

Execute the `doEpoch` in parallel on workers described by `dInfo` and collect
the results. Returns pair of numerator and denominator matrices.
"""
function distributedEpoch(dInfo::LoadedDataInfo, codes::Matrix{Float64}, tree)
    return distributed_mapreduce(
        dInfo,
        (data) -> doEpoch(data, codes, tree),
        ((n1, d1), (n2, d2)) -> (n1 + n2, d1 + d2),
    )
end


"""
    mapToGigaSOM(som::Som, dInfo::LoadedDataInfo;
        knnTreeFun = BruteTree, metric = Euclidean(),
        output::Symbol=tmpSym(dInfo)::LoadedDataInfo

Compute the index of the BMU for each row of the input data.

# Arguments
- `som`: a trained SOM
- `dInfo`: `LoadedDataInfo` that describes the loaded and distributed data
- `knnTreeFun`: Constructor of the KNN-tree (e.g. from NearestNeighbors package)
- `metric`: Passed as metric argument to the KNN-tree constructor
- `output`: Symbol to save the result, defaults to `tmpSym(dInfo)`

Data must have the same number of dimensions as the training dataset
and will be normalised with the same parameters.
"""
function mapToGigaSOM(
    som::Som,
    dInfo::LoadedDataInfo;
    knnTreeFun = BruteTree,
    metric = Euclidean(),
    output::Symbol = tmpSym(dInfo),
)::LoadedDataInfo

    tree = knnTreeFun(Array{Float64,2}(transpose(som.codes)), metric)

    return distributed_transform(
        dInfo,
        (d) -> (vcat(knn(tree, transpose(d), 1)[1]...)),
        output,
    )
end

"""
    mapToGigaSOM(som::Som, data;
                 knnTreeFun = BruteTree,
                 metric = Euclidean())
Overload of `mapToGigaSOM` for simple DataFrames and matrices. This slices the
data using `DistributedArrays`, sends them the workers, and runs normal
`mapToGigaSOM`. Data is `undistribute`d after the computation.
"""
function mapToGigaSOM(som::Som, data; knnTreeFun = BruteTree, metric = Euclidean())

    data = Matrix{Float64}(data)

    if size(data, 2) != size(som.codes, 2)
        @error "Data dimension ($(size(data,2))) does not match codebook dimension ($(size(som.codes,2)))."
        error("Data dimensions do not match")
    end

    dInfo = distribute_array(:GigaSOMmappingDataVar, data, workers())
    rInfo = mapToGigaSOM(som, dInfo, knnTreeFun = knnTreeFun, metric = metric)
    res = distributed_collect(rInfo)
    undistribute(dInfo)
    undistribute(rInfo)
    return DataFrame(index = res)
end

"""
    scaleEpochTime(iteration::Int64, epochs::Int64)

Convert iteration ID and epoch number to relative time in training.
"""
function scaleEpochTime(iteration::Int64, epochs::Int64)
    # prevent division by zero on 1-epoch training
    if epochs > 1
        epochs -= 1
    end

    return Float64(iteration - 1) / Float64(epochs)
end
