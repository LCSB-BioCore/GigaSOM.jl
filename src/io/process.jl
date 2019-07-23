
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
        fcsDf = flowframe[k]
        colnames = names(fcsDf) # keep the column names
        dMatrix = Matrix(fcsDf)
        dMatrix = asinh.(dMatrix / cofactor)
        ddf = DataFrame(dMatrix)

        names!(ddf, Symbol.(colnames))
        # singleFcs["data"] = ddf
        flowframe[k] = ddf
    end
end


"""
    cleanNames!(mydata)

Replaces problematic characters in column names.
Checks if the column name contains a '-' and transforms it to and '_' and it checks if the name starts with a number.

# Arguments:
- `mydata`: dict fcsRaw or array of string
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
    createDaFrame(fcsRaw, md, panel)

Creates a daFrame of type struct.
Read in the fcs raw, add sample id, subset the columns and transform

# Arguments:
- `fcsRaw`: raw FCS data
- `md`: Metadata table
- `panel`: Panel table with a column for Lineage Markers and one for Functional Markers
"""
function createDaFrame(fcsRaw, md, panel)

    # extract lineage markers
    lineageMarkers, functionalMarkers = getMarkers(panel)

    transformData(fcsRaw)

    for i in eachindex(md.file_name)
        df = fcsRaw[md.file_name[i]]
        df[:sample_id] = string(md.sample_id[i])
    end

    dfall = []
    for (k,v) in fcsRaw
        push!(dfall,v)
    end
    dfall = vcat(dfall...)
    cc = map(Symbol, vcat(lineageMarkers, functionalMarkers))
    push!(cc, :sample_id)
    # reduce the dataset to lineage (and later) functional (state) markers
    dfall = dfall[:, cc]
    daf = daFrame(dfall, md, panel)
end


"""
    getMarkers(panel)

Returns the `lineageMarkers` and `functionalMarkers` on a given panel

# Arguments:
- `panel`: Panel table with a column for Lineage Markers and one for Functional Markers
"""
function getMarkers(panel)

    # extract lineage markers
    lineageMarkers = panel.fcs_colname[panel.Lineage .== 1, : ]
    functionalMarkers = panel.fcs_colname[panel.Functional .== 1, :]

    # lineageMarkers are 2d array,
    # flatten this array by using vec:
    lineageMarkers = vec(lineageMarkers)
    functionalMarkers = vec(functionalMarkers)
    cleanNames!(lineageMarkers)
    cleanNames!(functionalMarkers)

    return lineageMarkers, functionalMarkers

end
