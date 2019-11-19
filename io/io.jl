using Distributed, XLSX, DataFrames, FileIO

# read directory
#listFiles = readdir("fcs")

md = DataFrame(XLSX.readtable("PBMC8_metadata.xlsx", "Sheet1", infer_eltypes=true)...)
panel = DataFrame(XLSX.readtable("PBMC8_panel.xlsx", "Sheet1", infer_eltypes=true)...)

cd("fcs")

# local read data function
nWorkers = 2

addprocs(nWorkers)
@everywhere using GigaSOM,  DataFrames, FCSFiles

@everywhere function loadData(md, panel)

    # load FCS file
    fcsRaw = readFlowset(md.file_name)

    # clean names
    cleanNames!(fcsRaw)

    # create daFrame
    daf = createDaFrame(fcsRaw, md, panel)

    # return a random sample
    gridSize = 100
    nSamples = convert(Int64, floor(gridSize/nworkers()))
    return daf.fcstable[rand(1:nSamples, nSamples), :]
end

#lineageMarkers, functionalMarkers = getMarkers(panel)
R = Vector{Any}(undef,nworkers())

# load files in parallel
N = convert(Int64, length(md.file_name)/nWorkers)
@sync begin
        for (idx, pid) in enumerate(workers())
            R[idx] =  fetch(@spawnat pid loadData(md[(idx-1)*N+1:idx*N, :], panel))
        end
end

cd("..")
rmprocs(workers())
