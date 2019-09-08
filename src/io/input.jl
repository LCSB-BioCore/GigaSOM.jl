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

        # get metadata
        # FCSFiles returns a dict with coumn names as key
        # As the dict is not in order, use the name column form meta
        # to sort the Dataframe after cast.
        meta = getMetaData(flowrun)
        markers = meta[:,1]
        markersIsotope = meta[:,5]
        flowDF = DataFrame(flowrun.data)
        # sort the DF according to the marker list
        flowDF = flowDF[:, Symbol.(markersIsotope)]
        cleanNames!(markers)

        names!(flowDF, Symbol.(markers), makeunique=true)
        flowFrame[name] = flowDF
    end

    return flowFrame
end
