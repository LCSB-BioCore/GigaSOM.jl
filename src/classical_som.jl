"""
    initSOM(train, xdim, ydim = xdim;  norm = :zscore, topol = :hexagonal,
            toroidal = false)
Initialises a SOM.
# Arguments:
- `train`: training data
- `xdim, ydim`: geometry of the SOM
           If DataFrame, the column names will be used as attribute names.
           Codebook vectors will be sampled from the training data.
           for spherical SOMs ydim can be omitted.
- `norm`: optional normalisation; one of :`minmax, :zscore or :none`
- `topol`: topology of the SOM; one of `:rectangular, :hexagonal or :spherical`.
- `toroidal`: optional flag; if true, the SOM is toroidal.
"""
function initSOM( train, xdim, ydim = xdim;
             norm::Symbol = :none, topol = :hexagonal, toroidal = false)

    if typeof(train) == DataFrame
        colNames = [String(x) for x in names(train)]
    else
        colNames = ["x$i" for i in 1:ncol(train)]
    end
    train = convertTrainingData(train)


    if topol == :spherical
        toroidal = false
        nCodes = xdim
    else
        nCodes = xdim * ydim
    end

    som = initAll(train, colNames, norm,
                 xdim, ydim, nCodes,
                 topol, toroidal)
    return som
end

"""
    initAll( train::Array{Float64,2}, colNames::Array{String,1},
                norm::Symbol,
                xdim::Int, ydim::Int, nCodes::Int,
                topology::Symbol, toroidal::Bool)
Initialise a new Self-Organising Map.
"""
function initAll( train::Array{Float64,2}, colNames::Array{String,1},
                norm::Symbol,
                xdim::Int, ydim::Int, nCodes::Int,
                topology::Symbol, toroidal::Bool)

    # normalise training data:
    train, normParams = normTrainData(train, norm)
    codes = initCodes(nCodes, train, colNames)

    if topology == :rectangular
        grid = gridRectangular(xdim, ydim)
    elseif topology == :hexagonal
        grid = gridHexagonal(xdim, ydim)
    elseif topology == :spherical
        grid = gridSpherical(nCodes)
    else
        error("Topology $topology is not supported!")
    end

    normParams = convert(DataFrame, normParams)
    names!(normParams, Symbol.(colNames))

    # create X,y-indices for neurons:
    #
    if topology != :spherical
        x = [mod(i-1, xdim)+1 for i in 1:nCodes]
        y = [div(i-1, xdim)+1 for i in 1:nCodes]
    else
        x = y = collect(1:nCodes)
    end
    indices = DataFrame(X = x, Y = y)

    # make SOM object:
    som = Som(codes = codes, colNames = colNames,
              normParams = normParams, norm = norm,
              xdim = xdim, ydim = ydim,
              nCodes = nCodes,
              grid = grid, indices = indices,
              topol = topology,
              toroidal = toroidal,
              population = zeros(Int, nCodes))
    return som
end

"""
    trainSOM(som::Som, train::Any, len;
             η = 0.2, kernelFun = gaussianKernel,
             r = 0.0, rDecay = true, ηDecay = true)
Train an initialised or pre-trained SOM.
# Arguments:
- `som`: object of type Som with a trained som
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
function trainSOM(som::Som, train::Any, len;
                     η = 0.2, kernelFun::Function = gaussianKernel, r = 0.0,
                     rDecay = true, ηDecay = true)

    train = convertTrainingData(train)
    som = trainAll(som, train,
                 len, η, kernelFun, r,
                 rDecay, ηDecay)
    return som
end

"""
    function somAll(train::Array{Float64}, xdim, ydim,
                topology, len, η, kernelFun, r,
                norm, toroidal, rDecay, ηDecay)
Connects the high-level-API functions with
the backend.
# If `init == true` a new som is initialised with randomly sampled
# samples from train.
# Otherwise the som is trained.
"""
function trainAll(som::Som, train::Array{Float64,2},
                len, η, kernelFun, r,
                rDecay, ηDecay)

    # normalise training data:
    if som.norm != :none
        train = normTrainData(train, som.normParams)
    end

    # set default radius:
    if r == 0.0
        if som.topol != :spherical
            r = √(som.xdim^2 + som.ydim^2) / 2
        else
            r = π * som.ydim
        end
    end

    if som.topol == :spherical
        dm = distMatrixSphere(som.grid)
    else
        dm = distMatrix(som.grid, som.toroidal)
    end

    # println("$(show(IOContext(STDOUT, limit=true), "text/plain", train))")
    codes = doSom(train, som.codes, dm,
                  kernelFun, len, η, r,
                  som.toroidal, rDecay, ηDecay)

    # map training samles to SOM and calc. neuron population:
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
end


"""
    doSom(train::Array, distMatrix, kernelFun, len, η,
            r, toroidal, rDecay, ηDecay)
Train a SOM.
This worker function is called by the high-level-API-functions
`som(), somHexagonal() and somSpherical()`.
# Arguments:
- `x`: training Data
- `dm`: distance matrix of all neurons of the SOM
- `kernelFun`: distance kernel function of type fun(x, r)
- `len`: number of training steps (*not* epochs)
- `η`: learning rate
- `r`: training radius
- `toroidal`: if true, the SOM is toroidal.
- `rDecay`: if true, r decays to 0.0 during the training.
- `ηDecay`: if true, learning rate η decays to 0.0 during the training.
"""
function doSom(x::Array{Float64}, codes::Array{Float64},
             dm::Array{Float64}, kernelFun::Function, len::Int, η::Float64,
             r::Number, toroidal::Bool, rDecay::Bool, ηDecay::Bool)

    # make Δs for linear decay of r and η:
    r = Float64(r)
    if rDecay
        if r < 1.5
            Δr = 0.0
        else
            Δr = (r-1.0) / len
        end
    else
        Δr = 0.0
    end

    if ηDecay
        Δη = η / len
    else
        Δη = 0.0
    end

    numDat = nrow(x)
    numCodes = nrow(codes)

    # Training:
    # 1) select random sample
    # 2) find winner
    # 3) train all neurons with gaussian kernel
    #p = Progress(len, dt=1.0, desc="Training...", barglyphs=BarGlyphs("[=> ]"),
    #             barlen=50, color=:yellow)
    @time for s in 1:len

        sampl = rowSample(x)
        winner = findWinner(codes, sampl)

        for i in 1:numCodes
            # v = view(codes, i, :)
            Δi = codes[i,:] .- sampl
            codes[i,:] -= Δi .* kernelFun(dm[winner,i], r) .* η
            # v -=  @. v - sampl * kernelFun(dm[winner,i], r) * η
        end

        η -= Δη
        r -= Δr
       # next!(p)
    end

    return codes
end
