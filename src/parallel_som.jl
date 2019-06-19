"""
        initGigaSOM_parallel(train, xdim, ydim = xdim;  norm = :none, toroidal = false)

Initialises a SOM.

# Arguments:
- `train`: training data
- `xdim, ydim`: geometry of the SOM
           If DataFrame, the column names will be used as attribute names.
           Codebook vectors will be sampled from the training data.
- `norm`: optional normalisation; one of :`minmax, :zscore or :none`
- `toroidal`: optional flag; if true, the SOM is toroidal.
"""
function initGigaSOM( train, xdim, ydim = xdim;
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

    # create X,y-indices for neurons:
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
    trainGigaSOM_parallel(som::Som, train::Any, kernelFun = gaussianKernel,
                        r = 0.0, epochs = 10)

# Arguments:
- `som`: object of type Som with an initialised som
- `train`: training data
- `kernel::function`: optional distance kernel; one of (`bubbleKernel, gaussianKernel`)
            default is `gaussianKernel`
- `r`: optional training radius.
       If r is not specified, it defaults to √(xdim^2 + ydim^2) / 2
Training data must be convertable to Array{Float34,2} with `convert()`.
Training samples are row-wise; one sample per row. An alternative kernel function
can be provided to modify the distance-dependent training. The function must fit
to the signature fun(x, r) where x is an arbitrary distance and r is a parameter
controlling the function and the return value is between 0.0 and 1.0.
"""
function trainGigaSOM(som::Som, train::Any; kernelFun::Function = gaussianKernel,
                    r = 0.0, epochs = 10)

    train = convertTrainingData(train)

    # set default radius:
    if r == 0.0
        r = √(som.xdim^2 + som.ydim^2) / 2
        @info "The radius has been determined automatically."
    end

    dm = distMatrix(som.grid, som.toroidal)

    codes = som.codes
    global_sum_numerator = zeros(Float64, size(codes))
    global_sum_denominator = zeros(Float64, size(codes)[1])

    # linear decay
    if r < 1.5
        Δr = 0.0
    else
        Δr = (r-1.0) / epochs
    end

    nWorkers = nprocs()
    dTrain = distribute(train)

    for j in 1:epochs

     println("Epoch: $j")

     if nWorkers > 1
         # distribution across workers
         R = Array{Future}(undef,nWorkers, 1)
          @sync for p in workers()

              println("worker: $p")
              @async R[p] = @spawnat p begin
                 doEpoch(localpart(dTrain), codes, dm, kernelFun, r, false)
              end
          end

          @sync for p in workers()
              tmp = fetch(R[p])
              global_sum_numerator += tmp[1]
              global_sum_denominator += tmp[2]
          end
     else
         # only batch mode
         println("In batch mode: ")
         sum_numerator, sum_denominator = doEpoch(localpart(dTrain), codes, dm,
                                                    kernelFun, r, false)

        global_sum_numerator += sum_numerator
        global_sum_denominator += sum_denominator
     end

     r -= Δr
     if r < 0.0
         r = 0.0
     end

     println("Radius: $r")
     codes = global_sum_numerator ./ global_sum_denominator
    end

    # map training samples to SOM and calc. neuron population:
    vis = visual(codes, train)
    population = makePopulation(som.numCodes, vis)
    # update SOM object:
    som.codes[:,:] = codes[:,:]
    som.population[:] = population[:]
    return som
end


"""
    doEpoch(x::Array{Float64}, codes::Array{Float64}, dm::Array{Float64},
            kernelFun::Function, r::Number, toroidal::Bool)

vectors and the adjustment in radius after each epoch.

# Arguments:
- `x`: training Data
- `codes`: Codebook
- `dm`: distance matrix of all neurons of the SOM
- `kernelFun`: distance kernel function of type fun(x, r)
- `r`: training radius
- `toroidal`: if true, the SOM is toroidal.
"""
function doEpoch(x::Array{Float64}, codes::Array{Float64}, dm::Array{Float64},
                kernelFun::Function, r::Number, toroidal::Bool)

     nRows = size(x, 1)
     nCodes = size(codes, 1)

     # initialise numerator and denominator with 0's
     sum_numerator = zeros(Float64, size(codes))
     sum_denominator = zeros(Float64, size(codes)[1])

     # for each sample in dataset / trainingsset
     for s in 1:nRows
         sampl = vec(x[s, : ])
         bmu_idx, bmu_vec = findBmu(codes, sampl)

         # for each node in codebook get distances to bmu and multiply it
         # with sample row: x(i)
         for i in 1:nCodes
             dist = kernelFun(dm[bmu_idx, i], r)

             @inbounds @views begin
                 sum_numerator[i,:] .+= sampl .* dist
             end
             sum_denominator[i] += dist
         end
     end
     return sum_numerator, sum_denominator
end


"""
    mapToGigaSOM(som::Som, data)

Return a DataFrame with X-, Y-indices and index of winner neuron for
every row in data.

# Arguments
- `som`: a trained SOM
- `data`: Array or DataFrame with training data.

Data must have the same number of dimensions as the training dataset
and will be normalised with the same parameters.
"""
function mapToGigaSOM(som::Som, data)

    data = convertTrainingData(data)

    if size(data,2) != size(som.codes,2)
        println("    data: $(size(data,2)), codes: $(size(som.codes,2))")
        error(SOM_ERRORS[:ERR_COL_NUM])
    end

    vis = visual(som.codes, data)
    x = [som.indices[i,:X] for i in vis]
    y = [som.indices[i,:Y] for i in vis]

    return DataFrame(X = x, Y = y, index = vis)
end


"""
    classFrequencies(som::Som, data, classes)

Return a DataFrame with class frequencies for all neurons.

# Arguments:
- `som`: a trained SOM
- `data`: data with row-wise samples and class information in each row
- `classes`: Name of column with class information.

Data must have the same number of dimensions as the training dataset.
The column with class labels is given as `classes` (name or index).
Returned DataFrame has the columns:
* X-, Y-indices and index: of winner neuron for every row in data
* population: number of samples mapped to the neuron
* frequencies: one column for each class label.
"""
function classFrequencies(som::Som, data, classes)

    if size(data,2) != size(som.codes,2) + 1
        println("    data: $(size(data,2)-1), codes: $(size(som.codes,2))")
        error(SOM_ERRORS[:ERR_COL_NUM])
    end

    x = deepcopy(data)
    deletecols!(x, classes)
    classes = data[classes]
    vis = visual(som.codes, x)

    df = makeClassFreqs(som, vis, classes)
    return df
end


"""
    visual(codes, x)

Return the index of the winner neuron for each training pattern
in x (row-wise).

# Arguments
- `codes`: Codebook
- `x`: training Data
"""
function visual(codes, x)

    vis = zeros(Int, size(x,1))
    for i in 1:size(x,1)
        (vis[i],) = findBmu(codes, [x[i, col] for col in 1:size(x, 2)])
    end

    return vis
end


"""
    makePopulation(numCodes, vis)

Return a vector of neuron populations.

# Arguments
- `numCodes`: total number of neurons
- `vis`: index of the winner neuron for each training pattern in x
"""
function makePopulation(numCodes, vis)

    population = zeros(Int, numCodes)
    for i in 1:size(vis,1)
        population[vis[i]] += 1
    end

    return population
end


"""
    makeClassFreqs(som, vis, classes)

Return a DataFrame with class frequencies for all neurons.

# Arguments
- `som`: a trained SOM
- `vis`: index of the winner neuron for each training pattern in x
- `classes`: Name of column with class information
"""
function makeClassFreqs(som, vis, classes)

    # count classes and construct DataFrame:
    #
    classLabels = sort(unique(classes))
    classNum = size(classLabels,1)

    cfs = DataFrame(index = 1:som.numCodes)
    cfs[:X] = som.indices[:X]
    cfs[:Y] = som.indices[:Y]

    cfs[:Population] = zeros(Int, som.numCodes)

    for class in classLabels
        cfs[Symbol(class)] = zeros(Float64, som.numCodes)
    end

    # loop vis and count:
    #
    for i in 1:size(vis,1)

        cfs[vis[i], :Population] += 1
        class = Symbol(classes[i])
        cfs[vis[i], class] += 1
    end

    # make frequencies from counts:
    #
    for i in 1:size(cfs,1)

        counts = [cfs[i, col] for col in 5:size(cfs, 2)]
        total = cfs[i,:Population]
        if total == 0
            freqs = counts * 0.0
        else
            freqs = counts ./ total
        end

        for c in 1:classNum
            class = Symbol(classLabels[c])
            cfs[i,class] = freqs[c]
        end
    end

    return cfs
end



# Arguments


"""
    findBmu(cod, sampl)

Find the best matching unit for a given vector, row_t, in the SOM

# Arguments


Returns: A (bmu, bmu_idx) tuple where bmu is the high-dimensional
Best Matching Unit and bmu_idx is the index of this vector in the SOM

"""
function findBmu(cod, sampl)

    dist = floatmax()
    winner = 1
    n = size(cod,1)

    for i in 1:n

        d = euclidean(sampl, cod[i,:])
        if (d < dist)
            dist = d
            winner = i
        end
    end
    # get the code vector of the bmu
    bmu_vec = cod[winner,:]
    return winner, bmu_vec
end


"""
    normTrainData(x::DataFrame, normParams::DataFrame)

Normalise every column of training data with the params.

# Arguments
- `x`: DataFrame with training Data
- `normParams`: Shift and scale parameters for each attribute column.
"""
function normTrainData(x::Array{Float64,2}, normParams)

    for i in 1:size(x,2)
        x[:,i] = (x[:,i] .- normParams[1,i]) ./ normParams[2,i]
    end

    return x
end


"""
    normTrainData(train::DataFrame, norm::Symbol)

Normalise every column of training data.

# Arguments
- `train`: DataFrame with training Data
- `norm`: type of normalisation; one of `minmax, zscore, none`
"""
function normTrainData(train::Array{Float64, 2}, norm::Symbol)

    normParams = zeros(2, size(train,2))

    if  norm == :minmax
        for i in 1:size(train,2)
            normParams[1,i] = minimum(train[:,i])
            normParams[2,i] = maximum(train[:,i]) - minimum(train[:,i])
        end
    elseif norm == :zscore
        for i in 1:size(train,2)
            normParams[1,i] = mean(train[:,i])
            normParams[2,i] = std(train[:,i])
        end
    else
        for i in 1:size(train,2)
            normParams[1,i] = 0.0  # shift
            normParams[2,i] = 1.0  # scale
        end
    end

    # do the scaling:
    if norm == :none
        x = train
    else
        x = normTrainData(train, normParams)
    end

    return x, normParams
end

"""
    convertTrainingData(data)

Converts the training data to an Array of type Float64.

# Arguments:
- `data`: Data to be converted

"""
function convertTrainingData(data)::Array{Float64,2}

    if typeof(data) == DataFrame
        train = convert(Matrix{Float64}, data)

    elseif typeof(data) != Matrix{Float64}
        try
            train = convert(Matrix{Float64}, data)
        catch ex
            Base.showerror(STDERR, ex, backtrace())
            error("Unable to convert training data to Array{Float64,2}!")
        end
    else
        train = data
    end

    return train
end

prettyPrintArray(arr) = println("$(show(IOContext(STDOUT, limit=true), "text/plain", arr))")
