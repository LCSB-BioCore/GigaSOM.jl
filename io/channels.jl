
using GigaSOM, DataFrames, XLSX, CSV, Test, Random, Distributed, SHA, JSON

checkDir()
#create genData and data folder and change dir to dataPath
cwd = pwd()
#
dataPath = "/Users/ohunewald/work/data_felD1/"
cd(dataPath)
md = DataFrame(XLSX.readtable("metadata.xlsx", "Sheet1", infer_eltypes=true)...)
panel = DataFrame(XLSX.readtable("panel.xlsx", "Sheet1", infer_eltypes=true)...)

@info "md and panel files read"


addprocs(2)
@everywhere using GigaSOM, FileIO, DataFrames

@info "packages loaded"

@everywhere struct Object
    table::DataFrame
end

@everywhere function loadData(ch, fn, md, panel)

    # load FCS file
    fcsRaw = readFlowset(fn)
    println(keys(fcsRaw))
    # clean names
    cleanNames!(fcsRaw)

    # create daFrame
    # daf = fcsRaw.vals[1] #createDaFrame(fcsRaw)
    # daf = createDaFrame(fcsRaw, md, panel)

    # # return a random sample
    # gridSize = 100
    # nSamples = convert(Int64, floor(gridSize/nworkers()))

    # put!(ch, Object(daf[rand(1:nSamples, nSamples), :]))

end

function distributed_channel_load(fileload_func, filenames, md, panel; ctype=Any, csize=2^10)
    Channel(ctype=ctype, csize=csize) do local_ch
        remote_ch = RemoteChannel(()->local_ch)

        c_pool = CachingPool(workers())
        file_dones = map(filenames) do filename
            #@show filename
            remotecall(fileload_func, c_pool, remote_ch, [filename], md, panel)
        end

        # Wait till all the all files are done
        for file_done in file_dones
            wait(file_done)
        end
        clear!(c_pool)
    end
end

function test_loading(channel_load, md, panel)
    inchannel = channel_load(loadData, md.file_name, md ,panel; ctype=Any)
    take!(inchannel)
end

@time test_loading(distributed_channel_load, md, panel)
# @time test_loading(distributed_channel_load)

rmprocs(workers())