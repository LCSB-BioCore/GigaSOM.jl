
# How to get started

For the installation of Julia or GigaSOM.jl please refer to the installation instructions.

## Cytometry Data

In this example we will use a subset of the Cytometry data from Bodenmiller et al.
(Bodenmiller et al., 2012). This data-set contains samples from peripheral blood
mononuclear cells (PBMCs) in unstimulated and stimulated conditions for 8 healthy donors.

10 cell surface markers (lineage markers) are used to identify different cell populations:
    - PBMC8_panel.xlsx (with Antigen name and columns for lineage markers and functional markers)
    - PBMC8_metadata.xlsx (file names, sample id, condition and patient id)

Before running this minimum working example, make sure to use the package:


```julia
using GigaSOM
```

## Input and output

The example data can be downloaded from [imlspenticton.uzh.ch/robinson_lab/cytofWorkflow/](http://imlspenticton.uzh.ch/robinson_lab/cytofWorkflow/)

You can fetch the files directly from within Julia:


```julia
# fetch the required data for testing and download the zip archive and unzip it
dataFiles = ["PBMC8_metadata.xlsx", "PBMC8_panel.xlsx", "PBMC8_fcs_files.zip"]
for f in dataFiles
    if !isfile(f)
        download("http://imlspenticton.uzh.ch/robinson_lab/cytofWorkflow/"*f, f)
        if occursin(".zip", f)
            run(`unzip PBMC8_fcs_files.zip`)
        end
    end
end
```

Read meta-data and panel as a `DataFrame`, and make sure that the column names match the CyTOF
FCS file names:


```julia
# Read  files as DataFrames
md = GigaSOM.DataFrame(GigaSOM.XLSX.readtable("PBMC8_metadata.xlsx", "Sheet1")...)
panel = GigaSOM.DataFrame(GigaSOM.XLSX.readtable("PBMC8_panel.xlsx", "Sheet1")...)
panel[:Isotope] = map(string, panel[:Isotope])
panel[:Metal] = map(string, panel[:Metal])
panel[:Antigen] = map(string, panel[:Antigen])
panel.Metal[1]=""
GigaSOM.insertcols!(panel,4,:fcs_colname => map((x,y,z)->x.*"(".*y.*z.*")".*"Dd",panel[:Antigen],panel[:Metal],panel[:Isotope]))
print(panel.fcs_colname)
```

Extract the lineage and functional markers with `getMarkers()` function:


```julia
lineageMarkers, functionalMarkers = getMarkers(panel)
```

Read FCS files `readFlowset()`:


```julia
fcsRaw = readFlowset(md.file_name)
```

`readFlowset()` is a wrapper function around [FCSFiles.jl](https://github.com/tlnagy/FCSFiles.jl). Please note the current limitations
of this package (i.e., the [limit for large files](https://github.com/tlnagy/FCSFiles.jl/blob/master/src/parse.jl#L20)).

Clean names to remove problematic characters in the column names:


```julia
cleanNames!(fcsRaw)
```

Finally, create a `daFrame` that contains the expression data as well as panel
and meta-data. It automatically applies a `asinh` tranformation with a cofactor of 5.


```julia
daf = createDaFrame(fcsRaw, md, panel)
```

## Creating a Self Organizing MAP (SOM)

The main advantage of `GigaSOM.jl` is the capability of parallel processing.
In order to activate this dependency, please activate the GigaSOM environment:


```julia
import Pkg; Pkg.activate("GigaSOM")
```

Alternatively, on the REPL, you can also activate the `GigaSOM` environment by typing `]`:
```julia
v(1.1) pkg> activate GigaSOM
```

Without the explicit declaration of multiple workers, `GigaSOM` will train the SOM grid on a single
core. Therefore, we will add some workers and make sure that `GigaSOM` is accessible to
all the workers:


```julia
using Distributed
addprocs(2) # the number of workers can be higher than 2
@everywhere using GigaSOM
```

We will use only the lineage markers (cell surface) for the training of the SOM map
and extract the expression data:


```julia
cc = map(Symbol, lineageMarkers)
dfSom = daf.fcstable[:,cc]
```

Initialize the SOM grid by size and expression values:


```julia
som2 = initGigaSOM(dfSom, 10, 10)
```

Train the SOM grid with the initialized SOM object and define the number of training
rounds (also referred to as *epochs*).


```julia
 som2 = trainGigaSOM(som2, dfSom, epochs = 10)
```

Finally, calculate the winner neurons from the trained SOM object:


```julia
winners = mapToGigaSOM(som2, dfSom)
```
