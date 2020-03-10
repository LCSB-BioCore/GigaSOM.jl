
# Where to continue after finishing the tutorials?

After reading through the tutorials, you should now have a decent idea of how
GigaSOM.jl works internally. With real data, you may encounter situations that
require deeper digging in parameters and GigaSOM internals. We list several of
the most frequently used ones:

- You may want to increase the size of SOM in [`initGigaSOM`](@ref) to get more
  precise clusters.
- You may speed up the computation a lot by using neighborhood-indexing
  structures -- see package `NearestNeighbors` and parameters `knnTreeFun` of
  functions [`trainGigaSOM`](@ref) and [`embedGigaSOM`](@ref)
- It is adviced to try different settings of SOM training -- of the arguments
  of [`trainGigaSOM`](@ref), try modifying the starting/finishing radius
  (`rStart`, `rFinal`), using a different radius decay (parameter `radiusFun`,
  try e.g. `linearRadius`) or try a different neighborhood (`kernelFun` and
  `somDistFun`) or a completely different metric.
- You can get a sharper or smoother embedding by varying the amount of
  neighbors (`k`) and smoothing of the neighborhood (`smooth`) of
  [`embedGigaSOM`](@ref).
- For plotting of really huge data, you may want to try
  [GigaScatter](https://github.com/LCSB-BioCore/GigaScatter.jl).
