"""
Collect the meta data information in a more user friendly format.
"""
function getMetaData(f)

    # initializations
    meta = f.params
    channel_properties = []

    # determine the number of channels
    pars = parse(Int, strip(join(meta["\$PAR"])))

    # Channel number count starts from 0
    channel_numbers = 1:pars

    # determine the channel properties
    for (key,) in meta
        if key[1:3] == "\$P1"
            if !occursin(key[4], "0123456789")
                push!(channel_properties, key[4:end])
            end
        end
    end

    # define the column names
    column_names = ["\$Pn$p" for p in channel_properties]

    # Capture all the channel information in a list of lists -- used to create a data frame
    df = DataFrame([Vector{Any}(undef, 0) for i = 1:length(column_names)])
    for ch in channel_numbers
        push!(df, [meta["\$P$ch$p"] for p in channel_properties])
    end

    # set the names of the df
    names!(df, Symbol.(column_names))

    return df

end


using FileIO, DataFrames, FCSFiles
f = load("/Users/laurent.heirendt/Downloads/file1.fcs")
meta = getMetaData(f)