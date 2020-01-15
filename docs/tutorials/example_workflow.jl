# Test the GigaSOM package first:
import Pkg
Pkg.activate("GigaSOM")
Pkg.update()

#Pkg.test("GigaSOM")
using Distributed
using GigaSOM

checkDir()
cwd = pwd()

dataPath = joinpath(dirname(pathof(GigaSOM)), "..")*"/test/data"
cd(dataPath)
md = GigaSOM.DataFrame(GigaSOM.XLSX.readtable("PBMC8_metadata.xlsx", "Sheet1", infer_eltypes=true)...)
panel = GigaSOM.DataFrame(GigaSOM.XLSX.readtable("PBMC8_panel.xlsx", "Sheet1", infer_eltypes=true)...)

lineageMarkers, functionalMarkers = getMarkers(panel)

nWorkers = 2
addprocs(nWorkers, topology=:master_worker)
@everywhere using GigaSOM

# Split the data according to the number of worker as temp binary file
# md can be a metadata file or a single file_name:
# generateIO(dataPath, <filename>, nWorkers, true, 1, true)
generateIO(dataPath, md, nWorkers, true, 1, true)

R =  Vector{Any}(undef,nWorkers)

# Load the data by each worker
# Without panel file, all columns are loaded:
# loadData(idx, "input-$idx.jls")
# Columns ca be selected by an array of indicies:
# loadData(idx, "input-$idx.jls", [3:6;9:11]) <- this will concatenate ranges into arrays
# Please note that all optional arguments are by default "false"
@time @sync for (idx, pid) in enumerate(workers())
    @async R[idx] = fetch(@spawnat pid loadData(idx, "input-$idx.jls", panel, 
                        reduce=true, transform=true))
end

som = initGigaSOM(R, 10, 10)

cc = map(Symbol, vcat(lineageMarkers, functionalMarkers))

@time som = trainGigaSOM(som, R)

winners = mapToGigaSOM(som, R)

embed = embedGigaSOM(som, R, k=10, smooth=0.0, adjust=0.5)

rmprocs(workers())
cd(cwd)