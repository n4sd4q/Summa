# Summa — fast Einstein summation for Mathematica

`Summa` is a Wolfram Language package for contracting tensors with the syntax of `numpy.einsum` (main function: `Einsum`). No
manual transposes and reshapes. Unlike `ResourceFunction["EinsteinSummation"]`, **an index may appear any number of times**: within
one tensor (diagonals, traces) and across tensors (hyperedges, or batch indices shared by 3, 4, … tensors).

```mathematica
Needs["Summa`"]

Einsum["ij,jk->ik", a, b]                 (* matrix product (BLAS) *)
Einsum["ijk,ijk,ijk->", a, b, c]          (* an index repeated 3 times *)
Einsum["ai,bi,ci->abc", A, B, C]          (* CP reconstruction: i shared by 3 tensors *)
Einsum["bij,bjk->bik", x, y]              (* batched matmul *)
Einsum["pa,aqb,brc,cs,pA,AqB,BrC,Cs->", A1, A2, A3, A4, A1, A2, A3, A4]  (* norm of an MPS *)
EinsumDiagram["ai,ibj,jck,kd->abcd"]      (* draws the tensor network *)
```

## Features

- **Full numpy syntax**: `"ij,jk->ik"`, implicit output (`"ij,jk"` gives `"ik"`, `"ba"` transposes), ellipsis `"...ij,...jk->...ik"`
  with broadcasting, broadcasting of axes of size 1, scalar operands (`",ij->ij"`), Unicode labels (`"αβ,βγ->αγ"`) and the arrow `→`.
- **List syntax** with arbitrary labels: `Einsum[{{"bond1","x"},{"x","bond2"}} -> {"bond2","bond1"}, a, b]`.
- **Indices repeated at will**: generalised diagonals (`"iij->j"`, `"iii->i"`), traces, sums, hyperedges with 3 or more legs.
- **Optimised contraction order**: exact dynamic programming over subsets (minimum number of flops) up to 8 tensors, then a greedy
  search as in opt_einsum. Alternatively a sequential order or a path of your choice.
- **Vectorised kernels**. Every pairwise contraction becomes one of:
  - `Dot` (BLAS/MKL), after a single `Transpose` + `ArrayReshape` per operand, and only when needed;
  - a batched contraction (`C[b,i,k] = Σ_j L[b,i,j] R[b,j,k]`), with a cost model that chooses between a loop of BLAS `Dot` (large
    matrices) and vectorised broadcasting on packed arrays (large batches of small matrices);
  - a Hadamard or broadcasting product (prefix/suffix), without transposes;
  - a product and `Total` in place for a batched contraction of two operands with the same indices.
- **Plan cache**: a second call with the same shapes skips parsing and optimisation. `EinsumFunction` precompiles an einsum for fixed
  shapes, for use in loops.
- **Visualisation**: `EinsumDiagram` (the tensor network), `EinsumTree` (the contraction tree with costs) and `"Steps" -> True` (one
  frame per contraction, to animate).
- Also works with **symbolic**, **complex** and exact integer arrays, and with `SparseArray` in the `Dot`-type steps. Any argument
  that is not a list (even `Sqrt[2]` or `a + b`) is a scalar.

## Installation

Any of the three:

1. **Direct**: `Get["/path/to/Summa/Kernel/Summa.wl"]`
2. **Paclet**: `PacletDirectoryLoad["/path/to/Summa"]; Needs["Summa`"]`
3. **Permanent**: copy the `Summa` folder into `FileNameJoin[{$UserBaseDirectory, "Applications"}]`; from then on `Needs["Summa`"]`
   is enough.

Requires Mathematica 11.3 or later.

## Functions

| Function | What it does |
|---|---|
| `Einsum[spec, t1, t2, …]` | computes the einsum. Options: `"Path"` (`Automatic`, `"Optimal"`, `"Greedy"`, `"Sequential"`, `{{i,j},…}`), `"BatchMethod"` (`Automatic`, `"Dot"`, `"Vectorized"`), `"Cache"` (`True`) |
| `EinsumPath[spec, t1, …]` or `EinsumPath[spec, {dims1, …}]` | the chosen path (numpy linear format, 1-based), flops, naive flops, speed-up, largest intermediate, the string of each contraction |
| `EinsumFunction[spec, {dims1, …}]` | a precompiled einsum: `ef[t1, t2]`. Properties: `ef["Path"]`, `ef["Flops"]`, `ef["Diagram"]`, `ef["Tree"]`, … It has a summary box with the icon of the network |
| `EinsumDiagram[spec]`, `EinsumDiagram[spec, t1, …]` | drawing of the tensor network. Options: `"ShowPath"`, `"Steps"`, `"Layout"` (`Automatic`, `"Circle"`, `"Line"` or coordinates), `"TensorNames"`, `"Highlight"`, `"ShowDimensions"` |
| `EinsumTree[spec, t1, …]` | contraction tree with the indices, the summed indices and the flops of each intermediate |
| `EinsumClearCache[]` | empties the plan cache |

## How hyperedges are drawn

Every index is a COPY tensor (a delta) with one leg per occurrence, plus one if the index appears in the output:

- **2 legs**: a wire. It becomes a bond between two tensors, an open leg (an output index) or a loop (a trace).
- **1 leg**: the index is summed over. The leg ends in a small circle, i.e. a contraction with the vector of ones.
- **3 or more legs**: a **hyperedge**, drawn as a purple dot connected to all the tensors that share it.

Dangling legs are placed in the free angular gaps. The automatic layout uses classical MDS on the graph distances, refined by stress
majorization: chains (MPS) come out straight, rings circular, grids as grids. The thickness of a bond grows with log(dimension).
Tensors with the same name have the same colour, and hovering over an element shows a tooltip with its indices, dimensions and role.

`Examples/diagram_preview.png` is an approximate preview of the drawings, made outside Mathematica.

`EinsumDiagram[..., "ShowPath" -> True]` writes on each bond the number of the step in which it is contracted.
`ListAnimate[EinsumDiagram[spec, dims, "Steps" -> True]]` shows the contraction step by step: the highlighted pair is the one
contracted next.

## How it works (and why it is fast)

1. **Parsing and resolution**: labels become integers, the ellipsis is expanded and the dimensions are checked, with broadcasting of
   the axes of size 1.
2. **Per-operand preprocessing**: the diagonals of repeated indices are extracted with `Transpose[t, {1,1,2,…}]` (a Transpose with
   repeated levels). Indices needed nowhere else are summed at once with `Total`.
3. **Path**: for every subset S of tensors, the result of S keeps only the indices still needed outside S or in the output. This is
   what turns an index shared by three or more tensors into a **batch index** of the intermediate contractions. On this basis runs the
   exact O(3ⁿ) dynamic programming for n ≤ 8, otherwise the greedy search.
4. **Lowering**: each step L×R is classified into batch, contracted and free indices. The combination of operand order, batch-index
   order and contracted-index order that minimises the data to transpose, the final result included, is chosen. Then the best kernel
   runs:
   - empty batch: `Dot` on 2D matrices;
   - batch of large matrices: `MapThread[Dot, …]`;
   - batch of small matrices: vectorised broadcasting and `Total`;
   - batch of two operands with the same indices (`"kh,kh->h"`, `"khn,hkn->kh"`): product in the layout of one operand and `Total`
     over the contracted levels, instead of transposing both to put the batch index first (2–8× faster);
   - no summed index, nested index sets: broadcasting product.
5. **Execution**: intermediates are freed as soon as they are used, and the whole plan stays in the cache.

Tips for maximum speed:

- use packed arrays (`RandomReal`, `N[...]`, `Developer`ToPackedArray`);
- in loops use `EinsumFunction`, or call `Einsum` always with the same shapes so that the cache is reused;
- for networks of more than 8 tensors, if the planning time is negligible compared to the computation, try `"Path" -> "Optimal"` (up
  to 14 tensors; beyond that the greedy search is used, with a warning).

## Verification

The package was first developed without a Mathematica licence and checked with Mathics3 (an open-source Wolfram Language interpreter)
against `numpy.einsum` on about 2500 random and hand-picked einsums, with every path and every kernel (0 errors); the dynamic
programming was checked against an exhaustive search. With Mathematica 15.0 the whole test suite passes (700 of 700).

## Tests

```mathematica
TestReport["/path/to/Summa/Tests/SummaTests.wlt"]
```

About 700 tests:

- 213 cases with expected results computed by `numpy.einsum` in exact integer arithmetic: 63 hand-picked cases that cover every
  kernel, plus 150 random ones. The 63 hand-picked cases are repeated with every path strategy and with both batch methods;
- 40 networks for which the cost of the `"Optimal"` path must equal an exhaustive search over all contraction orders (and `"Greedy"`
  cannot do better);
- comparisons in machine precision (real and complex) with an explicit reference sum;
- symbolic and sparse inputs, alternative syntaxes, error messages, `EinsumFunction` and the diagrams.

`Examples/Benchmarks.wl` measures the timings on your machine against hand-written equivalents: `Dot`, `MapThread`,
`TensorContract`, `Total`.

## Files

```
Summa/
├── PacletInfo.m
├── Kernel/Summa.wl           ← the package
├── Kernel/init.m             ← loader for the Applications folder
├── Tests/SummaTests.wlt      ← test suite (TestReport)
├── Examples/SummaDemo.nb     ← demo notebook
├── Examples/Benchmarks.wl    ← benchmarks
├── Examples/diagram_preview.png
└── README.md
```

## Known limitations

- Output indices cannot repeat (`"i->ii"` is not allowed, as in numpy).
- The optimal dynamic programming is exponential: beyond 8 tensors the default is greedy, and `"Optimal"` is accepted up to 14 tensors.
- A `SparseArray` stays sparse only in the `Dot`-type steps; the other kernels convert it to dense.
- The constants of the cost model for batched steps are reasonable estimates, not calibrated on your machine. A kernel can be forced
  with `"BatchMethod"`.

