"""
    function initGigaSOM(initMatrix, xdim, ydim = xdim;
        norm::Symbol = :none, toroidal = false)

Initialises a SOM.

# Arguments:
- `initMatrix`: codeBook vector as random input matrix from random workers
- `xdim, ydim`: geometry of the SOM
- `norm`: optional normalisation
- `toroidal`: optional flag; if true, the SOM is toroidal.
"""
function initGigaSOM(initMatrix::Array{Float64, 2}, xdim, ydim = xdim;
             norm::Symbol = :none, toroidal = false)

    numCodes = xdim * ydim

    # TODO: Normalization need to be adjusted for distributed loading
    # normParams = convert(DataFrame, normParams)

    # initialise the codes with random samples from workers
    codes = initMatrix
    grid = gridRectangular(xdim, ydim)

    # create X,Y-indices for neurons:
    x = y = collect(1:numCodes)
    indices = DataFrame(X = x, Y = y)

    # TODO: simulate colnames for testing only !!!
    colNames = ["a", "b", "c"]
    normParams = DataFrame()
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


function initGigaSOM(train::DataFrame, xdim, ydim = xdim;
             norm::Symbol = :none, toroidal = false)

    if typeof(train) == DataFrame
        colNames = [String(x) for x in names(train)]
    else
        colNames = ["x$i" for i in 1:size(train,2)]
    end

    train = convertTrainingData(train)

    numCodes = xdim * ydim

    # normalise training data:
    train, normParams = normTrainData(train, norm)

    # initialise the codes with random samples
    codes = train[rand(1:size(train,1), numCodes),:]
    grid = gridRectangular(xdim, ydim)

    normParams = convert(DataFrame, normParams)
    names!(normParams, Symbol.(colNames))

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
    function trainGigaSOM(som::Som, trainRef, cc;
        kernelFun::Function = gaussianKernel,
        metric = Euclidean(),
        knnTreeFun = BruteTree,
        rStart = 0.0, rFinal=0.1, radiusFun=linearRadius,
        epochs = 10)

# Arguments:
- `som`: object of type Som with an initialised som
- `trainRef`: reference to data on each worker
- `cc`: list of columns to be used in training
- `kernelFun::function`: optional distance kernel; one of (`bubbleKernel, gaussianKernel`)
            default is `gaussianKernel`
- `metric`: Passed as metric argument to the KNN-tree constructor
- `knnTreeFun`: Constructor of the KNN-tree (e.g. from NearestNeighbors package)
- `rStart`: optional training radius.
       If r is not specified, it defaults to (xdim+ydim)/3
- `rFinal`: target radius at the last epoch, defaults to 0.1
- `radiusFun`: Function that generates radius decay, e.g. `linearRadius` or `expRadius(10.0)`
- `epochs`: number of SOM training iterations (default 10)
"""
function trainGigaSOM(som::Som, trainRef::Array{Any,1}, cc;
                      kernelFun::Function = gaussianKernel,
                      metric = Euclidean(),
                      knnTreeFun = BruteTree,
                      rStart = 0.0, rFinal=0.1, radiusFun=linearRadius,
                      epochs = 10)

    # set default radius:
    if rStart == 0.0
        rStart = √(som.xdim^2 + som.ydim^2) / 2
        @info "The radius has been determined automatically."
    end

    dm = distMatrix(som.grid, som.toroidal)

    codes = som.codes

    for j in 1:epochs

        globalSumNumerator = zeros(Float64, size(codes))
        globalSumDenominator = zeros(Float64, size(codes)[1])

        tree = knnTreeFun(Array{Float64,2}(transpose(codes)), metric)
        R = Vector{Any}(undef,nworkers())
        # only batch mode
        # train is of type Ref{DataFrame}
        @sync begin
            for (idx, pid) in enumerate(workers())
                @async begin
                    # @info pid
                    R[idx] =  fetch(@spawnat pid begin doEpoch(trainRef[idx], codes, tree, cc) end)
                    globalSumNumerator += R[idx][1]
                    globalSumDenominator += R[idx][2]
                end
            end
        end

        r = radiusFun(rStart, rFinal, j, epochs)
        println("Radius: $r")
        if r <= 0
            error("Sanity check: radius must be positive")
        end

        wEpoch = kernelFun(dm, r)
        codes = (wEpoch*globalSumNumerator) ./ (wEpoch*globalSumDenominator)
    end

    som.codes[:,:] = codes[:,:]

    return som
end


function trainGigaSOM(som::Som, train::DataFrame;
                      kernelFun::Function = gaussianKernel,
                      metric = Euclidean(),
                      knnTreeFun = BruteTree,
                      rStart = 0.0, rFinal=0.1, radiusFun=linearRadius,
                      epochs = 10)

    train = convertTrainingData(train)

    # set default radius:

    if rStart == 0.0
        rStart = √(som.xdim^2 + som.ydim^2) / 2
        @info "The radius has been determined automatically."
    end

    dm = distMatrix(som.grid, som.toroidal)

    codes = som.codes

    nWorkers = nprocs()
    dTrain = distribute(train)

    for j in 1:epochs

        globalSumNumerator = zeros(Float64, size(codes))
        globalSumDenominator = zeros(Float64, size(codes)[1])

        tree = knnTreeFun(Array{Float64,2}(transpose(codes)), metric)

        if nworkers() > 1

            R = Vector{Any}(undef,nworkers())

            @sync begin
                for (idx, pid) in enumerate(workers())
                    @async begin
                        R[idx] =  fetch(@spawnat pid begin doEpoch(localpart(dTrain), codes, tree) end)
                        globalSumNumerator += R[idx][1]
                        globalSumDenominator += R[idx][2]
                    end
                end
            end
        else
            # only batch mode
            sumNumerator, sumDenominator = doEpoch(localpart(dTrain), codes, tree)
            globalSumNumerator += sumNumerator
            globalSumDenominator += sumDenominator
        end

        r = radiusFun(rStart, rFinal, j, epochs)
        println("Radius: $r")
        if r <= 0
            error("Sanity check: radius must be positive")
        end

        wEpoch = kernelFun(dm, r)
        codes = (wEpoch*globalSumNumerator) ./ (wEpoch*globalSumDenominator)
    end

    som.codes[:,:] = codes[:,:]

    return som
end


"""
    doEpoch(x::Array{Float64}, codes::Array{Float64}, tree)

vectors and the adjustment in radius after each epoch.

# Arguments:
- `x`: training Data
- `codes`: Codebook
- `tree`: knn-compatible tree built upon the codes
"""
function doEpoch(x::Ref, codes::Array{Float64, 2}, tree, cc)

    # initialise numerator and denominator with 0's
    sumNumerator = zeros(Float64, size(codes))
    sumDenominator = zeros(Float64, size(codes)[1])

    for s in 1:size(x.x, 1)

        (bmuIdx, bmuDist) = knn(tree, x.x[s, :], 1)

        target = bmuIdx[1]

        sumNumerator[target, :] .+= x.x[s, :]
        sumDenominator[target] += 1
    end

    return sumNumerator, sumDenominator
end


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
    mapToGigaSOM(som::Som, data)

Return a DataFrame with X-, Y-indices and index of winner neuron for
every row in data.

# Arguments
- `som`: a trained SOM
- `data`: Array or DataFrame with training data.
- `knnTreeFun`: Constructor of the KNN-tree (e.g. from NearestNeighbors package)
- `metric`: Passed as metric argument to the KNN-tree constructor

Data must have the same number of dimensions as the training dataset
and will be normalised with the same parameters.
"""
function mapToGigaSOM(som::Som, data::DataFrame;
                      knnTreeFun = BruteTree,
                      metric = Euclidean())

    data::Array{Float64,2} = convertTrainingData(data)
    if size(data,2) != size(som.codes,2)
        println("    data: $(size(data,2)), codes: $(size(som.codes,2))")
        error(SOM_ERRORS[:ERR_COL_NUM])
    end

    nWorkers = nprocs()
    vis = Int64[]
    tree = knnTreeFun(Array{Float64,2}(transpose(som.codes)), metric)

    if nWorkers > 1
        # distribution across workers
        dData = distribute(data)

        R = Array{Future}(undef,nWorkers, 1)
        @sync for (p, pid) in enumerate(workers())
            @async R[p] = @spawnat pid begin
                # knn() returns a tuple of 2 arrays of arrays (one with indexes
                # that we take out, the second with distances that we discard
                # here). vcat() nicely squashes the arrays-in-arrays into a
                # single vector.
                vcat(knn(tree, transpose(localpart(dData)), 1)[1]...)
            end
        end

        @sync begin
            for (p, pid) in enumerate(sort!(workers()))
                append!(vis, fetch(R[p]))
            end
        end
    else
        vis = vcat(knn(tree, transpose(data), 1)[1]...)
    end

    return DataFrame(index = vis)
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

"""
    linearRadius(initRadius::Float64, iteration::Int64, decay::String, epochs::Int64)

Return a neighbourhood radius. Use as the `radiusFun` parameter for `trainGigaSOM`.

# Arguments
- `initRadius`: Initial Radius
- `finalRadius`: Final Radius
- `iteration`: Training iteration
- `epochs`: Total number of epochs
"""
function linearRadius(initRadius::Float64, finalRadius::Float64,
                      iteration::Int64, epochs::Int64)

    scaledTime = scaleEpochTime(iteration,epochs)
    return initRadius*(1-scaledTime) + finalRadius*scaledTime
end

"""
    expRadius(steepness::Float64)

Return a function to be used as a `radiusFun` of `trainGigaSOM`, which causes
exponencial decay with the selected steepness.

Use: `trainGigaSOM(..., radiusFun = expRadius(0.5))`

# Arguments
- `steepness`: Steepness of exponential descent. Good values range
  from -100.0 (almost linear) to 100.0 (really quick decay).

"""
function expRadius(steepness::Float64 = 1.0)
    return (initRadius::Float64, finalRadius::Float64,
            iteration::Int64, epochs::Int64) -> begin

        scaledTime = scaleEpochTime(iteration,epochs)

        if steepness < -100.0
            # prevent floating point underflows
            error("Sanity check: steepness too low, use linearRadius instead.")
        end

        # steepness is simulated by moving both points closer to zero
        adjust = finalRadius * (1 - 1.1^(-steepness))

        if initRadius <= 0 || (initRadius-adjust) <= 0 || finalRadius <= 0
            error("Radii must be positive. (Possible alternative cause: steepness is too high.)")
        end

        initRadius -= adjust
        finalRadius -= adjust

        return adjust + initRadius * ((finalRadius/initRadius)^scaledTime)
    end
end
