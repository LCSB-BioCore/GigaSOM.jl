using Distributed
using DistributedArrays

addprocs(2)

@everywhere using DistributedArrays
@everywhere using LinearAlgebra

dtable = dones((100,100), workers()[1:2], [1,2])
res3 = @spawnat 3 sum(dtable)
fetch(res3)
res=localpart(dtable)

dzeros(10,10, 2)

nworkers()

# addprocs(Sys.CPU_CORES - 1)  # Run this line if needed.
r1 = remotecall(rand, 2, 2, 2) # Function, id of the worker, args of the function.
r2 = remotecall(rand, 2, 1:8, 3, 4) # We obtain a 'Future'.

fetch(r1) # We get the value.
fetch(r2)

# Notice what happens once the value is fetched:
r1
r1[2, 2]

# However, r1 is still a Future so some operations might not work:
typeof(r1)
sum(r1)         # This does not work because r1 is a Future, no an array.

r3 = fetch(r1); # We save the result in another variable.
typeof(r3)
sum(r3)

# Option 1: using remotecall and spawnat.
r1 = remotecall(rand, 3, 2, 2)
s1 = @spawnat 3 1 .+ fetch(r1) # id process, expression: 1 .+ fetch(r1)
fetch(s1)

# Option 2: using only spawnat.
s2 = @spawnat 3 rand(2, 2)
s3 = @spawnat 2 1 .+ fetch(s2)
fetch(s3) # The result changes because we are using random numbers.

# Option 3: Letting Julia to select the process for us.
s2 = @spawn rand(2, 2)     # Notice that there is no "at", so we do not specify the worker.
s3 = @spawn 1 .+ fetch(s2) # It is Julia that selects it.
fetch(s3)

# Tip: due to efficiency reasons, use
remotecall_fetch(rand, 3, 2, 2) # instead of fetch(remotecall())

# We create a function that returns the sum of the eigenvalues.
function eig_sum(A)
    autoVal, autoVec = eigvals(A);
    return sum(autoVal)
end

# We test the function as usual... and it works fine.
eig_sum(rand(2, 2))

# We use it at process 1.
s1 = @spawnat 1 eig_sum(rand(2, 2))
fetch(s1)

# We use it at process 2.
s2 = @spawnat 3 eig_sum(rand(2, 2))
fetch(s2) # returns an error.

@everywhere function eig_sum(A) # Now all the processes know about the function.
    autoVal, autoVec = eigvals(A);
    return sum(autoVal)
end

s2 = @spawnat 2 eig_sum(rand(2, 2))
fetch(s2) # Now everything works fine.

# When having the functions in an external file:
@everywhere include("FileWithFunctions.jl")


@DArray [i+j for i = 1:3, j = 1:3]

@everywhere function dummy_som(x, df_som)

end
