"""
    readFlowset(filenames)

Create a dictionary with filenames as keys and daFrame as values

# Arguments:
- `filenames`: Array of type string
"""
function readFlowset(md, fcsparser)


    flowFrame = Dict()

    # get the meta data from the first file
    meta, data = fcsparser.parse(md.file_name[1], reformat_meta=true)
    # get the channel names
    df = meta["_channels_"]."\$PnS"
    markers = String[]
    for i in df.values
        if i == nothing
            push!(markers, "nothing") # replace empty with nothing string
        else
            push!(markers, convert(String, i))
        end
    end

    cleanNames!(markers)
    # read all FCS files into flowFrame
    for name in md.file_name

        meta, data = fcsparser.parse(name, reformat_meta=true)
        data = DataFrame(data.values)
        names!(data, Symbol.(markers), makeunique=true)
        flowFrame[name] = data
    end

    return flowFrame
end
