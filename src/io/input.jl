"""
    readFlowset(filenames::AbstractArray)

Create a dictionary with filenames as keys and daFrame as values

# Arguments:
- `filenames`: Array of type string with names of files
"""
function readFlowset(filenames::AbstractArray)::Dict{String, DataFrame}
    @warn "This function will be deprecated in a future version. Please use readFlowFrame(filenames)."

    readFlowFrame(filenames)
end

"""
    readFlowFrame(filename)

Create a dictionary with a single flowframe

# Arguments:
- `filename`: string
"""
function readFlowFrame(fn::String)::DataFrame
    _, _, colnames, data = readFCS(fn)
    return DataFrame(data, Symbol.(colnames))
end

"""
    readFlowFrame(filenames::AbstractArray)

Create a dictionary with filenames as keys and daFrame as values

# Arguments:
- `filenames`: Array of type string with names of files
"""
function readFlowFrame(filenames::AbstractArray)::Dict{String, DataFrame}
    flowFrame = Dict()
    for name in filenames # file list
        flowFrame[name] = readFlowFrame(name)
    end
    return flowFrame
end

"""
    loadFCSHeader(fn::String)::Tuple{Vector{Int}, Dict{String,String}}

Efficiently extract data offsets and keyword dictionary from an FCS file.
"""
function loadFCSHeader(fn::String)::Tuple{Vector{Int}, Dict{String,String}}
    open(fn) do io
        offsets = FCSFiles.parse_header(io)
        params = FCSFiles.parse_text(io, offsets[1], offsets[2])
        FCSFiles.verify_text(params)
        (offsets, params)
    end
end

"""
    getFCSSize(offsets, params)::Tuple{Int,Int}

Convert the offsets and keywords from an FCS file to cell and parameter count,
respectively.
"""
function getFCSSize(offsets, params)::Tuple{Int,Int}
    nData = parse(Int, params["\$TOT"])
    nParams = parse(Int, params["\$PAR"])

    if params["\$DATATYPE"]!="F"
        @error "Only float32 FCS files are currently supported"
        error("Unsupported FCS format")
    end

    beginData = parse(Int, params["\$BEGINDATA"])
    endData = parse(Int, params["\$ENDDATA"])

    #check that the $TOT and $PAR look okay
    if !(offsets[3]==0 && offsets[4]==0) &&
        (1+offsets[4]-offsets[3] != nData*nParams*4 ||
        offsets[3]!=beginData || offsets[4] != endData)
        @error "Data size mismatch, FCS is likely broken."
        error("Data size mismatch")
    end

    return (nData, nParams)
end

"""
    loadFCSSizes(fns::Vector{String})

Load cell counts in many FCS files at once. Useful as input for `slicesof`.
"""
function loadFCSSizes(fns::Vector{String})
    [(begin
        o,s = loadFCSHeader(fn)
        getFCSSize(o,s)[1]
      end
     ) for fn in fns]
end

"""
    loadFCS(fn::String)::Tuple{Dict{String,String}, Vector{String}, Vector{String}, Matrix{Float64}}

Read a FCS file. Return a tuple that contains in order:

- dictionary of the keywords contained in the file
- raw column names
- prettified and annotated column names
- raw data matrix
"""
function loadFCS(fn::String)::Tuple{Dict{String,String}, Vector{String}, Vector{String}, Matrix{Float64}}
    fcs = FileIO.load(fn)
    meta = getMetaData(fcs.params)
    colnames, nicenames = getMarkerNames(meta)
    cleanNames!(nicenames)
    data = hcat(map(x->Vector{Float64}(fcs.data[x]), colnames)...)
    return (fcs.params, colnames, nicenames, data)
end

"""
    loadData(name::Symbol, fns::Vector{String}, pids=workers())::LoadedDataInfo

This runs the FCS loading machinery in a distributed way, so that the files
`fns` (with full path) are sliced into equal parts and saved as a distributed
variable `name` on workers specified by `pids`.

See `slicesof` for description of the slicing.

The loaded dataset can be manipulated by the distributed functions, e.g.
- `dselect` for removing columns
- `dscale` for normalization
- `dtransform_asinh` (and others) for transformation
- etc.
"""
function loadData(name::Symbol, fns::Vector{String}, pids=workers())::LoadedDataInfo
    slices = slicesof(loadFCSSizes(fns), length(pids))
    distributed_foreach(slices,
        (slice) -> eval(:(
            begin
                $name = vcollectSlice(loadMtxFCS($fns), $slice)
                nothing
            end
        )), pids)
    return LoadedDataInfo(name, pids)
end
