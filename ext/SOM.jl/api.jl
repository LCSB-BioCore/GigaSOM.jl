#
# the API
#

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
