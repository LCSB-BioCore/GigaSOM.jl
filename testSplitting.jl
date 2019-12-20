using GigaSOM, FileIO, Test, Serialization, FCSFiles

location = ENV["HOME"]*"/Archive_AF_files" #"/artificial_data_cytof" #"/Archive_AF_files"
binFileType = ".jls"
nWorkers = 12
cd(location)
mdFileName = location*"/metadata.xlsx"

# read the directory and their metadata
fileDir = readdir(location)
md = GigaSOM.DataFrame(GigaSOM.XLSX.readtable(mdFileName, "Sheet1")...)

include("satellites.jl")

# test the sizes
totalSize, inSize, runSum = getTotalSize(md, 0)

@test totalSize == 3295
@test inSize == [500, 800, 150, 200, 625, 330, 290, 400]
@test runSum == [500, 1300, 1450, 1650, 2275, 2605, 2895, 3295]


#test if the differences between the local indices correspond
@test sum(localEndVect - localStartVect) + length(localEndVect) == totalSize

@test localStartVect' == [1  275  1  50  324  598  1  72  1  196  1  270  544  1  193  1  137  1  121]
@test localEndVect' == [274  500  49  323  597  800  71  150  195  200  269  543  625  192  330  136  290  120  400]
