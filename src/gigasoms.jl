"""
 Modified version of the SOM.jl package
"""



include("../src/errors.jl")
include("../src/types.jl")
include("../src/helpers.jl")
include("../src/grids.jl")
include("../src/kernels.jl")


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

#
#
# predict functions:
#
#
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


#########################################################
# TODO:  this function needs to be updated to batch mode
#########################################################
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

        # serial version:
        # updated all codes after each winner
        for i in 1:numCodes # for each row in codes
            Δi = codes[i,:] .- sampl # substract the sample array from each
                                    # code in row
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

#
#
# Plotting functions:
#
#
"""
    plotDensity(som::Som; predict = nothing,
                title = "Density of Self-Organising Map",
                paper = :a4r,
                colormap = "autumn_r",
                detail = 45,
                device = :display, fileName = "somplot")
Plot the population of neurons as colours.
# Arguments:
- `som`: the som of type `Som`; som is the only mandatory argument
- `predict`: DataFrame of mappings as outputed by `mapToSOM()`
- `title`: main title of plot
- `paper`: plot size; currentlx supported: `:a4, :a4r, :letter, :letterr`
- `colormap`: MatPlotLib colourmap (Python-style strings; e.g. `"Greys"`).
- `detail`: only relevant for 3D-plotting of spherical SOMs: higher
            values result in smoother display of the 3D-sphere
- `device`: one of `:display, :png, :svg, :pdf` or any file-type supported
            by MatPlotLib; default is `:display`
- `fileName`: name of image file. File extention overrides the setting of
              `device`.
"""
function plotDensity(som::Som; predict = nothing,
                     title = "Density of Self-Organising Map",
                     paper = :a4r,
                     colormap = "autumn_r",
                     detail = 45,
                     device = :display, fileName = "somplot")

    # do nothing, if matplotlib is not installed correctly:
    #
    if !MPL_INSTALLED
        error(SOM_ERRORS[:ERR_MPL])
    end

    # use population form the som itself, if no prediction is given as arg.
    #
    if predict == nothing
        population = som.population
    else
        population = makePopulation(som.nCodes, predict[:index])
    end

    if typeof(colormap) == Symbol
        colormap = string(colormap)
    end

    if som.topol == :spherical
        drawSpherePopulation(som, population, detail, title,
                             paper, colormap, device, fileName)
    else
        drawPopulation(som, population, title, paper, colormap, device, fileName)
    end
end


"""
    plotClasses(som::Som, frequencies;
                title = "Class Frequencies of Self-Organising Map",
                paper = :a4r,
                colors = "brg",
                detail = 45,
                device = :display, fileName = "somplot")
Plot the population of neurons as colours.
# Arguments:
- `som`: the som of type `Som`
- `frequencies`: DataFrame of frequencies as outputed by classFrequencies()
- `title`: main title of plot
- `paper`: plot size; currentlx supported: `:a4, :a4r, :letter, :letterr`
- `colors`: MatPlotLib colourmap (Python-style as string `"gray"` or
              Julia-style as Symbol `:gray`) *or* dictionary with
              classes as keys and colours as vals;
              keys can be provides as Strings or Symbols; colours must be
              valid coulour definitions (such as RGB, names, etc).
              Default: `brg`
- `detail`: only relevant for 3D-plotting of spherical SOMs: higher
            values result in smoother display of the 3D-sphere
- `device`: one of `:display, :png, :svg, :pdf` or any file-type supported
            by MatPlotLib; default is `:display`
- `fileName`: name of image file. File extention overrides the setting of
              `device`.
"""
function plotClasses(som::Som, frequencies;
                     title = "Class Frequencies of Self-Organising Map",
                     paper = :a4r,
                     colors = "brg",
                     detail = 45,
                     device = :display, fileName = "somplot")

    # do nothing, if matplotlib is not installed correctly:
    #
    if !MPL_INSTALLED
        error(SOM_ERRORS[:ERR_MPL])
    end

    # create dictionary of colours and classes if necessary:
    #
    if isa(colors, Symbol)
        colors = string(colors)
    end
    if isa(colors, String)
        numClasses = size(frequencies)[2] - 4
        classes = sort(names(frequencies)[5:end])
        cmap = get_cmap(colors)
        coloursRGB = cmap.(range(0.0, stop = 1.0, length = numClasses))

        colourDict = Dict((classes[i], coloursRGB[i]) for i in 1:numClasses)

    # else create Dict of colours with Symbols as keys:
    #
    elseif isa(colors, Dict)
        colourDict = Dict(Symbol(i) => colors[i] for i in keys(colors))
    else
        println(SOM_ERRORS[:ERR_COLOUR_DEF])
        return :ERR_COLOUR_DEF
    end

    if som.topol == :spherical
        drawSphereFreqs(som, frequencies, detail, title, paper, colourDict, device, fileName)
    else
        drawFrequencies(som, frequencies, title, paper, colourDict, device, fileName)
    end
end
