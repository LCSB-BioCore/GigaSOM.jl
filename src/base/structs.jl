"""
    Som

Structure to hold all data of a trained SOM.

# Fields:
- `codes::Array{Float64,2}`: 2D-array of codebook vectors. One vector per row
- `colNames::Array{String,1}`: names of the attribute with which the SOM is trained
- `xdim::Int`: number of neurons in x-direction
- `ydim::Int`: number of neurons in y-direction
- `numCodes::Int`: total number of neurons
- `grid::Array{Float64,2}`: 2D-array of coordinates of neurons on the map
          (2 columns (x,y)] for rectangular and hexagonal maps
           3 columns (x,y,z) for spherical maps)
"""
mutable struct Som
    codes::Array{Float64,2}
    colNames::Array{String}
    xdim::Int
    ydim::Int
    numCodes::Int
    grid::Array{Float64,2}

    Som(;codes::Array{Float64} = Array{Float64}(0),
        colNames::Array{String,1} = Array{String}(0),
        xdim::Int = 1,
        ydim::Int = 1,
        numCodes::Int = 1,
        grid::Array{Float64,2} = zeros(1,1)) = new(codes,
                                              colNames,
                                              xdim,
                                              ydim,
                                              numCodes,
                                              grid)
end

"""
    LoadedDataInfo

The basic structure for working with loaded data, distributed amongst workers. In completeness, it represents a dataset as such:

- `val` is the "value name" under which the data are saved in processes. E.g.
  `val=:foo` means that there is a variable `foo` on each process holding a
  part of the matrix.
- `workers` is a list of workers (in correct order!) that hold the data
  (similar to `DArray.pids`)
"""
struct LoadedDataInfo
    val::Symbol
    workers::Array{Int64}
    LoadedDataInfo(
        val,
        workers
        ) = new(val, workers)
end
