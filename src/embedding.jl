"""
    embedGigaSOM(som::Som, data::DataFrame, k, adjust, smooth)

Return a data frame with X,Y coordinates of EmbedSOM projection of the data.

# Arguments
- `som`: a trained SOM
- `data`: Array or DataFrame with the data.
- `k`: number of nearest neighbors to consider (high values get quadratically
  slower)
- `adjust`: position adjustment parameter (higher values avoid non-local
  approximations)
- `smooth`: approximation smoothness (the higher the value, the larger the
  neighborhood of approximate local linearity of the projection)
- `knnTreeFun`: Constructor of the KNN-tree (e.g. from NearestNeighbors package)
- `metric`: Passed as metric argument to the KNN-tree constructor

Example:

Produce a 2-column matrix with 2D cell coordinates:

```
e = embedGigaSOM(som, data)
```

Plotting of the result is best done using 2D histograms; e.g. with Gadfly:

```
using Gadfly
draw(PNG("output.png",20cm,20cm),
     plot(x=e[:,1], y=e[:,2],
     Geom.histogram2d(xbincount=200, ybincount=200)))
```

Data must have the same number of dimensions as the training dataset
and will be normalised with the same parameters.
"""
function embedGigaSOM(som::GigaSOM.Som, data::DataFrame;
                      knnTreeFun = BruteTree,
                      metric = Euclidean(),
                      k::Int64=0, adjust::Float64=1.0, smooth::Float64=0.0)

    data::Array{Float64,2} = convertTrainingData(data)
    if size(data,2) != size(som.codes,2)
        println("    data: $(size(data,2)), codes: $(size(som.codes,2))")
        error(SOM_ERRORS[:ERR_COL_NUM])
    end

    # convert `smooth` to `boost`
    boost = ((1+sqrt(Float64(5)))/2)^(smooth-2)

    # default `k`
    if k == 0
        k = Integer((som.xdim+som.ydim)/2)
    end

    # check if `k` isn't too high
    if k > som.xdim*som.ydim
        k = Integer(som.xdim * som.ydim)
    end

    # prepare the kNN-tree for lookups
    tree = knnTreeFun(Array{Float64,2}(transpose(som.codes)), metric)

    # run the distributed computation
    nWorkers = nprocs()
    if nWorkers > 1
        dData = distribute(data)

        dRes = [ (@spawnat pid embedGigaSOM_internal(som, localpart(dData), tree,
                                                   k, adjust, boost))
                 for (p,pid) in enumerate(workers()) ]

        return vcat([fetch(r) for r in dRes]...)
    else
        return embedGigaSOM_internal(som, data, tree, k, adjust, boost)
    end
end

"""
    embedGigaSOM_internal(som::GigaSOM.Som, data::Array{Float64,2}, tree,
                          k::Int64, adjust::Float64, boost::Float64)

Internal function to compute parts of the embedding on a prepared kNN-tree
structure (`tree`) and `smooth` converted to `boost`.
"""
function embedGigaSOM_internal(som::GigaSOM.Som, data::Array{Float64,2},
			       tree, k::Int64, adjust::Float64, boost::Float64)

    ndata = size(data,1)
    dim = size(data,2)

    # output buffer
    e = zeros(Float64, ndata, 2)

    # buffer for indexes of the k nearest SOM points
    sp = zeros(Int, k)

    # process all data points in this batch
    for di in 1:size(data,1)

        # find the nearest neighbors of the point and sort them by distance
        (knidx,kndist) = knn(tree, data[di,:], k)
        sortperm!(sp, kndist)
        knidx=knidx[sp] # nearest point indexes
        kndist=kndist[sp] # their corresponding distances

        # compute the scores accordingly to EmbedSOM scoring
        sum=0.0
        ssum=0.0
        min=kndist[1]
        for i in 1:k
            sum += kndist[i] / i
            ssum += 1.0/i
            if kndist[i] < min
                min = kndist[i]
            end
        end

        # Compute the final scores. The tiny constant avoids hitting zero.
        # Higher `smooth` (and therefore `boost`) parameter causes the `sum` to
        # be exaggerated, which (after the inverse) results in slower decay of
        # the SOM point score with increasing distance from the point that is
        # being embedded.
        sum = -ssum / (1e-9 + sum * boost)
        for i in 1:k
            kndist[i] = exp(sum*(kndist[i]-min))
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
                hpxy = hx*hx+hy*hy
                ihpxy = 1/hpxy
                # Higher `adjust` parameter lowers approximation influence of
                # SOM points that are too far in 2D.
                s = is*js/(hpxy^adjust)
                diag = s * hx * hy * ihpxy
                rhsc = s * (scalar + (hx*ix+hy*iy) * ihpxy)

                mtx[1,1] += s * hx * hx * ihpxy
                mtx[2,2] += s * hy * hy * ihpxy

                mtx[1,2] += diag
                mtx[2,1] += diag

                mtx[1,3] += hx*rhsc
                mtx[2,3] += hy*rhsc
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
