What happens in a call `Einsum[spec, t1, t2, ...]`. The first four stages make a plan, which depends only on the einsum,
the shapes of the tensors and the options, and is kept in a cache; the last one computes. The plan of an
`EinsumFunction` can be read, `ef["Plan"]`. Every block on this page runs after

```mathematica
Needs["Summa`"]
```

## Parsing

The string is split at the arrow and at the commas: spaces are dropped, `→` is the arrow, `...` and `…` are the
ellipsis; a list is read as it is. The labels become the integers 1, 2, ... in their order of first appearance, the
ellipsis becomes as many labels as each tensor needs (aligned from the right), and the implicit result is written out:

```mathematica
EinsumPath["ba,cb", {{2, 3}, {4, 2}}]["Spec"]
```

```text
ba,cb->ac
```

Every index must have one dimension in all the tensors that have it, or the dimension 1, which is broadcast. A wrong
einsum stops here, with one message ([FAQ](FAQ#what-do-the-error-messages-mean)).

## The preprocessing of each tensor

Before any product, each tensor is reduced alone: its broadcast axes of size 1 are dropped; an index repeated in it
gives a diagonal, taken by one `Transpose` with repeated levels (`Transpose[t, {1, 1, 2}]` is $t_{iij}$); and the
indices that no other tensor has, and the result does not keep, are summed with `Total`. For `"iijx,jk->k"` the first
tensor becomes a vector in `j` (label 2) at once:

```mathematica
ef = EinsumFunction["iijx,jk->k", {{3, 3, 4, 5}, {4, 6}}];
First[ef["Plan"]["Pre"]]
```

```text
<|Squeeze -> None, Diag -> {1, 1, 2, 3}, Sum -> {3, 1}, Labels -> {2}|>
```

`Transpose[t, {1, 1, 2, 3}]` takes the diagonal in `i`, and `Total` sums the levels of `x` and of `i`.

## The search of the order

The order is a sequence of pairwise contractions. When a set $S$ of tensors has been contracted into one, its result
keeps only the indices still needed, by a tensor outside $S$ or by the result $O$:

$$K(S)=I(S)\cap\big(I(\bar S)\cup O\big),$$

with $I(S)$ the indices of the tensors in $S$ and $\bar S$ the other tensors. An index shared by three tensors stays in
$K(S)$ as long as one tensor that has it is outside $S$: it is a batch index of the steps before, and is summed in the
step that brings in the last tensor that has it. The exact search (`"Optimal"`) finds the least total cost by dynamic
programming over the subsets,

$$C(S)=\min_{S_1\cup S_2=S}\Big[C(S_1)+C(S_2)+\prod_{l\in K(S_1)\cup K(S_2)}d_l\Big],$$

over the disjoint $S_1$, $S_2$, with $C=0$ for a single tensor and $d_l$ the dimension of the index $l$: $3^n$ terms for
$n$ tensors. The greedy search, as in opt_einsum, contracts at each step the pair that shares an index and whose result
is smallest compared to the two tensors, the flops breaking ties, and takes an outer product only when no pair shares an
index. `Automatic` is the exact search up to eight tensors and the greedy one beyond; `"Optimal"` is accepted up to
fourteen.

## Lowering

Each step of the order becomes a call to one kernel. The indices of its two tensors are sorted: an index of one tensor
only, not needed later, is summed first; an index of both tensors is a batch index if it is still needed, and summed
otherwise; the others are free. Then

- if one tensor is a scalar: a multiplication (`Scale`);
- if nothing is summed and the indices of one tensor are among those of the other: a product element by element,
  broadcast, with no transpose (`Hadamard`, `Prefix`, `Suffix`);
- if both tensors have the same indices, some summed and some kept: the product in the layout of one tensor and
  `Total` over the summed levels, used when the batched product would have to transpose (`Reduce`);
- with no batch index: the product of two matrices, (free × summed) and (summed × free), by BLAS (`Dot`);
- with batch indices: a batch of matrix products, `MapThread[Dot, ...]` or products of whole arrays and `Total`, chosen
  by a cost model (`Batch`; the option `"BatchMethod"`).

For the last two, the order of the two tensors, of the batch indices and of the summed indices (eight choices) is the
one that transposes the least data, with the transpose of the result in the last step; then each tensor needs at most
one `Transpose` and one `ArrayReshape`. The kernel of each step is in the plan:

```mathematica
kernels[spec_, dims_] := spec <> ": " <> StringRiffle[#["Type"] & /@ EinsumFunction[spec, dims]["Plan"]["Steps"], ", "];
Column[{kernels["ij,jk->ik", {{3, 4}, {4, 5}}], kernels["bij,bjk->bik", {{9, 4, 4}, {9, 4, 4}}],
  kernels["ij,j->ij", {{3, 4}, {4}}], kernels["kh,kh->h", {{5, 4}, {5, 4}}], kernels["ai,bi,ci->abc", {{40, 8}, {40, 8}, {40, 8}}]}]
```

```text
ij,jk->ik: Dot
bij,bjk->bik: Batch
ij,j->ij: Suffix
kh,kh->h: Reduce
ai,bi,ci->abc: Batch, Dot
```

## Execution and the cache

The tensors are packed when they can be, and preprocessed; the steps run in order, and each intermediate tensor is
dropped as soon as it has been used; a last `Transpose`, if needed, puts the result in the order asked. The plan is kept
under the einsum, the shapes and the options `"Path"` and `"BatchMethod"`, so that the next call with the same shapes
only computes; the cache keeps up to 2000 plans, starts again when full, and `EinsumClearCache[]` empties it. An
`EinsumFunction` keeps its own plan.

## How it is checked

The tests (`wolfram -script Tests/RunTests.wls`, 735 of them) compare `Einsum` with `numpy.einsum` on 213 contractions
computed in exact integer arithmetic, each with every order and every kernel, and with an explicit sum in machine
precision, real and complex; on 40 networks the exact search must cost as little as an exhaustive search over all
orders, and the greedy one no less.