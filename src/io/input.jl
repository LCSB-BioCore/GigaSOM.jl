"""
    readFlowset(filenames)

Create a dictionary with filenames as keys and daFrame as values

# Arguments:
- `filenames`: Array of type string
"""
function readFlowset(filenames)

    flowFrame = Dict()

    # read all FCS files into flowFrame
    for name in filenames # file list
        flowrun = FileIO.load(name) # FCS file

        # get metadata
        # FCSFiles returns a dict with coumn names as key
        # As the dict is not in order, use the name column form meta
        # to sort the Dataframe after cast.
        meta = getMetaData(flowrun)
        markers = meta[:,1]
        markersIsotope = meta[:,5]
        flowDF = DataFrame(flowrun.data)
        # sort the DF according to the marker list
        flowDF = flowDF[:, Symbol.(markersIsotope)]
        cleanNames!(markers)

        names!(flowDF, Symbol.(markers), makeunique=true)
        flowFrame[name] = flowDF
    end

    return flowFrame
end


# TODO: add function header
function readSingleFlowFrame(filename)

    flowrun = FileIO.load(filename) # FCS file

    # get metadata
    # FCSFiles returns a dict with coumn names as key
    # As the dict is not in order, use the name column form meta
    # to sort the Dataframe after cast.
    meta = getMetaData(flowrun)
    markers = meta[:,1]
    markersIsotope = meta[:,5]
    flowDF = DataFrame(flowrun.data)
    # sort the DF according to the marker list
    flowDF = flowDF[:, Symbol.(markersIsotope)]
    cleanNames!(markers)
    names!(flowDF, Symbol.(markers), makeunique=true)

    return flowDF
end


"""
    loadData(fn, md,panel; method = "asinh", cofactor = 5,
            reduce = true, sort = true)

Load the data in parallel

# Arguments:
- `fn`: Array of type string
- `md`: Metadata table
- `panel`: Panel table with a column for Lineage Markers and one for Functional Markers
- `method`: transformation method, default arcsinh, optional
- `cofactor`: Cofactor for transformation, default 5, optional
- `reduce`: Selected only columns which are defined by lineage and functional, optional,
    default: true. If false the check for any none columns to be removed (none columns can appear
    after concatenating FCS files as well as parameter like: time, event length)
- `sort`: Sort columns by name to make sure the order when concatinating the dataframes, optional, default: true
"""
function loadData(idx, fn, md, panel; method = "asinh", cofactor = 5,
                            reduce = true, sort = true)

    fcsRaw = readSingleFlowFrame(fn) #readFlowset(fn)
    cleanNames!(fcsRaw)

    # extract lineage markers
    lineageMarkers, functionalMarkers = getMarkers(panel)

    cc = map(Symbol, vcat(lineageMarkers, functionalMarkers))
    # markers can be lineage and functional at tthe same time
    # therefore make cc unique
    unique!(cc)

    #=
    transformData(fcsRaw, method, cofactor)

    dfall = []
    colnames = []

    df = fcsRaw
    df = sortReduce(df, cc, reduce, sort)

    insertcols!(df, 1, sample_id = string(k))
    push!(dfall,df)

    # collect the column names of each file for order check
    push!(colnames, names(df))

    # # check if all the column names are in the same order
    if !(all(y->y==colnames[1], colnames))
        throw(UndefVarError(:TheColumnOrderIsNotEqual))
    end

    dfall = vcat(dfall...)
=#
    # return a reference to dfall to be used by trainGigaSOM
    #dfallRefMatrix = convertTrainingData(dfall[:, cc])
    dfallRefMatrix = convertTrainingData(fcsRaw[:, cc])
    dfallRef = Ref{Array{Float64, 2}}(dfallRefMatrix)

    # return random samples for init Grid
    #gridSize = 100
    #nSamples = convert(Int64, floor(gridSize/nworkers()))

    # return (dfall[rand(1:nSamples, 2), :], dfallRef)
    return (dfallRef)
end
