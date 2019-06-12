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
