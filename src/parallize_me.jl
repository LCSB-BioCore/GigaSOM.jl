using Distributed
using DistributedArrays

addprocs(2)

@everywhere using DistributedArrays
@everywhere using LinearAlgebra

M = rand(4,4)

dM = distribute(M)

nprocs()
dM.indices


@spawn rank(dM)
@spawn rank(dM)

@spawnat 2 println(localpart(dM))

@spawnat 3 println(localpart(dM))

X = ones(10,10)
dX = distribute(X)

x = @spawn 2 sum(localpart(dX))
fetch(x)

a = @spawnat 2 sum(localpart(dM))
fetch(a)

b = @spawnat 3 sum(localpart(dM))
fetch(b)
