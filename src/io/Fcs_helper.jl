
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
    cleanNames!(mydata)

Replaces problematic characters in column names.
Checks if the column name contains a '-' and transforms it to and '_' and it checks if the name starts with a number.

# Arguments:
- `mydata`: dict fcs_raw or array of string
"""
function cleanNames!(mydata)
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
    createDaFrame(fcs_raw, md, panel)

Creates a daFrame of type struct.
Read in the fcs raw, add sample id, subset the columns and transform

# Arguments:
- `fcs_raw`: raw FCS data
- `md`: Metadata table
- `panel`: Panel table with a column for Lineage Markers and one for Functional Markers
"""
function createDaFrame(fcs_raw, md, panel)

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

Returns the lineage and functional markers on a given panel

# Arguments:
- `panel`: Panel table with a column for Lineage Markers and one for Functional Markers
"""
function getMarkers(panel)

    # extract lineage markers
    lineage_markers = panel.fcs_colname[panel.Lineage .== 1, : ]
    functional_markers = panel.fcs_colname[panel.Functional .== 1, :]

    # lineage_markers are 2d array,
    # flatten this array by using vec:
    lineage_markers = vec(lineage_markers)
    functional_markers = vec(functional_markers)
    cleanNames!(lineage_markers)
    cleanNames!(functional_markers)

    return lineage_markers, functional_markers

end
