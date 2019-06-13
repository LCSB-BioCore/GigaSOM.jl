import DataFrames


"""
    rowSample(df::DataFrame, n::Int)

Take n random rows from a DataFrame with replacement.
"""
function rowSample(df::DataFrame, n::Int)
    
    return df[rand(1:size(df,1), n),:]
end


"""
    rowSample(df::Array, n::Int)

Take n random rows from an Array with replacement and return it as a row vector.
"""
function rowSample(a::Array, n::Int)

    return a[rand(1:size(a,1), n),:]
end

"""
    rowSample(df::Array)

Take 1 random row from an Array and return it as a 1-d-vector (== column vector).
"""
function rowSample(a::Array)

    return vec(a[rand(1:size(a,1), 1),:])
end
