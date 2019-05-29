# stuct Som holds all important parameters of a trained som:
#
"""
    struct Som

Structure to hold all data of a trained SOM.

# Fields:
- `codes::Array{Float64,2}`: 2D-array of codebook vectors. One vector per row
- `colNames::Array{String,1}`: names of the attribute with which the SOM is trained
- `normParams::DataFrame`: normalisation parameters for each column
                of training data. Column headers corresponds with
                colNames.
- `norm::Symbol`: normalisation type; one of `:none, :minmax, :zscore`
- `xdim::Int`: number of neurons in x-direction
- `ydim::Int`: number of neurons in y-direction
- `nCodes::Int`: total number of neurons
- `grid::Array{Float64,2}`: 2D-array of coordinates of neurons on the map
          (2 columns (x,y)] for rectangular and hexagonal maps
           3 columns (x,y,z) for spherical maps)
- `indices::DataFrame`: X-, Y-indices of the neurons
- `topol::Symbol`: topology of the SOM; one of `:rectangular, :hexagonal, :spherical`
- `toroidal::Bool`: if `true`, the SOM is toroidal (has no edges)
- `population::Array{Int,1}`: 1D-array of numbers of training samples mapped to
                each neuron.
"""
struct Som
    codes::Array{Float64,2}
    colNames::Array{String}
    normParams::DataFrame
    norm::Symbol        # one of :none :minmax :zscore
    xdim::Int
    ydim::Int
    nCodes::Int
    grid::Array{Float64,2}
    indices::DataFrame
    topol::Symbol       # one of :rectangular :hexagonal :spherical
    toroidal::Bool
    population::Array{Int,1}

    Som(;codes::Array{Float64} = Array{Float64}(0),
        colNames::Array{String,1} = Array{String}(0),
        normParams::DataFrame = DataFrame(),
        norm::Symbol = :none,
        xdim::Int = 1,
        ydim::Int = 1,
        nCodes::Int = 1,
        grid::Array{Float64,2} = zeros(1,1),
        indices::DataFrame = DataFrame(),
        topol::Symbol = :hexagonal,
        toroidal::Bool = false,
        population::Array{Int,1} = [1]) = new(codes,
                                              colNames,
                                              normParams,
                                              norm,
                                              xdim,
                                              ydim,
                                              nCodes,
                                              grid,
                                              indices,
                                              topol,
                                              toroidal,
                                              population)
end
