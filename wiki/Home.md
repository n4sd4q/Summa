# Summa

Practical guides and a FAQ for Summa, a Wolfram Language package for Einstein summation with the syntax of
`numpy.einsum`. You write a contraction as on paper, the indices of every factor, `"ij,jk->ik"`, and you do not have to
work out how to compute it: Summa chooses the order of the pairwise contractions and the kernel of each (BLAS, batched
or broadcasting products), with no transposes, reshapes or intermediate arrays by hand. An index may appear in any
number of tensors, and the network can be drawn as it is computed. The [website](https://n4sd4q.github.io/Summa/)
gives the overview and a first example, the [guided tour](https://github.com/n4sd4q/Summa/blob/main/Examples.wl) builds
everything up step by step, the [showcase](https://n4sd4q.github.io/Summa/Showcase/Summa_Showcase.pdf) shows what the
package can do and the [manual](https://n4sd4q.github.io/Summa/Documentation/Summa_Manual.pdf) describes every function.

## Pages

- Start
  - [Installation](Installation): installing, loading, updating, and what to do when loading fails
  - [The syntax](Syntax): the strings of numpy, the implicit output, transposes, ellipsis and broadcasting, scalars,
    Unicode, labels of any kind
  - [FAQ](FAQ): short answers to the usual questions
- Recipes
  - [Repeated indices](Repeated-Indices): diagonals, traces and sums; an index in three or more tensors: hyperedges,
    batch indices, the CP decomposition
  - [Orders and costs](Orders-and-Costs): the order of the contractions and its cost, choosing it, the contraction tree,
    large networks
  - [Speed](Speed): the kernels, packed arrays, the plan cache, `EinsumFunction` in loops, benchmarks
  - [Diagrams](Diagrams): the tensor network drawn, its options, and the order of the contractions
  - [Physics examples](Physics-Examples): the Kubo formula of a two-band chain as one einsum, a trace at every k, the
    norm of a matrix-product state
- Reference
  - [How it works](How-It-Works): parsing, the preprocessing of each tensor, the search of the order, the kernels,
    execution and the cache

The code on these pages is run, and gives what is shown after it: a formula as `TeXForm` writes it, or a result as a
terminal prints it; the pictures are drawn by the code before them.
