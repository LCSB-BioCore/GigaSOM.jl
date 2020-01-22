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

    rename!(flowDF, Symbol.(markers), makeunique=true)

    return flowDF
end

"""
    loadData(dataPath, data, nWorkers; panel=Nothing(), 
            type = "fcs", method = "asinh", cofactor = 5,
            reduce = false, sort = false, transform = false)

This function is of 2 parts. Part 1: Generates the temporary binaray files to be loaded by the
    workers. The Input data will be equally divided into n parts according to the number of workers.
    Part2: each worker loads independently its own data-package in parallel and returns

# Arguments:
- `dataPath`: path to data folder
- `data`: single filename::String or a metadata::DataFrame with a column sample_name
- `panel`: Panel table with a column for Lineage Markers and one for Functional Markers,
    or Array::{Int} used as column indices, default: Nothing()
- `type`: String, type of datafile, default FCS
- `method`: transformation method, default arcsinh, optional
- `cofactor`: Cofactor for transformation, default 5, optional
- `reduce`: Selected only columns which are defined by lineage and functional, optional,
    default: false. If false the check for any none columns to be removed (none columns can appear
    after concatenating FCS files as well as parameter like: time, event length)
- `sort`: Sort columns by name to make sure the order when concatinating the dataframes, optional, default: false
- `transform`: Boolean to indicate if the data will be transformed according to method, default: false
"""
function loadData(dataPath, data, nWorkers; panel=Nothing(), 
                type = "fcs", method = "asinh", cofactor = 5,
                reduce = false, sort = false, transform = false)

    # Split the data according to the number of worker as temp binary file
    # md can be a metadata file or a single file_name:
    # generateIO(dataPath, <filename>, nWorkers, true, 1, true)
    xRange = generateIO(dataPath, data, nWorkers, true, 1, true)

    R =  Vector{Any}(undef,nWorkers)

    # Load the data by each worker
    # Without panel file, all columns are loaded:
    # loadData(idx, "input-$idx.jls")
    # Columns ca be selected by an array of indicies:
    # loadData(idx, "input-$idx.jls", [3:6;9:11]) <- this will concatenate ranges into arrays
    # Please note that all optional arguments are by default "false"
    if type == "fcs"
        @sync for (idx, pid) in enumerate(workers())
            @async R[idx] = fetch(@spawnat pid loadFCSData(idx, "input-$idx.jls", panel, method,
                                cofactor,reduce, sort, transform))
        end
    else
        @error "File Type not yet supported!"
    end

    return R, xRange

end

"""
    loadFCSData(idx, fn, panel, method, cofactor, reduce, sort, transform)

Load the data in parallel on each worker. Returns a reference of the loaded Data

# Arguments:
- `idx`: worker index
- `fn`: filename
- `panel`: Panel table with a column for Lineage Markers and one for Functional Markers, 
    or Array::{Int} used as column indicies
- `method`: transformation method, default arcsinh, optional
- `cofactor`: Cofactor for transformation, default 5, optional
- `reduce`: Selected only columns which are defined by lineage and functional, optional,
    default: true. If false the check for any none columns to be removed (none columns can appear
    after concatenating FCS files as well as parameter like: time, event length)
- `sort`: Sort columns by name to make sure the order when concatinating the dataframes, optional, default: true
- `transform`: Boolean to indicate if the data will be transformed according to method
"""
function loadFCSData(idx, fn, panel, method, cofactor, reduce, sort, transform)

    y = open(deserialize, fn)
    fcsData = y[idx]
    cleanNames!(fcsData)

    # Define the clustering column by range object
    if typeof(panel) == Array{Int64,1}
        cc = panel
    elseif typeof(panel) == DataFrame
        # extract lineage markers
        lineageMarkers, functionalMarkers = getMarkers(panel)
        cc = map(Symbol, vcat(lineageMarkers, functionalMarkers))
        # markers can be lineage and functional at tthe same time
        # therefore make cc unique
        unique!(cc)
    else
        # If no panel is provided, use all column names as cc
        # and set reduce to false
        cc = map(Symbol, names(fcsData))
    end

    if transform
        fcsData = transformData(fcsData, method, cofactor)
    end
    sortReduce(fcsData, cc, reduce, sort)

    # get the sample_id from md
    # return value is an array with only one entry -> take [1]
    # sid = md.sample_id[md.file_name .== fn][1]
    # insertcols!(fcsData, 1, sample_id = sid)

    # return a reference to dfall to be used by trainGigaSOM
    dfallRefMatrix = convertTrainingData(fcsData[:, cc])
    dfallRef = Ref{Array{Float64, 2}}(dfallRefMatrix)

    # remove all the temp file
    rmFile(fn)

    return (dfallRef)
end

