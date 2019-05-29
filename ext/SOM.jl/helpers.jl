import DataFrames: nrow, ncol

"""
    nrow(a::Array)

Returns size of the first dimenstion of Array a (== nrow() for Arrays).
"""
function nrow(a::Array)

    return size(a)[1]
end

"""
    ncol(a::Array)

Returns size of the second dimenstion of Array a (== ncol() for Arrays).
"""
function ncol(a::Array)

    return size(a)[2]
end


"""
    rowSample(df::DataFrame, n::Int)

Take n random rows from a DataFrame with replacement.
"""
function rowSample(df::DataFrame, n::Int)

    return df[rand(1:nrow(df), n),:]
end


"""
    rowSample(df::Array, n::Int)

Take n random rows from an Array with replacement and return it as a row vector.
"""
function rowSample(a::Array, n::Int)

    return a[rand(1:nrow(a), n),:]
end

"""
    rowSample(df::Array)

Take 1 random row from an Array and return it as a 1-d-vector (== column vector).
"""
function rowSample(a::Array)

    return vec(a[rand(1:nrow(a), 1),:])
end




"""
    initCodes(num::Int, x::Array)

Return num rows from Array x as initial codes.
"""
function initCodes(num::Int, x::Array{Float64}, colNames)

    codes = rowSample(x, num)
    return codes
end


"""
    findWinner(cod, sampl)

Return index of the winner neuron for sample sampl.
"""
function findWinner(cod, sampl)

    dist = floatmax()
    winner = 1
    n = nrow(cod)

    for i in 1:n

        d = euclidean(sampl, cod[i,:])
        if (d < dist)
            dist = d
            winner = i
        end
    end

    return winner
end


"""
    normTrainData(train::DataFrame, normParams::DataFrame)

Normalise every column of training data with the params.

# Arguments
- `train`: DataFrame with training Data
- `normParams`: Shift and scale parameters for each attribute column.
"""
function normTrainData(x::Array{Float64,2}, normParams)

    for i in 1:ncol(x)
        x[:,i] = (x[:,i] .- normParams[1,i]) ./ normParams[2,i]
    end

    return x
end


"""
    normTrainData(train::DataFrame, norm::Symbol)

Normalise every column of training data.

# Arguments
- `train`: DataFrame with training Data
- `norm`: type of normalisation; one of `minmax, zscore, none`
"""
function normTrainData(train::Array{Float64,2}, norm::Symbol)

    normParams = zeros(2, ncol(train))

    if  norm == :minmax
        for i in 1:ncol(train)
            normParams[1,i] = minimum(train[:,i])
            normParams[2,i] = maximum(train[:,i]) - minimum(train[:,i])
        end
    elseif norm == :zscore
        for i in 1:ncol(train)
            normParams[1,i] = mean(train[:,i])
            normParams[2,i] = std(train[:,i])
        end
    else
        for i in 1:ncol(train)
            normParams[1,i] = 0.0  # shift
            normParams[2,i] = 1.0  # scale
        end
    end

    # do the scaling:
    if norm == :none
        x = train
    else
        x = normTrainData(train, normParams)
    end

    return x, normParams
end


function convertTrainingData(data)::Array{Float64,2}

    if typeof(data) == DataFrame
        train = convert(Matrix{Float64}, data)

    elseif typeof(data) != Matrix{Float64}
        try
            train = convert(Matrix{Float64}, data)
        catch ex
            Base.showerror(STDERR, ex, backtrace())
            error("Unable to convert training data to Array{Float64,2}!")
        end
    else
        train = data
    end

    return train
end


prettyPrintArray(arr) = println("$(show(IOContext(STDOUT, limit=true), "text/plain", arr))")
