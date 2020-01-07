"""
    readFlowset(filenames::AbstractArray)

Create a dictionary with filenames as keys and daFrame as values

# Arguments:
- `filenames`: Array of type string with names of files
"""
function readFlowset(filenames::AbstractArray)
    @warn "This function will be deprecated in a future version. Please use readFlowFrame(filenames)."

    readFlowFrame(filenames)
end

"""
    readFlowFrame(filenames::AbstractArray)

Create a dictionary with filenames as keys and daFrame as values

# Arguments:
- `filenames`: Array of type string with names of files
"""
function readFlowFrame(filenames::AbstractArray)

    flowFrame = Dict()

    # read all FCS files into flowFrame
    for name in filenames # file list
        flowFrame[name] = readFlowFrame(name)
    end

    return flowFrame
end

"""
    readFlowFrame(filename)

Create a dictionary with a single flowframe

# Arguments:
- `filename`: string
"""
function readFlowFrame(filename::String)

    #flowFrame = Dict()

    # read single FCS file into flowFrame
    flowrun = FileIO.load(filename) # FCS file

    # get metadata
    # FCSFiles returns a dict with coumn names as key
    # As the dict is not in order, use the name column form meta
    # to sort the Dataframe after cast.
    meta = getMetaData(flowrun)
    markers = meta[!, Symbol("\$PnS")]
    markersIsotope = meta[!, Symbol("\$PnN")]
    # if marker labels are empty use Isotope marker as column names
    if markers[1] == " "
        markers = markersIsotope
    end
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

    fcsRaw = readFlowFrame(fn)
    cleanNames!(fcsRaw)

    # extract lineage markers
    lineageMarkers, functionalMarkers = getMarkers(panel)

    cc = map(Symbol, vcat(lineageMarkers, functionalMarkers))
    # markers can be lineage and functional at tthe same time
    # therefore make cc unique
    unique!(cc)

    fcsData = transformData(fcsRaw, method, cofactor)
    fcsData = sortReduce(fcsData, cc, reduce, sort)

    # get the sample_id from md
    # return value is an array with only one entry -> take [1]
    sid = md.sample_id[md.file_name .== fn][1]
    insertcols!(fcsData, 1, sample_id = sid)

    # return a reference to dfall to be used by trainGigaSOM
    dfallRefMatrix = convertTrainingData(fcsData[:, cc])
    dfallRef = Ref{Array{Float64, 2}}(dfallRefMatrix)

    return (dfallRef, myid())
end
