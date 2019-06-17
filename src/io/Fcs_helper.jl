
"""
    readflowset(filenames)

Create a dictionary with filenames as keys and daFrame as values

# Arguments:
- `filenames`: Array of type string
"""

function readflowset(filenames)
    flowFrame = Dict()

    # read all FCS files into flowFrame
    for name in filenames # file list
        flowrun = FileIO.load(name) # FCS file
        flowDF = DataFrame(flowrun.data)
        flowFrame[name] = flowDF
    end
    return flowFrame
end

"""
    transformData(flowframe, method = "asinh", cofactor = 5)

Tansforms FCS data. Currently only asinh

# Arguments:
- `flowframe`: Flowframe containing daFrame per sample
- `method`: transformation method
- `cofactor`: Cofactor for transformation
"""
function transformData(flowframe, method = "asinh", cofactor = 5)
    # loop through every file in dict
    # get the dataframe
    # convert to matrix
    # arcsinh transformation
    # convert back to dataframe
    for (k,v) in flowframe
        fcs_df = flowframe[k]
        colnames = names(fcs_df) # keep the column names
        dMatrix = Matrix(fcs_df)
        # single_fcs["data"] = [(asinh(x)/cofactor) for x in dMatrix]
        dMatrix = [(asinh(x)/cofactor) for x in dMatrix]

        ddf = DataFrame(dMatrix)

        names!(ddf, Symbol.(colnames))
        # single_fcs["data"] = ddf
        flowframe[k] = ddf
    end
end

"""
    cleannames!(mydata)

Replaces problematic characters in column names

# Arguments:
- `mydata`: dict fcs_raw or array of string
"""
function cleannames!(mydata)
    # replace chritical characters
    # put "_" in front of colname in case it starts with a number
    # println(typeof(mydata))
    if mydata isa Dict{Any, Any}
        for (k,v) in mydata
            colnames = names(v)
            for i in eachindex(colnames)
                colnames[i] = Symbol(replace(String(colnames[i]), "-"=>"_"))
                if isnumeric(first(String(colnames[i])))
                    colnames[i] = Symbol("_" * String(colnames[i]))
                end
            end
            names!(v, colnames)
        end
    else
        for j in eachindex(mydata)
            mydata[j] = replace(mydata[j], "-"=>"_")
            if isnumeric(first(mydata[j]))
                mydata[j] = "_" * mydata[j]
            end
        end
    end

end

"""
    create_daFrame(fcs_raw, md, panel)

Creates a daFrame of type struct.
Read in the fcs raw, add sample id, subset the columns and transform

# Arguments:
- `fcs_raw`: raw FCS data
- `md`: Metadata table
- `panel`: Panel table with column each for lineage and functional markers
"""
function create_daFrame(fcs_raw, md, panel)

    # extract lineage markers
    lineage_markers, functional_markers = getMarkers(panel)

    transformData(fcs_raw)

    for i in eachindex(md.file_name)
        df = fcs_raw[md.file_name[i]]
        df[:sample_id] = string(md.sample_id[i])
    end

    dfall = []
    for (k,v) in fcs_raw
        push!(dfall,v)
    end
    dfall = vcat(dfall...)
    cc = map(Symbol, vcat(lineage_markers, functional_markers))
    push!(cc, :sample_id)
    # reduce the dataset to lineage (and later) functional (state) markers
    dfall = dfall[:, cc]
    daf = daFrame(dfall, md, panel)
end


"""
    getMarkers(panel)

"""
function getMarkers(panel)

    # extract lineage markers
    lineage_markers = panel.fcs_colname[panel.Lineage .== 1, : ]
    functional_markers = panel.fcs_colname[panel.Functional .== 1, :]

    # lineage_markers are 2d array,
    # flatten this array by using vec:
    lineage_markers = vec(lineage_markers)
    functional_markers = vec(functional_markers)
    cleannames!(lineage_markers)
    cleannames!(functional_markers)

    return lineage_markers, functional_markers

end
