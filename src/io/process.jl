"""
    cleanNames!(mydata::Vector{String})

Replaces problematic characters in column names, avoids duplicate names, and
prefixes an '_' if the name starts with a number.

# Arguments:
- `mydata`: vector of names (gets modified)
"""
function cleanNames!(mydata::Vector{String})
    # replace problematic characters,
    # put "_" in front of colname in case it starts with a number
    # avoid duplicate names (add suffixes _2, _3, ...)
    usedNames=Set{String}()
    for j in eachindex(mydata)
        mydata[j] = replace(mydata[j], "-"=>"_")
        if isnumeric(first(mydata[j]))
            mydata[j] = "_" * mydata[j]
        end
        # avoid duplicate names
        if mydata[j] in usedNames
            idx=2
            while "$(mydata[j])_$idx" in usedNames
                idx += 1
            end
            mydata[j]*="_$idx"
        end
        push!(usedNames, mydata[j])
    end
end

"""
    getMetaData(f)
Collect the meta data information in a more user friendly format.

# Arguments:
- `f`: input structure with `.params` and `.data` fields
"""
function getMetaData(meta::Dict{String,String})::DataFrame

    # declarations and initializations
    metaKeys = keys(meta)
    channel_properties = []
    defaultValue = ""

    # determine the number of channels
    pars = parse(Int, strip(join(meta["\$PAR"])))

    # determine the available channel properties
    for (key,) in meta
        if length(key)>=2 && key[1:2] == "\$P"
            i=3
            while i<=length(key) && isdigit(key[i])
                i+=1
            end
            if i<=length(key) && !in(key[i:end], channel_properties)
                push!(channel_properties, key[i:end])
            end
        end
    end

    # create a data frame for the results
    df = Matrix{String}(undef, pars, length(channel_properties))
    df .= defaultValue
    df = DataFrame(df)
    rename!(df, Symbol.(channel_properties))

    # collect the data from params
    for ch in 1:pars
        for p in channel_properties
            if "\$P$ch$p" in metaKeys
                df[ch, Symbol(p)] = meta["\$P$ch$p"]
            end
        end
    end

    return df
end

"""
    getMarkerNames(meta::DataFrame)::Tuple{Vector{String}, Vector{String}}

Extract suitable raw names (useful for selecting columns) and pretty readable
names (useful for humans) from FCS file metadata.

"""
function getMarkerNames(meta::DataFrame)::Tuple{Vector{String}, Vector{String}}
    orig = Array{String}(meta[:,:N])
    nice = copy(orig)
    if hasproperty(meta, :S)
        for i in 1:size(meta,1)
            if strip(meta[i, :S]) != ""
                nice[i] = meta[i, :S]
            end
        end
    end
    return (orig, nice)
end


"""
    compensate!(data::Matrix{Float64}, spillover::Matrix{Float64}, cols::Vector{Int})

Apply a compensation matrix in `spillover` (the individual columns of which
describe, in order, the spillover of `cols` in `data`) to the matrix `data`
in-place.
"""
function compensate!(data::Matrix{Float64}, spillover::Matrix{Float64}, cols::Vector{Int})
    data[:,cols] = data[:,cols] * inv(spillover)
end

"""
    parseSpillover(str::String)::Union{Tuple{Vector{String},Matrix{Float64}}, Nothing}

Parses the spillover matrix from the string from FCS parameter value.
"""
function parseSpillover(str::String)::Tuple{Vector{String},Matrix{Float64}}
    fields = split(str, ',')
    n = parse(Int, fields[1])
    if length(fields) != 1 + n + n*n
        @error "Spillover matrix of size $n expects $(1+n+n*n) fields, got $(length(fields)) instead."
        error("Invalid spillover matrix")
    end

    names = fields[2:(1+n)]
    spill = collect(transpose(reshape(parse.(Float64, fields[(2+n):length(fields)]), n, n)))

    names, spill
end

"""
    getSpillover(params::Dict{String, String})::Union{Tuple{Vector{String},Matrix{Float64}}, Nothing}

Get a spillover matrix from FCS `params`. Returns a pair with description of
columns to be applied, and with the actual spillover matrix. Returns `nothing`
in case spillover is not present.
"""
function getSpillover(params::Dict{String, String})::Union{Tuple{Vector{String},Matrix{Float64}}, Nothing}
    spillNames = ["\$SPILL", "\$SPILLOVER", "SPILL", "SPILLOVER"]
    for i in spillNames
        if in(i, keys(params))
            return parseSpillover(params[i])
        end
    end
    return nothing
end
