"""
$(TYPEDSIGNATURES)

Efficiently extract data offsets and keyword dictionary from an FCS file.
"""
function load_fcs_header(fn::String)::Tuple{Vector{Int},Dict{String,String}}
    open(fn) do io
        offsets = FCSFiles.parse_header(io)
        params = FCSFiles.parse_text(io, offsets[1], offsets[2])
        FCSFiles.verify_text(params)
        (offsets, params)
    end
end

"""
$(TYPEDSIGNATURES)

Convert the offsets and keywords from an FCS file to cell and parameter count,
respectively.
"""
function read_fcs_size(offsets, params)::Tuple{Int,Int}
    nData = parse(Int, params["\$TOT"])
    nParams = parse(Int, params["\$PAR"])

    if params["\$DATATYPE"] != "F"
        @error "Only float32 FCS files are currently supported"
        error("Unsupported FCS format")
    end

    beginData = parse(Int, params["\$BEGINDATA"])
    endData = parse(Int, params["\$ENDDATA"])

    #check that the $TOT and $PAR look okay
    if !(offsets[3] == 0 && offsets[4] == 0) && (
        (
            1 + offsets[4] - offsets[3] != nData * nParams * 4 &&
            offsets[4] - offsets[3] != nData * nParams * 4
        ) ||
        offsets[3] != beginData ||
        offsets[4] != endData
    )
        @warn "Data size mismatch, FCS is likely broken."
    end

    return (nData, nParams)
end

"""
$(TYPEDSIGNATURES)

Load cell counts in many FCS files at once. Useful as input for `slicesof`.
"""
function read_fcs_sizes(fns::Vector{String})::Vector{Int}
    [(
        begin
            o, s = load_fcs_header(fn)
            read_fcs_size(o, s)[1]
        end
    ) for fn in fns]
end

"""
$(TYPEDSIGNATURES)

Read a FCS file. Return a tuple that contains in order:

- dictionary of the keywords contained in the file
- raw column names
- prettified and annotated column names
- raw data matrix

If `applyCompensation` is set, the function parses and retrieves a spillover
matrix (if any valid keyword in the FCS is found that would contain it) and
applies it to compensate the data.
"""
function load_fcs(
    fn::String;
    applyCompensation::Bool = true,
)::Tuple{Dict{String,String},Matrix{Float64}}
    fcs = FileIO.load(fn)
    meta = fcs_column_metadata(fcs.params)
    data = hcat(map(x -> Vector{Float64}(fcs.data[x]), meta[:, :N])...)
    if applyCompensation
        spill = fcs_spillover(fcs.params)
        if spill != nothing
            names, mtx = spill
            cols = indexin(names, meta[:, :N])
            if any(cols .== nothing)
                @error "Unknown columns in compensation matrix" names cols
                error("Invalid compensation matrix")
            end
            compensate!(data, mtx, Vector{Int}(cols))
        end
    end
    return (fcs.params, data)
end

export load_fcs

"""
$(TYPEDSIGNATURES)

This runs the FCS loading machinery in a distributed way, so that the files
`fns` (with full path) are sliced into equal parts and saved as a distributed
variable `name` on workers specified by `pids`.

`applyCompensation` is passed to load_fcs function.

See `slicesof` for description of the slicing.

`postLoad` is applied to the loaded FCS file data (and the index) -- use this
function to e.g. filter out certain columns right on loading, using `select_fcs_columns`.

The loaded dataset can be manipulated by the distributed functions, e.g.
- `dselect` for removing columns
- `dscale` for normalization
- `dtransform_asinh` (and others) for transformation
- etc.
"""
function load_fcs_distributed(
    name::Symbol,
    fns::Vector{String},
    pids = workers();
    applyCompensation = true,
    postLoad = (d, i) -> d,
)::Dinfo
    slices = slicesof(read_fcs_sizes(fns), length(pids))
    dmap(
        slices,
        (slice) -> Base.eval(
            Main,
            :(
                begin
                    $name = vcollect_slice(
                        (i) -> last(
                            $postLoad(
                                load_fcs($fns[i]; applyCompensation = $applyCompensation),
                                i,
                            ),
                        ),
                        $slice,
                    )
                    nothing
                end
            ),
        ),
        pids,
    )
    return Dinfo(name, pids)
end

export load_fcs_distributed

"""
$(TYPEDSIGNATURES)

Return a function useful with `load_fcs_distributed`, which loads only the specified
(prettified) column names from the FCS files. Use `fcs_column_metadata`,
`fcs_metadata_marker_names` and `clean_names!` to retrieve the usable column names for a
FCS.
"""
function select_fcs_columns(selectColnames::Vector{String})
    ((metadata, data), idx) -> begin
        _, names = fcs_metadata_marker_names(fcs_column_metadata(metadata))
        clean_names!(names)
        colIdxs = indexin(selectColnames, names)
        if any(colIdxs .== nothing)
            @error "Some columns were not found"
            error("unknown column")
        end
        (metadata, data[:, colIdxs])
    end
end

export select_fcs_columns

"""
$(TYPEDSIGNATURES)

Distribute a vector of integers among the workers that describes which file
from `fns` the cell comes from. Useful for producing per-file statistics. The
vector is saved on workers specified by `pids` as a distributed variable
`name`.
"""
function fcs_filevector_distribute(name::Symbol, fns::Vector{String}, pids = workers())::Dinfo
    sizes = read_fcs_sizes(fns)
    slices = slicesof(sizes, length(pids))
    return filevector_distribute(name, sizes, slices, pids)
end

"""
$(TYPEDSIGNATURES)

Generalized version of `fcs_filevector_distribute` that produces the integer
vector from any `sizes` and `slices`.
"""
function filevector_distribute(
    name::Symbol,
    sizes::Vector{Int},
    slices::Vector{Tuple{Int,Int,Int,Int}},
    pids = workers(),
)::Dinfo
    dmap(
        slices,
        (slice) ->
            Base.eval(Main, :($name = collect_slice((i) -> fill(i, $sizes[i]), $slice))),
        pids,
    )
    return Dinfo(name, pids)
end

"""
$(TYPEDSIGNATURES)

Read the dimensions (number of rows and columns, respectively) from a CSV file
`fn`. `args` are passed to function `CSV.file`.

# Example

    read_csv_size("test.csv", header=false)
"""
function read_csv_size(fn::String; args...)::Tuple{Int,Int}
    n = 0
    k = 0
    # ideally, this will not try to load the whole CSV in the memory
    for row in CSV.File(fn, types = Float64; args...)
        n += 1
        if length(row) > k
            k = length(row)
        end
    end
    return (n, k)
end

"""
$(TYPEDSIGNATURES)

Determine number of rows in a list of CSV files (passed as `fns`). Equivalent
to `read_fcs_sizes`.
"""
function read_csv_sizes(fns::Vector{String}; args...)::Vector{Int}
    [read_csv_size(fn, types = Float64; args...)[1] for fn in fns]
end

"""
$(TYPEDSIGNATURES)

CSV equivalent of `load_fcs`. The metadata (header, column names) are not
extracted. `args` are passed to `CSV.read`.
"""
function load_csv(fn::String; args...)::Matrix{Float64}
    CSV.read(fn, DataFrame, types = Float64; args...) |> Matrix{Float64}
end

export load_csv

"""
$(TYPEDSIGNATURES)

CSV equivalent of `load_fcs_distributed`. `csvargs` are passed as keyword arguments to
CSV-loading functions.
"""
function load_csv_distributed(
    name::Symbol,
    fns::Vector{String},
    pids = workers();
    postLoad = (d, i) -> d,
    csvargs...,
)::Dinfo
    slices = slicesof(read_csv_sizes(fns; csvargs...), length(pids))
    dmap(
        slices,
        (slice) -> Base.eval(
            Main,
            :(
                begin
                    $name = vcollect_slice(
                        (i) -> $postLoad(load_csv($fns[i]; $csvargs...), i),
                        $slice,
                    )
                    nothing
                end
            ),
        ),
        pids,
    )
    return Dinfo(name, pids)
end

export load_csv_distributed
