# Minimal Working Example

- For the installation of Julia or GigaSOM.jl please refer to the README section.

## Cytometry Data
#### Description:
- In this example we will use a subset of the Cytometry data from Bodenmiller et al.
  (Bodenmiller et al., 2012). This data-set contains samples from peripheral blood
  mononuclear cells (PBMCs) in unstimulated and stimulated conditions for 8 healthy donors.
  10 cell surface markers (lineage markers) are used to identify different cell populations.
    * PBMC8_panel.xlsx (with Antigen name and columns for lineage markers and functional markers)
    * PBMC8_metadata.xlsx (file names, sample id, condition and patient id)


#### File IO
- You can either download the data manually from their website
  [http://imlspenticton.uzh.ch/robinson_lab/cytofWorkflow/](http://imlspenticton.uzh.ch/robinson_lab/cytofWorkflow/)

- Or within Julia:
```julia
# fetch the required data for testing and download the zip archive and unzip it
dataFiles = ["PBMC8_metadata.xlsx", "PBMC8_panel.xlsx", "PBMC8_fcs_files.zip"]
for f in dataFiles
    if !isfile(f)
        download("http://imlspenticton.uzh.ch/robinson_lab/cytofWorkflow/"*f, f)
        if occursin(".zip", f)
            run(`unzip PBMC8_fcs_files.zip`)
        end
    else
    end
end
```
- Read meta-data and panel as DataFrame and make sure that the column names match the CyTOF
FCS file names:

```julia
# Read  files as DataFrames
md = DataFrame(XLSX.readtable("PBMC8_metadata.xlsx", "Sheet1")...)
panel = DataFrame(XLSX.readtable("PBMC8_panel.xlsx", "Sheet1")...)
panel[:Isotope] = map(string, panel[:Isotope])
panel[:Metal] = map(string, panel[:Metal])
panel[:Antigen] = map(string, panel[:Antigen])
panel.Metal[1]=""
insertcols!(panel,4,:fcs_colname => map((x,y,z)->x.*"(".*y.*z.*")".*"Dd",panel[:Antigen],panel[:Metal],panel[:Isotope]))
print(panel.fcs_colname)
```

- Extract the lineage and functional markers with *getMarkers()* function:
```julia
lineageMarkers, functionalMarkers = getMarkers(panel)
```

- Read FCS files *readFlowset()* :
```julia
fcsRaw = readFlowset(md.file_name)
```
  *readFlowset()* is a wrapper function around *FCSFiles.jl*. Due to current limitations
  of this package (FCS file size maximum is 99 MB and the description column is missing) we will
  move soon to *FCSParser* which is a *python* implementation.

- Clean names to remove problematic characters in the column names:
```julia
cleanNames!(fcsRaw)
```
- And finally we create a daFrame which contains the expression data as well as panel
and meta-data. It automatically applies a *asinh* tranformation with cofactor of 5.
(A future version will let the user choose different settings).
```julia
daf = createDaFrame(fcsRaw, md, panel)
```

#### Creating a Self Organizing MAP

- The main advantage of *GigaSOM.jl* is the capability of parallel processing. Without
the explicit declaration of multiple *workers* GigaSOM will train the som grid in single core
modus. Therefore we will add some workers and make sure that some packages are accessible to
all the workers:
```julia
addprocs(2)
@everywhere using DistributedArrays
@everywhere using GigaSOM
@everywhere using Distances
```
- We will use only the lineage markers (cell surface) for the training of the som map
and extract the expression data:
```julia
cc = map(Symbol, lineageMarkers)
dfSom = daf.fcstable[:,cc]
```
- Init the som grid by size and expression values:
```julia
som2 = initGigaSOM(dfSom, 10, 10)
```
- Train the som grid with the initialized som object and define the number of training
rounds (*epochs*). We let the function choose a default radius:
```julia
som2 = trainGigaSOM(som2, dfSom, epochs = 10)
```
- And finally calculate the winner neurons from the trained SOM object:
```julia
winners = mapToGigaSOM(som2, dfSom)
```
