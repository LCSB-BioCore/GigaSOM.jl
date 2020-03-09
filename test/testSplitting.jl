
@testset "Dataset splitting helpers" begin

    @testset "slice computation" begin
        @test slicesof([11],2) == [(1,1,1,6), (1,7,1,11)]
        a=[30,40,50]
        @test slicesof(a, 1) == [(1, 1, 3, 50)]

        @test slicesof(a,2) ==
         [(1, 1, 2, 30), (2, 31, 3, 50)]

        @test slicesof(a,3) ==
         [(1, 1, 2, 10), (2, 11, 3, 10),
          (3, 11, 3, 50)]

        @test slicesof(a,4) ==
         [(1, 1, 1, 30), (2, 1, 2, 30),
          (2, 31, 3, 20), (3, 21, 3, 50)]

        @test slicesof(a,5) ==
         [(1, 1, 1, 24), (1, 25, 2, 18),
          (2, 19, 3, 2), (3, 3, 3, 26),
          (3, 27, 3, 50)]

        @test slicesof(a,10) ==
         [(1, 1, 1, 12), (1, 13, 1, 24),
          (1, 25, 2, 6), (2, 7, 2, 18),
          (2, 19, 2, 30), (2, 31, 3, 2),
          (3, 3, 3, 14), (3, 15, 3, 26),
          (3, 27, 3, 38), (3, 39, 3, 50)]

    end

    @testset "slice collection" begin
        s = slicesof([4,4], 3)
        
        @test vcollectSlice(i -> repeat([i],4), s[1])[:,1] == [1,1,1]
        @test vcollectSlice(i -> repeat([i],4), s[2])[:,1] == [1,2,2]
        @test vcollectSlice(i -> repeat([i],4), s[3])[:,1] == [2,2]
    end
end
