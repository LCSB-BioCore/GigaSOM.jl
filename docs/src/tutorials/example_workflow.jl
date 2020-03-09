import Pkg
Pkg.activate("GigaSOM")

using Distributed
using GigaSOM
using ClusterManagers

checkDir()
cwd = pwd()

metadataFile = "metadata_100.xlsx"
panelFile = "panel.xlsx"
dataPath = ENV["SCRATCH"]*"/GigaSOM/data" 

cd(dataPath)
md = GigaSOM.DataFrame(GigaSOM.XLSX.readtable(metadataFile, "Sheet1", infer_eltypes=true)...)
panel = GigaSOM.DataFrame(GigaSOM.XLSX.readtable(panelFile, "Sheet1", infer_eltypes=true)...)

lineageMarkers, functionalMarkers = getMarkers(panel)

const IN_SLURM = "SLURM_JOBID" in keys(ENV)

nWorkers = parse(Int, ENV["SLURM_NTASKS"])
addprocs_slurm(nWorkers, topology=:master_worker)
@everywhere using GigaSOM

using Logging
global_logger(ConsoleLogger(stderr, Logging.Debug))

#check this out
@info "Distribution:" workers=workers()

# dInfo: LoadedDataInfo object that describes the data distributed on the workers
dInfo = loadData(:myData, dataPath, md, workers(), panel=panel, reduce=true, transform=true)

som = initGigaSOM(dInfo, 10, 10)

cc = map(Symbol, vcat(lineageMarkers, functionalMarkers))

@time som = trainGigaSOM(som, dInfo)

# winners = mapToGigaSOM(som, dInfo)

# @time embed = embedGigaSOM(som, dInfo, k=10)

rmprocs(workers())
cd(cwd)
