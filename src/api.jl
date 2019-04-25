
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
        flowFrame[fname] = flowDF
    end
    return flowFrame
end



function cleannames!(mydata)

    # replace chritical characters
    # put "_" in front of colname in case it starts with a number
    println(typeof(mydata))
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
    elseif mydata isa Array
        for j in eachindex(mydata)
            mydata[j] = replace(mydata[j], "-"=>"_")
            if isnumeric(first(mydata[j]))
                mydata[j] = "_" * mydata[j]
            end
        end
    end

end



# "data transformation, currently only asinh"
# function transform_ff(flowset, method = "asinh", cofactor = 5)
#
#     # loop through every file in dict
#     # get the dataframe
#     # convert to matrix
#     # arcsinh transformation
#     # convert back to dataframe
#     for (k,v) in flowset
#         single_fcs = flowset[k]
#         colnames = names(single_fcs["data"]) # keep the column names
#         dMatrix = Matrix(single_fcs["data"])
#         # single_fcs["data"] = [(asinh(x)/cofactor) for x in dMatrix]
#         dMatrix = [(asinh(x)/cofactor) for x in dMatrix]
#
#         ddf = DataFrame(dMatrix)
#
#         names!(ddf, Symbol.(colnames))
#         single_fcs["data"] = ddf
#         flowset[k] = single_fcs
#     end
# end


function transform_ff2!(flowframe, method = "asinh", cofactor = 5)
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
        dMatrix = [asinh(x/cofactor) for x in dMatrix]

        ddf = DataFrame(dMatrix)

        names!(ddf, Symbol.(colnames))
        # single_fcs["data"] = ddf
        flowframe[k] = ddf
    end
end

# function transform_fcs!(daf)
#
#     cofactor = 5
#
#     colnames = names(daf.fcstable)
#     df_matrix = Matrix(daf.fcstable)
#     # print(typeof(df_matrix))
#     # TODO: error because of sample id
#     [(asinh(x) / cofactor) for x in df_matrix[:, 1:end-1]]
#     # df_matrix = [(asinh(x) / cofactor) for x in df_matrix[:, 1:end-1]]
#     ddf = DataFrame(df_matrix)
#     names!(ddf, Symbol.(colnames))
#     daf.fcstable = ddf
# end


"barplot of cell counts per sample"
function plotcounts(fcs_raw, md, group_by = "condition")

    df_barplot = DataFrame(filename = String[], size = Int[], condition = String[])

    for (k,v) in fcs_raw
        sid = md.sample_id[k .== md.file_name]
        # println(sid[1])
        condition = md.condition[k .== md.file_name]
        push!(df_barplot, (string(sid[1]), size(v)[1], condition[1]) )
    end
    sort!(df_barplot)
    bar(df_barplot.filename, df_barplot.size, title="Numer of Cells", group=df_barplot.condition,xrotation=60)
end

"read in the fcs raw, add sample id, subset the columns and transform"
function create_daFrame(fcs_raw, md, panel)

    transform_ff2!(fcs_raw)

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


function plotPCA(daf)
    dfall_median = aggregate(daf.fcstable, :sample_id, median)

    T = convert(Matrix, dfall_median)
    samples_ids = T[:,1]
    T_reshaped = permutedims(convert(Matrix{Float32}, T[:, 2:10]), [2, 1])

    my_pca = fit(PCA, T_reshaped)

    yte = MultivariateStats.transform(my_pca,T_reshaped)

    df_pca = DataFrame(yte')
    df_pca[:sample_id] = samples_ids

    # get the condition per sample id and add in DF
    v1= df_pca.sample_id; v2=md.sample_id
    idxs = indexin(v1, v2)
    df_pca[:condition] = md.condition[idxs]

    StatsPlots.@df df_pca scatter(:x1, :x2, group=:condition)
end


struct daFrame
    fcstable
    md::DataFrame
    panel::DataFrame
end


# TODO: implement function
"applies a function to all data sets in this frame"
function fsApply(args)
    body
end

# TODO: write functions exprs (original from flowCore package)
# which returns the data matrix. Find if we can use some
# kind of named matrix with column names and rownumbers
"returns the data matrix of a flow files"
function exprs(args)
    body
end


# TODO:
" This function is a workaround for R's match"
# this is a helper to find which sampleid has which condition
function matched(v1::Array, v2::Array)
    # tb implemented
end
