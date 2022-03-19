"""
    dtransform_asinh(dInfo::Dinfo, columns::Vector{Int}, cofactor=5)

Transform columns of the dataset by asinh transformation with `cofactor`.
"""
function dtransform_asinh(dInfo::Dinfo, columns::Vector{Int}, cofactor = 5)
    dapply_cols(dInfo, (v, _) -> asinh.(v ./ cofactor), columns)
end

