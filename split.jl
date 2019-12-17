location = ENV["HOME"]*"/artificial_data_cytof"
fileType = ".fcs"
binFileType = ".jls"

nWorkers = 4

fileDir = readdir(location)

mdFileName = location*"/metadata.xlsx"
panelFileName = location*"/panel.xlsx"

using GigaSOM, FileIO, Test
md = GigaSOM.DataFrame(GigaSOM.XLSX.readtable(mdFileName, "Sheet1")...)
panel = GigaSOM.DataFrame(GigaSOM.XLSX.readtable(panelFileName, "Sheet1")...)

# count the number of FCS files
nFiles = 0
for file in fileDir
    global nFiles
    if file[end-3:end] == fileType
        nFiles = nFiles + 1
    end
end

# read the file
fileName = "file1"
df = FileIO.load(fileName*fileType)

# write the dataframe as a binary file
open(f -> serialize(f,df), fileName*binFileType, "w")

y = open(deserialize, fileName*binFileType)

@test y.data == df.data
@test y.params == df.params

# determine length of the data
keyArray = collect(keys(df.data))
L = length(df.data[keyArray[1]])

# determine the size per file
fileL = Int(floor(L/nWorkers))

# determine the size of the last (residual) file
lastFileL = Int(fileL + L - nWorkers * fileL)

# split the file properly speaking
out = Dict()
for key in keyArray
    out[key] = df.data[key][1:fileL]
end
