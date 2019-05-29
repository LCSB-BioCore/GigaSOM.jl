"""
    trainSOM_batch(som::Som, train::Any, len;
             η = 0.2, kernelFun = gaussianKernel,
             r = 0.0, rDecay = true, ηDecay = true)

Train an initialised or pre-trained SOM.

# Arguments:
- `som`: object of type Som with a trained som
- `train`: training data
- `len`: number of single training steps (*not* epochs)
- `η`: learning rate
- `kernel::function`: optional distance kernel; one of (`bubbleKernel, gaussianKernel`)
            default is `gaussianKernel`
- `r`: optional training radius.
       If r is not specified, it defaults to √(xdim^2 + ydim^2) / 2
- `rDecay`: optional flag; if true, r decays to 0.0 during the training.
- `ηDecay`: optional flag; if true, learning rate η decays to 0.0
            during the training.

Training data must be convertable to Array{Float64,2} with
`convert()`. Training samples are row-wise; one sample per row.

An alternative kernel function can be provided to modify the distance-dependent
training. The function must fit to the signature fun(x, r) where
x is an arbitrary distance and
r is a parameter controlling the function and the return value is
between 0.0 and 1.0.
"""
function trainSOM_batch(som::Som, train::Any, len;
                     kernelFun::Function = gaussianKernel, r = 0.0,
                     rDecay = true, epochs = 10)

    train = convertTrainingData(train)
    som = trainAll_batch(som, train,
                 len, kernelFun, r,
                 rDecay, epochs)
    return som
end


"""
    function trainAll_batch(train::Array{Float64}, xdim, ydim,
                topology, len, η, kernelFun, r,
                norm, toroidal, rDecay, ηDecay)
Connects the high-level-API functions with
the backend.
# If `init == true` a new som is initialised with randomly sampled
# samples from train.
# Otherwise the som is trained.
"""
function trainAll_batch(som::Som, train::Array{Float64,2},
                len, kernelFun, r,
                rDecay, epochs)

    # normalise training data:
    if som.norm != :none
        train = SOM.normTrainData(train, som.normParams)
    end

    # set default radius:
    if r == 0.0
        if som.topol != :spherical
            r = √(som.xdim^2 + som.ydim^2) / 2
        else
            r = π * som.ydim
        end
    end

    if som.topol == :spherical
        dm = SOM.distMatrixSphere(som.grid)
    else
        dm = distMatrix(som.grid, som.toroidal)
    end

    ### TRY with one epoch first
    codes = doEpoch_batch(train, som.codes, dm,
                  kernelFun, len, r,
                  som.toroidal, rDecay, epochs)


    # map training samles to SOM and calc. neuron population:
    vis = SOM.visual(codes, train)
    population = SOM.makePopulation(som.nCodes, vis)

    # create X,Y-indices for neurons:
    #
    if som.topol != :spherical
        x = [mod(i-1, som.xdim)+1 for i in 1:som.nCodes]
        y = [div(i-1, som.xdim)+1 for i in 1:som.nCodes]
    else
        x = y = collect(1:som.nCodes)
    end
    indices = DataFrame(X = x, Y = y)

    # update SOM object:
    somNew = deepcopy(som)
    somNew.codes[:,:] = codes[:,:]
    somNew.population[:] = population[:]
    return somNew
end

"""
    doEpoch_batch(x::Array{Float64}, codes::Array{Float64},
             dm::Array{Float64}, kernelFun::Function, len::Int, η::Float64,
             r::Number, toroidal::Bool, rDecay::Bool, ηDecay::Bool)
Train a SOM for one epoch. This implements also the batch update
of the codebook vectors and the adjustment in radius after each
epoch.
This worker function is called by the high-level-API-functions
`som(), somHexagonal() and somSpherical()`.
# Arguments:
- `x`: training Data
- `dm`: distance matrix of all neurons of the SOM
- `kernelFun`: distance kernel function of type fun(x, r)
- `len`: number of training steps (*not* epochs)
- `r`: training radius
- `toroidal`: if true, the SOM is toroidal.
- `rDecay`: if true, r decays to 0.0 during the training.
"""
function doEpoch_batch(x::Array{Float64}, codes::Array{Float64},
             dm::Array{Float64}, kernelFun::Function, len::Int,
             r::Number, toroidal::Bool, rDecay::Bool, epochs)


     numDat = nrow(x)
     numCodes = nrow(codes)

     # For each epoch:
     # interpolate new value for sigma(t)
     # create a new distance matrix for each epoch?
     ep = 1

     # make Δs for linear decay of r:
     r = Float64(r)

     for j in 1:epochs

         # TODO: evaluate the radius decay



         if rDecay
             if r < 1.5
                 Δr = 0.0
             else
                 Δr = (r-1.0) / epochs # this should adapt the decay

             end
         else
             Δr = 0.0
         end

         println("Epoch: $ep")
         # initialise numerator and denominator with 0's
         sum_numerator = zeros(Float64, size(codes))
         sum_denominator = zeros(Float64, size(codes)[1])

         # for each sample in dataset / or trainingsset
         for s in 1:len

             sampl = rowSample(x) # get random sample
             bmu_idx, bmu_vec = find_bmu(codes, sampl)

             # for each row in codebook get distances to bmu and multiply it
             # with sample row: x(i)
             for i in 1:numCodes

                 dist = kernelFun(dm[bmu_idx, i], r)
                 temp = sampl .* dist
                 # println(temp)
                 sum_numerator[i,:] = sum_numerator[i,:] + temp
                 sum_denominator[i] = sum_denominator[i] + dist
             end

         end

         # println(sum_numerator)
         # println(sum_denominator)
         codes_new = sum_numerator ./ sum_denominator
         # println(codes)
         codes = codes_new
         r -= Δr

         if r < 0.0
             r = 0.0
         end

         println("Radius: $r")

         ep = ep + 1
     end

     return codes


end

