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
dX = distribute(X ,workers(), [2,1])

x = @spawn 2 sum(localpart(dX))
fetch(x)

a = @spawnat 2 sum(localpart(dM))
fetch(a)

b = @spawnat 3 sum(localpart(dM))
fetch(b)

# split the dataset by rows
X2 = dones((10,10), workers()[1:2], [2,1])
@spawnat 2 println(localpart(X2))
[@fetchfrom p localindices(X2) for p in workers()]



A = ones(170000,35)
dA = distribute(A)

[@fetchfrom p localindices(dA) for p in workers()]
