using Distributed, XLSX, DataFrames

# read directory
#listFiles = readdir("fcs")

md = DataFrame(XLSX.readtable("PBMC8_metadata.xlsx", "Sheet1", infer_eltypes=true)...)
listFiles = md.file_name
#panel = DataFrame(XLSX.readtable("PBMC8_panel.xlsx", "Sheet1", infer_eltypes=true)...)

# local read data function
nWorkers = 2

addprocs(nWorkers)
@everywhere using  DataFrames, FCSFiles

@everywhere function loadData(fileName, sid)
    @info string(sid) * " - " * string(fileName)

    return ones(2,2)
end


#lineageMarkers, functionalMarkers = getMarkers(panel)

#fcsRaw = readFlowset(md.file_name)
#cleanNames!(fcsRaw)

# create daFrame file
#daf = createDaFrame(fcsRaw, md, panel)

R = Vector{Any}(undef,nworkers())

# load files in parallel
N = convert(Int64, length(listFiles)/nWorkers)
@sync begin
        for (idx, pid) in enumerate(workers())
            R[idx] =  fetch(@spawnat pid loadData(listFiles[(idx-1)*N+1:idx*N], md.sample_id[(idx-1)*N+1:idx*N]))
        end
end

rmprocs(workers())
