location = ENV["HOME"]*"/Archive_AF_files" #"/artificial_data_cytof" #"/Archive_AF_files"
binFileType = ".jls"
nWorkers = 12
cd(location)
fileDir = readdir(location)

mdFileName = location*"/metadata.xlsx"

using GigaSOM, FileIO, Test, Serialization, FCSFiles
md = GigaSOM.DataFrame(GigaSOM.XLSX.readtable(mdFileName, "Sheet1")...)

include("satellites.jl")

localStartVect, localEndVect = generateIO(fileNames, nWorkers, true, 1, true)

#= split the file properly speaking
open(f -> serialize(f,out), "out.jls", "w")
y = open(deserialize, "out.jls")
@test y == outa
=#
