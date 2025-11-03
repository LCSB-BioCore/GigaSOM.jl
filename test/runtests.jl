
using Test
using Aqua
import GigaSOM

# helper functions for running tests en masse
print_timing(fn, t) = @info "$(fn) done in $(round(t; digits = 2))s"

function run_test_file(path...)
    fn = joinpath(path...)
    t = @elapsed include(fn)
    print_timing(fn, t)
end

function run_doc_examples()
    for ex in filter(endswith(".jl"), readdir("../docs/src/tutorials", join = true))
        @testset "docs/$(basename(ex))" begin
            run_test_file(ex)
        end
    end
end

@testset "GigaSOM test suite" begin
    @testset "Documentation tests" begin
        run_doc_examples()
    end

    run_test_file("aqua.jl")
end
