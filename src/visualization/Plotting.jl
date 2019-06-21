"""
    plotCounts(fcsRaw, md, group_by = "condition")

Barplot showing the number of cells per sample, used as a guide to identify samples where not enough cells were assayed

# Arguments:
- `fcsRaw`: raw FCS data
- `md`: Metadata table
"""

function plotCounts(fcsRaw, md, group_by = "condition")

    df_barplot = DataFrame(filename = String[], size = Int[], condition = String[])

    for (k,v) in fcsRaw
        sid = md.sample_id[k .== md.file_name]
        # println(sid[1])
        condition = md.condition[k .== md.file_name]
        push!(df_barplot, (string(sid[1]), size(v)[1], condition[1]) )
    end
    sort!(df_barplot)
    bar(df_barplot.filename, df_barplot.size, title="Numer of Cells", group=df_barplot.condition,xrotation=60)
end


"""
    plotPCA(daFrame)

Plotting the PCA of all median marker expression

# Arguments:
- `daFrame`: daFrame containing the fcs data, metadata and panel
"""

function plotPCA(daf, md)
    dfall_median = aggregate(daf.fcstable, :sample_id, Statistics.median)

    T = convert(Matrix, dfall_median)
    samples_ids = T[:,1]
    T_reshaped = permutedims(convert(Matrix{Float64}, T[:, 2:10]), [2, 1])

    my_pca = StatsBase.fit(MultivariateStats.PCA, T_reshaped)

    yte = MultivariateStats.transform(my_pca,T_reshaped)

    df_pca = DataFrame(yte')
    df_pca[:sample_id] = samples_ids

    # get the condition per sample id and add in DF
    v1= df_pca.sample_id; v2=md.sample_id
    idxs = indexin(v1, v2)
    df_pca[:condition] = md.condition[idxs]

    StatsPlots.@df df_pca scatter(:x1, :x2, group=:condition)
end
