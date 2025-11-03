"""
$(TYPEDEF)

Structure to hold all data of a trained SOM.

# Fields:
$(TYPEDFIELDS)
"""
mutable struct SOM
    codes::Matrix{Float64}
    xdim::Int
    ydim::Int
    numCodes::Int
    grid::Matrix{Float64}

    SOM(;
        codes::Matrix{Float64},
        xdim::Int,
        ydim::Int,
        numCodes::Int = xdim * ydim,
        grid::Matrix{Float64},
    ) = new(codes, xdim, ydim, numCodes, grid)
end

export SOM

Base.copy(som::SOM) = SOM(
    codes = som.codes,
    xdim = som.xdim,
    ydim = som.ydim,
    numCodes = som.numCodes,
    grid = som.grid,
)
