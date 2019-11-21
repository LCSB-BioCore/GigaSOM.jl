using Distributed, XLSX, DataFrames, FileIO

# read directory
#listFiles = readdir("fcs")

md = DataFrame(XLSX.readtable("PBMC8_metadata.xlsx", "Sheet1", infer_eltypes=true)...)
panel = DataFrame(XLSX.readtable("PBMC8_panel.xlsx", "Sheet1", infer_eltypes=true)...)

@info "md and panel files read"

cd("fcs")

addprocs(2)
@everywhere using GigaSOM, FileIO, DataFrames

@info "packages loaded"

@everywhere struct Object
    table::DataFrame
end

@everywhere function loadData(ch, fn)

    # load FCS file
    #@show fn
    fcsRaw = readFlowset(fn)

    # clean names
    cleanNames!(fcsRaw)

    # create daFrame
    daf = fcsRaw.vals[1] #createDaFrame(fcsRaw)

    # return a random sample
    gridSize = 100
    #nSamples = 10
    nSamples = convert(Int64, floor(gridSize/nworkers()))
    #@show nSamples
    #@show daf[rand(1:nSamples, nSamples), :]
    #put!(ch, rand(1:nSamples, nSamples))
    put!(ch, Object(daf[rand(1:nSamples, nSamples), :]))
    #return daf.fcstable[rand(1:nSamples, nSamples), :]
end

function distributed_channel_load(fileload_func, filenames; ctype=Any, csize=2^10)
    Channel(ctype=ctype, csize=csize) do local_ch
		remote_ch = RemoteChannel(()->local_ch)

		c_pool = CachingPool(workers())
        file_dones = map(filenames) do filename
            #@show filename
            remotecall(fileload_func, c_pool, remote_ch, [filename])
        end

		# Wait till all the all files are done
        for file_done in file_dones
            #@show file_done
			wait(file_done)
		end
		clear!(c_pool)
	end
end

function test_loading(channel_load)
    inchannel = channel_load(loadData, md.file_name; ctype=Any)
    take!(inchannel)
end

@time out = test_loading(distributed_channel_load)
cd("..")
rmprocs(workers())


