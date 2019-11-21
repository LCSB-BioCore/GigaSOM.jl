@info "Start ... "
using Distributed, XLSX, DataFrames, FileIO

# read directory
#listFiles = readdir("fcs")

md = DataFrame(XLSX.readtable("PBMC8_metadata.xlsx", "Sheet1", infer_eltypes=true)...)
panel = DataFrame(XLSX.readtable("PBMC8_panel.xlsx", "Sheet1", infer_eltypes=true)...)

@info "md and panel files read"

cd("fcs")

# local read data function
nWorkers = 4
addprocs(nWorkers)
@everywhere using DataFrames
@everywhere using GigaSOM
#@everywhere using FCSFiles
#@everywhere using FileIO

#@everywhere md=$md

@info "processes added"

@everywhere function loadData(fn)

    # load FCS file
    #@info fn
    #sleep(1.0)
    fcsRaw = readFlowset(fn)

    # clean names
    #cleanNames!(fcsRaw)

    # create daFrame
    #daf = createDaFrame(fcsRaw, md, panel)

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
#@time loadData([md.file_name[1]], panel)
#@info "first file loaded"
@time @sync for (idx, pid) in enumerate(workers())
            #@show idx
            #@show pid
            @async R[idx] = @spawnat pid begin
                #@show "reading $idx"
                #readFlowset(md.file_name[(idx-1)*N+1:idx*N, :])
                #sleep(1.0)
                loadData(md.file_name[(idx-1)*N+1:idx*N])
            end
    end

#=
func_future = Array{Future, 1}()
for file in md.file_name
        func_fut = @spawn FileIO.load(file)
        push!(func_future, func_fut)
end
=#

@info "loop ended"

cd("..")
rmprocs(workers())




@info "Start ... "
using Distributed, XLSX, DataFrames, FileIO

# read directory
#listFiles = readdir("fcs")

md = DataFrame(XLSX.readtable("PBMC8_metadata.xlsx", "Sheet1", infer_eltypes=true)...)
addprocs(4)
cd("fcs")
@everywhere using GigaSOM, FileIO
function parallelFile(md; N=16)
    @sync @distributed for i=1:N
        #fcsRaw = readFlowset([md.file_name[i]])
        fcsRaw = FileIO.load(md.file_name[i])
    end
end

@time parallelFile(md)