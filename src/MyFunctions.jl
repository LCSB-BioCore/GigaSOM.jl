
"reads in FCS files from metada list and retuns a flowset. Add sampleid as column"
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
