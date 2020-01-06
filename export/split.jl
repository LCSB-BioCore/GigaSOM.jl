using GigaSOM, FileIO, Test, Serialization, FCSFiles

location = ENV["HOME"]*"/Archive_AF_files" #"/artificial_data_cytof" #"/Archive_AF_files"
nWorkers = 4

mdFileName = location*"/metadata.xlsx"
md = GigaSOM.DataFrame(GigaSOM.XLSX.readtable(mdFileName, "Sheet1")...)

include("satellites.jl")

localStartVect, localEndVect = generateIO(location, md, nWorkers, true, 1, true)
