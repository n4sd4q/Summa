An einsum names the indices of every tensor, as on paper. Summa reads the strings of `numpy.einsum`, with the same
rules, and a list syntax whose labels can be of any kind. Every block on this page runs after

```mathematica
Needs["Summa`"]
```

## Indices as on paper

`Einsum["ij,jk->ik", a, b]` is the product $C_{ik}=\sum_j A_{ij}B_{jk}$: the indices of each tensor, separated by
commas, then `->` and the indices of the result. An index that does not reach the result is summed:

```mathematica
m = {{a, b}, {c, d}};
Einsum["ij,jk->ik", m, m]
```

```math
\left(
\begin{array}{cc}
 a^2+b c & a b+b d \\
 a c+c d & b c+d^2 \\
\end{array}
\right)
```

The same letter is the same index in every tensor, and its dimension must be the same. Nothing after the arrow is a
scalar result, a sum over every index:

```mathematica
Einsum["ij->", m]
```

$$a+b+c+d$$

## The implicit output

Without the arrow, the result has the indices that appear exactly once, in alphabetical order, as in numpy (by
character code: capitals before small letters). So `"ij,jk"` is the product and `"ii"` the trace:

```mathematica
{Einsum["ij,jk", m, m] == Einsum["ij,jk->ik", m, m], Einsum["ii", m]}
```

```text
{True, a + d}
```

and `"ba"`, whose result is `"ab"`, is a transpose:

```mathematica
Einsum["ba", m]
```

```math
\left(
\begin{array}{cc}
 a & c \\
 b & d \\
\end{array}
\right)
```

## Transposes

The result can take its indices in any order, at any rank, without working out the permutation that `Transpose` needs:

```mathematica
t = RandomReal[1, {2, 3, 4}];
{Dimensions[Einsum["ijk->kij", t]], Einsum["ijk->kij", t] == Transpose[t, {2, 3, 1}]}
```

```text
{{4, 2, 3}, True}
```

## Ellipsis and broadcasting

`...` stands for any number of indices, the same in every tensor that has it, and broadcast as in numpy: here a stack of
five matrices times one matrix.

```mathematica
stack = RandomReal[1, {5, 3, 3}]; one = RandomReal[1, {3, 3}];
Einsum["...ij,...jk->...ik", stack, one] == (# . one & /@ stack)
```

```text
True
```

The indices of the ellipsis are aligned from the right, and an axis of size 1 is stretched to the size of the others:

```mathematica
Dimensions[Einsum["...ij,...jk->...ik", RandomReal[1, {5, 1, 3, 3}], RandomReal[1, {4, 3, 3}]]]
```

```text
{5, 4, 3, 3}
```

The ellipsis can stand anywhere in a subscript: `"...ii->...i"` takes the diagonals of a stack of matrices,
`"ij...->ji..."` swaps the first two indices. `…` (`\[Ellipsis]`) is the same as `...`. When the tensors have indices
under an ellipsis, an explicit result must have `...` too (`Einsum::ellout`); the implicit result puts them first.

## Axes of size 1

Without an ellipsis, an axis of size 1 is broadcast too, against the same index of another tensor: a row multiplies
every row of a matrix.

```mathematica
Einsum["ij,ij->ij", {{x, y}}, m]
```

```math
\left(
\begin{array}{cc}
 a x & b y \\
 c x & d y \\
\end{array}
\right)
```

## Scalars

An empty subscript is a scalar. Anything that is not a list or a `SparseArray` is a scalar, also `a + b` or `Sqrt[2]`:

```mathematica
Einsum[",i,i->", a + b, {1, 2}, {3, 4}]
```

$$11 (a+b)$$

## Unicode and the arrow

Any character is an index but `,`, `.`, `-` and `>`, and spaces are ignored. The arrow can be typed `→`
(`\[RightArrow]`; `\[Rule]` and `\[LongRightArrow]` work too):

```mathematica
Einsum["αβ, βγ → αγ", m, m] == m . m
```

```text
True
```

## Labels of any kind

`Einsum[{labels1, labels2, ...} -> labels, t1, t2, ...]` gives the indices of each tensor as a list. A label can be any
expression but a list: a string, a number, a symbol, `p[1]`.

```mathematica
Einsum[{{"left", "bond"}, {"bond", "right"}} -> {"right", "left"}, m, m]
```

```math
\left(
\begin{array}{cc}
 a^2+b c & a c+c d \\
 a b+b d & b c+d^2 \\
\end{array}
\right)
```

Labels made by code serve networks with more indices than letters. A chain of four matrices, with the integers as
indices:

```mathematica
chain = Table[{i, i + 1}, {i, 4}] -> {1, 5};
Expand[Einsum[chain, m, m, m, m]] == Expand[MatrixPower[m, 4]]
```

```text
True
```

Without the rule, the result has the labels that appear once, in the order of `Sort`; `"..."` in a list is the ellipsis.
Labels are evaluated before they are compared, so a symbol with a value stands for its value: in code, strings and
numbers are the safe labels.