using Test
using Distributed

p = addprocs(2)

@everywhere using DistributedArrays
@everywhere using GigaSOM

# only use lineage_markers for clustering
cc = map(Symbol, lineage_markers)
df_som = daf.fcstable[:,cc]

# concatenate the dataset for performance testing
# df_som = vcat(df_som, df_som)
n = 0
for i in 1:n
    global df_som
    df_som = vcat(df_som, df_som)
end

som2 = initGigaSOM(df_som, 10, 10)

@testset "GigaSOM initialisation" begin
    @testset "Type test" begin
        @test typeof(som2) == GigaSOM.Som
        @test som2.toroidal == false
        @test typeof(som2.grid) == Array{Float64,2}
    end
    @testset "Dimensions Test" begin
        @test size(som2.codes) == (100,10)
        @test som2.xdim == 10
        @test som2.ydim == 10
        @test som2.nCodes == 100
    end

end

@time som2 = trainGigaSOM(som2, df_som, epochs = 10, r = 6.0)

mywinners = mapToSOM(som2, df_som)
CSV.write("cell_clustering_som.csv", mywinners)

# myfreqs = SOM.classFrequencies(som2, daf.fcstable, :sample_id)

codes = som2.codes
@test size(codes) == (100,10)

df_codes = DataFrame(codes)
names!(df_codes, Symbol.(som2.colNames))
CSV.write("df_codes.csv", df_codes)
CSV.write("mywinners.csv", mywinners)
# CSV.write("myfreqs.csv", myfreqs)
