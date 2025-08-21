
"""
$(TYPEDSIGNATURES)

Return a neighbourhood radius. Use as the `radiusFun` parameter for `train`.

# Arguments
- `initRadius`: Initial Radius
- `finalRadius`: Final Radius
- `iteration`: Training iteration
- `epochs`: Total number of epochs
"""
function radius_linear(
    initRadius::Float64,
    finalRadius::Float64,
    iteration::Int64,
    epochs::Int64,
)

    scaledTime = scaled_epoch_time(iteration, epochs)
    return initRadius * (1 - scaledTime) + finalRadius * scaledTime
end

export radius_linear

"""
$(TYPEDSIGNATURES)

Return a function to be used as a `radiusFun` of `train`, which causes
exponencial decay with the selected steepness.

Use: `train(..., radiusFun = radius_exp(0.5))`

# Arguments
- `steepness`: Steepness of exponential descent. Good values range
  from -100.0 (almost linear) to 100.0 (really quick decay).

"""
function radius_exp(steepness::Float64 = 0.0)
    return (initRadius::Float64, finalRadius::Float64, iteration::Int64, epochs::Int64) ->
        begin

            scaledTime = scaled_epoch_time(iteration, epochs)

            if steepness < -100.0
                # prevent floating point underflows
                error("Sanity check: steepness too low, use radius_linear instead.")
            end

            # steepness is simulated by moving both points closer to zero
            adjust = finalRadius * (1 - 1.1^(-steepness))

            if initRadius <= 0 || (initRadius - adjust) <= 0 || finalRadius <= 0
                error(
                    "Radii must be positive. (Possible alternative cause: steepness is too high.)",
                )
            end

            initRadius -= adjust
            finalRadius -= adjust

            return adjust + initRadius * ((finalRadius / initRadius)^scaledTime)
        end
end

export radius_exp

"""
$(TYPEDSIGNATURES)

Create coordinates of all neurons on a rectangular SOM.

The return-value is an array of size (Number-of-neurons, 2) with
x- and y- coordinates of the neurons in the first and second
column respectively.
The distance between neighbours is 1.0.
The point of origin is bottom-left.
The first neuron sits at (0,0).

# Arguments
- `xdim`: number of neurons in x-direction
- `ydim`: number of neurons in y-direction
"""
function grid_rectangular(xdim, ydim)

    grid = zeros(Float64, (xdim * ydim, 2))
    for ix = 1:xdim
        for iy = 1:ydim
            grid[ix+(iy-1)*xdim, 1] = ix - 1
            grid[ix+(iy-1)*xdim, 2] = iy - 1
        end
    end
    return grid
end

export grid_rectangular

"""
$(TYPEDSIGNATURES)

Return the value of normal distribution PDF (σ=`r`, μ=0) at `x`
"""
kernel_gaussian(x, r::Float64) =
    Distributions.pdf.(Distributions.Normal(0.0, r), x)

export kernel_gaussian

bubble_kernel_squared_scalar(x::Float64, r::Float64) = x >= r ? 0 : sqrt(1 - x / r)


"""
$(TYPEDSIGNATURES)

Return a "bubble" (spherical) distribution kernel.

"""
kernel_bubble(x, r::Float64) = bubbleKernelSqScalar.(x .^ 2, r^2)

export kernel_bubble

"""
$(TYPEDSIGNATURES)
    kernel_threshold(x, r::Float64)

Simple FlowSOM-like hard-threshold kernel
"""
function kernel_threshold(x, r::Float64, maxRatio = 4 / 5, zero = 1e-6)
    if r >= maxRatio * maximum(x) #prevent smoothing everything to a single point
        r = maxRatio * maximum(x)
    end
    return zero .+ (x .<= r)
end

export kernel_threshold

"""
$(TYPEDSIGNATURES)

Return a function that uses the `metric` (compatible with metrics from package `Distances`) calculates distance matrixes from normal row-wise data matrices, using the `metric`.

Use as a parameter of `train`.
"""
distance_matrix(metric = Chebyshev()) = (grid::Matrix{Float64}) -> begin
        n = size(grid, 1)
        dm = zeros(Float64, n, n)

        for i = 1:n
            for j = 1:n
                dm[i, j] = metric(grid[i, :], grid[j, :])
            end
        end

        return dm::Matrix{Float64}
    end

export distance_matrix
