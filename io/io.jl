
using GigaSOM, DataFrames, XLSX, CSV, Test, Random, Distributed, SHA, JSON

checkDir()
#create genData and data folder and change dir to dataPath
cwd = pwd()
#
dataPath = "/Users/ohunewald/work/GigaSOM.jl/test/data"
cd(dataPath)
md = DataFrame(XLSX.readtable("PBMC8_metadata.xlsx", "Sheet1", infer_eltypes=true)...)
panel = DataFrame(XLSX.readtable("PBMC8_panel.xlsx", "Sheet1", infer_eltypes=true)...)
#
lineageMarkers, functionalMarkers = getMarkers(panel)

nWorkers = 2
addprocs(nWorkers)
@everywhere using GigaSOM

@info "processes added"

 @everywhere function loadData(fn, md, panel)

    fcsRaw = readFlowset(fn)

    cleanNames!(fcsRaw)

    # create daFrame
    daf = createDaFrame(fcsRaw, md, panel)

    # return a random sample
    return ones(1,1)
    #gridSize = 100
    #nSamples = convert(Int64, floor(gridSize/nworkers()))
    #return daf.fcstable[rand(1:nSamples, nSamples), :]
end



@info "loadData function defined"

#lineageMarkers, functionalMarkers = getMarkers(panel)
R = Vector{Any}(undef,nworkers())

@info "loop started"
# load files in parallel
N = convert(Int64, length(md.file_name)/nWorkers)

@time @sync for (idx, pid) in enumerate(workers())
            #@show idx
            #@show pid
            @async R[idx] = @spawnat pid begin
                loadData(md.file_name[(idx-1)*N+1:idx*N], md, panel)
            end
    end


rmprocs(workers())





