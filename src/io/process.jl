
"""
    transformData(flowframe, method, cofactor)

Tansforms FCS data. Currently only asinh

# Arguments:
- `flowframe`: Flowframe containing daFrame per sample
- `method`: transformation method
- `cofactor`: Cofactor for transformation
"""
function transformData(flowframe, method, cofactor)
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
- `method`: transformation method, default arcsinh, optional
- `cofactor`: Cofactor for transformation, default 5, optional
- `reduce`: Selected only columns which are defined by lineage and functional, optional, 
    default: true. If false the check for any none columns to be removed (none columns can appear 
    after concatenating FCS files as well as parameter like: time, event length)
- `sort`: Sort columns by name to make sure the order when concatinating the dataframes, optional, default: true 
"""
function createDaFrame(fcsRaw, md, panel; method = "asinh", cofactor = 5, reduce = true, sort = true)

    # extract lineage markers
    lineageMarkers, functionalMarkers = getMarkers(panel)

    cc = map(Symbol, vcat(lineageMarkers, functionalMarkers))
    # markers can be lineage and functional at tthe same time
    # therefore make cc unique
    unique!(cc)

    transformData(fcsRaw, method, cofactor)

    dfall = []
    colnames = []

    for (k, v) in fcsRaw
        
        df = v
        df = sortReduce(df, cc, reduce, sort)

        insertcols!(df, 1, sample_id = string(k))
        push!(dfall,df)
        # collect the column names of each file for order check
        push!(colnames, names(df))
    end

    # # check if all the column names are in the same order
    if !(all(y->y==colnames[1], colnames))
        throw(UndefVarError(:TheColumnOrderIsNotEqual))
    end

    dfall = vcat(dfall...)
    daf = daFrame(dfall, md, panel)
end


"""
    sortReduce(df, cc, reduce, sort)

Sorts the columns and/or reduces them to sleected markers

# Arguments:
- `df`: FCS dataframe
- `cc`: Columns to reduce to
- `reduce`: Boolean
- `sort`: Boolean
"""
function sortReduce(df, cc, reduce, sort)

    if reduce
        df = df[:, cc]
    else
        for n in names(df)
        # remove the None columns if the columns are not reduced
            if occursin(r"None", string(n))
                select!(df, Not(n))
            end
        end
    end

    # sort columns because the order is not garantiert
    if sort
        n = names(df)
        sort!(n)
        permutecols!(df, n)
    end
end


"""
    getMarkers(panel)

Returns the `lineageMarkers` and `functionalMarkers` on a given panel

# Arguments:
- `panel`: Panel table with a column for Lineage Markers and one for Functional Markers
"""
function getMarkers(panel)

    # extract lineage markers
    lineageMarkers = panel.Antigen[panel.Lineage .== 1, : ]
    functionalMarkers = panel.Antigen[panel.Functional .== 1, : ]

    # lineageMarkers are 2d array,
    # flatten this array by using vec:
    lineageMarkers = vec(lineageMarkers)
    functionalMarkers = vec(functionalMarkers)
    cleanNames!(lineageMarkers)
    cleanNames!(functionalMarkers)

    return lineageMarkers, functionalMarkers

end

"""
    getMetaData(f)
Collect the meta data information in a more user friendly format.

# Arguments:
- `f`: input structure with `.params` and `.data` fields
"""
function getMetaData(f)

    # declarations and initializations
    meta = f.params
    metaKeys = keys(meta)
    channel_properties = []
    defaultValue = "None"

    # determine the number of channels
    pars = parse(Int, strip(join(meta["\$PAR"])))

    # determine the range of channel numbers
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

    # create a data frame
    df = DataFrame([Vector{Any}(undef, 0) for i = 1:length(column_names)])

    # fill the data frame
    for ch in channel_numbers
        # build first each row of the datatable
        tmpV = []
        for p in channel_properties
            if "\$P$ch$p" in metaKeys
                tmp = meta["\$P$ch$p"]
            else
                tmp = defaultValue
            end
            push!(tmpV, tmp)
        end

        # push the row to the dataframe
        push!(df, tmpV)
    end

    # set the names of the df
    names!(df, Symbol.(column_names))

    return df
end