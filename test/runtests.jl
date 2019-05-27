using GigaSOM
using Test

cd("C:/Users/vasco.verissimo/ownCloud/PhD Vasco/CyTOF Project/CyTOF Data")
df_codes = CSV.File("df_codes.csv") |> DataFrame


cd("C:/Users/vasco.verissimo/work/git/hub/GigaSOM.jl/test/refdata")
refdata_df_codes = CSV.File("refdata_df_codes.csv") |> DataFrame



@test isapprox(refdata_df_codes, df_codes)
