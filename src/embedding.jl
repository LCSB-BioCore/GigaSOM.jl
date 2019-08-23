"""
    embedGigaSOM(som::Som, data::DataFrame, k, adjust, smooth)

Return a data frame with X,Y coordinates of EmbedSOM projection of the data.

# Arguments
- `som`: a trained SOM
- `data`: Array or DataFrame with the data.
- `k`: number of nearest neighbors to consider (high values get quadratically slower)
- `adjust`: position adjustment parameter (higher values avoid non-local approximations)
- `smooth`: approximation smoothness (the higher the value, the larger the neighborhood of approximate local linearity of the projection)

Example:

Produce a 2-column matrix with 2D cell coordinates:

```
e = embedGigaSOM(som, data)
```

Plotting is best done using histograms; e.g. with Gadfly:

```
draw(PNG("output.png",20cm,20cm),
     plot(x=e[:,1], y=e[:,2],
     Geom.histogram2d(xbincount=200, ybincount=200)))
```

Data must have the same number of dimensions as the training dataset
and will be normalised with the same parameters.
"""
function embedGigaSOM(som::GigaSOM.Som, data::DataFrame;
                      knnTreeFun = BruteTree,
                      k=0, adjust=1.0, smooth=0.0)

    data::Array{Float64,2} = convertTrainingData(data)
    if size(data,2) != size(som.codes,2)
        println("    data: $(size(data,2)), codes: $(size(som.codes,2))")
        error(SOM_ERRORS[:ERR_COL_NUM])
    end

    boost = ((1+sqrt(Float64(5)))/2)^(Float64(smooth)-2)
    adjust = Float64(adjust)

    if k == 0
        k = Integer((som.xdim+som.ydim)/2)
    end

    if k > som.xdim*som.ydim
        k = Integer(som.xdim * som.ydim)
    end

    t = knnTreeFun(Array{Float64,2}(transpose(som.codes)))

    ndata = size(data, 1)
    dim = size(data, 2)

    nWorkers = nprocs()
    if nWorkers > 1
        dData = distribute(data)

        dRes = [ (@spawnat w embedGigaSOM_internal(som, localpart(dData), t, k, adjust, boost)) for w in workers() ]

        #hopefully the data are separated to localparts in correct order...
        return vcat([fetch(r) for r in dRes]...)
    else
        return embedGigaSOM_internal(som, data, t, k, adjust, boost)
    end
end

function embedGigaSOM_internal(som::GigaSOM.Som, data::Array{Float64,2}, t, k, adjust, boost)
    ndata=size(data,1)
    dim=size(data,2)

    e=zeros(Float64, ndata, 2)
    sp=zeros(Int, k)

    # process all data points in this batch
    for di in 1:size(data,1)

        # find the nearest neighbors and put them into correct order
        (knidx,kndist) = knn(t, data[di,:], k)
        sortperm!(sp, kndist)
        knidx=knidx[sp]
        kndist=kndist[sp]

        # compute the scores
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

        #0.000001 avoids hitting zeroes
        sum = -ssum / (0.00000001 + sum * boost)
        for i in 1:k
            kndist[i] = exp(sum*(kndist[i]-min))
        end

        # prepare the empty matrix
        mtx = zeros(Float64, 2, 3)

        for i in 1:k
            idx = knidx[i]
            ix = Float64(som.grid[idx,1])
            iy = Float64(som.grid[idx,2])
            ip = kndist[i]

            # a bit of gravity to avoid singularities
            gs = 0.00001 * ip

            mtx[1,1] += gs
            mtx[2,2] += gs

            mtx[1,3] += gs*ix
            mtx[2,3] += gs*iy

            for j in (i+1):k
                jdx = knidx[j]
                jx = Float64(som.grid[jdx,1])
                jy = Float64(som.grid[jdx,2])
                jp = kndist[j]

                scalar::Float64 = 0
                sqdist::Float64 = 0

                for kk in 1:dim
                    tmp = som.codes[idx,kk]*som.codes[jdx,kk]
                    sqdist += tmp*tmp
                    scalar += tmp*(data[di,kk]-som.codes[idx,kk])
                end

                if scalar != 0
                    if sqdist == 0
                        continue
                    else
                        scalar /= sqdist
                    end
                end

                hx = jx-ix
                hy = jy-iy
                hpxy = hx*hx+hy*hy
                ihpxy = 1/hpxy
                s = ip*jp/(hpxy^adjust)
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

        # now solve the equation in mtx
        det = mtx[1,1]*mtx[2,2] - mtx[1,2]*mtx[2,1]
        e[di,1] = (mtx[1,3]*mtx[2,2] - mtx[1,2]*mtx[2,3]) / det
        e[di,2] = (mtx[1,1]*mtx[2,3] - mtx[2,1]*mtx[1,3]) / det
    end

    return e
end
