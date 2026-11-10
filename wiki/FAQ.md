Short answers to the usual questions. Every block on this page runs after

```mathematica
Needs["Summa`"]
```

## Which function do I need?

| To... | use |
|---|---|
| contract tensors | `Einsum` |
| see the order of the contractions and its cost, before computing | `EinsumPath` |
| contract many times with the same shapes | `EinsumFunction` |
| draw the network | `EinsumDiagram` |
| draw the order, with the cost of every step | `EinsumTree` |
| free the memory of the plans | `EinsumClearCache` |

## How does Summa differ from numpy.einsum?

The strings and their rules are the same: the implicit result, the ellipsis, broadcasting. The arrays are the same too,
with their indices in the same order (Mathematica, like numpy by default, stores the last index fastest). The
differences:

- a path counts positions from 1: numpy's `[(1, 2), (0, 1)]` is `{{2, 3}, {1, 2}}`;
- Summa always chooses the order (numpy only with `optimize`);
- the labels can be any character, or any expression in the list syntax;
- numpy's `einsum_path` counts a multiplication and an addition for a step that sums an index, Summa one operation: the
  flops of numpy can be up to twice those of Summa for the same order;
- there is no `out`, `dtype` or `casting`; the entries can be exact or symbolic.

## Can an index appear twice in the result?

No, as in numpy: `"i->ii"` gives `Einsum::outrep`. To put a vector on a diagonal, multiply it by the identity matrix
(or use `DiagonalMatrix`):

```mathematica
Einsum["i,ij->ij", {a, b}, IdentityMatrix[2]]
```

```math
\left(
\begin{array}{cc}
 a & 0 \\
 0 & b \\
\end{array}
\right)
```

## What do the error messages mean?

A wrong einsum prints one message, and gives `$Failed`; two messages are only warnings, and the result is computed:

| Message | For example | Meaning |
|---|---|---|
| `Einsum::spec` | `"ij,jk->>ik"` | the einsum cannot be read: two arrows, or `.`, `-`, `>` as indices |
| `Einsum::nargs` | `Einsum["ij,jk->ik", m]` | the einsum has another number of tensors |
| `Einsum::rank` | `"ijk,jk->ik"` with two matrices | a tensor has another number of indices than its subscript |
| `Einsum::ellrank` | `"...ijk->..."` with a matrix | a tensor has fewer indices than its subscript outside the ellipsis |
| `Einsum::ell` | `"...i...->"` | two ellipses in one subscript |
| `Einsum::ellout` | `"...i->i"` with a matrix | the ellipsis stands for indices, so the result must have `...` |
| `Einsum::dim` | `"ij,jk->ik"` with a 2×2 and a 3×3 matrix | an index has two dimensions, and neither is 1 |
| `Einsum::outrep` | `"i->ii"` | an index twice in the result |
| `Einsum::outnf` | `"ij->iz"` | an index of the result that no tensor has |
| `Einsum::path` | `"Path" -> {{1, 2}}` for three tensors | a path that does not contract everything, or an unknown method |
| `Einsum::array` | `{{1, 2}, {3}}` | a tensor that is not a rectangular array |
| `Einsum::mismatch` | an `EinsumFunction` made for 2×2 matrices, given 2×3 ones | the tensors do not have the shapes it was made for |
| `Einsum::optbig` | `"Path" -> "Optimal"` for fifteen tensors | the exact search stops at fourteen tensors: the greedy one is used, and the result computed |
| `Einsum::optx` | the option `"Foo" -> 1` | an unknown option: it is dropped, and the result computed |

## Can the entries be exact, symbolic, complex or sparse?

Yes. Exact and symbolic entries give exact results ([The syntax](Syntax)). Complex numbers are multiplied as they are,
with no conjugation: write `Conjugate` where the formula has it.

```mathematica
Einsum["i,i->", Conjugate[{1 + I, 2}], {1 + I, 2}]
```

$$6$$

A `SparseArray` stays sparse in the steps that are products of matrices; the other kernels make it dense.

```mathematica
s = SparseArray[{{1, 1} -> 1., {1000, 1000} -> 2.}, {1000, 1000}];
{Head[Einsum["ij,jk->ik", s, s]], Einsum["ii->", s]}
```

```text
{SparseArray, 3.}
```

## Why does `Einsum["ba", m]` transpose `m`?

Without the arrow, the result has its indices in alphabetical order, `"ab"`, as in numpy. `"ba->ba"` keeps the order.

## When should I use EinsumFunction?

When the same einsum is computed many times with the same shapes, in a loop over small tensors, where the time spent
outside the arithmetic matters: `Einsum` already keeps its plans in a cache, and `EinsumFunction` also skips the lookup
and the options. It also keeps the order, its cost and its drawings at hand (`ef["Properties"]`). See
[Speed](Speed#einsumfunction-in-loops).

## Why not TensorContract or EinsteinSummation?

Because of the indices repeated more than twice. `TensorContract` can sum over three slots and more
(`TensorContract[TensorProduct[x, y, z], {{1, 2, 3}}]` is $\sum_i x_iy_iz_i$), but it builds the whole outer product
first: for `"ai,bi,ci->abc"` with three 40×8 matrices, 262 MB and 0.37 s, against 1.6 ms for `Einsum` (Mathematica 15,
one machine). It cannot keep a shared index in the result. The resource function `EinsteinSummation` refuses an index
that appears three times (`{{i}, {i}, {i}} -> {}`) and a batch index kept in the result
(`{{k, a, b}, {k, b, c}} -> {k, a, c}`). See [Repeated indices](Repeated-Indices#without-summa).

## How large can a network be?

Any number of tensors: the exact search of the order goes up to eight tensors by default and fourteen on request, the
greedy search beyond. The limit is the memory of the largest intermediate tensor, which `EinsumPath` gives before
computing (`"LargestIntermediate"`, in entries). See [Orders and costs](Orders-and-Costs#large-networks).

## How do I cite Summa?

As described in [`CITATION.cff`](https://github.com/n4sd4q/Summa/blob/main/CITATION.cff); GitHub's "Cite this
repository" button gives the BibTeX.