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
    p = Progress(len, dt=1.0, desc="Training...", barglyphs=BarGlyphs("[=> ]"),
                 barlen=50, color=:yellow)
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
        next!(p)
    end

    return codes
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
    if norm != :none
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
