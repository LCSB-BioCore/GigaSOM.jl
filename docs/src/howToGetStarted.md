
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

    ┌ Warning: `getindex(df::DataFrame, col_ind::ColumnIndex)` is deprecated, use `df[!, col_ind]` instead.
    │   caller = top-level scope at In[3]:4
    └ @ Core In[3]:4
    ┌ Warning: `setindex!(df::DataFrame, v::AbstractVector, col_ind::ColumnIndex)` is deprecated, use `begin
    │     df[!, col_ind] = v
    │     df
    │ end` instead.
    │   caller = top-level scope at In[3]:4
    └ @ Core In[3]:4
    ┌ Warning: `getindex(df::DataFrame, col_ind::ColumnIndex)` is deprecated, use `df[!, col_ind]` instead.
    │   caller = top-level scope at In[3]:5
    └ @ Core In[3]:5
    ┌ Warning: `setindex!(df::DataFrame, v::AbstractVector, col_ind::ColumnIndex)` is deprecated, use `begin
    │     df[!, col_ind] = v
    │     df
    │ end` instead.
    │   caller = top-level scope at In[3]:5
    └ @ Core In[3]:5
    ┌ Warning: `getindex(df::DataFrame, col_ind::ColumnIndex)` is deprecated, use `df[!, col_ind]` instead.
    │   caller = top-level scope at In[3]:6
    └ @ Core In[3]:6
    ┌ Warning: `setindex!(df::DataFrame, v::AbstractVector, col_ind::ColumnIndex)` is deprecated, use `begin
    │     df[!, col_ind] = v
    │     df
    │ end` instead.
    │   caller = top-level scope at In[3]:6
    └ @ Core In[3]:6
    ┌ Warning: `getindex(df::DataFrame, col_ind::ColumnIndex)` is deprecated, use `df[!, col_ind]` instead.
    │   caller = top-level scope at In[3]:8
    └ @ Core In[3]:8
    ┌ Warning: `getindex(df::DataFrame, col_ind::ColumnIndex)` is deprecated, use `df[!, col_ind]` instead.
    │   caller = top-level scope at In[3]:8
    └ @ Core In[3]:8
    ┌ Warning: `getindex(df::DataFrame, col_ind::ColumnIndex)` is deprecated, use `df[!, col_ind]` instead.
    │   caller = top-level scope at In[3]:8
    └ @ Core In[3]:8


    ["CD3(110:114)Dd", "CD45(In115)Dd", "BC1(La139)Dd", "BC2(Pr141)Dd", "pNFkB(Nd142)Dd", "pp38(Nd144)Dd", "CD4(Nd145)Dd", "BC3(Nd146)Dd", "CD20(Sm147)Dd", "CD33(Nd148)Dd", "pStat5(Nd150)Dd", "CD123(Eu151)Dd", "pAkt(Sm152)Dd", "pStat1(Eu153)Dd", "pSHP2(Sm154)Dd", "pZap70(Gd156)Dd", "pStat3(Gd158)Dd", "BC4(Tb159)Dd", "CD14(Gd160)Dd", "pSlp76(Dy164)Dd", "BC5(Ho165)Dd", "pBtk(Er166)Dd", "pPlcg2(Er167)Dd", "pErk(Er168)Dd", "BC6(Tm169)Dd", "pLat(Er170)Dd", "IgM(Yb171)Dd", "pS6(Yb172)Dd", "HLA-DR(Yb174)Dd", "BC7(Lu175)Dd", "CD7(Yb176)Dd", "DNA-1(Ir191)Dd", "DNA-2(Ir193)Dd"]

Extract the lineage and functional markers with `getMarkers()` function:


```julia
lineageMarkers, functionalMarkers = getMarkers(panel)
```




    (["CD3(110:114)Dd", "CD45(In115)Dd", "CD4(Nd145)Dd", "CD20(Sm147)Dd", "CD33(Nd148)Dd", "CD123(Eu151)Dd", "CD14(Gd160)Dd", "IgM(Yb171)Dd", "HLA_DR(Yb174)Dd", "CD7(Yb176)Dd"], ["pNFkB(Nd142)Dd", "pp38(Nd144)Dd", "pStat5(Nd150)Dd", "pAkt(Sm152)Dd", "pStat1(Eu153)Dd", "pSHP2(Sm154)Dd", "pZap70(Gd156)Dd", "pStat3(Gd158)Dd", "pSlp76(Dy164)Dd", "pBtk(Er166)Dd", "pPlcg2(Er167)Dd", "pErk(Er168)Dd", "pLat(Er170)Dd", "pS6(Yb172)Dd"])



Read FCS files `readFlowset()`:


```julia
fcsRaw = readFlowset(md.file_name)
```




    Dict{Any,Any} with 16 entries:
      "PBMC8_30min_patient8_Reference.fcs" => 13670×35 DataFrames.DataFrame. Omitte…
      "PBMC8_30min_patient2_BCR-XL.fcs"    => 16675×35 DataFrames.DataFrame. Omitte…
      "PBMC8_30min_patient5_BCR-XL.fcs"    => 8543×35 DataFrames.DataFrame. Omitted…
      "PBMC8_30min_patient1_Reference.fcs" => 2739×35 DataFrames.DataFrame. Omitted…
      "PBMC8_30min_patient6_BCR-XL.fcs"    => 8622×35 DataFrames.DataFrame. Omitted…
      "PBMC8_30min_patient4_Reference.fcs" => 6906×35 DataFrames.DataFrame. Omitted…
      "PBMC8_30min_patient3_BCR-XL.fcs"    => 12252×35 DataFrames.DataFrame. Omitte…
      "PBMC8_30min_patient7_Reference.fcs" => 15974×35 DataFrames.DataFrame. Omitte…
      "PBMC8_30min_patient1_BCR-XL.fcs"    => 2838×35 DataFrames.DataFrame. Omitted…
      "PBMC8_30min_patient5_Reference.fcs" => 11962×35 DataFrames.DataFrame. Omitte…
      "PBMC8_30min_patient6_Reference.fcs" => 11038×35 DataFrames.DataFrame. Omitte…
      "PBMC8_30min_patient7_BCR-XL.fcs"    => 14770×35 DataFrames.DataFrame. Omitte…
      "PBMC8_30min_patient2_Reference.fcs" => 16725×35 DataFrames.DataFrame. Omitte…
      "PBMC8_30min_patient3_Reference.fcs" => 9434×35 DataFrames.DataFrame. Omitted…
      "PBMC8_30min_patient8_BCR-XL.fcs"    => 11653×35 DataFrames.DataFrame. Omitte…
      "PBMC8_30min_patient4_BCR-XL.fcs"    => 8990×35 DataFrames.DataFrame. Omitted…



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

    ┌ Warning: Implicit broadcasting to a new column in DataFrame assignment is deprecated.Use an explicit broadcast with `df[!, col_ind] .= v`
    │   caller = createDaFrame(::Dict{Any,Any}, ::DataFrames.DataFrame, ::DataFrames.DataFrame) at process.jl:88
    └ @ GigaSOM /Users/laurent.heirendt/.julia/packages/GigaSOM/QAKEY/src/io/process.jl:88





    daFrame(172791×25 DataFrames.DataFrame. Omitted printing of 21 columns
    │ Row    │ CD3(110:114)Dd │ CD45(In115)Dd │ CD4(Nd145)Dd │ CD20(Sm147)Dd │
    │        │ [90mFloat32[39m        │ [90mFloat32[39m       │ [90mFloat32[39m      │ [90mFloat32[39m       │
    ├────────┼────────────────┼───────────────┼──────────────┼───────────────┤
    │ 1      │ 0.863966       │ 4.59768       │ -0.157656    │ -0.131486     │
    │ 2      │ 1.90267        │ 5.88631       │ 2.13232      │ 2.4149        │
    │ 3      │ 4.96538        │ 6.63111       │ -0.100279    │ 0.993387      │
    │ 4      │ 2.92577        │ 5.08396       │ -0.0759843   │ 1.50545       │
    │ 5      │ 4.19087        │ 6.53202       │ 2.49969      │ 2.24803       │
    │ 6      │ 3.78095        │ 5.96461       │ 1.66088      │ 0.201739      │
    │ 7      │ -1.04096       │ 5.53396       │ 1.65052      │ 5.1049        │
    │ 8      │ 4.36623        │ 6.24286       │ 4.87603      │ -0.0164116    │
    │ 9      │ 1.36755        │ 1.2471        │ 3.8174       │ -0.112002     │
    │ 10     │ 3.98743        │ 5.44619       │ 4.83482      │ 1.17624       │
    ⋮
    │ 172781 │ 0.90711        │ 5.54408       │ -0.197069    │ -0.11462      │
    │ 172782 │ 1.83223        │ 4.4922        │ 3.81046      │ -0.215928     │
    │ 172783 │ 0.107077       │ 3.83716       │ 0.169585     │ -0.144243     │
    │ 172784 │ 1.24811        │ 3.83896       │ -0.0242499   │ -0.0531656    │
    │ 172785 │ -0.568296      │ 3.95064       │ -0.513142    │ 4.48944       │
    │ 172786 │ -0.163096      │ 4.4963        │ 0.329497     │ -0.187294     │
    │ 172787 │ -0.483535      │ 4.35172       │ -0.162001    │ -0.0154214    │
    │ 172788 │ 3.45583        │ 5.47509       │ 4.47387      │ 0.859977      │
    │ 172789 │ 0.0534078      │ 4.89584       │ -0.178506    │ -0.0734782    │
    │ 172790 │ 1.49993        │ 5.03604       │ -0.0801966   │ -0.135197     │
    │ 172791 │ 3.8933         │ 4.76634       │ -0.0687005   │ -0.149238     │, 16×4 DataFrames.DataFrame. Omitted printing of 1 columns
    │ Row │ file_name                          │ sample_id │ condition │
    │     │ [90mAny[39m                                │ [90mAny[39m       │ [90mAny[39m       │
    ├─────┼────────────────────────────────────┼───────────┼───────────┤
    │ 1   │ PBMC8_30min_patient1_BCR-XL.fcs    │ BCRXL1    │ BCRXL     │
    │ 2   │ PBMC8_30min_patient1_Reference.fcs │ Ref1      │ Ref       │
    │ 3   │ PBMC8_30min_patient2_BCR-XL.fcs    │ BCRXL2    │ BCRXL     │
    │ 4   │ PBMC8_30min_patient2_Reference.fcs │ Ref2      │ Ref       │
    │ 5   │ PBMC8_30min_patient3_BCR-XL.fcs    │ BCRXL3    │ BCRXL     │
    │ 6   │ PBMC8_30min_patient3_Reference.fcs │ Ref3      │ Ref       │
    │ 7   │ PBMC8_30min_patient4_BCR-XL.fcs    │ BCRXL4    │ BCRXL     │
    │ 8   │ PBMC8_30min_patient4_Reference.fcs │ Ref4      │ Ref       │
    │ 9   │ PBMC8_30min_patient5_BCR-XL.fcs    │ BCRXL5    │ BCRXL     │
    │ 10  │ PBMC8_30min_patient5_Reference.fcs │ Ref5      │ Ref       │
    │ 11  │ PBMC8_30min_patient6_BCR-XL.fcs    │ BCRXL6    │ BCRXL     │
    │ 12  │ PBMC8_30min_patient6_Reference.fcs │ Ref6      │ Ref       │
    │ 13  │ PBMC8_30min_patient7_BCR-XL.fcs    │ BCRXL7    │ BCRXL     │
    │ 14  │ PBMC8_30min_patient7_Reference.fcs │ Ref7      │ Ref       │
    │ 15  │ PBMC8_30min_patient8_BCR-XL.fcs    │ BCRXL8    │ BCRXL     │
    │ 16  │ PBMC8_30min_patient8_Reference.fcs │ Ref8      │ Ref       │, 33×6 DataFrames.DataFrame
    │ Row │ Metal  │ Isotope │ Antigen │ fcs_colname     │ Lineage │ Functional │
    │     │ [90mString[39m │ [90mString[39m  │ [90mString[39m  │ [90mString[39m          │ [90mAny[39m     │ [90mAny[39m        │
    ├─────┼────────┼─────────┼─────────┼─────────────────┼─────────┼────────────┤
    │ 1   │        │ 110:114 │ CD3     │ CD3(110:114)Dd  │ 1       │ 0          │
    │ 2   │ In     │ 115     │ CD45    │ CD45(In115)Dd   │ 1       │ 0          │
    │ 3   │ La     │ 139     │ BC1     │ BC1(La139)Dd    │ 0       │ 0          │
    │ 4   │ Pr     │ 141     │ BC2     │ BC2(Pr141)Dd    │ 0       │ 0          │
    │ 5   │ Nd     │ 142     │ pNFkB   │ pNFkB(Nd142)Dd  │ 0       │ 1          │
    │ 6   │ Nd     │ 144     │ pp38    │ pp38(Nd144)Dd   │ 0       │ 1          │
    │ 7   │ Nd     │ 145     │ CD4     │ CD4(Nd145)Dd    │ 1       │ 0          │
    │ 8   │ Nd     │ 146     │ BC3     │ BC3(Nd146)Dd    │ 0       │ 0          │
    │ 9   │ Sm     │ 147     │ CD20    │ CD20(Sm147)Dd   │ 1       │ 0          │
    │ 10  │ Nd     │ 148     │ CD33    │ CD33(Nd148)Dd   │ 1       │ 0          │
    ⋮
    │ 23  │ Er     │ 167     │ pPlcg2  │ pPlcg2(Er167)Dd │ 0       │ 1          │
    │ 24  │ Er     │ 168     │ pErk    │ pErk(Er168)Dd   │ 0       │ 1          │
    │ 25  │ Tm     │ 169     │ BC6     │ BC6(Tm169)Dd    │ 0       │ 0          │
    │ 26  │ Er     │ 170     │ pLat    │ pLat(Er170)Dd   │ 0       │ 1          │
    │ 27  │ Yb     │ 171     │ IgM     │ IgM(Yb171)Dd    │ 1       │ 0          │
    │ 28  │ Yb     │ 172     │ pS6     │ pS6(Yb172)Dd    │ 0       │ 1          │
    │ 29  │ Yb     │ 174     │ HLA-DR  │ HLA-DR(Yb174)Dd │ 1       │ 0          │
    │ 30  │ Lu     │ 175     │ BC7     │ BC7(Lu175)Dd    │ 0       │ 0          │
    │ 31  │ Yb     │ 176     │ CD7     │ CD7(Yb176)Dd    │ 1       │ 0          │
    │ 32  │ Ir     │ 191     │ DNA-1   │ DNA-1(Ir191)Dd  │ 0       │ 0          │
    │ 33  │ Ir     │ 193     │ DNA-2   │ DNA-2(Ir193)Dd  │ 0       │ 0          │)



## Creating a Self Organizing MAP (SOM)

The main advantage of `GigaSOM.jl` is the capability of parallel processing.
In order to activate this dependency, please activate the GigaSOM environment:


```julia
import Pkg; Pkg.activate("GigaSOM")
```

    ┌ Info: activating new environment at ~/work/git/hub/GigaSOM.jl/docs/src/GigaSOM.
    └ @ Pkg.API /Users/osx/buildbot/slave/package_osx64/build/usr/share/julia/stdlib/v1.1/Pkg/src/API.jl:519





    "/Users/laurent.heirendt/work/git/hub/GigaSOM.jl/docs/src/GigaSOM"



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




<table class="data-frame"><thead><tr><th></th><th>CD3(110:114)Dd</th><th>CD45(In115)Dd</th><th>CD4(Nd145)Dd</th><th>CD20(Sm147)Dd</th><th>CD33(Nd148)Dd</th><th>CD123(Eu151)Dd</th></tr><tr><th></th><th>Float32</th><th>Float32</th><th>Float32</th><th>Float32</th><th>Float32</th><th>Float32</th></tr></thead><tbody><p>172,791 rows × 10 columns (omitted printing of 4 columns)</p><tr><th>1</th><td>0.863966</td><td>4.59768</td><td>-0.157656</td><td>-0.131486</td><td>1.496</td><td>0.0192691</td></tr><tr><th>2</th><td>1.90267</td><td>5.88631</td><td>2.13232</td><td>2.4149</td><td>0.718917</td><td>-0.174217</td></tr><tr><th>3</th><td>4.96538</td><td>6.63111</td><td>-0.100279</td><td>0.993387</td><td>0.995998</td><td>0.886214</td></tr><tr><th>4</th><td>2.92577</td><td>5.08396</td><td>-0.0759843</td><td>1.50545</td><td>-0.144179</td><td>0.211041</td></tr><tr><th>5</th><td>4.19087</td><td>6.53202</td><td>2.49969</td><td>2.24803</td><td>0.570482</td><td>-0.106751</td></tr><tr><th>6</th><td>3.78095</td><td>5.96461</td><td>1.66088</td><td>0.201739</td><td>0.0156762</td><td>0.28967</td></tr><tr><th>7</th><td>-1.04096</td><td>5.53396</td><td>1.65052</td><td>5.1049</td><td>-0.0939763</td><td>-0.863822</td></tr><tr><th>8</th><td>4.36623</td><td>6.24286</td><td>4.87603</td><td>-0.0164116</td><td>1.24873</td><td>0.414543</td></tr><tr><th>9</th><td>1.36755</td><td>1.2471</td><td>3.8174</td><td>-0.112002</td><td>-0.0941085</td><td>0.44179</td></tr><tr><th>10</th><td>3.98743</td><td>5.44619</td><td>4.83482</td><td>1.17624</td><td>-0.161853</td><td>3.1649</td></tr><tr><th>11</th><td>0.491215</td><td>3.3969</td><td>-0.0973286</td><td>1.44815</td><td>2.10363</td><td>0.710595</td></tr><tr><th>12</th><td>3.29113</td><td>5.53696</td><td>-0.0761106</td><td>-0.0852924</td><td>-0.147134</td><td>-0.0894011</td></tr><tr><th>13</th><td>0.391164</td><td>5.084</td><td>-0.189996</td><td>4.62741</td><td>-0.108741</td><td>-0.297026</td></tr><tr><th>14</th><td>2.34348</td><td>5.54706</td><td>-0.166527</td><td>2.3804</td><td>0.166191</td><td>-0.0387583</td></tr><tr><th>15</th><td>2.20089</td><td>5.86743</td><td>0.0619583</td><td>1.16075</td><td>-0.0757926</td><td>2.14581</td></tr><tr><th>16</th><td>3.39157</td><td>5.79934</td><td>3.03677</td><td>0.5754</td><td>-0.0252033</td><td>-1.44807</td></tr><tr><th>17</th><td>2.49139</td><td>4.54159</td><td>1.99819</td><td>2.65098</td><td>0.18271</td><td>0.731839</td></tr><tr><th>18</th><td>1.77419</td><td>5.29252</td><td>2.07913</td><td>2.1213</td><td>0.54527</td><td>2.82337</td></tr><tr><th>19</th><td>4.21076</td><td>5.48598</td><td>4.68946</td><td>2.23834</td><td>0.157703</td><td>-0.0409706</td></tr><tr><th>20</th><td>1.34281</td><td>6.04369</td><td>2.77003</td><td>1.40473</td><td>-0.177313</td><td>-0.0736867</td></tr><tr><th>21</th><td>4.03355</td><td>6.09835</td><td>4.33682</td><td>0.0585207</td><td>-0.0308316</td><td>-0.124643</td></tr><tr><th>22</th><td>4.31784</td><td>6.15371</td><td>0.338293</td><td>1.43171</td><td>-0.0228252</td><td>0.152519</td></tr><tr><th>23</th><td>2.02134</td><td>6.00962</td><td>-0.0714526</td><td>1.68415</td><td>-0.0962214</td><td>-0.132436</td></tr><tr><th>24</th><td>-0.174358</td><td>4.31894</td><td>-0.0203309</td><td>-0.177097</td><td>-0.192134</td><td>-0.189357</td></tr><tr><th>25</th><td>4.0333</td><td>5.84685</td><td>3.46101</td><td>1.81658</td><td>0.0744277</td><td>0.0189411</td></tr><tr><th>26</th><td>4.12367</td><td>5.98168</td><td>4.93147</td><td>2.50626</td><td>-0.31175</td><td>-0.175012</td></tr><tr><th>27</th><td>1.75073</td><td>5.35504</td><td>0.0458442</td><td>1.77718</td><td>0.703319</td><td>-0.160959</td></tr><tr><th>28</th><td>3.93608</td><td>6.03993</td><td>4.00892</td><td>1.78989</td><td>-0.194665</td><td>-0.177051</td></tr><tr><th>29</th><td>4.44235</td><td>5.84511</td><td>-0.122069</td><td>-0.100323</td><td>-0.0485999</td><td>-0.136472</td></tr><tr><th>30</th><td>3.5706</td><td>6.52926</td><td>4.78116</td><td>-0.0772988</td><td>0.101967</td><td>0.517451</td></tr><tr><th>&vellip;</th><td>&vellip;</td><td>&vellip;</td><td>&vellip;</td><td>&vellip;</td><td>&vellip;</td><td>&vellip;</td></tr></tbody></table>



Initialize the SOM grid by size and expression values:


```julia
som2 = initGigaSOM(dfSom, 10, 10)
```




    GigaSOM.Som([0.772605 5.55571 … 0.812848 -0.288866; 1.42088 4.97668 … 1.07725 4.22555; … ; -0.738192 3.88047 … 0.795165 -0.145001; 0.535444 5.25279 … 0.430748 2.74619], ["CD3(110:114)Dd", "CD45(In115)Dd", "CD4(Nd145)Dd", "CD20(Sm147)Dd", "CD33(Nd148)Dd", "CD123(Eu151)Dd", "CD14(Gd160)Dd", "IgM(Yb171)Dd", "HLA_DR(Yb174)Dd", "CD7(Yb176)Dd"], 2×10 DataFrames.DataFrame. Omitted printing of 6 columns
    │ Row │ CD3(110:114)Dd │ CD45(In115)Dd │ CD4(Nd145)Dd │ CD20(Sm147)Dd │
    │     │ [90mFloat64[39m        │ [90mFloat64[39m       │ [90mFloat64[39m      │ [90mFloat64[39m       │
    ├─────┼────────────────┼───────────────┼──────────────┼───────────────┤
    │ 1   │ 0.0            │ 0.0           │ 0.0          │ 0.0           │
    │ 2   │ 1.0            │ 1.0           │ 1.0          │ 1.0           │, :none, 10, 10, 100, [0.0 0.0; 1.0 0.0; … ; 8.0 9.0; 9.0 9.0], 100×2 DataFrames.DataFrame
    │ Row │ X     │ Y     │
    │     │ [90mInt64[39m │ [90mInt64[39m │
    ├─────┼───────┼───────┤
    │ 1   │ 1     │ 1     │
    │ 2   │ 2     │ 2     │
    │ 3   │ 3     │ 3     │
    │ 4   │ 4     │ 4     │
    │ 5   │ 5     │ 5     │
    │ 6   │ 6     │ 6     │
    │ 7   │ 7     │ 7     │
    │ 8   │ 8     │ 8     │
    │ 9   │ 9     │ 9     │
    │ 10  │ 10    │ 10    │
    ⋮
    │ 90  │ 90    │ 90    │
    │ 91  │ 91    │ 91    │
    │ 92  │ 92    │ 92    │
    │ 93  │ 93    │ 93    │
    │ 94  │ 94    │ 94    │
    │ 95  │ 95    │ 95    │
    │ 96  │ 96    │ 96    │
    │ 97  │ 97    │ 97    │
    │ 98  │ 98    │ 98    │
    │ 99  │ 99    │ 99    │
    │ 100 │ 100   │ 100   │, :hexagonal, false, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0  …  0, 0, 0, 0, 0, 0, 0, 0, 0, 0])



Train the SOM grid with the initialized SOM object and define the number of training
rounds (also referred to as *epochs*).


```julia
 som2 = trainGigaSOM(som2, dfSom, epochs = 10)
```

    ┌ Info: The radius has been determined automatically.
    └ @ GigaSOM /Users/laurent.heirendt/.julia/packages/GigaSOM/QAKEY/src/core.jl:79


    Epoch: 1
    Radius: 6.463961030678928
    Epoch: 2
    Radius: 5.856854249492381
    Epoch: 3
    Radius: 5.249747468305833
    Epoch: 4
    Radius: 4.642640687119286
    Epoch: 5
    Radius: 4.035533905932739
    Epoch: 6
    Radius: 3.4284271247461913
    Epoch: 7
    Radius: 2.821320343559644
    Epoch: 8
    Radius: 2.2142135623730965
    Epoch: 9
    Radius: 1.607106781186549
    Epoch: 10
    Radius: 1.0000000000000013





    GigaSOM.Som([0.648143 5.0357 … 2.59634 0.466907; 0.928678 5.05525 … 2.38048 0.78602; … ; 0.738282 4.70267 … 0.671534 0.777843; 0.92694 4.86462 … 0.568667 0.467445], ["CD3(110:114)Dd", "CD45(In115)Dd", "CD4(Nd145)Dd", "CD20(Sm147)Dd", "CD33(Nd148)Dd", "CD123(Eu151)Dd", "CD14(Gd160)Dd", "IgM(Yb171)Dd", "HLA_DR(Yb174)Dd", "CD7(Yb176)Dd"], 2×10 DataFrames.DataFrame. Omitted printing of 6 columns
    │ Row │ CD3(110:114)Dd │ CD45(In115)Dd │ CD4(Nd145)Dd │ CD20(Sm147)Dd │
    │     │ [90mFloat64[39m        │ [90mFloat64[39m       │ [90mFloat64[39m      │ [90mFloat64[39m       │
    ├─────┼────────────────┼───────────────┼──────────────┼───────────────┤
    │ 1   │ 0.0            │ 0.0           │ 0.0          │ 0.0           │
    │ 2   │ 1.0            │ 1.0           │ 1.0          │ 1.0           │, :none, 10, 10, 100, [0.0 0.0; 1.0 0.0; … ; 8.0 9.0; 9.0 9.0], 100×2 DataFrames.DataFrame
    │ Row │ X     │ Y     │
    │     │ [90mInt64[39m │ [90mInt64[39m │
    ├─────┼───────┼───────┤
    │ 1   │ 1     │ 1     │
    │ 2   │ 2     │ 2     │
    │ 3   │ 3     │ 3     │
    │ 4   │ 4     │ 4     │
    │ 5   │ 5     │ 5     │
    │ 6   │ 6     │ 6     │
    │ 7   │ 7     │ 7     │
    │ 8   │ 8     │ 8     │
    │ 9   │ 9     │ 9     │
    │ 10  │ 10    │ 10    │
    ⋮
    │ 90  │ 90    │ 90    │
    │ 91  │ 91    │ 91    │
    │ 92  │ 92    │ 92    │
    │ 93  │ 93    │ 93    │
    │ 94  │ 94    │ 94    │
    │ 95  │ 95    │ 95    │
    │ 96  │ 96    │ 96    │
    │ 97  │ 97    │ 97    │
    │ 98  │ 98    │ 98    │
    │ 99  │ 99    │ 99    │
    │ 100 │ 100   │ 100   │, :hexagonal, false, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0  …  0, 0, 0, 0, 0, 0, 0, 0, 0, 0])



Finally, calculate the winner neurons from the trained SOM object:


```julia
winners = mapToGigaSOM(som2, dfSom)
```

    [2, 3]





<table class="data-frame"><thead><tr><th></th><th>index</th></tr><tr><th></th><th>Int64</th></tr></thead><tbody><p>172,791 rows × 1 columns</p><tr><th>1</th><td>100</td></tr><tr><th>2</th><td>91</td></tr><tr><th>3</th><td>61</td></tr><tr><th>4</th><td>36</td></tr><tr><th>5</th><td>18</td></tr><tr><th>6</th><td>16</td></tr><tr><th>7</th><td>1</td></tr><tr><th>8</th><td>9</td></tr><tr><th>9</th><td>94</td></tr><tr><th>10</th><td>7</td></tr><tr><th>11</th><td>66</td></tr><tr><th>12</th><td>50</td></tr><tr><th>13</th><td>1</td></tr><tr><th>14</th><td>50</td></tr><tr><th>15</th><td>51</td></tr><tr><th>16</th><td>91</td></tr><tr><th>17</th><td>2</td></tr><tr><th>18</th><td>21</td></tr><tr><th>19</th><td>8</td></tr><tr><th>20</th><td>91</td></tr><tr><th>21</th><td>8</td></tr><tr><th>22</th><td>40</td></tr><tr><th>23</th><td>61</td></tr><tr><th>24</th><td>98</td></tr><tr><th>25</th><td>10</td></tr><tr><th>26</th><td>10</td></tr><tr><th>27</th><td>47</td></tr><tr><th>28</th><td>8</td></tr><tr><th>29</th><td>61</td></tr><tr><th>30</th><td>10</td></tr><tr><th>&vellip;</th><td>&vellip;</td></tr></tbody></table>


