<img src="https://user-images.githubusercontent.com/1152087/188331266-5e03565b-00a7-490c-a616-50598ca46010.png" width="280">

# MolecularEvolution.jl

<!---[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://MurrellGroup.github.io/MolecularEvolution.jl/stable/)-->
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://MurrellGroup.github.io/MolecularEvolution.jl/dev/)
[![Build Status](https://github.com/MurrellGroup/MolecularEvolution.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/MurrellGroup/MolecularEvolution.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/MurrellGroup/MolecularEvolution.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/MurrellGroup/MolecularEvolution.jl)

### A Julia package for the flexible development of phylogenetic models.

MolecularEvolution.jl exploits Julia's multiple dispatch, implementing a fully generic suite of likelihood calculations, branchlength optimization, topology optimization, and ancestral inference. Users can define probability distributions over their own data types, and specify the behavior of these under their own model types.

If the behavior you need is not already available in `MolecularEvolution.jl`:
- If you have a new data type:
  - A `Partition` type that represents the uncertainty over your state. 
  - `combine!()` that merges evidence from two `Partition`s.
- If you have a new model:
  - A `BranchModel` type that stores your model parameters.
  - `forward!()` that evolves state distributions over branches, in the root-to-tip direction.
  - `backward!()` that reverse-evolves state distributions over branches, in the tip-to-root direction.

And then sampling, likelihood calculations, branch-length optimization, ancestral reconstruction, etc should be available for your new data or model.

### Design principles
In order of importance, we aim for the following:
- Flexibility and generality
  - Where possible, we avoid design decisions that limit the development of new models, or make it harder to develop new models.
  - We do not sacrifice flexibility for performance.
- Scalability
  - Analyses implemented using `MolecularEvolution.jl` should scale to large, real-world datasets.
- Performance
  - While the above take precedence over speed, it should be possible to optimize your `Partition`, `combine!()`, `BranchModel`, `forward!()` and `backward!()` functions to obtain competative runtimes.

### Authors:
Venkatesh Kumar and Ben Murrell, with additional contributions by Sanjay Mohan, Alec Pankow, Hassan Sadiq, and Kenta Sato.

### Quick example: Likelihood calculations under phylogenetic Brownian motion:

```julia
using MolecularEvolution, Plots

#First simulate a tree, using a coalescent process
tree = sim_tree(n=200)
internal_message_init!(tree, GaussianPartition())
#Simulate brownian motion over the tree
bm_model = BrownianMotion(0.0,1.0)
sample_down!(tree, bm_model)
#And plot the log likelihood as a function of the parameter value
ll(x) = log_likelihood!(tree,BrownianMotion(0.0,x))
plot(0.7:0.001:1.6,ll, xlabel = "variance per unit time", ylabel = "log likelihood")
```
<img width="500" alt="image" src="https://user-images.githubusercontent.com/1152087/188332021-051021a9-b571-43c5-9ff9-048de1036892.png">

