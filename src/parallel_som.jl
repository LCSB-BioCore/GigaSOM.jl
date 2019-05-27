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
    train, normParams = SOM.normTrainData(train, norm)
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
    trainSOM_paralell(som::Som, train::Any, len;
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
function trainSOM_paralell(som::Som, train::Any, len;
                     kernelFun::Function = gaussianKernel, r = 0.0,
                     rDecay = true, epochs = 10)

    println(first(train, 6))

    # double conversion:
    # train was already converted during initialization
    train = convertTrainingData(train)

     if norm != :none
         train = SOM.normTrainData(train, som.normParams)
     end

    # set default radius:
    if r == 0.0
     if som.topol != :spherical
         r = √(som.xdim^2 + som.ydim^2) / 2
     else
         r = π * som.ydim
     end
    end

    dm = distMatrix(som.grid, som.toroidal)

    # make Δs for linear decay of r:
    # r = Float64(r)
    dTrain = distribute(train)

    codes = som.codes
    global_sum_numerator = zeros(Float64, size(codes))
    global_sum_denominator = zeros(Float64, size(codes)[1])

    # linear decay function
    if rDecay
     if r < 1.5
         Δr = 0.0
     else
         println("in r decay")
         Δr = (r-1.0) / epochs
     end
    else
     Δr = 0.0
    end

    for j in 1:epochs

     println("Epoch: $j")

     A = [@fetchfrom p localindices(dTrain) for p in workers()]
     println(A)

     # tmp = reduce(reduce_me, map(fetch, Any[@spawnat w doEpoch_parallel(localpart(dTrain), codes, dm, kernelFun, len, r,
     # false, rDecay, epochs) for w in workers() ]))

     # using Any is 2x faster
     # tmp = map(fetch, Any[@spawnat w doEpoch_parallel(localpart(dTrain), codes, dm, kernelFun, len, r,
     # false, rDecay, epochs) for w in workers() ])

     # no difference for workers or procs
     tmp = @time map(fetch, Any[@spawnat p doEpoch_parallel(localpart(dTrain), codes, dm, kernelFun, len, r,
                    false, rDecay, epochs) for p = procs(dTrain) ])

     #
     # wp = WorkerPool([2, 3])

     # tmp = remotecall_wait(doEpoch_parallel, wp, localpart(dTrain), codes, dm, kernelFun, len, r, false, rDecay, epochs)
     # tmp = remotecall_wait(sum, wp, [1,2,3,4,5,6,7,8,9])

     for dset in tmp
         global_sum_numerator += dset[1]
         global_sum_denominator += dset[2]
     end

     r -= Δr

     if r < 0.0
         r = 0.0
     end

     println("Radius: $r")

     codes = global_sum_numerator ./ global_sum_denominator

    end

    # map training samples to SOM and calc. neuron population:
    vis = SOM.visual(codes, train)
    population = SOM.makePopulation(som.nCodes, vis)

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
     # sum_numerator = Matrix{Float64}[size(codes)]
     # for each sample in dataset / or trainingsset
     for s in 1:len
         sampl = vec(x[rand(1:nrow(x), 1),:])
         bmu_idx, bmu_vec = find_bmu(codes, sampl)
         # for each node in codebook get distances to bmu and multiply it
         # with sample row: x(i)
         for i in 1:numCodes
             # cost of this dist function is around 2 sec.
             dist = kernelFun(dm[bmu_idx, i], r)
             # temp = sampl .* dist
             # very slow assignment !!!
             # just by commenting out, time decreases from
             # 34 sec to 11 sec
             sum_numerator[i,:] += sampl .* dist
             sum_denominator[i] += dist
             # this one is no difference
             # sum_numerator[i,:] = sum_numerator[i,:] + temp
             # sum_denominator[i] = sum_denominator[i] + dist
         end
     end
     return sum_numerator, sum_denominator
end
