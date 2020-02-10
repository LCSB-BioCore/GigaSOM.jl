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
    fcs = FileIO.load(filename) # FCS file

    # get metadata
    # FCSFiles returns a dict with coumn names as key
    # As the dict is not in order, use the name column form meta
    # to sort the Dataframe after cast.
    meta = getMetaData(fcs)
    markersIsotope = Array{String}(meta[!, :N])
    # collect better marker names
    markers = copy(markersIsotope)
    if hasproperty(meta, :S)
        for i in 1:size(meta,1)
            if meta[i, :S] != ""
                markers[i] = meta[i, :S]
            end
        end
    end
    flowDF = DataFrame(fcs.data)
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
function loadData(name, dataPath, data; pids=workers(), panel=Nothing(),
                method = "asinh", cofactor = 5,
                reduce = false, sort = false, transform = false)::LoadedDataInfo

    xRange = generateIO(dataPath, data, length(pids), true, 1, true)

    distribute_jls_data(name,
        ["input-$i.jls" for i in 1:length(pids)],
        pids,
        panel=panel,
        method=method,
        cofactor=cofactor,
        reduce=reduce,
        sort=sort,
        transform=transform)

    return LoadedDataInfo(name, pids, xRange)
end

function unloadData(data::LoadedDataInfo)
    undistribute(data.val, data.pids)
end

"""
    loadDataFile(fn, panel, method, cofactor, reduce, sort, transform)

Load the data in parallel on each worker. Returns a reference of the loaded Data

# Arguments:
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
function loadDataFile(fn, panel, method, cofactor, reduce, sort, transform)

    data = deserialize(fn)
    cleanNames!(data)

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
        cc = map(Symbol, names(data))
    end

    if transform
        data = transformData(data, method, cofactor)
    end

    sortReduce(data, cc, reduce, sort)

    # get the sample_id from md
    # return value is an array with only one entry -> take [1]
    # sid = md.sample_id[md.file_name .== fn][1]
    # insertcols!(data, 1, sample_id = sid)

    # return a reference to dfall to be used by trainGigaSOM
    dfallMatrix = convertTrainingData(data[:, cc])

    # remove all the temp file
    rmFile(fn)

    return dfallMatrix
end

