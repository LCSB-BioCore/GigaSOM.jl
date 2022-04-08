"""
    Som

Structure to hold all data of a trained SOM.

# Fields:
- `codes::Array{Float64,2}`: 2D-array of codebook vectors. One vector per row
- `xdim::Int`: number of neurons in x-direction
- `ydim::Int`: number of neurons in y-direction
- `numCodes::Int`: total number of neurons
- `grid::Array{Float64,2}`: 2D-array of coordinates of neurons on the map
          (2 columns (x,y)] for rectangular and hexagonal maps
           3 columns (x,y,z) for spherical maps)
"""
mutable struct Som
    codes::Matrix{Float64}
    xdim::Int
    ydim::Int
    numCodes::Int
    grid::Matrix{Float64}

    Som(;
        codes::Matrix{Float64},
        xdim::Int,
        ydim::Int,
        numCodes::Int = xdim * ydim,
        grid::Matrix{Float64},
    ) = new(codes, xdim, ydim, numCodes, grid)
end

Base.copy(som::Som) = Som(
    codes = som.codes,
    xdim = som.xdim,
    ydim = som.ydim,
    numCodes = som.numCodes,
    grid = som.grid,
)
