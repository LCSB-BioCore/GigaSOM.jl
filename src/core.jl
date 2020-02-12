"""
    initGigaSOM(train, xdim, ydim = xdim;
                norm::Symbol = :none, toroidal = false)

Initializes a SOM by random selection from the training data.

# Arguments:
- `train`: codeBook vector as random input matrix from random workers
- `xdim, ydim`: geometry of the SOM
- `norm`: optional normalisation
- `toroidal`: optional flag; if true, the SOM is toroidal.
"""
function initGigaSOM(train, xdim::Int64, ydim :: Int64 = xdim;
                     norm::Symbol = :none, toroidal = false)

    if typeof(train) == DataFrame
        colNames = [String(x) for x in names(train)]
    else
        colNames = ["x$i" for i in 1:size(train,2)]
        @debug "assuming default colNames"
    end

    train = convertTrainingData(train)

    numCodes = xdim * ydim

    # normalise training data:
    # TODO: is this needed here?
    train, normParams = normTrainData(train, norm)

    # initialise the codes with random samples
    codes = train[rand(1:size(train,1), numCodes),:]
    grid = gridRectangular(xdim, ydim)

    normParams = convert(DataFrame, normParams)
    rename!(normParams, Symbol.(colNames))

    # create X,Y-indices for neurons:
    #
    x = y = collect(1:numCodes)
    indices = DataFrame(X = x, Y = y)

    # make SOM object:
    som = Som(codes = codes, colNames = colNames,
           normParams = normParams, norm = norm,
           xdim = xdim, ydim = ydim,
           numCodes = numCodes,
           grid = grid, indices = indices,
           toroidal = toroidal,
           population = zeros(Int, numCodes))
    return som
end

"""
    initGigaSOM(trainInfo::LoadedDataInfo,
                xdim::Int64, ydim :: Int64 = xdim;
                norm::Symbol = :none, toroidal = false)

`initGigaSOM` overloaded for working distributed `LoadedDataInfo` in
`trainInfo`. The rest of arguments is the same.

It uses the data saved on the first worker for initialization, the init work is
actually done on that worker to avoid data copying.
"""
function initGigaSOM(trainInfo::LoadedDataInfo,
    xdim::Int64, ydim :: Int64 = xdim;
    norm::Symbol = :none, toroidal = false)

    # Snatch the init data from the first available worker (for he cares not).
    return get_val_from(trainInfo.workers[1],
        Expr(:call, :initGigaSOM, trainInfo.val,
             xdim, ydim,
             Expr(:kw, :norm, QuoteNode(norm)),
             Expr(:kw, :toroidal, toroidal)))
end

"""
    trainGigaSOM(som::Som, dInfo::LoadedDataInfo;
                 kernelFun::Function = gaussianKernel,
                 metric = Euclidean(),
                 knnTreeFun = BruteTree,
                 rStart = 0.0, rFinal=0.1, radiusFun=linearRadius,
                 epochs = 10)

# Arguments:
- `som`: object of type Som with an initialised som
- `dInfo`: `LoadedDataInfo` object that describes a loaded dataset
- `kernelFun::function`: optional distance kernel; one of (`bubbleKernel, gaussianKernel`)
            default is `gaussianKernel`
- `metric`: Passed as metric argument to the KNN-tree constructor
- `knnTreeFun`: Constructor of the KNN-tree (e.g. from NearestNeighbors package)
- `rStart`: optional training radius. If zero (default), it is computed from the SOM grid size.
- `rFinal`: target radius at the last epoch, defaults to 0.1
- `radiusFun`: Function that generates radius decay, e.g. `linearRadius` or `expRadius(10.0)`
- `epochs`: number of SOM training iterations (default 10)
"""
function trainGigaSOM(som::Som, dInfo::LoadedDataInfo;
                      kernelFun::Function = gaussianKernel,
                      metric = Euclidean(),
                      knnTreeFun = BruteTree,
                      rStart = 0.0, rFinal=0.1, radiusFun=linearRadius,
                      epochs = 10)

    # set the default radius
    if rStart == 0.0
        rStart = √(som.xdim^2 + som.ydim^2) / 2
        @debug "The radius has been determined automatically." rStart rFinal
    end

    # get the SOM neighborhood distances
    dm = distMatrix(som.grid, som.toroidal)

    codes = som.codes

    for j in 1:epochs
        @debug "Epoch $j..."

        numerator, denominator = distributedEpoch(dInfo,
            codes,
            knnTreeFun(Array{Float64,2}(transpose(codes)), metric))

        r = radiusFun(rStart, rFinal, j, epochs)
        @debug "radius: $r"
        if r <= 0
            @error "Sanity check failed: radius must be positive"
        end

        wEpoch = kernelFun(dm, r)
        codes = (wEpoch*numerator) ./ (wEpoch*denominator)
    end

    som.codes = copy(codes)

    return som
end

"""
function trainGigaSOM(som::Som, train::DataFrame;
                      kernelFun::Function = gaussianKernel,
                      metric = Euclidean(),
                      knnTreeFun = BruteTree,
                      rStart = 0.0, rFinal=0.1, radiusFun=linearRadius,
                      epochs = 10)

Overload of `trainGigaSOM` for simple DataFrames and matrices. This slices the
data using `DistributedArrays`, sends them the workers, and runs normal
`trainGigaSOM`. Data is `undistribute`d after the computation.
"""
function trainGigaSOM(som::Som, train;
                      kernelFun::Function = gaussianKernel,
                      metric = Euclidean(),
                      knnTreeFun = BruteTree,
                      rStart = 0.0, rFinal=0.1, radiusFun=linearRadius,
                      epochs = 10)

    train = convertTrainingData(train)

    #this slices the data using `distribute` and sends them to workers
    dInfo = distribute_darray(:trainDataVar, distribute(train))
    res = trainGigaSOM(som, dInfo,
                       kernelFun=kernelFun,
                       metric=metric,
                       knnTreeFun=knnTreeFun,
                       rStart=rStart, rFinal=rFinal, radiusFun=radiusFun,
                       epochs=epochs)
    undistribute(dInfo)
    return res
end


"""
    doEpoch(x::Array{Float64, 2}, codes::Array{Float64, 2}, tree)

vectors and the adjustment in radius after each epoch.

# Arguments:
- `x`: training Data
- `codes`: Codebook
- `tree`: knn-compatible tree built upon the codes
"""
function doEpoch(x::Array{Float64, 2}, codes::Array{Float64, 2}, tree)

    # initialise numerator and denominator with 0's
    sumNumerator = zeros(Float64, size(codes))
    sumDenominator = zeros(Float64, size(codes)[1])

    # for each sample in dataset / trainingsset
    for s in 1:size(x, 1)
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
    return distributed_mapreduce(dInfo,
        (data) ->
          doEpoch(data, codes, tree),
        ((n1, d1), (n2, d2)) ->
          (n1 + n2, d1 + d2))
end


"""
    mapToGigaSOM(som::Som, dInfo::LoadedDataInfo;
                 knnTreeFun = BruteTree,
                 metric = Euclidean())

Return a DataFrame with X-, Y-indices and index of winner neuron for
every row in data.

# Arguments
- `som`: a trained SOM
- `dInfo`: `LoadedDataInfo` that describes the loaded and distributed data
- `knnTreeFun`: Constructor of the KNN-tree (e.g. from NearestNeighbors package)
- `metric`: Passed as metric argument to the KNN-tree constructor

Data must have the same number of dimensions as the training dataset
and will be normalised with the same parameters.
"""
function mapToGigaSOM(som::Som, dInfo::LoadedDataInfo;
    knnTreeFun = BruteTree, metric = Euclidean())

    tree = knnTreeFun(Array{Float64,2}(transpose(som.codes)), metric)

    idxs = distributed_mapreduce(dInfo,
        (d) -> (vcat(knn(tree, transpose(d), 1)[1]...)),
        (d1, d2) -> vcat(d1, d2))

    return DataFrame(index = idxs)
end

"""
    mapToGigaSOM(som::Som, data;
                 knnTreeFun = BruteTree,
                 metric = Euclidean())
Overload of `mapToGigaSOM` for simple DataFrames and matrices. This slices the
data using `DistributedArrays`, sends them the workers, and runs normal
`mapToGigaSOM`. Data is `undistribute`d after the computation.
"""
function mapToGigaSOM(som::Som, data;
                      knnTreeFun = BruteTree,
                      metric = Euclidean())

    data = convertTrainingData(data)

    if size(data,2) != size(som.codes,2)
        @error "Data dimension ($(size(data,2))) does not match codebook dimension ($(size(som.codes,2)))."
    end

    dInfo= distribute_darray(:mappingDataVar, distribute(data))
    res = mapToGigaSOM(som, dInfo, knnTreeFun=knnTreeFun, metric=metric)
    undistribute(dInfo)
    return res
end

"""
    scaleEpochTime(iteration::Int64, epochs::Int64)

Convert iteration ID and epoch number to relative time in training.
"""
function scaleEpochTime(iteration::Int64, epochs::Int64)
    # prevent division by zero on 1-epoch training
    if epochs>1
        epochs -= 1
    end

    return Float64(iteration-1) / Float64(epochs)
end
