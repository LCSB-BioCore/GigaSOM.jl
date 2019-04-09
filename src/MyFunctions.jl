
"reads in FCS files from metada list and retuns a flowset. Add sampleid as column"
# the package ReadFCS is very basic and only reads the marker names and not the description
# column ! which is used in the R workflow
# let's keep this function generic and only return the dict of dataframes (FCS files)
function readflowset(flist)
    flowFrame = Dict()

    # read all FCS files into flowFrame
    for fname in flist # file list

        flowfile = Dict()
        flowrun = load(fname) # FCS file
        flowfile["params"] = flowrun.params
        # change the data structure into a dataframe
        df = DataFrame()
        for (k,v) in flowrun.data
            # because column names start with a number
            # '_' has to be added to avoid conflict when
            # using as Symbol
            # TODO: check if first char start with a number
            df[Symbol("_",k)] = v

        end
        flowfile["data"] = df
        flowFrame[fname] = flowfile
    end
    return flowFrame
end

"simpler version of readflowset, does the cleaning of the col names"
function readflowset2(flist)
    flowFrame = Dict()

    # read all FCS files into flowFrame
    for fname in flist # file list
        flowrun = load(fname) # FCS file
        flowDF = DataFrame(flowrun.data)

        # replace chritical characters
        # put "_" in front of colname in case it starts with a number
        # TODO: check if string starts with a number 
        names!(flowDF, [Symbol(replace(String(j), "-"=>"_")) for j in names(flowDF)])
        names!(flowDF, [Symbol("_$i") for i in names(flowDF)])

        flowFrame[fname] = flowDF

    end
    return flowFrame
end


"data transformation, currently only asinh"
function transform_ff(flowset, method = "asinh", cofactor = 5)

    # loop through every file in dict
    # get the dataframe
    # convert to matrix
    # arcsinh transformation
    # convert back to dataframe
    for (k,v) in flowset
        single_fcs = flowset[k]
        colnames = names(single_fcs["data"]) # keep the column names
        dMatrix = Matrix(single_fcs["data"])
        # single_fcs["data"] = [(asinh(x)/cofactor) for x in dMatrix]
        dMatrix = [(asinh(x)/cofactor) for x in dMatrix]

        ddf = DataFrame(dMatrix)

        names!(ddf, Symbol.(colnames))
        single_fcs["data"] = ddf
        flowset[k] = single_fcs
    end
end


function transform_ff2(flowframe, method = "asinh", cofactor = 5)
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
