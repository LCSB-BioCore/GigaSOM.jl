"""
    embedGigaSOM(som::GigaSOM.Som,
                 dInfo::LoadedDataInfo;
                 knnTreeFun = BruteTree,
                 metric = Euclidean(),
                 k::Int64=0,
                 adjust::Float64=1.0,
                 smooth::Float64=0.0,
                 m::Float64=10.0)

Return a data frame with X,Y coordinates of EmbedSOM projection of the data.

# Arguments:
- `som`: a trained SOM
- `dInfo`: `LoadedDataInfo` that describes the loaded dataset
- `knnTreeFun`: Constructor of the KNN-tree (e.g. from NearestNeighbors package)
- `metric`: Passed as metric argument to the KNN-tree constructor
- `k`: number of nearest neighbors to consider (high values get quadratically
  slower)
- `adjust`: position adjustment parameter (higher values avoid non-local
  approximations)
- `smooth`: approximation smoothness (the higher the value, the larger the
  neighborhood of approximate local linearity of the projection)
- `m`: exponential decay rate for the score when approaching the `k+1`-th neighbor distance

Data must have the same number of dimensions as the training dataset,
and must be normalized using the same parameters.

# Examples:

Produce a 2-column matrix with 2D cell coordinates:
```
e = embedGigaSOM(som, data)
```

Plot the result using 2D histogram from Gadfly:
```
using Gadfly
draw(PNG("output.png",20cm,20cm),
     plot(x=e[:,1], y=e[:,2],
     Geom.histogram2d(xbincount=200, ybincount=200)))
```
"""
function embedGigaSOM(som::GigaSOM.Som,
                      dInfo::LoadedDataInfo;
                      knnTreeFun = BruteTree,
                      metric = Euclidean(),
                      k::Int64=0,
                      adjust::Float64=1.0,
                      smooth::Float64=0.0,
                      m::Float64=10.0)

    # convert `smooth` to `boost`
    boost = exp(-smooth-1)

    # default `k`
    if k == 0
        k = Integer(1+sqrt(som.xdim*som.ydim))
        @debug "embedding defaults" k
    end

    # check if `k` isn't too high
    if k > som.xdim*som.ydim
        k = Integer(som.xdim * som.ydim)
    end

    # prepare the kNN-tree for lookups
    tree = knnTreeFun(Array{Float64,2}(transpose(som.codes)), metric)

    # run the distributed computation
    return distributed_mapreduce(dInfo,
        (d) -> (embedGigaSOM_internal(som, d, tree, k, adjust, boost, m)),
        (e1, e2) -> vcat(e1, e2))
end

"""
    embedGigaSOM(som::GigaSOM.Som,
                 data;
                 knnTreeFun = BruteTree,
                 metric = Euclidean(),
                 k::Int64=0,
                 adjust::Float64=1.0,
                 smooth::Float64=0.0,
                 m::Float64=10.0)

Overload of `embedGigaSOM` for simple DataFrames and matrices. This slices the
data using `DistributedArrays`, sends them the workers, and runs normal
`embedGigaSOM`. Data is `undistribute`d after the computation.
"""
function embedGigaSOM(som::GigaSOM.Som,
                      data;
                      knnTreeFun = BruteTree,
                      metric = Euclidean(),
                      k::Int64=0,
                      adjust::Float64=1.0,
                      smooth::Float64=0.0,
                      m::Float64=10.0)

    data = convertTrainingData(data)

    dInfo = distribute_darray(:embeddingDataVar, distribute(data))
    res = embedGigaSOM(som, dInfo,
        knnTreeFun=knnTreeFun, metric=metric,
        k=k, adjust=adjust, smooth=smooth, m=m)
    undistribute(dInfo)
    return res
end

"""
    embedGigaSOM_internal(som::GigaSOM.Som,
                          data::Matrix{Float64},
                          tree,
                          k::Int64,
                          adjust::Float64,
                          boost::Float64,
                          m::Float64)

Internal function to compute parts of the embedding on a prepared kNN-tree
structure (`tree`) and `smooth` converted to `boost`.
"""
function embedGigaSOM_internal(som::GigaSOM.Som,
                               data::Matrix{Float64},
                               tree,
                               k::Int64,
                               adjust::Float64,
                               boost::Float64,
                               m::Float64)

    ndata = size(data,1)
    ncodes = size(som.codes,1)
    dim = size(data,2)

    # output buffer
    e = zeros(Float64, ndata, 2)

    # in case k<ncodes, we use 1 more neighbor to estimate the decay from 'm'
    nk=k
    if nk<ncodes
        nk+=1
    end

    # buffer for indexes of the nk nearest SOM points
    sp = zeros(Int, nk)

    # process all data points in this batch
    for di in 1:size(data,1)

        # find the nearest neighbors of the point and sort them by distance
        (knidx,kndist) = knn(tree, Array{Float64,1}(data[di,:]), nk)
        sortperm!(sp, kndist)
        knidx=knidx[sp] # nearest point indexes
        kndist=kndist[sp] # their corresponding distances

        # Compute the distribution of the weighted distances
        mean = 0.0
        sd = 0.0
        wsum = 0.0
        for i in 1:nk
            tmp = kndist[i]
            w = 1.0/i #the weight
            mean += tmp * w
            sd += tmp * tmp * w
            wsum += w
        end

        mean /= wsum
        sd = boost / sqrt(sd / wsum - mean * mean)
        nmax = m / kndist[nk]

        # if there is the cutoff
        if k<nk
            for i in 1:k
                kndist[i] =
                    exp((mean-kndist[i])*sd) *
                    (1-exp(kndist[i]*nmax-m))
            end
        else #no neighborhood cutoff
            for i in 1:k
                kndist[i] =
                    exp((mean-kndist[i])*sd)
            end
        end

        # `mtx` is used as a matrix of a linear equation (like A|b) with 2
        # unknowns. Derivations of square-error function are added to the
        # matrix in a way that solving the matrix (i.e. finding the zero)
        # effectively minimizes the error.
        mtx = zeros(Float64, 2, 3)

        # The embedding works with pairs of points on the SOM, say I and J.
        # Thus there are 2 cycles for all pairs of `i` and `j`.
        for i in 1:k
            idx = knidx[i] # index of I in SOM
            ix = Float64(som.grid[idx,1]) # position of I in 2D space
            iy = Float64(som.grid[idx,2])
            is = kndist[i] # precomputed score of I

            # a bit of single-point gravity helps with avoiding singularities
            gs = 1e-9 * is
            mtx[1,1] += gs
            mtx[2,2] += gs
            mtx[1,3] += gs*ix
            mtx[2,3] += gs*iy

            for j in (i+1):k
                jdx = knidx[j] # same values for J as for I
                jx = Float64(som.grid[jdx,1])
                jy = Float64(som.grid[jdx,2])
                js = kndist[j]

                # compute values for approximation
                scalar::Float64 = 0 # this will be dot(Point-I, J-I)
                sqdist::Float64 = 0 # ... norm(J-I)

                for kk in 1:dim
                    tmp = som.codes[idx,kk]*som.codes[jdx,kk]
                    sqdist += tmp*tmp
                    scalar += tmp*(data[di,kk]-som.codes[idx,kk])
                end

                if scalar != 0
                    if sqdist == 0
                        # sounds like I==J ...
                        continue
                    else
                        # If everything went right, `scalar` now becomes the
                        # position of the point being embedded on the line
                        # defined by I,J, relatively to both points (I has
                        # position 0 and J has position 1).
                        scalar /= sqdist
                    end
                end

                # Process this information into matrix coefficients that give
                # derivation of the error that the resulting point will have
                # from the `scalar` position between 2D images of I and J.
                #
                # Note: I originally did the math by hand, but, seriously, do
                # not waste time with that and use e.g. Sage for getting the
                # derivatives right if anything should get modified here.
                hx = jx-ix
                hy = jy-iy
                hp = hx*hx + hy*hy
                # Higher `adjust` parameter lowers approximation influence of
                # SOM points that are too far in 2D.
                s = is*js * ((1+hp)^(-adjust)) * exp(-((scalar-.5)^2))
                sihp = s / hp
                rhsc = s * (scalar + (hx*ix + hy*iy) / hp)

                mtx[1,1] += hx * hx * sihp
                mtx[1,2] += hx * hy * sihp
                mtx[2,1] += hy * hx * sihp
                mtx[2,2] += hy * hy * sihp

                mtx[1,3] += hx * rhsc
                mtx[2,3] += hy * rhsc
            end
        end

        # Now the matrix contains a derivative of the error sum function;
        # solving the matrix using the Cramer rule means finding zero of the
        # derivative, which gives the minimum-error position, which is in turn
        # the desired embedded point position that gets saved to output `e`.
        det = mtx[1,1]*mtx[2,2] - mtx[1,2]*mtx[2,1]
        e[di,1] = (mtx[1,3]*mtx[2,2] - mtx[1,2]*mtx[2,3]) / det
        e[di,2] = (mtx[1,1]*mtx[2,3] - mtx[2,1]*mtx[1,3]) / det
    end

    return e
end
