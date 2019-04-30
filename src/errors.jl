#
# error messages:
#
SOM_ERRORS = Dict(
:ERR_MPL =>
"""
    Matplotlib is not correctly installed!

    See the documentation at https://andreasdominik.github.io/SOM.jl/stable/
    for details and potential solutions.
""",
:ERR_MATRIX =>
"""
    Input data is not a numerical 2D-matrix!

    Please provide a numerical 2D-array or DataFrame
    that can be converted into an Array{Float64,2}.
""",
:ERR_COLOUR_DEF =>
"""
    Incorrect colour definition!

    Please provide a Dict of class lables and colours or
    a colour map name (as String or as Symbol).
""",
:ERR_COL_NUM =>
"""
    Wrong number of attributes!

    Number of columns of data (i.e. attributes) does not match
    number of dimensions of codes.
"""

)
