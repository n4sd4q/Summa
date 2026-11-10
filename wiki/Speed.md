Summa is fast for two reasons: the order of the contractions ([Orders and costs](Orders-and-Costs)), and a fast kernel
for each of them. Times depend on the machine, so this page shows flops and speed-ups, which do not;
[`Examples/Benchmarks.wl`](#benchmarks) measures your machine. Every block on this page runs after

```mathematica
Needs["Summa`"]
```

## The order first

The largest gains come from the order. The norm of a matrix-product state of four sites, with bonds of dimension 64:

```mathematica
mps = "pa,aqb,brc,cs,pA,AqB,BrC,Cs->";
dims64 = {{2, 64}, {64, 2, 64}, {64, 2, 64}, {64, 2}, {2, 64}, {64, 2, 64}, {64, 2, 64}, {64, 2}};
Lookup[EinsumPath[mps, dims64], {"Flops", "NaiveFlops", "Speedup"}]
```

$$\\{67600.,7.69658\times 10^{12},1.13855\times 10^8\\}$$

## The kernels

Each pairwise step runs on one kernel, chosen by what the step does with the indices of its two tensors:

| The step | The kernel |
|---|---|
| sums the indices the two tensors share | `Dot` (BLAS) on two matrices, after at most one `Transpose` and one `ArrayReshape` of each tensor |
| sums some shared indices, keeps others (a batch) | a batch of matrix products: `MapThread[Dot, ...]` for large matrices, products of whole arrays and `Total` for many small ones |
| the same indices in both tensors, some summed, some kept | the product in place, and `Total` over the summed levels |
| sums nothing | a product element by element, broadcast when one tensor has fewer indices |
| one tensor is a scalar | a multiplication |

The order of the two tensors, of their batch indices and of their summed indices is chosen to transpose as little data
as possible, the transpose of the result included. [How it works](How-It-Works#lowering) has the details.

## The batch method

For a batch, `"BatchMethod" -> Automatic` (the default) chooses between the two kernels by a cost model; `"Dot"` and
`"Vectorized"` force one of them. The constants of the model are estimates, not measured on your machine: for a loop
that matters, time both. What `Automatic` chose is in the plan of an `EinsumFunction`:

```mathematica
batchMethod[dims_] := #["Method"] & /@ EinsumFunction["bij,bjk->bik", dims]["Plan"]["Steps"];
{batchMethod[{{1000, 4, 4}, {1000, 4, 4}}], batchMethod[{{200, 64, 64}, {200, 64, 64}}]}
```

```text
{{Vec}, {Dot}}
```

A thousand products of 4×4 matrices are vectorised (`Vec`); two hundred of 64×64 go to BLAS one by one. Both give the
same result:

```mathematica
SeedRandom[1]; {x1, x2} = RandomReal[1, {2, 1000, 4, 4}];
Einsum["bij,bjk->bik", x1, x2, "BatchMethod" -> "Dot"] == Einsum["bij,bjk->bik", x1, x2, "BatchMethod" -> "Vectorized"]
```

```text
True
```

## Packed arrays

The kernels are fastest on packed arrays of machine numbers, which `RandomReal`, `N` and ``Developer`ToPackedArray``
give. `Einsum` packs its tensors when it can, and its results are packed:

```mathematica
x = RandomReal[1, {300, 300}];
Developer`PackedArrayQ[Einsum["ij,jk->ik", x, x]]
```

```text
True
```

A list that mixes integers and reals cannot be packed, until `N` makes it real:

```mathematica
Developer`PackedArrayQ /@ {Developer`ToPackedArray[{1, 2.5}], Developer`ToPackedArray[N[{1, 2.5}]]}
```

```text
{False, True}
```

Exact and symbolic entries take the general code of Mathematica: slower, and exact.

## The plan cache

The first call with an einsum, shapes and options builds a plan (the parsing, the order, the kernels) and keeps it; the
next calls with the same shapes reuse it, and only compute. `"Cache" -> False` builds the plan without keeping it, and
`EinsumClearCache[]` empties the cache, which keeps up to 2000 plans and starts again when full. A loop whose shapes
change at every call builds a plan every time: cheap for a few tensors, not for the exact search of a large network.

## EinsumFunction in loops

`EinsumFunction[spec, {dims1, dims2, ...}]` builds the plan once, for these shapes, and is applied as a function, with
no parsing and no lookup in the cache. A quadratic form for each of 5000 rows:

```mathematica
form = EinsumFunction["bi,ij,bj->b", {{5000, 64}, {64, 64}, {5000, 64}}];
SeedRandom[2]; {rows, g} = {RandomReal[1, {5000, 64}], RandomReal[1, {64, 64}]};
form[rows, g, rows] == Total[(rows . g) rows, {2}]
```

```text
True
```

It knows its order and its cost:

```mathematica
form["Properties"]
```

```text
{Spec, Shapes, Path, Method, Flops, NaiveFlops, Speedup, LargestIntermediate, Contractions, Diagram, Tree, Plan}
```

```mathematica
{form["Flops"], form["Speedup"]}
```

$$\\{2.08\times 10^7,1.96923\\}$$

Tensors of other shapes give `Einsum::mismatch` and `$Failed`. In a notebook the function shows as a box with the
drawing of its network, its flops and its order.

## Benchmarks

`Examples/Benchmarks.wl` times `Einsum` (with its plan in the cache) and `EinsumFunction` on your machine, against what
one would write by hand, and checks that the results agree: a chain of three matrices and one product (`Dot`), batches
of 4×4 and 64×64 products (`MapThread[Dot, ...]`), a sum over an index in three tensors (`Total`), the CP
reconstruction (`Outer`), two indices contracted (`TensorContract`), a diagonal (`Diagonal`), a quadratic form for each
row; then the norm of a matrix-product state with bonds of dimension 64.

<!-- not run -->
```mathematica
Get["/path/to/Summa/Examples/Benchmarks.wl"]
```

From a terminal, in a clone of the repository: `wolfram -script Examples/Benchmarks.wl`.

## Habits that pay

- Write the whole formula as one einsum: the order is chosen for all of it, and an index in one tensor only is summed
  before any product.
- Use machine numbers in packed arrays (`N`, `RandomReal`).
- Call with the same shapes, or use `EinsumFunction`, so that the plan is built once.
- For a large network contracted many times, try `"Path" -> "Optimal"` (up to fourteen tensors), and compare the flops
  with `EinsumPath`.