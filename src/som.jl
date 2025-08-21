"""
$(TYPEDSIGNATURES)

Initializes a SOM by random selection from the training data. A generic
overload that works for matrices and DataFrames that can be coerced to
`Matrix{Float64}`. Other arguments are passed to the data-independent
`init`.

Arguments:
- `data`: matrix of data for running the initialization
"""
function init(data::Union{Matrix,DataFrame}, args...; kwargs...)

    d = Matrix{Float64}(data)

    (n, ncol) = size(d)
    means = [sum(d[:, i]) / n for i = 1:ncol]
    sdevs = [sqrt(sum((d[:, i] .- means[i]) .^ 2.0) / n) for i = 1:ncol]

    return init(ncol, means, sdevs, args...; kwargs...)
end

"""
$(TYPEDSIGNATURES)

`init` overload for working with distributed-style `Dinfo`
data. The rest of the arguments is passed to the data-independent
`init`.

Arguments:
- `data`: a `Dinfo` object with the distributed dataset matrix
"""
function init(data::Dinfo, args...; kwargs...)
    ncol = get_val_from(data.workers[1], :(size($(data.val))[2]))
    (means, sdevs) = dstat(data, Vector(1:ncol))

    init(ncol, means, sdevs, args...; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Generate a stable random initial SOM with the random distribution that matches the parameters.

Arguments:
- `ncol`: number of desired data columns
- `means`, `sdevs`: vectors that describe the data distribution, both of size `ncol`
- `xdim`, `ydim`: Size of the SOM
- `seed`: a seed (defaults to random seed from the current default random generator
- `rng`: a random number generator to be used (defaults to a `StableRNG` initialized with the `seed`)

Returns: a new `SOM` structure
"""
function init(
    ncol::Int64,
    means::Vector{Float64},
    sdevs::Vector{Float64},
    xdim::Int64,
    ydim::Int64 = xdim;
    seed = rand(UInt),
    rng = StableRNG(seed),
)

    numCodes = xdim * ydim
    grid = grid_rectangular(xdim, ydim)

    # Initialize with an unbiased random gaussian with same mean/sd as the data
    # in each dimension
    codes = randn(rng, (numCodes, ncol))
    for col = 1:ncol
        codes[:, col] .*= sdevs[col]
        codes[:, col] .+= means[col]
    end

    return SOM(codes = codes, xdim = xdim, ydim = ydim, grid = grid)
end

export init

"""
$(TYPEDSIGNATURES)

# Arguments:
- `som`: object of type SOM with an initialised som
- `dInfo`: `Dinfo` object that describes a loaded dataset
- `kernelFun::function`: optional distance kernel; one of (`kernel_bubble, kernel_gaussian`)
            default is `kernel_gaussian`
- `metric`: Passed as metric argument to the KNN-tree constructor
- `somDistFun`: Function for computing the distances in the SOM map
- `knnTreeFun`: Constructor of the KNN-tree (e.g. from NearestNeighbors package)
- `rStart`: optional training radius. If zero (default), it is computed from the SOM grid size.
- `rFinal`: target radius at the last epoch, defaults to 0.1
- `radiusFun`: Function that generates radius decay, e.g. `radius_linear` or `radius_exp(10.0)`
- `epochs`: number of SOM training iterations (default 10)
- `eachEpoch`: a function to call back after each epoch, accepting arguments
  `(epochNumber, radius, som)`. For simplicity, this gets additionally called
  once before the first epoch, with `epochNumber` set to zero.
"""
function train(
    som::SOM,
    dInfo::Dinfo;
    kernelFun::Function = kernel_gaussian,
    metric = Euclidean(),
    somDistFun = distance_matrix(Chebyshev()),
    knnTreeFun = BruteTree,
    rStart = 0.0,
    rFinal = 0.1,
    radiusFun = radius_exp(-5.0),
    epochs = 20,
    eachEpoch = (e, r, som) -> nothing,
)

    # set the default radius
    if rStart == 0.0
        rStart = (som.xdim + som.ydim) / 2
        @debug "The radius has been determined automatically." rStart rFinal
    end

    # get the SOM neighborhood distances
    dm = somDistFun(som.grid)

    result_som = copy(som)
    result_som.codes = copy(som.codes) # prevent rewriting by reference

    eachEpoch(0, rStart, result_som)

    for epoch = 1:epochs
        @debug "Epoch $epoch..."

        numerator, denominator = run_epoch_distributed(
            dInfo,
            result_som.codes,
            knnTreeFun(Array{Float64,2}(transpose(result_som.codes)), metric),
        )

        r = radiusFun(rStart, rFinal, epoch, epochs)
        @debug "radius: $r"
        if r <= 0
            @error "Sanity check failed: radius must be positive"
            error("Radius check")
        end

        wEpoch = kernelFun(dm, r)
        result_som.codes = (wEpoch * numerator) ./ (wEpoch * denominator)

        eachEpoch(epoch, r, result_som)
    end

    return result_som
end

"""
$(TYPEDSIGNATURES)

Overload of `train` for simple DataFrames and matrices. This slices the
data, distributes them to the workers, and runs normal `train`. Data is
`unscatter`d after the computation.
"""
function train(som::SOM, train; kwargs...)

    train = Matrix{Float64}(train)

    #this slices the data into parts and and sends them to workers
    dInfo = scatter_array(:GigaSOMtrainDataVar, train, workers())
    som_res = train(som, dInfo; kwargs...)
    unscatter(dInfo)
    return som_res
end

export train

"""
$(TYPEDSIGNATURES)

vectors and the adjustment in radius after each epoch.

# Arguments:
- `x`: training Data
- `codes`: Codebook
- `tree`: knn-compatible tree built upon the codes
"""
function run_epoch(x::Array{Float64,2}, codes::Array{Float64,2}, tree)

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
$(TYPEDSIGNATURES)

Execute the `run_epoch` in parallel on workers described by `dInfo` and collect
the results. Returns pair of numerator and denominator matrices.
"""
function run_epoch_distributed(dInfo::Dinfo, codes::Matrix{Float64}, tree)
    return dmapreduce(
        dInfo,
        (data) -> run_epoch(data, codes, tree),
        ((n1, d1), (n2, d2)) -> (n1 + n2, d1 + d2),
    )
end

"""
$(TYPEDSIGNATURES)

Compute the index of the BMU for each row of the input data.

# Arguments
- `som`: a trained SOM
- `dInfo`: `Dinfo` that describes the loaded and distributed data
- `knnTreeFun`: Constructor of the KNN-tree (e.g. from NearestNeighbors package)
- `metric`: Passed as metric argument to the KNN-tree constructor
- `output`: Symbol to save the result, defaults to `tmp_symbol(dInfo)`

Data must have the same number of dimensions as the training dataset
and will be normalised with the same parameters.
"""
function assign(
    som::SOM,
    dInfo::Dinfo;
    knnTreeFun = BruteTree,
    metric = Euclidean(),
    output::Symbol = tmp_symbol(dInfo),
)::Dinfo

    tree = knnTreeFun(Array{Float64,2}(transpose(som.codes)), metric)

    return dtransform(dInfo, (d) -> (vcat(knn(tree, transpose(d), 1)[1]...)), output)
end

"""
$(TYPEDSIGNATURES)

Overload of `assign` for simple DataFrames and matrices. This slices the
data using `DistributedArrays`, sends them the workers, and runs normal
`assign`. Data is `unscatter`d after the computation.
"""
function assign(som::SOM, data; knnTreeFun = BruteTree, metric = Euclidean())

    data = Matrix{Float64}(data)

    if size(data, 2) != size(som.codes, 2)
        @error "Data dimension ($(size(data,2))) does not match codebook dimension ($(size(som.codes,2)))."
        error("Data dimensions do not match")
    end

    dInfo = scatter_array(:GigaSOMmappingDataVar, data, workers())
    rInfo = assign(som, dInfo, knnTreeFun = knnTreeFun, metric = metric)
    res = gather_array(rInfo)
    unscatter(dInfo)
    unscatter(rInfo)
    return DataFrame(index = res)
end

export assign

"""
$(TYPEDSIGNATURES)

Convert iteration ID and epoch number to relative time in training.
"""
scaled_epoch_time(iteration::Int64, epochs::Int64) =
    Float64(iteration - 1) / Float64(max(epochs, 1))
