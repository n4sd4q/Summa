(* ::Package:: *)

(* ::Title:: *)
(*Summa*)

(* ::Subtitle:: *)
(*A guided tour: from a trace to tensor networks*)

(* ::Section:: *)
(*0. Welcome*)

(* ::Text:: *)
(*Summa contracts tensors with the syntax of numpy.einsum: you write the indices of a product as on paper, and Summa finds the cheapest order of the contractions and runs each one on fast kernels. This tour starts from a trace and builds up, one piece at a time: the syntax, indices shared by any number of tensors, the drawing of the network, the order of the contractions and its cost, speed, and a tensor network checked by hand.*)

(* ::Text:: *)
(*How to use this notebook: evaluate the cells in order (Shift+Enter, or Evaluation > Evaluate Notebook); the whole tour takes a few seconds. The comment under each input says what you should get. The same file runs as a script: wolfram -script Examples.wl.*)

(* ::Subsection:: *)
(*Loading the package*)

(* the paclet next to this file (the repository), otherwise the installed one *)
With[{folder = Quiet[If[$InputFileName =!= "", DirectoryName[$InputFileName], NotebookDirectory[]]]},
  If[StringQ[folder],
   Scan[If[FileExistsQ[FileNameJoin[{#, "PacletInfo.wl"}]], PacletDirectoryLoad[#]] &, {FileNameJoin[{folder, "Summa"}], folder}]]];
Needs["Summa`"];

$SummaVersion
(* the version of the package, e.g. "1.0.0" *)

(* ::Section:: *)
(*1. Indices as on paper*)

(* ::Text:: *)
(*An einsum names the indices of every tensor, separated by commas, and after the arrow those of the result; an index that does not reach the result is summed. The matrix product, the trace, the diagonal and the transpose:*)

m = {{a, b}, {c, d}};
Einsum["ij,jk->ik", m, m]
(* {{a^2 + b c, a b + b d}, {a c + c d, b c + d^2}}: the same as m . m *)

{Einsum["ii->", m], Einsum["ii->i", m], Einsum["ij->ji", m]}
(* {a + d, {a, d}, {{a, c}, {b, d}}}: the trace, the diagonal, the transpose *)

(* ::Text:: *)
(*Without an arrow, the result has the indices that appear once, in alphabetical order (as in numpy): "ij,jk" is the product, "ba" a transpose.*)

{Einsum["ij,jk", m, m] == m . m, Einsum["ba", m] == Transpose[m]}
(* {True, True} *)

(* ::Section:: *)
(*2. Batches and broadcasting*)

(* ::Text:: *)
(*An ellipsis stands for any number of leading indices, shared and broadcast as in numpy: a batch of products in one call.*)

SeedRandom[1]; batch = RandomReal[1, {5, 3, 3}];
Einsum["...ij,...jk->...ik", batch, batch] == (#.# & /@ batch)
(* True: five products of 3 x 3 matrices *)

(* ::Text:: *)
(*Indices can be any characters, Unicode included, and the list syntax takes labels of any kind:*)

{Einsum["\[Alpha]\[Beta],\[Beta]\[Gamma]->\[Alpha]\[Gamma]", m, m] == m . m, Einsum[{{"left", "bond"}, {"bond", "right"}} -> {"left", "right"}, m, m] == m . m}
(* {True, True} *)

(* ::Section:: *)
(*3. An index in any number of tensors*)

(* ::Text:: *)
(*In numpy and in Summa an index may appear in any number of tensors: here i is shared by three vectors.*)

Einsum["i,i,i->", {a, b}, {c, d}, {e, f}]
(* a c e + b d f *)

(* ::Text:: *)
(*The canonical (CP) decomposition of a tensor of order three is rebuilt by one einsum, in which i joins three matrices: a hyperedge.*)

SeedRandom[2]; {u, v, w} = RandomReal[1, {3, 4, 2}];
Einsum["ai,bi,ci->abc", u, v, w] == Table[Sum[u[[p, i]] v[[q, i]] w[[r, i]], {i, 2}], {p, 4}, {q, 4}, {r, 4}]
(* True *)

(* ::Text:: *)
(*A repeated index inside one tensor takes its diagonal, in any number of its levels:*)

t = Array[x, {2, 2, 2}];
Einsum["iii->i", t]
(* {x[1, 1, 1], x[2, 2, 2]} *)

(* ::Section:: *)
(*4. The network, drawn*)

(* ::Text:: *)
(*EinsumDiagram draws the tensor network of an einsum: the tensors are nodes, the contracted indices bonds, the indices of the result open legs, and an index shared by three or more tensors a hyperedge (a dot).*)

EinsumDiagram["ai,bi,ci->abc"]
(* three tensors with an open leg each, joined by the hyperedge i *)

(* ::Text:: *)
(*The norm of a matrix-product state of four sites: the state in the top row, its conjugate in the bottom one.*)

mps = "pa,aqb,brc,cs,pA,AqB,BrC,Cs->";
EinsumDiagram[mps]
(* two rows of four tensors: the bonds a, b, c and A, B, C along the rows, the physical indices p, q, r, s between them *)

(* ::Section:: *)
(*5. The order of the contractions*)

(* ::Text:: *)
(*An einsum of many tensors is done one pair at a time, and the order decides the cost. EinsumPath gives the order that Summa chooses, from the shapes alone, with its cost in flops, the cost of the naive sum and the speed-up:*)

dims = {{2, 32}, {32, 2, 32}, {32, 2, 32}, {32, 2}, {2, 32}, {32, 2, 32}, {32, 2, 32}, {32, 2}};
path = EinsumPath[mps, dims];
Lookup[path, {"Flops", "NaiveFlops", "Speedup"}]
(* {17424., 1.20259*10^11, 6.90192*10^6}: the naive sum is seven million times slower *)

path["Contractions"]
(* the pairwise steps, as einsums: each half of the network closed site by site, then the two halves joined *)

(* ::Text:: *)
(*EinsumTree draws the same order, with the cost of every step:*)

EinsumTree[mps, dims]
(* a tree with 4096 flops for the first steps and a scalar at the root *)

(* ::Text:: *)
(*The order can be chosen: "Optimal" (an exact search, up to eight tensors by default), "Greedy", "Sequential" (left to right), or a list of pairs.*)

Lookup[EinsumPath[mps, dims, "Path" -> #], "Flops"] & /@ {"Optimal", "Greedy", "Sequential"}
(* {17424., 17424., 25664.}: here the greedy order is optimal, and left to right costs half as much again *)

(* ::Section:: *)
(*6. Fast kernels*)

(* ::Text:: *)
(*Each pairwise step runs on BLAS Dot, on a batched kernel or on broadcasting, after as few transposes as possible. The reconstruction of a 40 x 40 x 40 tensor from its CP decomposition, against the same sum written out:*)

SeedRandom[3]; {u, v, w} = RandomReal[1, {3, 40, 8}];
{First[RepeatedTiming[Einsum["ai,bi,ci->abc", u, v, w]]], First[AbsoluteTiming[Table[Sum[u[[p, i]] v[[q, i]] w[[r, i]], {i, 8}], {p, 40}, {q, 40}, {r, 40}]]]}
(* the times in seconds: Einsum one or two orders of magnitude faster than the explicit sum *)

(* ::Text:: *)
(*A second call with the same shapes reuses the plan from a cache; EinsumFunction plans once for fixed shapes, for loops.*)

SeedRandom[4]; {x1, x2} = RandomReal[1, {2, 1000, 4, 4}];
product = EinsumFunction["bij,bjk->bik", {{1000, 4, 4}, {1000, 4, 4}}];
{product[x1, x2] == MapThread[Dot, {x1, x2}], product["Flops"]}
(* {True, 64000.} *)

(* ::Section:: *)
(*7. Exact, symbolic, complex and sparse entries*)

(* ::Text:: *)
(*The entries can be anything: exact numbers and symbols give exact results, complex numbers complex ones, and a SparseArray stays sparse in the steps that are products of matrices.*)

Einsum["ij,ij->", {{1, 2}, {3, 4}}, {{1/2, I}, {x, Sqrt[2]}}]
(* 1/2 + 2 I + 3 x + 4 Sqrt[2] *)

s = SparseArray[{{1, 1} -> 1., {1000, 1000} -> 2.}, {1000, 1000}];
Einsum["ij,jk->ik", s, s] == s . s
(* True *)

(* ::Section:: *)
(*8. A tensor network, checked by hand*)

(* ::Text:: *)
(*The norm of a random matrix-product state of four sites, by Einsum, against the same contraction written out with TensorContract and Dot, one step at a time.*)

SeedRandom[5];
{t1, t2, t3, t4} = {RandomReal[1, {2, 8}], RandomReal[1, {8, 2, 8}], RandomReal[1, {8, 2, 8}], RandomReal[1, {8, 2}]};
norm = Einsum[mps, t1, t2, t3, t4, t1, t2, t3, t4];
state = Flatten[TensorContract[TensorProduct[TensorContract[TensorProduct[TensorContract[TensorProduct[t1, t2], {{2, 3}}], t3], {{3, 4}}], t4], {{4, 5}}]];
Abs[norm - state . state] < 10^-9 norm
(* True: Einsum gives the squared norm of the state *)

(* ::Section:: *)
(*Where next*)

(* ::Text:: *)
(*The wiki (github.com/n4sd4q/Summa/wiki) has the recipes: the syntax, repeated indices, orders and costs, speed, the diagrams. The showcase shows what the package can do, and the manual describes every function; ?Summa`* lists the functions and ?Name explains each one.*)
