"""
    initCodes(num::Int, x::Array)

Return num rows from Array x as initial codes.
"""
function initCodes(num::Int, x::Array{Float64}, colNames)

    codes = rowSample(x, num)
    return codes
end

"""
        initSOM_parallel(train, xdim, ydim = xdim;  norm = :zscore, topol = :hexagonal,
            toroidal = false)
Initialises a SOM.
# Arguments:
- `train`: training data
- `xdim, ydim`: geometry of the SOM
           If DataFrame, the column names will be used as attribute names.
           Codebook vectors will be sampled from the training data.
           for spherical SOMs ydim can be omitted.
- `norm`: optional normalisation; one of :`minmax, :zscore or :none`
- `toroidal`: optional flag; if true, the SOM is toroidal.
"""
function initSOM_parallel( train, xdim, ydim = xdim;
             norm::Symbol = :none, toroidal = false)

    if typeof(train) == DataFrame
        colNames = [String(x) for x in names(train)]
    else
        colNames = ["x$i" for i in 1:ncol(train)]
    end

    train = convertTrainingData(train)

    nCodes = xdim * ydim

    # normalise training data:
    train, normParams = normTrainData(train, norm)
    codes = initCodes(nCodes, train, colNames)

    grid = gridRectangular(xdim, ydim)

    normParams = convert(DataFrame, normParams)
    names!(normParams, Symbol.(colNames))

    # create X,y-indices for neurons:
    #
     x = y = collect(1:nCodes)
    indices = DataFrame(X = x, Y = y)

    # make SOM object:
    som = Som(codes = codes, colNames = colNames,
           normParams = normParams, norm = norm,
           xdim = xdim, ydim = ydim,
           nCodes = nCodes,
           grid = grid, indices = indices,
           toroidal = toroidal,
           population = zeros(Int, nCodes))
    return som
end


"""
    trainSOM_parallel(som::Som, train::Any, len;
             η = 0.2, kernelFun = gaussianKernel,
             r = 0.0, rDecay = true, ηDecay = true)
# Arguments:
- `som`: object of type Som with an initialised som
- `train`: training data
- `len`: number of single training steps (*not* epochs)
- `η`: learning rate
- `kernel::function`: optional distance kernel; one of (`bubbleKernel, gaussianKernel`)
            default is `gaussianKernel`
- `r`: optional training radius.
       If r is not specified, it defaults to √(xdim^2 + ydim^2) / 2
- `rDecay`: optional flag; if true, r decays to 0.0 during the training.
- `ηDecay`: optional flag; if true, learning rate η decays to 0.0
            during the training.
Training data must be convertable to Array{Float64,2} with
`convert()`. Training samples are row-wise; one sample per row.
An alternative kernel function can be provided to modify the distance-dependent
training. The function must fit to the signature fun(x, r) where
x is an arbitrary distance and
r is a parameter controlling the function and the return value is
between 0.0 and 1.0.
"""
function trainSOM_parallel(som::Som, train::Any, len;
                     kernelFun::Function = gaussianKernel, r = 0.0,
                     rDecay = true, epochs = 10)

    # double conversion:
    # train was already converted during initialization
    train = convertTrainingData(train)

    # set default radius:
    if r == 0.0
     if som.topol != :spherical
         r = √(som.xdim^2 + som.ydim^2) / 2
     else
         r = π * som.ydim
     end
    end

    dm = distMatrix(som.grid, som.toroidal)

    codes = som.codes
    global_sum_numerator = zeros(Float64, size(codes))
    global_sum_denominator = zeros(Float64, size(codes)[1])

    # linear decay function
    if rDecay
        if r < 1.5
            Δr = 0.0
        else
            Δr = (r-1.0) / epochs
        end
    else
        Δr = 0.0
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
                 doEpoch_parallel(localpart(dTrain), codes, dm, kernelFun, len, r,
                                                    false, rDecay, epochs)
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
         sum_numerator, sum_denominator = doEpoch_parallel(localpart(dTrain), codes, dm, kernelFun, len, r,
                                                            false, rDecay, epochs)

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
    population = makePopulation(som.nCodes, vis)

    # create X,Y-indices for neurons:
    #
    if som.topol != :spherical
     x = [mod(i-1, som.xdim)+1 for i in 1:som.nCodes]
     y = [div(i-1, som.xdim)+1 for i in 1:som.nCodes]
    else
     x = y = collect(1:som.nCodes)
    end
    indices = DataFrame(X = x, Y = y)

    # update SOM object:
    somNew = deepcopy(som)
    somNew.codes[:,:] = codes[:,:]
    somNew.population[:] = population[:]
    return somNew
    # return som
end


"""
    doEpoch_parallel(x::Array{Float64}, codes::Array{Float64},
             dm::Array{Float64}, kernelFun::Function, len::Int, η::Float64,
             r::Number, toroidal::Bool, rDecay::Bool, ηDecay::Bool)
Train a SOM for one epoch. This implements also the batch update
of the codebook vectors and the adjustment in radius after each
epoch.
# Arguments:
- `x`: training Data
- `dm`: distance matrix of all neurons of the SOM
- `kernelFun`: distance kernel function of type fun(x, r)
- `len`: number of training steps (*not* epochs)
- `r`: training radius
- `toroidal`: if true, the SOM is toroidal.
- `rDecay`: if true, r decays to 0.0 during the training.
"""
function doEpoch_parallel(x::Array{Float64}, codes::Array{Float64},
                 dm::Array{Float64}, kernelFun::Function, len::Int,
                 r::Number, toroidal::Bool, rDecay::Bool, epochs)
     numDat = nrow(x)
     numCodes = nrow(codes)
     # initialise numerator and denominator with 0's
     sum_numerator = zeros(Float64, size(codes))
     sum_denominator = zeros(Float64, size(codes)[1])
     # for each sample in dataset / trainingsset
     for s in 1:numDat

         sampl = vec(x[rand(1:nrow(x), 1),:])
         bmu_idx, bmu_vec = find_bmu(codes, sampl)

         # for each node in codebook get distances to bmu and multiply it
         # with sample row: x(i)
         for i in 1:numCodes

             dist = kernelFun(dm[bmu_idx, i], r)

             # very slow assignment !!!
             # just by commenting out, time decreases from
             # 34 sec to 11 sec
             sum_numerator[i,:] += sampl .* dist
             sum_denominator[i] += dist

         end
     end
     return sum_numerator, sum_denominator
end

"""
    mapToSOM(som::Som, data)

Return a DataFrame with X-, Y-indices and index of winner neuron for
every row in data.

# Arguments
- `som`: a trained SOM
- `data`: Array or DataFrame with training data.

Data must have the same number of dimensions as the training dataset
and will be normalised with the same parameters.
"""
function mapToSOM(som::Som, data)

    data = convertTrainingData(data)

    if ncol(data) != ncol(som.codes)
        println("    data: $(ncol(data)), codes: $(ncol(som.codes))")
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

    if ncol(data) != ncol(som.codes) + 1
        println("    data: $(ncol(data)-1), codes: $(ncol(som.codes))")
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
    function visual(codes, x)

Return the index of the winner neuron for each training pattern
in x (row-wise).
"""
function visual(codes, x)

    vis = zeros(Int, nrow(x))
    for i in 1:nrow(x)
        vis[i] = findWinner(codes, [x[i, col] for col in 1:size(x, 2)])
    end

    return(vis)
end


"""
    makePopulation(nCodes, vis)

Return a vector of neuron populations.
"""
function makePopulation(nCodes, vis)

    population = zeros(Int, nCodes)
    for i in 1:nrow(vis)
        population[vis[i]] += 1
    end

    return population
end


"""
    makeClassFreqs(som, vis, classes)

Return a DataFrame with class frequencies for all neurons.
"""
function makeClassFreqs(som, vis, classes)

    # count classes and construct DataFrame:
    #
    classLabels = sort(unique(classes))
    classNum = nrow(classLabels)

    cfs = DataFrame(index = 1:som.nCodes)
    cfs[:X] = som.indices[:X]
    cfs[:Y] = som.indices[:Y]

    cfs[:Population] = zeros(Int, som.nCodes)

    for class in classLabels
        cfs[Symbol(class)] = zeros(Float64, som.nCodes)
    end

    # loop vis and count:
    #
    for i in 1:nrow(vis)

        cfs[vis[i], :Population] += 1
        class = Symbol(classes[i])
        cfs[vis[i], class] += 1
    end

    # make frequencies from counts:
    #
    for i in 1:nrow(cfs)

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

"""
    findWinner(cod, sampl)

Return index of the winner neuron for sample sampl.
"""
function findWinner(cod, sampl)

    dist = floatmax()
    winner = 1
    n = nrow(cod)

    for i in 1:n

        d = euclidean(sampl, cod[i,:])
        if (d < dist)
            dist = d
            winner = i
        end
    end

    return winner
end


"""
    Find the best matching unit for a given vector, row_t, in the SOM
    Returns: a (bmu, bmu_idx) tuple where bmu is the high-dimensional Best Matching Unit
           and bmu_idx is the index of this vector in the SOM
"""
function find_bmu(cod, sampl)

    dist = floatmax()
    winner = 1
    n = nrow(cod)

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
    normTrainData(train::DataFrame, normParams::DataFrame)

Normalise every column of training data with the params.

# Arguments
- `train`: DataFrame with training Data
- `normParams`: Shift and scale parameters for each attribute column.
"""
function normTrainData(x::Array{Float64,2}, normParams)

    for i in 1:ncol(x)
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
function normTrainData(train::Array{Float64,2}, norm::Symbol)

    normParams = zeros(2, ncol(train))

    if  norm == :minmax
        for i in 1:ncol(train)
            normParams[1,i] = minimum(train[:,i])
            normParams[2,i] = maximum(train[:,i]) - minimum(train[:,i])
        end
    elseif norm == :zscore
        for i in 1:ncol(train)
            normParams[1,i] = mean(train[:,i])
            normParams[2,i] = std(train[:,i])
        end
    else
        for i in 1:ncol(train)
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
