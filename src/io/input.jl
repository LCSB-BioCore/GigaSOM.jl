
"""
    readFlowset(filenames)

Create a dictionary with filenames as keys and daFrame as values

# Arguments:
- `filenames`: Array of type string
"""
function readFlowset(filenames::Array{String})
    flowFrame = Dict{String, DataFrame}()

    # read all FCS files into flowFrame
    for name in filenames # file list
        flowrun = FileIO.load(name) # FCS file
        flowDF = DataFrame(flowrun.data)
        flowFrame[name] = flowDF
    end
    return flowFrame
end
