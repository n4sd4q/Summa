(* ::Package:: *)
(* Test suite for the Summa` package.  Run with:   TestReport["/path/to/Summa/Tests/SummaTests.wlt"]
   Expected values of the data-driven tests were computed with numpy.einsum (exact integer arithmetic). *)

testDir = DirectoryName[$TestFileName]; root = ParentDirectory[testDir];
PacletDirectoryLoad[FileNameJoin[{root, "Summa"}]];   (* the paclet of this repository, not an installed one *)
Needs["Summa`"];

(* brute-force reference: explicit sum over all index assignments (string specs, no ellipsis) *)
refEinsum[spec_String, ts___] := Module[{tensors = {ts}, str, pos, lhs, rhs, cpos, terms, all, out, labs, dimOf, sumLabs, sumTuples, elem},
  str = StringReplace[spec, " " -> ""];
  pos = StringPosition[str, "->"];
  lhs = If[pos === {}, str, StringTake[str, pos[[1, 1]] - 1]];
  rhs = If[pos === {}, Automatic, StringDrop[str, pos[[1, 2]]]];
  cpos = Join[{0}, First /@ StringPosition[lhs, ","], {StringLength[lhs] + 1}];
  terms = Table[Characters[StringTake[lhs, {cpos[[k]] + 1, cpos[[k + 1]] - 1}]], {k, Length[cpos] - 1}];
  all = Join @@ terms;
  out = If[rhs === Automatic, SortBy[Select[DeleteDuplicates[all], Count[all, #] == 1 &], ToCharacterCode], Characters[rhs]];
  labs = DeleteDuplicates[all];
  dimOf[l_] := dimOf[l] = First[Flatten[Table[If[terms[[t, j]] === l, Dimensions[tensors[[t]]][[j]], {}], {t, Length[terms]}, {j, Length[terms[[t]]]}]]];
  sumLabs = Complement[labs, out];
  sumTuples = Tuples[Range /@ (dimOf /@ sumLabs)];
  elem[o_List] := Total[(Function[s, Module[{val},
      Do[val[out[[q]]] = o[[q]], {q, Length[out]}]; Do[val[sumLabs[[q]]] = s[[q]], {q, Length[sumLabs]}];
      Times @@ Table[If[terms[[t]] === {}, tensors[[t]], Extract[tensors[[t]], val /@ terms[[t]]]], {t, Length[terms]}]]]) /@ sumTuples];
  If[out === {}, elem[{}], Array[elem[{##}] &, dimOf /@ out]]
];
maxDiff[a_, b_] := Max[Abs[Flatten[{N[Normal[a] - Normal[b]]}]]];

(* ::Section:: *)
(* 1. Data-driven tests: hand-picked cases covering every kernel, then random cases *)

VerificationTest[Einsum["ij,jk->ik", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,2},{-1,0},{1,0},{-2,-2}}], {{-3,-4},{2,-8},{4,-2}}, TestID -> "case-1"]
VerificationTest[Einsum["ij,jk->ik", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,2},{-1,0},{1,0},{-2,-2}}, "Path" -> "Greedy"], {{-3,-4},{2,-8},{4,-2}}, TestID -> "case-1-cfg1"]
VerificationTest[Einsum["ij,jk->ik", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,2},{-1,0},{1,0},{-2,-2}}, "Path" -> "Sequential"], {{-3,-4},{2,-8},{4,-2}}, TestID -> "case-1-cfg2"]
VerificationTest[Einsum["ij,jk->ik", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,2},{-1,0},{1,0},{-2,-2}}, "BatchMethod" -> "Dot"], {{-3,-4},{2,-8},{4,-2}}, TestID -> "case-1-cfg3"]
VerificationTest[Einsum["ij,jk->ik", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,2},{-1,0},{1,0},{-2,-2}}, "BatchMethod" -> "Vectorized"], {{-3,-4},{2,-8},{4,-2}}, TestID -> "case-1-cfg4"]
VerificationTest[Einsum["ij,kj->ik", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{0,1,-2,-1},{-2,0,2,-2},{-1,0,2,-1},{0,-1,-2,1},{-2,-1,0,0}}], {{-4,-2,0,0,0},{-8,4,4,0,6},{-5,6,5,-3,3}}, TestID -> "case-2"]
VerificationTest[Einsum["ij,kj->ik", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{0,1,-2,-1},{-2,0,2,-2},{-1,0,2,-1},{0,-1,-2,1},{-2,-1,0,0}}, "Path" -> "Greedy"], {{-4,-2,0,0,0},{-8,4,4,0,6},{-5,6,5,-3,3}}, TestID -> "case-2-cfg1"]
VerificationTest[Einsum["ij,kj->ik", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{0,1,-2,-1},{-2,0,2,-2},{-1,0,2,-1},{0,-1,-2,1},{-2,-1,0,0}}, "Path" -> "Sequential"], {{-4,-2,0,0,0},{-8,4,4,0,6},{-5,6,5,-3,3}}, TestID -> "case-2-cfg2"]
VerificationTest[Einsum["ij,kj->ik", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{0,1,-2,-1},{-2,0,2,-2},{-1,0,2,-1},{0,-1,-2,1},{-2,-1,0,0}}, "BatchMethod" -> "Dot"], {{-4,-2,0,0,0},{-8,4,4,0,6},{-5,6,5,-3,3}}, TestID -> "case-2-cfg3"]
VerificationTest[Einsum["ij,kj->ik", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{0,1,-2,-1},{-2,0,2,-2},{-1,0,2,-1},{0,-1,-2,1},{-2,-1,0,0}}, "BatchMethod" -> "Vectorized"], {{-4,-2,0,0,0},{-8,4,4,0,6},{-5,6,5,-3,3}}, TestID -> "case-2-cfg4"]
VerificationTest[Einsum["ji,jk->ik", {{-2,2,1},{2,-2,1},{-1,0,2},{-1,1,-2}}, {{-1,2},{-1,0},{1,0},{-2,-2}}], {{1,-2},{-2,2},{4,6}}, TestID -> "case-3"]
VerificationTest[Einsum["ji,jk->ik", {{-2,2,1},{2,-2,1},{-1,0,2},{-1,1,-2}}, {{-1,2},{-1,0},{1,0},{-2,-2}}, "Path" -> "Greedy"], {{1,-2},{-2,2},{4,6}}, TestID -> "case-3-cfg1"]
VerificationTest[Einsum["ji,jk->ik", {{-2,2,1},{2,-2,1},{-1,0,2},{-1,1,-2}}, {{-1,2},{-1,0},{1,0},{-2,-2}}, "Path" -> "Sequential"], {{1,-2},{-2,2},{4,6}}, TestID -> "case-3-cfg2"]
VerificationTest[Einsum["ji,jk->ik", {{-2,2,1},{2,-2,1},{-1,0,2},{-1,1,-2}}, {{-1,2},{-1,0},{1,0},{-2,-2}}, "BatchMethod" -> "Dot"], {{1,-2},{-2,2},{4,6}}, TestID -> "case-3-cfg3"]
VerificationTest[Einsum["ji,jk->ik", {{-2,2,1},{2,-2,1},{-1,0,2},{-1,1,-2}}, {{-1,2},{-1,0},{1,0},{-2,-2}}, "BatchMethod" -> "Vectorized"], {{1,-2},{-2,2},{4,6}}, TestID -> "case-3-cfg4"]
VerificationTest[Einsum["ij,jk,ki->", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,2},{-1,0},{1,0},{-2,-2}}, {{2,1,2},{0,2,-1}}], -10, TestID -> "case-4"]
VerificationTest[Einsum["ij,jk,ki->", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,2},{-1,0},{1,0},{-2,-2}}, {{2,1,2},{0,2,-1}}, "Path" -> "Greedy"], -10, TestID -> "case-4-cfg1"]
VerificationTest[Einsum["ij,jk,ki->", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,2},{-1,0},{1,0},{-2,-2}}, {{2,1,2},{0,2,-1}}, "Path" -> "Sequential"], -10, TestID -> "case-4-cfg2"]
VerificationTest[Einsum["ij,jk,ki->", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,2},{-1,0},{1,0},{-2,-2}}, {{2,1,2},{0,2,-1}}, "BatchMethod" -> "Dot"], -10, TestID -> "case-4-cfg3"]
VerificationTest[Einsum["ij,jk,ki->", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,2},{-1,0},{1,0},{-2,-2}}, {{2,1,2},{0,2,-1}}, "BatchMethod" -> "Vectorized"], -10, TestID -> "case-4-cfg4"]
VerificationTest[Einsum["ij,jk,kl->il", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,2},{-1,0},{1,0},{-2,-2}}, {{-1,2,0,0,-1},{-2,0,1,0,1}}], {{11,-6,-4,0,-1},{14,4,-8,0,-10},{0,8,-2,0,-6}}, TestID -> "case-5"]
VerificationTest[Einsum["ij,jk,kl->il", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,2},{-1,0},{1,0},{-2,-2}}, {{-1,2,0,0,-1},{-2,0,1,0,1}}, "Path" -> "Greedy"], {{11,-6,-4,0,-1},{14,4,-8,0,-10},{0,8,-2,0,-6}}, TestID -> "case-5-cfg1"]
VerificationTest[Einsum["ij,jk,kl->il", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,2},{-1,0},{1,0},{-2,-2}}, {{-1,2,0,0,-1},{-2,0,1,0,1}}, "Path" -> "Sequential"], {{11,-6,-4,0,-1},{14,4,-8,0,-10},{0,8,-2,0,-6}}, TestID -> "case-5-cfg2"]
VerificationTest[Einsum["ij,jk,kl->il", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,2},{-1,0},{1,0},{-2,-2}}, {{-1,2,0,0,-1},{-2,0,1,0,1}}, "BatchMethod" -> "Dot"], {{11,-6,-4,0,-1},{14,4,-8,0,-10},{0,8,-2,0,-6}}, TestID -> "case-5-cfg3"]
VerificationTest[Einsum["ij,jk,kl->il", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,2},{-1,0},{1,0},{-2,-2}}, {{-1,2,0,0,-1},{-2,0,1,0,1}}, "BatchMethod" -> "Vectorized"], {{11,-6,-4,0,-1},{14,4,-8,0,-10},{0,8,-2,0,-6}}, TestID -> "case-5-cfg4"]
VerificationTest[Einsum["bij,bjk->bik", {{{-1,1,1},{2,0,-2}},{{1,0,2},{0,-1,-2}},{{0,1,1},{2,-1,0}},{{2,-1,-1},{2,0,0}},{{1,0,2},{1,-2,-2}}}, {{{0,2,-2,1},{1,1,2,-2},{0,2,-1,-2}},{{0,-2,-1,2},{1,2,2,2},{-1,0,1,-1}},{{2,-2,2,1},{-1,1,0,2},{2,-1,0,-1}},{{1,1,2,2},{2,2,2,-2},{-2,0,-1,2}},{{1,0,0,0},{2,-2,0,1},{0,2,2,2}}}], {{{1,1,3,-5},{0,0,-2,6}},{{-2,-2,1,0},{1,-2,-4,0}},{{1,0,0,1},{5,-5,4,0}},{{2,0,3,4},{2,2,4,4}},{{1,4,4,4},{-3,0,-4,-6}}}, TestID -> "case-6"]
VerificationTest[Einsum["bij,bjk->bik", {{{-1,1,1},{2,0,-2}},{{1,0,2},{0,-1,-2}},{{0,1,1},{2,-1,0}},{{2,-1,-1},{2,0,0}},{{1,0,2},{1,-2,-2}}}, {{{0,2,-2,1},{1,1,2,-2},{0,2,-1,-2}},{{0,-2,-1,2},{1,2,2,2},{-1,0,1,-1}},{{2,-2,2,1},{-1,1,0,2},{2,-1,0,-1}},{{1,1,2,2},{2,2,2,-2},{-2,0,-1,2}},{{1,0,0,0},{2,-2,0,1},{0,2,2,2}}}, "Path" -> "Greedy"], {{{1,1,3,-5},{0,0,-2,6}},{{-2,-2,1,0},{1,-2,-4,0}},{{1,0,0,1},{5,-5,4,0}},{{2,0,3,4},{2,2,4,4}},{{1,4,4,4},{-3,0,-4,-6}}}, TestID -> "case-6-cfg1"]
VerificationTest[Einsum["bij,bjk->bik", {{{-1,1,1},{2,0,-2}},{{1,0,2},{0,-1,-2}},{{0,1,1},{2,-1,0}},{{2,-1,-1},{2,0,0}},{{1,0,2},{1,-2,-2}}}, {{{0,2,-2,1},{1,1,2,-2},{0,2,-1,-2}},{{0,-2,-1,2},{1,2,2,2},{-1,0,1,-1}},{{2,-2,2,1},{-1,1,0,2},{2,-1,0,-1}},{{1,1,2,2},{2,2,2,-2},{-2,0,-1,2}},{{1,0,0,0},{2,-2,0,1},{0,2,2,2}}}, "Path" -> "Sequential"], {{{1,1,3,-5},{0,0,-2,6}},{{-2,-2,1,0},{1,-2,-4,0}},{{1,0,0,1},{5,-5,4,0}},{{2,0,3,4},{2,2,4,4}},{{1,4,4,4},{-3,0,-4,-6}}}, TestID -> "case-6-cfg2"]
VerificationTest[Einsum["bij,bjk->bik", {{{-1,1,1},{2,0,-2}},{{1,0,2},{0,-1,-2}},{{0,1,1},{2,-1,0}},{{2,-1,-1},{2,0,0}},{{1,0,2},{1,-2,-2}}}, {{{0,2,-2,1},{1,1,2,-2},{0,2,-1,-2}},{{0,-2,-1,2},{1,2,2,2},{-1,0,1,-1}},{{2,-2,2,1},{-1,1,0,2},{2,-1,0,-1}},{{1,1,2,2},{2,2,2,-2},{-2,0,-1,2}},{{1,0,0,0},{2,-2,0,1},{0,2,2,2}}}, "BatchMethod" -> "Dot"], {{{1,1,3,-5},{0,0,-2,6}},{{-2,-2,1,0},{1,-2,-4,0}},{{1,0,0,1},{5,-5,4,0}},{{2,0,3,4},{2,2,4,4}},{{1,4,4,4},{-3,0,-4,-6}}}, TestID -> "case-6-cfg3"]
VerificationTest[Einsum["bij,bjk->bik", {{{-1,1,1},{2,0,-2}},{{1,0,2},{0,-1,-2}},{{0,1,1},{2,-1,0}},{{2,-1,-1},{2,0,0}},{{1,0,2},{1,-2,-2}}}, {{{0,2,-2,1},{1,1,2,-2},{0,2,-1,-2}},{{0,-2,-1,2},{1,2,2,2},{-1,0,1,-1}},{{2,-2,2,1},{-1,1,0,2},{2,-1,0,-1}},{{1,1,2,2},{2,2,2,-2},{-2,0,-1,2}},{{1,0,0,0},{2,-2,0,1},{0,2,2,2}}}, "BatchMethod" -> "Vectorized"], {{{1,1,3,-5},{0,0,-2,6}},{{-2,-2,1,0},{1,-2,-4,0}},{{1,0,0,1},{5,-5,4,0}},{{2,0,3,4},{2,2,4,4}},{{1,4,4,4},{-3,0,-4,-6}}}, TestID -> "case-6-cfg4"]
VerificationTest[Einsum["bij,bjk->bki", {{{0,2,-2},{1,-1,-1}},{{1,1,2},{-1,2,2}},{{-1,-2,1},{2,0,-2}},{{-2,-1,1},{-1,-2,1}},{{1,-2,0},{-1,0,-2}}}, {{{1,-1,0,0},{1,-2,-1,1},{1,-1,-2,1}},{{0,1,-2,0},{2,2,-1,1},{-2,2,-1,-1}},{{2,0,2,-2},{1,2,-2,-1},{-2,-1,-1,-2}},{{2,-1,2,1},{-2,1,1,-2},{-2,-1,-2,0}},{{0,1,0,0},{-1,0,0,2},{1,1,0,-1}}}], {{{0,-1},{-2,2},{2,3},{0,-2}},{{-2,0},{7,7},{-5,-2},{-1,0}},{{-6,8},{-5,2},{1,6},{2,0}},{{-4,0},{0,-2},{-7,-6},{0,3}},{{2,-2},{1,-3},{0,0},{-4,2}}}, TestID -> "case-7"]
VerificationTest[Einsum["bij,bjk->bki", {{{0,2,-2},{1,-1,-1}},{{1,1,2},{-1,2,2}},{{-1,-2,1},{2,0,-2}},{{-2,-1,1},{-1,-2,1}},{{1,-2,0},{-1,0,-2}}}, {{{1,-1,0,0},{1,-2,-1,1},{1,-1,-2,1}},{{0,1,-2,0},{2,2,-1,1},{-2,2,-1,-1}},{{2,0,2,-2},{1,2,-2,-1},{-2,-1,-1,-2}},{{2,-1,2,1},{-2,1,1,-2},{-2,-1,-2,0}},{{0,1,0,0},{-1,0,0,2},{1,1,0,-1}}}, "Path" -> "Greedy"], {{{0,-1},{-2,2},{2,3},{0,-2}},{{-2,0},{7,7},{-5,-2},{-1,0}},{{-6,8},{-5,2},{1,6},{2,0}},{{-4,0},{0,-2},{-7,-6},{0,3}},{{2,-2},{1,-3},{0,0},{-4,2}}}, TestID -> "case-7-cfg1"]
VerificationTest[Einsum["bij,bjk->bki", {{{0,2,-2},{1,-1,-1}},{{1,1,2},{-1,2,2}},{{-1,-2,1},{2,0,-2}},{{-2,-1,1},{-1,-2,1}},{{1,-2,0},{-1,0,-2}}}, {{{1,-1,0,0},{1,-2,-1,1},{1,-1,-2,1}},{{0,1,-2,0},{2,2,-1,1},{-2,2,-1,-1}},{{2,0,2,-2},{1,2,-2,-1},{-2,-1,-1,-2}},{{2,-1,2,1},{-2,1,1,-2},{-2,-1,-2,0}},{{0,1,0,0},{-1,0,0,2},{1,1,0,-1}}}, "Path" -> "Sequential"], {{{0,-1},{-2,2},{2,3},{0,-2}},{{-2,0},{7,7},{-5,-2},{-1,0}},{{-6,8},{-5,2},{1,6},{2,0}},{{-4,0},{0,-2},{-7,-6},{0,3}},{{2,-2},{1,-3},{0,0},{-4,2}}}, TestID -> "case-7-cfg2"]
VerificationTest[Einsum["bij,bjk->bki", {{{0,2,-2},{1,-1,-1}},{{1,1,2},{-1,2,2}},{{-1,-2,1},{2,0,-2}},{{-2,-1,1},{-1,-2,1}},{{1,-2,0},{-1,0,-2}}}, {{{1,-1,0,0},{1,-2,-1,1},{1,-1,-2,1}},{{0,1,-2,0},{2,2,-1,1},{-2,2,-1,-1}},{{2,0,2,-2},{1,2,-2,-1},{-2,-1,-1,-2}},{{2,-1,2,1},{-2,1,1,-2},{-2,-1,-2,0}},{{0,1,0,0},{-1,0,0,2},{1,1,0,-1}}}, "BatchMethod" -> "Dot"], {{{0,-1},{-2,2},{2,3},{0,-2}},{{-2,0},{7,7},{-5,-2},{-1,0}},{{-6,8},{-5,2},{1,6},{2,0}},{{-4,0},{0,-2},{-7,-6},{0,3}},{{2,-2},{1,-3},{0,0},{-4,2}}}, TestID -> "case-7-cfg3"]
VerificationTest[Einsum["bij,bjk->bki", {{{0,2,-2},{1,-1,-1}},{{1,1,2},{-1,2,2}},{{-1,-2,1},{2,0,-2}},{{-2,-1,1},{-1,-2,1}},{{1,-2,0},{-1,0,-2}}}, {{{1,-1,0,0},{1,-2,-1,1},{1,-1,-2,1}},{{0,1,-2,0},{2,2,-1,1},{-2,2,-1,-1}},{{2,0,2,-2},{1,2,-2,-1},{-2,-1,-1,-2}},{{2,-1,2,1},{-2,1,1,-2},{-2,-1,-2,0}},{{0,1,0,0},{-1,0,0,2},{1,1,0,-1}}}, "BatchMethod" -> "Vectorized"], {{{0,-1},{-2,2},{2,3},{0,-2}},{{-2,0},{7,7},{-5,-2},{-1,0}},{{-6,8},{-5,2},{1,6},{2,0}},{{-4,0},{0,-2},{-7,-6},{0,3}},{{2,-2},{1,-3},{0,0},{-4,2}}}, TestID -> "case-7-cfg4"]
VerificationTest[Einsum["bij,bj->bi", {{{-1,0},{0,-1},{-2,-2}},{{-2,-1},{0,-1},{-2,-1}},{{1,-1},{2,0},{-2,2}},{{2,1},{-2,1},{1,1}}}, {{1,0},{-1,2},{2,1},{-1,0}}], {{-1,0,-2},{0,-2,0},{1,4,-2},{-2,2,-1}}, TestID -> "case-8"]
VerificationTest[Einsum["bij,bj->bi", {{{-1,0},{0,-1},{-2,-2}},{{-2,-1},{0,-1},{-2,-1}},{{1,-1},{2,0},{-2,2}},{{2,1},{-2,1},{1,1}}}, {{1,0},{-1,2},{2,1},{-1,0}}, "Path" -> "Greedy"], {{-1,0,-2},{0,-2,0},{1,4,-2},{-2,2,-1}}, TestID -> "case-8-cfg1"]
VerificationTest[Einsum["bij,bj->bi", {{{-1,0},{0,-1},{-2,-2}},{{-2,-1},{0,-1},{-2,-1}},{{1,-1},{2,0},{-2,2}},{{2,1},{-2,1},{1,1}}}, {{1,0},{-1,2},{2,1},{-1,0}}, "Path" -> "Sequential"], {{-1,0,-2},{0,-2,0},{1,4,-2},{-2,2,-1}}, TestID -> "case-8-cfg2"]
VerificationTest[Einsum["bij,bj->bi", {{{-1,0},{0,-1},{-2,-2}},{{-2,-1},{0,-1},{-2,-1}},{{1,-1},{2,0},{-2,2}},{{2,1},{-2,1},{1,1}}}, {{1,0},{-1,2},{2,1},{-1,0}}, "BatchMethod" -> "Dot"], {{-1,0,-2},{0,-2,0},{1,4,-2},{-2,2,-1}}, TestID -> "case-8-cfg3"]
VerificationTest[Einsum["bij,bj->bi", {{{-1,0},{0,-1},{-2,-2}},{{-2,-1},{0,-1},{-2,-1}},{{1,-1},{2,0},{-2,2}},{{2,1},{-2,1},{1,1}}}, {{1,0},{-1,2},{2,1},{-1,0}}, "BatchMethod" -> "Vectorized"], {{-1,0,-2},{0,-2,0},{1,4,-2},{-2,2,-1}}, TestID -> "case-8-cfg4"]
VerificationTest[Einsum["bj,bjk->bk", {{0,-2},{-2,0},{0,-1},{-1,-2}}, {{{2,0,-1},{1,2,-1}},{{2,1,1},{0,2,-2}},{{-2,2,0},{0,1,-1}},{{1,2,2},{-2,2,1}}}], {{-2,-4,2},{-4,-2,-2},{0,-1,1},{3,-6,-4}}, TestID -> "case-9"]
VerificationTest[Einsum["bj,bjk->bk", {{0,-2},{-2,0},{0,-1},{-1,-2}}, {{{2,0,-1},{1,2,-1}},{{2,1,1},{0,2,-2}},{{-2,2,0},{0,1,-1}},{{1,2,2},{-2,2,1}}}, "Path" -> "Greedy"], {{-2,-4,2},{-4,-2,-2},{0,-1,1},{3,-6,-4}}, TestID -> "case-9-cfg1"]
VerificationTest[Einsum["bj,bjk->bk", {{0,-2},{-2,0},{0,-1},{-1,-2}}, {{{2,0,-1},{1,2,-1}},{{2,1,1},{0,2,-2}},{{-2,2,0},{0,1,-1}},{{1,2,2},{-2,2,1}}}, "Path" -> "Sequential"], {{-2,-4,2},{-4,-2,-2},{0,-1,1},{3,-6,-4}}, TestID -> "case-9-cfg2"]
VerificationTest[Einsum["bj,bjk->bk", {{0,-2},{-2,0},{0,-1},{-1,-2}}, {{{2,0,-1},{1,2,-1}},{{2,1,1},{0,2,-2}},{{-2,2,0},{0,1,-1}},{{1,2,2},{-2,2,1}}}, "BatchMethod" -> "Dot"], {{-2,-4,2},{-4,-2,-2},{0,-1,1},{3,-6,-4}}, TestID -> "case-9-cfg3"]
VerificationTest[Einsum["bj,bjk->bk", {{0,-2},{-2,0},{0,-1},{-1,-2}}, {{{2,0,-1},{1,2,-1}},{{2,1,1},{0,2,-2}},{{-2,2,0},{0,1,-1}},{{1,2,2},{-2,2,1}}}, "BatchMethod" -> "Vectorized"], {{-2,-4,2},{-4,-2,-2},{0,-1,1},{3,-6,-4}}, TestID -> "case-9-cfg4"]
VerificationTest[Einsum["bi,bk->bik", {{1,-2},{2,-1},{2,-1}}, {{-2,2,0,-1},{2,2,-2,1},{2,1,1,0}}], {{{-2,2,0,-1},{4,-4,0,2}},{{4,4,-4,2},{-2,-2,2,-1}},{{4,2,2,0},{-2,-1,-1,0}}}, TestID -> "case-10"]
VerificationTest[Einsum["bi,bk->bik", {{1,-2},{2,-1},{2,-1}}, {{-2,2,0,-1},{2,2,-2,1},{2,1,1,0}}, "Path" -> "Greedy"], {{{-2,2,0,-1},{4,-4,0,2}},{{4,4,-4,2},{-2,-2,2,-1}},{{4,2,2,0},{-2,-1,-1,0}}}, TestID -> "case-10-cfg1"]
VerificationTest[Einsum["bi,bk->bik", {{1,-2},{2,-1},{2,-1}}, {{-2,2,0,-1},{2,2,-2,1},{2,1,1,0}}, "Path" -> "Sequential"], {{{-2,2,0,-1},{4,-4,0,2}},{{4,4,-4,2},{-2,-2,2,-1}},{{4,2,2,0},{-2,-1,-1,0}}}, TestID -> "case-10-cfg2"]
VerificationTest[Einsum["bi,bk->bik", {{1,-2},{2,-1},{2,-1}}, {{-2,2,0,-1},{2,2,-2,1},{2,1,1,0}}, "BatchMethod" -> "Dot"], {{{-2,2,0,-1},{4,-4,0,2}},{{4,4,-4,2},{-2,-2,2,-1}},{{4,2,2,0},{-2,-1,-1,0}}}, TestID -> "case-10-cfg3"]
VerificationTest[Einsum["bi,bk->bik", {{1,-2},{2,-1},{2,-1}}, {{-2,2,0,-1},{2,2,-2,1},{2,1,1,0}}, "BatchMethod" -> "Vectorized"], {{{-2,2,0,-1},{4,-4,0,2}},{{4,4,-4,2},{-2,-2,2,-1}},{{4,2,2,0},{-2,-1,-1,0}}}, TestID -> "case-10-cfg4"]
VerificationTest[Einsum["bi,b->bi", {{0,-1},{-2,-1},{1,2}}, {2,-1,-2}], {{0,-2},{2,1},{-2,-4}}, TestID -> "case-11"]
VerificationTest[Einsum["bi,b->bi", {{0,-1},{-2,-1},{1,2}}, {2,-1,-2}, "Path" -> "Greedy"], {{0,-2},{2,1},{-2,-4}}, TestID -> "case-11-cfg1"]
VerificationTest[Einsum["bi,b->bi", {{0,-1},{-2,-1},{1,2}}, {2,-1,-2}, "Path" -> "Sequential"], {{0,-2},{2,1},{-2,-4}}, TestID -> "case-11-cfg2"]
VerificationTest[Einsum["bi,b->bi", {{0,-1},{-2,-1},{1,2}}, {2,-1,-2}, "BatchMethod" -> "Dot"], {{0,-2},{2,1},{-2,-4}}, TestID -> "case-11-cfg3"]
VerificationTest[Einsum["bi,b->bi", {{0,-1},{-2,-1},{1,2}}, {2,-1,-2}, "BatchMethod" -> "Vectorized"], {{0,-2},{2,1},{-2,-4}}, TestID -> "case-11-cfg4"]
VerificationTest[Einsum["ijk,ijk,ijk->", {{{2,1},{1,2},{-1,2}},{{1,1},{-1,-1},{-1,1}}}, {{{0,-2},{-2,-2},{0,0}},{{2,1},{-1,0},{1,2}}}, {{{0,1},{-1,0},{2,-1}},{{-2,1},{-1,0},{2,-1}}}], -8, TestID -> "case-12"]
VerificationTest[Einsum["ijk,ijk,ijk->", {{{2,1},{1,2},{-1,2}},{{1,1},{-1,-1},{-1,1}}}, {{{0,-2},{-2,-2},{0,0}},{{2,1},{-1,0},{1,2}}}, {{{0,1},{-1,0},{2,-1}},{{-2,1},{-1,0},{2,-1}}}, "Path" -> "Greedy"], -8, TestID -> "case-12-cfg1"]
VerificationTest[Einsum["ijk,ijk,ijk->", {{{2,1},{1,2},{-1,2}},{{1,1},{-1,-1},{-1,1}}}, {{{0,-2},{-2,-2},{0,0}},{{2,1},{-1,0},{1,2}}}, {{{0,1},{-1,0},{2,-1}},{{-2,1},{-1,0},{2,-1}}}, "Path" -> "Sequential"], -8, TestID -> "case-12-cfg2"]
VerificationTest[Einsum["ijk,ijk,ijk->", {{{2,1},{1,2},{-1,2}},{{1,1},{-1,-1},{-1,1}}}, {{{0,-2},{-2,-2},{0,0}},{{2,1},{-1,0},{1,2}}}, {{{0,1},{-1,0},{2,-1}},{{-2,1},{-1,0},{2,-1}}}, "BatchMethod" -> "Dot"], -8, TestID -> "case-12-cfg3"]
VerificationTest[Einsum["ijk,ijk,ijk->", {{{2,1},{1,2},{-1,2}},{{1,1},{-1,-1},{-1,1}}}, {{{0,-2},{-2,-2},{0,0}},{{2,1},{-1,0},{1,2}}}, {{{0,1},{-1,0},{2,-1}},{{-2,1},{-1,0},{2,-1}}}, "BatchMethod" -> "Vectorized"], -8, TestID -> "case-12-cfg4"]
VerificationTest[Einsum["ij,ij,ij->ij", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,-1,2,-1},{1,-1,2,1},{1,0,-1,2}}, {{1,-1,-2,-2},{0,0,-1,2},{0,1,-2,-1}}], {{0,0,-4,4},{0,0,-4,4},{0,0,4,0}}, TestID -> "case-13"]
VerificationTest[Einsum["ij,ij,ij->ij", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,-1,2,-1},{1,-1,2,1},{1,0,-1,2}}, {{1,-1,-2,-2},{0,0,-1,2},{0,1,-2,-1}}, "Path" -> "Greedy"], {{0,0,-4,4},{0,0,-4,4},{0,0,4,0}}, TestID -> "case-13-cfg1"]
VerificationTest[Einsum["ij,ij,ij->ij", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,-1,2,-1},{1,-1,2,1},{1,0,-1,2}}, {{1,-1,-2,-2},{0,0,-1,2},{0,1,-2,-1}}, "Path" -> "Sequential"], {{0,0,-4,4},{0,0,-4,4},{0,0,4,0}}, TestID -> "case-13-cfg2"]
VerificationTest[Einsum["ij,ij,ij->ij", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,-1,2,-1},{1,-1,2,1},{1,0,-1,2}}, {{1,-1,-2,-2},{0,0,-1,2},{0,1,-2,-1}}, "BatchMethod" -> "Dot"], {{0,0,-4,4},{0,0,-4,4},{0,0,4,0}}, TestID -> "case-13-cfg3"]
VerificationTest[Einsum["ij,ij,ij->ij", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,-1,2,-1},{1,-1,2,1},{1,0,-1,2}}, {{1,-1,-2,-2},{0,0,-1,2},{0,1,-2,-1}}, "BatchMethod" -> "Vectorized"], {{0,0,-4,4},{0,0,-4,4},{0,0,4,0}}, TestID -> "case-13-cfg4"]
VerificationTest[Einsum["ai,bi,ci->abc", {{-1,-2,0},{-2,-1,1}}, {{1,0,1},{-1,2,-2},{1,-2,1}}, {{-1,-1,-1},{1,1,-1},{0,-2,2},{2,-1,0}}], {{{1,-1,0,-2},{3,-3,8,6},{-3,3,-8,-6}},{{1,-3,2,-4},{2,2,0,6},{-1,-1,-2,-6}}}, TestID -> "case-14"]
VerificationTest[Einsum["ai,bi,ci->abc", {{-1,-2,0},{-2,-1,1}}, {{1,0,1},{-1,2,-2},{1,-2,1}}, {{-1,-1,-1},{1,1,-1},{0,-2,2},{2,-1,0}}, "Path" -> "Greedy"], {{{1,-1,0,-2},{3,-3,8,6},{-3,3,-8,-6}},{{1,-3,2,-4},{2,2,0,6},{-1,-1,-2,-6}}}, TestID -> "case-14-cfg1"]
VerificationTest[Einsum["ai,bi,ci->abc", {{-1,-2,0},{-2,-1,1}}, {{1,0,1},{-1,2,-2},{1,-2,1}}, {{-1,-1,-1},{1,1,-1},{0,-2,2},{2,-1,0}}, "Path" -> "Sequential"], {{{1,-1,0,-2},{3,-3,8,6},{-3,3,-8,-6}},{{1,-3,2,-4},{2,2,0,6},{-1,-1,-2,-6}}}, TestID -> "case-14-cfg2"]
VerificationTest[Einsum["ai,bi,ci->abc", {{-1,-2,0},{-2,-1,1}}, {{1,0,1},{-1,2,-2},{1,-2,1}}, {{-1,-1,-1},{1,1,-1},{0,-2,2},{2,-1,0}}, "BatchMethod" -> "Dot"], {{{1,-1,0,-2},{3,-3,8,6},{-3,3,-8,-6}},{{1,-3,2,-4},{2,2,0,6},{-1,-1,-2,-6}}}, TestID -> "case-14-cfg3"]
VerificationTest[Einsum["ai,bi,ci->abc", {{-1,-2,0},{-2,-1,1}}, {{1,0,1},{-1,2,-2},{1,-2,1}}, {{-1,-1,-1},{1,1,-1},{0,-2,2},{2,-1,0}}, "BatchMethod" -> "Vectorized"], {{{1,-1,0,-2},{3,-3,8,6},{-3,3,-8,-6}},{{1,-3,2,-4},{2,2,0,6},{-1,-1,-2,-6}}}, TestID -> "case-14-cfg4"]
VerificationTest[Einsum["i,i,i,i->", {0,1,-2,0,2}, {1,0,-2,2,-2}, {-1,1,0,0,0}, {-2,-2,2,2,-2}], 0, TestID -> "case-15"]
VerificationTest[Einsum["i,i,i,i->", {0,1,-2,0,2}, {1,0,-2,2,-2}, {-1,1,0,0,0}, {-2,-2,2,2,-2}, "Path" -> "Greedy"], 0, TestID -> "case-15-cfg1"]
VerificationTest[Einsum["i,i,i,i->", {0,1,-2,0,2}, {1,0,-2,2,-2}, {-1,1,0,0,0}, {-2,-2,2,2,-2}, "Path" -> "Sequential"], 0, TestID -> "case-15-cfg2"]
VerificationTest[Einsum["i,i,i,i->", {0,1,-2,0,2}, {1,0,-2,2,-2}, {-1,1,0,0,0}, {-2,-2,2,2,-2}, "BatchMethod" -> "Dot"], 0, TestID -> "case-15-cfg3"]
VerificationTest[Einsum["i,i,i,i->", {0,1,-2,0,2}, {1,0,-2,2,-2}, {-1,1,0,0,0}, {-2,-2,2,2,-2}, "BatchMethod" -> "Vectorized"], 0, TestID -> "case-15-cfg4"]
VerificationTest[Einsum["ij,jk,jl->ikl", {{1,0,1},{-2,1,1}}, {{2,-1},{0,-2},{-2,-2}}, {{0,-2,1,-2},{1,0,-1,0},{2,2,-1,2}}], {{{-4,-8,4,-8},{-4,-2,1,-2}},{{-4,4,-2,4},{-6,-8,6,-8}}}, TestID -> "case-16"]
VerificationTest[Einsum["ij,jk,jl->ikl", {{1,0,1},{-2,1,1}}, {{2,-1},{0,-2},{-2,-2}}, {{0,-2,1,-2},{1,0,-1,0},{2,2,-1,2}}, "Path" -> "Greedy"], {{{-4,-8,4,-8},{-4,-2,1,-2}},{{-4,4,-2,4},{-6,-8,6,-8}}}, TestID -> "case-16-cfg1"]
VerificationTest[Einsum["ij,jk,jl->ikl", {{1,0,1},{-2,1,1}}, {{2,-1},{0,-2},{-2,-2}}, {{0,-2,1,-2},{1,0,-1,0},{2,2,-1,2}}, "Path" -> "Sequential"], {{{-4,-8,4,-8},{-4,-2,1,-2}},{{-4,4,-2,4},{-6,-8,6,-8}}}, TestID -> "case-16-cfg2"]
VerificationTest[Einsum["ij,jk,jl->ikl", {{1,0,1},{-2,1,1}}, {{2,-1},{0,-2},{-2,-2}}, {{0,-2,1,-2},{1,0,-1,0},{2,2,-1,2}}, "BatchMethod" -> "Dot"], {{{-4,-8,4,-8},{-4,-2,1,-2}},{{-4,4,-2,4},{-6,-8,6,-8}}}, TestID -> "case-16-cfg3"]
VerificationTest[Einsum["ij,jk,jl->ikl", {{1,0,1},{-2,1,1}}, {{2,-1},{0,-2},{-2,-2}}, {{0,-2,1,-2},{1,0,-1,0},{2,2,-1,2}}, "BatchMethod" -> "Vectorized"], {{{-4,-8,4,-8},{-4,-2,1,-2}},{{-4,4,-2,4},{-6,-8,6,-8}}}, TestID -> "case-16-cfg4"]
VerificationTest[Einsum["ab,ac,ad,ae->bcde", {{-1,1},{-1,1},{1,2}}, {{-1,2},{2,-2},{-2,-2}}, {{1},{-1},{-2}}, {{-2,2},{0,-2},{-1,1}}], {{{{-6,2}},{{0,4}}},{{{-6,10}},{{-12,8}}}}, TestID -> "case-17"]
VerificationTest[Einsum["ab,ac,ad,ae->bcde", {{-1,1},{-1,1},{1,2}}, {{-1,2},{2,-2},{-2,-2}}, {{1},{-1},{-2}}, {{-2,2},{0,-2},{-1,1}}, "Path" -> "Greedy"], {{{{-6,2}},{{0,4}}},{{{-6,10}},{{-12,8}}}}, TestID -> "case-17-cfg1"]
VerificationTest[Einsum["ab,ac,ad,ae->bcde", {{-1,1},{-1,1},{1,2}}, {{-1,2},{2,-2},{-2,-2}}, {{1},{-1},{-2}}, {{-2,2},{0,-2},{-1,1}}, "Path" -> "Sequential"], {{{{-6,2}},{{0,4}}},{{{-6,10}},{{-12,8}}}}, TestID -> "case-17-cfg2"]
VerificationTest[Einsum["ab,ac,ad,ae->bcde", {{-1,1},{-1,1},{1,2}}, {{-1,2},{2,-2},{-2,-2}}, {{1},{-1},{-2}}, {{-2,2},{0,-2},{-1,1}}, "BatchMethod" -> "Dot"], {{{{-6,2}},{{0,4}}},{{{-6,10}},{{-12,8}}}}, TestID -> "case-17-cfg3"]
VerificationTest[Einsum["ab,ac,ad,ae->bcde", {{-1,1},{-1,1},{1,2}}, {{-1,2},{2,-2},{-2,-2}}, {{1},{-1},{-2}}, {{-2,2},{0,-2},{-1,1}}, "BatchMethod" -> "Vectorized"], {{{{-6,2}},{{0,4}}},{{{-6,10}},{{-12,8}}}}, TestID -> "case-17-cfg4"]
VerificationTest[Einsum["ii->i", {{-1,1,-1},{1,-2,2},{1,0,1}}], {-1,-2,1}, TestID -> "case-18"]
VerificationTest[Einsum["ii->i", {{-1,1,-1},{1,-2,2},{1,0,1}}, "Path" -> "Greedy"], {-1,-2,1}, TestID -> "case-18-cfg1"]
VerificationTest[Einsum["ii->i", {{-1,1,-1},{1,-2,2},{1,0,1}}, "Path" -> "Sequential"], {-1,-2,1}, TestID -> "case-18-cfg2"]
VerificationTest[Einsum["ii->i", {{-1,1,-1},{1,-2,2},{1,0,1}}, "BatchMethod" -> "Dot"], {-1,-2,1}, TestID -> "case-18-cfg3"]
VerificationTest[Einsum["ii->i", {{-1,1,-1},{1,-2,2},{1,0,1}}, "BatchMethod" -> "Vectorized"], {-1,-2,1}, TestID -> "case-18-cfg4"]
VerificationTest[Einsum["ii->", {{-2,1,0},{-2,-2,0},{1,1,-2}}], -6, TestID -> "case-19"]
VerificationTest[Einsum["ii->", {{-2,1,0},{-2,-2,0},{1,1,-2}}, "Path" -> "Greedy"], -6, TestID -> "case-19-cfg1"]
VerificationTest[Einsum["ii->", {{-2,1,0},{-2,-2,0},{1,1,-2}}, "Path" -> "Sequential"], -6, TestID -> "case-19-cfg2"]
VerificationTest[Einsum["ii->", {{-2,1,0},{-2,-2,0},{1,1,-2}}, "BatchMethod" -> "Dot"], -6, TestID -> "case-19-cfg3"]
VerificationTest[Einsum["ii->", {{-2,1,0},{-2,-2,0},{1,1,-2}}, "BatchMethod" -> "Vectorized"], -6, TestID -> "case-19-cfg4"]
VerificationTest[Einsum["iij->j", {{{-2,-1,-1},{-2,-2,-1}},{{-2,-2,-1},{-1,0,-2}}}], {-3,-1,-3}, TestID -> "case-20"]
VerificationTest[Einsum["iij->j", {{{-2,-1,-1},{-2,-2,-1}},{{-2,-2,-1},{-1,0,-2}}}, "Path" -> "Greedy"], {-3,-1,-3}, TestID -> "case-20-cfg1"]
VerificationTest[Einsum["iij->j", {{{-2,-1,-1},{-2,-2,-1}},{{-2,-2,-1},{-1,0,-2}}}, "Path" -> "Sequential"], {-3,-1,-3}, TestID -> "case-20-cfg2"]
VerificationTest[Einsum["iij->j", {{{-2,-1,-1},{-2,-2,-1}},{{-2,-2,-1},{-1,0,-2}}}, "BatchMethod" -> "Dot"], {-3,-1,-3}, TestID -> "case-20-cfg3"]
VerificationTest[Einsum["iij->j", {{{-2,-1,-1},{-2,-2,-1}},{{-2,-2,-1},{-1,0,-2}}}, "BatchMethod" -> "Vectorized"], {-3,-1,-3}, TestID -> "case-20-cfg4"]
VerificationTest[Einsum["iii->i", {{{0,2,2},{-2,-1,1},{-2,0,2}},{{1,-2,-1},{-2,0,2},{1,1,1}},{{-1,2,-2},{-2,-1,0},{-1,0,2}}}], {0,0,2}, TestID -> "case-21"]
VerificationTest[Einsum["iii->i", {{{0,2,2},{-2,-1,1},{-2,0,2}},{{1,-2,-1},{-2,0,2},{1,1,1}},{{-1,2,-2},{-2,-1,0},{-1,0,2}}}, "Path" -> "Greedy"], {0,0,2}, TestID -> "case-21-cfg1"]
VerificationTest[Einsum["iii->i", {{{0,2,2},{-2,-1,1},{-2,0,2}},{{1,-2,-1},{-2,0,2},{1,1,1}},{{-1,2,-2},{-2,-1,0},{-1,0,2}}}, "Path" -> "Sequential"], {0,0,2}, TestID -> "case-21-cfg2"]
VerificationTest[Einsum["iii->i", {{{0,2,2},{-2,-1,1},{-2,0,2}},{{1,-2,-1},{-2,0,2},{1,1,1}},{{-1,2,-2},{-2,-1,0},{-1,0,2}}}, "BatchMethod" -> "Dot"], {0,0,2}, TestID -> "case-21-cfg3"]
VerificationTest[Einsum["iii->i", {{{0,2,2},{-2,-1,1},{-2,0,2}},{{1,-2,-1},{-2,0,2},{1,1,1}},{{-1,2,-2},{-2,-1,0},{-1,0,2}}}, "BatchMethod" -> "Vectorized"], {0,0,2}, TestID -> "case-21-cfg4"]
VerificationTest[Einsum["iji->ij", {{{0,0},{1,-2},{2,2}},{{-2,1},{2,-2},{-2,-2}}}], {{0,1,2},{1,-2,-2}}, TestID -> "case-22"]
VerificationTest[Einsum["iji->ij", {{{0,0},{1,-2},{2,2}},{{-2,1},{2,-2},{-2,-2}}}, "Path" -> "Greedy"], {{0,1,2},{1,-2,-2}}, TestID -> "case-22-cfg1"]
VerificationTest[Einsum["iji->ij", {{{0,0},{1,-2},{2,2}},{{-2,1},{2,-2},{-2,-2}}}, "Path" -> "Sequential"], {{0,1,2},{1,-2,-2}}, TestID -> "case-22-cfg2"]
VerificationTest[Einsum["iji->ij", {{{0,0},{1,-2},{2,2}},{{-2,1},{2,-2},{-2,-2}}}, "BatchMethod" -> "Dot"], {{0,1,2},{1,-2,-2}}, TestID -> "case-22-cfg3"]
VerificationTest[Einsum["iji->ij", {{{0,0},{1,-2},{2,2}},{{-2,1},{2,-2},{-2,-2}}}, "BatchMethod" -> "Vectorized"], {{0,1,2},{1,-2,-2}}, TestID -> "case-22-cfg4"]
VerificationTest[Einsum["ii,ii->i", {{2,0,2},{-2,1,1},{0,1,-2}}, {{-2,1,2},{2,1,0},{2,-2,1}}], {-4,1,-2}, TestID -> "case-23"]
VerificationTest[Einsum["ii,ii->i", {{2,0,2},{-2,1,1},{0,1,-2}}, {{-2,1,2},{2,1,0},{2,-2,1}}, "Path" -> "Greedy"], {-4,1,-2}, TestID -> "case-23-cfg1"]
VerificationTest[Einsum["ii,ii->i", {{2,0,2},{-2,1,1},{0,1,-2}}, {{-2,1,2},{2,1,0},{2,-2,1}}, "Path" -> "Sequential"], {-4,1,-2}, TestID -> "case-23-cfg2"]
VerificationTest[Einsum["ii,ii->i", {{2,0,2},{-2,1,1},{0,1,-2}}, {{-2,1,2},{2,1,0},{2,-2,1}}, "BatchMethod" -> "Dot"], {-4,1,-2}, TestID -> "case-23-cfg3"]
VerificationTest[Einsum["ii,ii->i", {{2,0,2},{-2,1,1},{0,1,-2}}, {{-2,1,2},{2,1,0},{2,-2,1}}, "BatchMethod" -> "Vectorized"], {-4,1,-2}, TestID -> "case-23-cfg4"]
VerificationTest[Einsum["ii", {{0,1,2,-2},{1,-2,0,-2},{-1,2,0,1},{2,2,-2,-1}}], -3, TestID -> "case-24"]
VerificationTest[Einsum["ii", {{0,1,2,-2},{1,-2,0,-2},{-1,2,0,1},{2,2,-2,-1}}, "Path" -> "Greedy"], -3, TestID -> "case-24-cfg1"]
VerificationTest[Einsum["ii", {{0,1,2,-2},{1,-2,0,-2},{-1,2,0,1},{2,2,-2,-1}}, "Path" -> "Sequential"], -3, TestID -> "case-24-cfg2"]
VerificationTest[Einsum["ii", {{0,1,2,-2},{1,-2,0,-2},{-1,2,0,1},{2,2,-2,-1}}, "BatchMethod" -> "Dot"], -3, TestID -> "case-24-cfg3"]
VerificationTest[Einsum["ii", {{0,1,2,-2},{1,-2,0,-2},{-1,2,0,1},{2,2,-2,-1}}, "BatchMethod" -> "Vectorized"], -3, TestID -> "case-24-cfg4"]
VerificationTest[Einsum["ij,j->ij", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {2,1,0,-2}], {{0,0,0,-4},{-4,-2,0,-4},{-2,-1,0,0}}, TestID -> "case-25"]
VerificationTest[Einsum["ij,j->ij", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {2,1,0,-2}, "Path" -> "Greedy"], {{0,0,0,-4},{-4,-2,0,-4},{-2,-1,0,0}}, TestID -> "case-25-cfg1"]
VerificationTest[Einsum["ij,j->ij", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {2,1,0,-2}, "Path" -> "Sequential"], {{0,0,0,-4},{-4,-2,0,-4},{-2,-1,0,0}}, TestID -> "case-25-cfg2"]
VerificationTest[Einsum["ij,j->ij", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {2,1,0,-2}, "BatchMethod" -> "Dot"], {{0,0,0,-4},{-4,-2,0,-4},{-2,-1,0,0}}, TestID -> "case-25-cfg3"]
VerificationTest[Einsum["ij,j->ij", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {2,1,0,-2}, "BatchMethod" -> "Vectorized"], {{0,0,0,-4},{-4,-2,0,-4},{-2,-1,0,0}}, TestID -> "case-25-cfg4"]
VerificationTest[Einsum["ij,i->ij", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {1,-2,2}], {{0,0,1,2},{4,4,-4,-4},{-2,-2,4,0}}, TestID -> "case-26"]
VerificationTest[Einsum["ij,i->ij", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {1,-2,2}, "Path" -> "Greedy"], {{0,0,1,2},{4,4,-4,-4},{-2,-2,4,0}}, TestID -> "case-26-cfg1"]
VerificationTest[Einsum["ij,i->ij", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {1,-2,2}, "Path" -> "Sequential"], {{0,0,1,2},{4,4,-4,-4},{-2,-2,4,0}}, TestID -> "case-26-cfg2"]
VerificationTest[Einsum["ij,i->ij", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {1,-2,2}, "BatchMethod" -> "Dot"], {{0,0,1,2},{4,4,-4,-4},{-2,-2,4,0}}, TestID -> "case-26-cfg3"]
VerificationTest[Einsum["ij,i->ij", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {1,-2,2}, "BatchMethod" -> "Vectorized"], {{0,0,1,2},{4,4,-4,-4},{-2,-2,4,0}}, TestID -> "case-26-cfg4"]
VerificationTest[Einsum["ij,ji->ij", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,0,0},{0,0,2},{0,-1,0},{1,0,0}}], {{0,0,0,2},{0,0,-2,0},{0,-2,0,0}}, TestID -> "case-27"]
VerificationTest[Einsum["ij,ji->ij", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,0,0},{0,0,2},{0,-1,0},{1,0,0}}, "Path" -> "Greedy"], {{0,0,0,2},{0,0,-2,0},{0,-2,0,0}}, TestID -> "case-27-cfg1"]
VerificationTest[Einsum["ij,ji->ij", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,0,0},{0,0,2},{0,-1,0},{1,0,0}}, "Path" -> "Sequential"], {{0,0,0,2},{0,0,-2,0},{0,-2,0,0}}, TestID -> "case-27-cfg2"]
VerificationTest[Einsum["ij,ji->ij", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,0,0},{0,0,2},{0,-1,0},{1,0,0}}, "BatchMethod" -> "Dot"], {{0,0,0,2},{0,0,-2,0},{0,-2,0,0}}, TestID -> "case-27-cfg3"]
VerificationTest[Einsum["ij,ji->ij", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, {{-1,0,0},{0,0,2},{0,-1,0},{1,0,0}}, "BatchMethod" -> "Vectorized"], {{0,0,0,2},{0,0,-2,0},{0,-2,0,0}}, TestID -> "case-27-cfg4"]
VerificationTest[Einsum["ijk,jk->ijk", {{{2,-1},{0,2},{2,0}},{{-2,0},{-1,2},{0,0}}}, {{1,0},{-1,0},{-1,2}}], {{{2,0},{0,0},{-2,0}},{{-2,0},{1,0},{0,0}}}, TestID -> "case-28"]
VerificationTest[Einsum["ijk,jk->ijk", {{{2,-1},{0,2},{2,0}},{{-2,0},{-1,2},{0,0}}}, {{1,0},{-1,0},{-1,2}}, "Path" -> "Greedy"], {{{2,0},{0,0},{-2,0}},{{-2,0},{1,0},{0,0}}}, TestID -> "case-28-cfg1"]
VerificationTest[Einsum["ijk,jk->ijk", {{{2,-1},{0,2},{2,0}},{{-2,0},{-1,2},{0,0}}}, {{1,0},{-1,0},{-1,2}}, "Path" -> "Sequential"], {{{2,0},{0,0},{-2,0}},{{-2,0},{1,0},{0,0}}}, TestID -> "case-28-cfg2"]
VerificationTest[Einsum["ijk,jk->ijk", {{{2,-1},{0,2},{2,0}},{{-2,0},{-1,2},{0,0}}}, {{1,0},{-1,0},{-1,2}}, "BatchMethod" -> "Dot"], {{{2,0},{0,0},{-2,0}},{{-2,0},{1,0},{0,0}}}, TestID -> "case-28-cfg3"]
VerificationTest[Einsum["ijk,jk->ijk", {{{2,-1},{0,2},{2,0}},{{-2,0},{-1,2},{0,0}}}, {{1,0},{-1,0},{-1,2}}, "BatchMethod" -> "Vectorized"], {{{2,0},{0,0},{-2,0}},{{-2,0},{1,0},{0,0}}}, TestID -> "case-28-cfg4"]
VerificationTest[Einsum["ijk,ik->ijk", {{{2,0},{1,-2},{0,-2}},{{-2,-1},{-2,2},{-1,2}}}, {{-2,1},{2,-2}}], {{{-4,0},{-2,-2},{0,-2}},{{-4,2},{-4,-4},{-2,-4}}}, TestID -> "case-29"]
VerificationTest[Einsum["ijk,ik->ijk", {{{2,0},{1,-2},{0,-2}},{{-2,-1},{-2,2},{-1,2}}}, {{-2,1},{2,-2}}, "Path" -> "Greedy"], {{{-4,0},{-2,-2},{0,-2}},{{-4,2},{-4,-4},{-2,-4}}}, TestID -> "case-29-cfg1"]
VerificationTest[Einsum["ijk,ik->ijk", {{{2,0},{1,-2},{0,-2}},{{-2,-1},{-2,2},{-1,2}}}, {{-2,1},{2,-2}}, "Path" -> "Sequential"], {{{-4,0},{-2,-2},{0,-2}},{{-4,2},{-4,-4},{-2,-4}}}, TestID -> "case-29-cfg2"]
VerificationTest[Einsum["ijk,ik->ijk", {{{2,0},{1,-2},{0,-2}},{{-2,-1},{-2,2},{-1,2}}}, {{-2,1},{2,-2}}, "BatchMethod" -> "Dot"], {{{-4,0},{-2,-2},{0,-2}},{{-4,2},{-4,-4},{-2,-4}}}, TestID -> "case-29-cfg3"]
VerificationTest[Einsum["ijk,ik->ijk", {{{2,0},{1,-2},{0,-2}},{{-2,-1},{-2,2},{-1,2}}}, {{-2,1},{2,-2}}, "BatchMethod" -> "Vectorized"], {{{-4,0},{-2,-2},{0,-2}},{{-4,2},{-4,-4},{-2,-4}}}, TestID -> "case-29-cfg4"]
VerificationTest[Einsum["ijk,k->kji", {{{-2,-1},{-1,0},{-2,-2}},{{1,-2},{-2,-1},{-2,-2}}}, {-2,0}], {{{4,-2},{2,4},{4,4}},{{0,0},{0,0},{0,0}}}, TestID -> "case-30"]
VerificationTest[Einsum["ijk,k->kji", {{{-2,-1},{-1,0},{-2,-2}},{{1,-2},{-2,-1},{-2,-2}}}, {-2,0}, "Path" -> "Greedy"], {{{4,-2},{2,4},{4,4}},{{0,0},{0,0},{0,0}}}, TestID -> "case-30-cfg1"]
VerificationTest[Einsum["ijk,k->kji", {{{-2,-1},{-1,0},{-2,-2}},{{1,-2},{-2,-1},{-2,-2}}}, {-2,0}, "Path" -> "Sequential"], {{{4,-2},{2,4},{4,4}},{{0,0},{0,0},{0,0}}}, TestID -> "case-30-cfg2"]
VerificationTest[Einsum["ijk,k->kji", {{{-2,-1},{-1,0},{-2,-2}},{{1,-2},{-2,-1},{-2,-2}}}, {-2,0}, "BatchMethod" -> "Dot"], {{{4,-2},{2,4},{4,4}},{{0,0},{0,0},{0,0}}}, TestID -> "case-30-cfg3"]
VerificationTest[Einsum["ijk,k->kji", {{{-2,-1},{-1,0},{-2,-2}},{{1,-2},{-2,-1},{-2,-2}}}, {-2,0}, "BatchMethod" -> "Vectorized"], {{{4,-2},{2,4},{4,4}},{{0,0},{0,0},{0,0}}}, TestID -> "case-30-cfg4"]
VerificationTest[Einsum[",ij->ij", 3, {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}], {{0,0,3,6},{-6,-6,6,6},{-3,-3,6,0}}, TestID -> "case-31"]
VerificationTest[Einsum[",ij->ij", 3, {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, "Path" -> "Greedy"], {{0,0,3,6},{-6,-6,6,6},{-3,-3,6,0}}, TestID -> "case-31-cfg1"]
VerificationTest[Einsum[",ij->ij", 3, {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, "Path" -> "Sequential"], {{0,0,3,6},{-6,-6,6,6},{-3,-3,6,0}}, TestID -> "case-31-cfg2"]
VerificationTest[Einsum[",ij->ij", 3, {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, "BatchMethod" -> "Dot"], {{0,0,3,6},{-6,-6,6,6},{-3,-3,6,0}}, TestID -> "case-31-cfg3"]
VerificationTest[Einsum[",ij->ij", 3, {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, "BatchMethod" -> "Vectorized"], {{0,0,3,6},{-6,-6,6,6},{-3,-3,6,0}}, TestID -> "case-31-cfg4"]
VerificationTest[Einsum["i,->i", {-1,2,0}, -2], {2,-4,0}, TestID -> "case-32"]
VerificationTest[Einsum["i,->i", {-1,2,0}, -2, "Path" -> "Greedy"], {2,-4,0}, TestID -> "case-32-cfg1"]
VerificationTest[Einsum["i,->i", {-1,2,0}, -2, "Path" -> "Sequential"], {2,-4,0}, TestID -> "case-32-cfg2"]
VerificationTest[Einsum["i,->i", {-1,2,0}, -2, "BatchMethod" -> "Dot"], {2,-4,0}, TestID -> "case-32-cfg3"]
VerificationTest[Einsum["i,->i", {-1,2,0}, -2, "BatchMethod" -> "Vectorized"], {2,-4,0}, TestID -> "case-32-cfg4"]
VerificationTest[Einsum[",->", 2, 5], 10, TestID -> "case-33"]
VerificationTest[Einsum[",->", 2, 5, "Path" -> "Greedy"], 10, TestID -> "case-33-cfg1"]
VerificationTest[Einsum[",->", 2, 5, "Path" -> "Sequential"], 10, TestID -> "case-33-cfg2"]
VerificationTest[Einsum[",->", 2, 5, "BatchMethod" -> "Dot"], 10, TestID -> "case-33-cfg3"]
VerificationTest[Einsum[",->", 2, 5, "BatchMethod" -> "Vectorized"], 10, TestID -> "case-33-cfg4"]
VerificationTest[Einsum["i,j->ij", {-1,2,-2}, {-1,-2}], {{1,2},{-2,-4},{2,4}}, TestID -> "case-34"]
VerificationTest[Einsum["i,j->ij", {-1,2,-2}, {-1,-2}, "Path" -> "Greedy"], {{1,2},{-2,-4},{2,4}}, TestID -> "case-34-cfg1"]
VerificationTest[Einsum["i,j->ij", {-1,2,-2}, {-1,-2}, "Path" -> "Sequential"], {{1,2},{-2,-4},{2,4}}, TestID -> "case-34-cfg2"]
VerificationTest[Einsum["i,j->ij", {-1,2,-2}, {-1,-2}, "BatchMethod" -> "Dot"], {{1,2},{-2,-4},{2,4}}, TestID -> "case-34-cfg3"]
VerificationTest[Einsum["i,j->ij", {-1,2,-2}, {-1,-2}, "BatchMethod" -> "Vectorized"], {{1,2},{-2,-4},{2,4}}, TestID -> "case-34-cfg4"]
VerificationTest[Einsum["i,j,k->kji", {-1,0}, {2,-1,1}, {2,-2}], {{{-4,0},{2,0},{-2,0}},{{4,0},{-2,0},{2,0}}}, TestID -> "case-35"]
VerificationTest[Einsum["i,j,k->kji", {-1,0}, {2,-1,1}, {2,-2}, "Path" -> "Greedy"], {{{-4,0},{2,0},{-2,0}},{{4,0},{-2,0},{2,0}}}, TestID -> "case-35-cfg1"]
VerificationTest[Einsum["i,j,k->kji", {-1,0}, {2,-1,1}, {2,-2}, "Path" -> "Sequential"], {{{-4,0},{2,0},{-2,0}},{{4,0},{-2,0},{2,0}}}, TestID -> "case-35-cfg2"]
VerificationTest[Einsum["i,j,k->kji", {-1,0}, {2,-1,1}, {2,-2}, "BatchMethod" -> "Dot"], {{{-4,0},{2,0},{-2,0}},{{4,0},{-2,0},{2,0}}}, TestID -> "case-35-cfg3"]
VerificationTest[Einsum["i,j,k->kji", {-1,0}, {2,-1,1}, {2,-2}, "BatchMethod" -> "Vectorized"], {{{-4,0},{2,0},{-2,0}},{{4,0},{-2,0},{2,0}}}, TestID -> "case-35-cfg4"]
VerificationTest[Einsum["ij,kl->ijkl", {{1,2},{-1,2}}, {{2},{-2},{-2}}], {{{{2},{-2},{-2}},{{4},{-4},{-4}}},{{{-2},{2},{2}},{{4},{-4},{-4}}}}, TestID -> "case-36"]
VerificationTest[Einsum["ij,kl->ijkl", {{1,2},{-1,2}}, {{2},{-2},{-2}}, "Path" -> "Greedy"], {{{{2},{-2},{-2}},{{4},{-4},{-4}}},{{{-2},{2},{2}},{{4},{-4},{-4}}}}, TestID -> "case-36-cfg1"]
VerificationTest[Einsum["ij,kl->ijkl", {{1,2},{-1,2}}, {{2},{-2},{-2}}, "Path" -> "Sequential"], {{{{2},{-2},{-2}},{{4},{-4},{-4}}},{{{-2},{2},{2}},{{4},{-4},{-4}}}}, TestID -> "case-36-cfg2"]
VerificationTest[Einsum["ij,kl->ijkl", {{1,2},{-1,2}}, {{2},{-2},{-2}}, "BatchMethod" -> "Dot"], {{{{2},{-2},{-2}},{{4},{-4},{-4}}},{{{-2},{2},{2}},{{4},{-4},{-4}}}}, TestID -> "case-36-cfg3"]
VerificationTest[Einsum["ij,kl->ijkl", {{1,2},{-1,2}}, {{2},{-2},{-2}}, "BatchMethod" -> "Vectorized"], {{{{2},{-2},{-2}},{{4},{-4},{-4}}},{{{-2},{2},{2}},{{4},{-4},{-4}}}}, TestID -> "case-36-cfg4"]
VerificationTest[Einsum["ij->", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}], 3, TestID -> "case-37"]
VerificationTest[Einsum["ij->", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, "Path" -> "Greedy"], 3, TestID -> "case-37-cfg1"]
VerificationTest[Einsum["ij->", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, "Path" -> "Sequential"], 3, TestID -> "case-37-cfg2"]
VerificationTest[Einsum["ij->", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, "BatchMethod" -> "Dot"], 3, TestID -> "case-37-cfg3"]
VerificationTest[Einsum["ij->", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, "BatchMethod" -> "Vectorized"], 3, TestID -> "case-37-cfg4"]
VerificationTest[Einsum["ij->ji", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}], {{0,-2,-1},{0,-2,-1},{1,2,2},{2,2,0}}, TestID -> "case-38"]
VerificationTest[Einsum["ij->ji", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, "Path" -> "Greedy"], {{0,-2,-1},{0,-2,-1},{1,2,2},{2,2,0}}, TestID -> "case-38-cfg1"]
VerificationTest[Einsum["ij->ji", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, "Path" -> "Sequential"], {{0,-2,-1},{0,-2,-1},{1,2,2},{2,2,0}}, TestID -> "case-38-cfg2"]
VerificationTest[Einsum["ij->ji", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, "BatchMethod" -> "Dot"], {{0,-2,-1},{0,-2,-1},{1,2,2},{2,2,0}}, TestID -> "case-38-cfg3"]
VerificationTest[Einsum["ij->ji", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, "BatchMethod" -> "Vectorized"], {{0,-2,-1},{0,-2,-1},{1,2,2},{2,2,0}}, TestID -> "case-38-cfg4"]
VerificationTest[Einsum["ba", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}], {{0,-2,-1},{0,-2,-1},{1,2,2},{2,2,0}}, TestID -> "case-39"]
VerificationTest[Einsum["ba", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, "Path" -> "Greedy"], {{0,-2,-1},{0,-2,-1},{1,2,2},{2,2,0}}, TestID -> "case-39-cfg1"]
VerificationTest[Einsum["ba", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, "Path" -> "Sequential"], {{0,-2,-1},{0,-2,-1},{1,2,2},{2,2,0}}, TestID -> "case-39-cfg2"]
VerificationTest[Einsum["ba", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, "BatchMethod" -> "Dot"], {{0,-2,-1},{0,-2,-1},{1,2,2},{2,2,0}}, TestID -> "case-39-cfg3"]
VerificationTest[Einsum["ba", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, "BatchMethod" -> "Vectorized"], {{0,-2,-1},{0,-2,-1},{1,2,2},{2,2,0}}, TestID -> "case-39-cfg4"]
VerificationTest[Einsum["ijk->kij", {{{1,0,-2,2},{-1,-2,0,-1},{0,-1,0,0}},{{0,2,-1,0},{1,2,-1,2},{2,-1,0,1}}}], {{{1,-1,0},{0,1,2}},{{0,-2,-1},{2,2,-1}},{{-2,0,0},{-1,-1,0}},{{2,-1,0},{0,2,1}}}, TestID -> "case-40"]
VerificationTest[Einsum["ijk->kij", {{{1,0,-2,2},{-1,-2,0,-1},{0,-1,0,0}},{{0,2,-1,0},{1,2,-1,2},{2,-1,0,1}}}, "Path" -> "Greedy"], {{{1,-1,0},{0,1,2}},{{0,-2,-1},{2,2,-1}},{{-2,0,0},{-1,-1,0}},{{2,-1,0},{0,2,1}}}, TestID -> "case-40-cfg1"]
VerificationTest[Einsum["ijk->kij", {{{1,0,-2,2},{-1,-2,0,-1},{0,-1,0,0}},{{0,2,-1,0},{1,2,-1,2},{2,-1,0,1}}}, "Path" -> "Sequential"], {{{1,-1,0},{0,1,2}},{{0,-2,-1},{2,2,-1}},{{-2,0,0},{-1,-1,0}},{{2,-1,0},{0,2,1}}}, TestID -> "case-40-cfg2"]
VerificationTest[Einsum["ijk->kij", {{{1,0,-2,2},{-1,-2,0,-1},{0,-1,0,0}},{{0,2,-1,0},{1,2,-1,2},{2,-1,0,1}}}, "BatchMethod" -> "Dot"], {{{1,-1,0},{0,1,2}},{{0,-2,-1},{2,2,-1}},{{-2,0,0},{-1,-1,0}},{{2,-1,0},{0,2,1}}}, TestID -> "case-40-cfg3"]
VerificationTest[Einsum["ijk->kij", {{{1,0,-2,2},{-1,-2,0,-1},{0,-1,0,0}},{{0,2,-1,0},{1,2,-1,2},{2,-1,0,1}}}, "BatchMethod" -> "Vectorized"], {{{1,-1,0},{0,1,2}},{{0,-2,-1},{2,2,-1}},{{-2,0,0},{-1,-1,0}},{{2,-1,0},{0,2,1}}}, TestID -> "case-40-cfg4"]
VerificationTest[Einsum["ij->i", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}], {3,0,0}, TestID -> "case-41"]
VerificationTest[Einsum["ij->i", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, "Path" -> "Greedy"], {3,0,0}, TestID -> "case-41-cfg1"]
VerificationTest[Einsum["ij->i", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, "Path" -> "Sequential"], {3,0,0}, TestID -> "case-41-cfg2"]
VerificationTest[Einsum["ij->i", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, "BatchMethod" -> "Dot"], {3,0,0}, TestID -> "case-41-cfg3"]
VerificationTest[Einsum["ij->i", {{0,0,1,2},{-2,-2,2,2},{-1,-1,2,0}}, "BatchMethod" -> "Vectorized"], {3,0,0}, TestID -> "case-41-cfg4"]
VerificationTest[Einsum["ij,ij->ij", {{-1},{-1},{-2}}, {{0,0,1,-1},{0,1,1,0},{-2,-2,0,2}}], {{0,0,-1,1},{0,-1,-1,0},{4,4,0,-4}}, TestID -> "case-42"]
VerificationTest[Einsum["ij,ij->ij", {{-1},{-1},{-2}}, {{0,0,1,-1},{0,1,1,0},{-2,-2,0,2}}, "Path" -> "Greedy"], {{0,0,-1,1},{0,-1,-1,0},{4,4,0,-4}}, TestID -> "case-42-cfg1"]
VerificationTest[Einsum["ij,ij->ij", {{-1},{-1},{-2}}, {{0,0,1,-1},{0,1,1,0},{-2,-2,0,2}}, "Path" -> "Sequential"], {{0,0,-1,1},{0,-1,-1,0},{4,4,0,-4}}, TestID -> "case-42-cfg2"]
VerificationTest[Einsum["ij,ij->ij", {{-1},{-1},{-2}}, {{0,0,1,-1},{0,1,1,0},{-2,-2,0,2}}, "BatchMethod" -> "Dot"], {{0,0,-1,1},{0,-1,-1,0},{4,4,0,-4}}, TestID -> "case-42-cfg3"]
VerificationTest[Einsum["ij,ij->ij", {{-1},{-1},{-2}}, {{0,0,1,-1},{0,1,1,0},{-2,-2,0,2}}, "BatchMethod" -> "Vectorized"], {{0,0,-1,1},{0,-1,-1,0},{4,4,0,-4}}, TestID -> "case-42-cfg4"]
VerificationTest[Einsum["ij,jk->ik", {{0},{-2},{-2}}, {{2,-1},{2,-2},{2,-2},{1,0}}], {{0,0},{-14,10},{-14,10}}, TestID -> "case-43"]
VerificationTest[Einsum["ij,jk->ik", {{0},{-2},{-2}}, {{2,-1},{2,-2},{2,-2},{1,0}}, "Path" -> "Greedy"], {{0,0},{-14,10},{-14,10}}, TestID -> "case-43-cfg1"]
VerificationTest[Einsum["ij,jk->ik", {{0},{-2},{-2}}, {{2,-1},{2,-2},{2,-2},{1,0}}, "Path" -> "Sequential"], {{0,0},{-14,10},{-14,10}}, TestID -> "case-43-cfg2"]
VerificationTest[Einsum["ij,jk->ik", {{0},{-2},{-2}}, {{2,-1},{2,-2},{2,-2},{1,0}}, "BatchMethod" -> "Dot"], {{0,0},{-14,10},{-14,10}}, TestID -> "case-43-cfg3"]
VerificationTest[Einsum["ij,jk->ik", {{0},{-2},{-2}}, {{2,-1},{2,-2},{2,-2},{1,0}}, "BatchMethod" -> "Vectorized"], {{0,0},{-14,10},{-14,10}}, TestID -> "case-43-cfg4"]
VerificationTest[Einsum["i,i->i", {-2}, {-1,0,-1,0}], {2,0,2,0}, TestID -> "case-44"]
VerificationTest[Einsum["i,i->i", {-2}, {-1,0,-1,0}, "Path" -> "Greedy"], {2,0,2,0}, TestID -> "case-44-cfg1"]
VerificationTest[Einsum["i,i->i", {-2}, {-1,0,-1,0}, "Path" -> "Sequential"], {2,0,2,0}, TestID -> "case-44-cfg2"]
VerificationTest[Einsum["i,i->i", {-2}, {-1,0,-1,0}, "BatchMethod" -> "Dot"], {2,0,2,0}, TestID -> "case-44-cfg3"]
VerificationTest[Einsum["i,i->i", {-2}, {-1,0,-1,0}, "BatchMethod" -> "Vectorized"], {2,0,2,0}, TestID -> "case-44-cfg4"]
VerificationTest[Einsum["...ij,...jk->...ik", {{{-2,1,2,-1},{0,1,2,-1},{-2,-1,2,0}},{{-2,0,2,-2},{-1,2,-2,1},{0,2,2,-1}}}, {{{-1,2,1,2,-2},{2,0,-2,1,0},{1,-1,-1,1,2},{-1,1,-2,-2,0}},{{-2,1,0,-1,1},{2,2,0,1,-1},{-2,2,0,0,0},{-1,1,-1,-2,2}}}], {{{7,-7,-4,1,8},{5,-3,-2,5,4},{2,-6,-2,-3,8}},{{2,0,2,6,-6},{9,0,-1,1,-1},{1,7,1,4,-4}}}, TestID -> "case-45"]
VerificationTest[Einsum["...ij,...jk->...ik", {{{-2,1,2,-1},{0,1,2,-1},{-2,-1,2,0}},{{-2,0,2,-2},{-1,2,-2,1},{0,2,2,-1}}}, {{{-1,2,1,2,-2},{2,0,-2,1,0},{1,-1,-1,1,2},{-1,1,-2,-2,0}},{{-2,1,0,-1,1},{2,2,0,1,-1},{-2,2,0,0,0},{-1,1,-1,-2,2}}}, "Path" -> "Greedy"], {{{7,-7,-4,1,8},{5,-3,-2,5,4},{2,-6,-2,-3,8}},{{2,0,2,6,-6},{9,0,-1,1,-1},{1,7,1,4,-4}}}, TestID -> "case-45-cfg1"]
VerificationTest[Einsum["...ij,...jk->...ik", {{{-2,1,2,-1},{0,1,2,-1},{-2,-1,2,0}},{{-2,0,2,-2},{-1,2,-2,1},{0,2,2,-1}}}, {{{-1,2,1,2,-2},{2,0,-2,1,0},{1,-1,-1,1,2},{-1,1,-2,-2,0}},{{-2,1,0,-1,1},{2,2,0,1,-1},{-2,2,0,0,0},{-1,1,-1,-2,2}}}, "Path" -> "Sequential"], {{{7,-7,-4,1,8},{5,-3,-2,5,4},{2,-6,-2,-3,8}},{{2,0,2,6,-6},{9,0,-1,1,-1},{1,7,1,4,-4}}}, TestID -> "case-45-cfg2"]
VerificationTest[Einsum["...ij,...jk->...ik", {{{-2,1,2,-1},{0,1,2,-1},{-2,-1,2,0}},{{-2,0,2,-2},{-1,2,-2,1},{0,2,2,-1}}}, {{{-1,2,1,2,-2},{2,0,-2,1,0},{1,-1,-1,1,2},{-1,1,-2,-2,0}},{{-2,1,0,-1,1},{2,2,0,1,-1},{-2,2,0,0,0},{-1,1,-1,-2,2}}}, "BatchMethod" -> "Dot"], {{{7,-7,-4,1,8},{5,-3,-2,5,4},{2,-6,-2,-3,8}},{{2,0,2,6,-6},{9,0,-1,1,-1},{1,7,1,4,-4}}}, TestID -> "case-45-cfg3"]
VerificationTest[Einsum["...ij,...jk->...ik", {{{-2,1,2,-1},{0,1,2,-1},{-2,-1,2,0}},{{-2,0,2,-2},{-1,2,-2,1},{0,2,2,-1}}}, {{{-1,2,1,2,-2},{2,0,-2,1,0},{1,-1,-1,1,2},{-1,1,-2,-2,0}},{{-2,1,0,-1,1},{2,2,0,1,-1},{-2,2,0,0,0},{-1,1,-1,-2,2}}}, "BatchMethod" -> "Vectorized"], {{{7,-7,-4,1,8},{5,-3,-2,5,4},{2,-6,-2,-3,8}},{{2,0,2,6,-6},{9,0,-1,1,-1},{1,7,1,4,-4}}}, TestID -> "case-45-cfg4"]
VerificationTest[Einsum["...ij,...jk->...ik", {{1,2,2,1},{2,-1,-2,1},{1,-1,2,-1}}, {{{2,0,-2,0,-2},{-1,0,2,2,-2},{1,1,-1,-2,0},{-2,2,-1,1,2}},{{0,1,0,2,1},{-2,-1,1,0,0},{0,0,0,1,-1},{-1,0,0,0,-1}}}], {{{0,4,-1,1,-4},{1,0,-5,3,0},{7,0,-5,-7,-2}},{{-5,-1,2,4,-2},{1,3,-1,2,3},{3,2,-1,4,0}}}, TestID -> "case-46"]
VerificationTest[Einsum["...ij,...jk->...ik", {{1,2,2,1},{2,-1,-2,1},{1,-1,2,-1}}, {{{2,0,-2,0,-2},{-1,0,2,2,-2},{1,1,-1,-2,0},{-2,2,-1,1,2}},{{0,1,0,2,1},{-2,-1,1,0,0},{0,0,0,1,-1},{-1,0,0,0,-1}}}, "Path" -> "Greedy"], {{{0,4,-1,1,-4},{1,0,-5,3,0},{7,0,-5,-7,-2}},{{-5,-1,2,4,-2},{1,3,-1,2,3},{3,2,-1,4,0}}}, TestID -> "case-46-cfg1"]
VerificationTest[Einsum["...ij,...jk->...ik", {{1,2,2,1},{2,-1,-2,1},{1,-1,2,-1}}, {{{2,0,-2,0,-2},{-1,0,2,2,-2},{1,1,-1,-2,0},{-2,2,-1,1,2}},{{0,1,0,2,1},{-2,-1,1,0,0},{0,0,0,1,-1},{-1,0,0,0,-1}}}, "Path" -> "Sequential"], {{{0,4,-1,1,-4},{1,0,-5,3,0},{7,0,-5,-7,-2}},{{-5,-1,2,4,-2},{1,3,-1,2,3},{3,2,-1,4,0}}}, TestID -> "case-46-cfg2"]
VerificationTest[Einsum["...ij,...jk->...ik", {{1,2,2,1},{2,-1,-2,1},{1,-1,2,-1}}, {{{2,0,-2,0,-2},{-1,0,2,2,-2},{1,1,-1,-2,0},{-2,2,-1,1,2}},{{0,1,0,2,1},{-2,-1,1,0,0},{0,0,0,1,-1},{-1,0,0,0,-1}}}, "BatchMethod" -> "Dot"], {{{0,4,-1,1,-4},{1,0,-5,3,0},{7,0,-5,-7,-2}},{{-5,-1,2,4,-2},{1,3,-1,2,3},{3,2,-1,4,0}}}, TestID -> "case-46-cfg3"]
VerificationTest[Einsum["...ij,...jk->...ik", {{1,2,2,1},{2,-1,-2,1},{1,-1,2,-1}}, {{{2,0,-2,0,-2},{-1,0,2,2,-2},{1,1,-1,-2,0},{-2,2,-1,1,2}},{{0,1,0,2,1},{-2,-1,1,0,0},{0,0,0,1,-1},{-1,0,0,0,-1}}}, "BatchMethod" -> "Vectorized"], {{{0,4,-1,1,-4},{1,0,-5,3,0},{7,0,-5,-7,-2}},{{-5,-1,2,4,-2},{1,3,-1,2,3},{3,2,-1,4,0}}}, TestID -> "case-46-cfg4"]
VerificationTest[Einsum["...ij,jk", {{{1,-1,1,0},{1,-2,-2,-1},{2,0,-2,0}},{{-1,2,-2,1},{-2,0,1,2},{-2,-2,-2,-2}}}, {{-2,-1,0,-2,2},{0,1,0,0,-2},{-1,1,-1,0,1},{0,2,2,1,2}}], {{{-3,-1,-1,-2,5},{0,-7,0,-3,2},{-2,-4,2,-4,2}},{{4,3,4,3,-6},{3,7,3,6,1},{6,-6,-2,2,-6}}}, TestID -> "case-47"]
VerificationTest[Einsum["...ij,jk", {{{1,-1,1,0},{1,-2,-2,-1},{2,0,-2,0}},{{-1,2,-2,1},{-2,0,1,2},{-2,-2,-2,-2}}}, {{-2,-1,0,-2,2},{0,1,0,0,-2},{-1,1,-1,0,1},{0,2,2,1,2}}, "Path" -> "Greedy"], {{{-3,-1,-1,-2,5},{0,-7,0,-3,2},{-2,-4,2,-4,2}},{{4,3,4,3,-6},{3,7,3,6,1},{6,-6,-2,2,-6}}}, TestID -> "case-47-cfg1"]
VerificationTest[Einsum["...ij,jk", {{{1,-1,1,0},{1,-2,-2,-1},{2,0,-2,0}},{{-1,2,-2,1},{-2,0,1,2},{-2,-2,-2,-2}}}, {{-2,-1,0,-2,2},{0,1,0,0,-2},{-1,1,-1,0,1},{0,2,2,1,2}}, "Path" -> "Sequential"], {{{-3,-1,-1,-2,5},{0,-7,0,-3,2},{-2,-4,2,-4,2}},{{4,3,4,3,-6},{3,7,3,6,1},{6,-6,-2,2,-6}}}, TestID -> "case-47-cfg2"]
VerificationTest[Einsum["...ij,jk", {{{1,-1,1,0},{1,-2,-2,-1},{2,0,-2,0}},{{-1,2,-2,1},{-2,0,1,2},{-2,-2,-2,-2}}}, {{-2,-1,0,-2,2},{0,1,0,0,-2},{-1,1,-1,0,1},{0,2,2,1,2}}, "BatchMethod" -> "Dot"], {{{-3,-1,-1,-2,5},{0,-7,0,-3,2},{-2,-4,2,-4,2}},{{4,3,4,3,-6},{3,7,3,6,1},{6,-6,-2,2,-6}}}, TestID -> "case-47-cfg3"]
VerificationTest[Einsum["...ij,jk", {{{1,-1,1,0},{1,-2,-2,-1},{2,0,-2,0}},{{-1,2,-2,1},{-2,0,1,2},{-2,-2,-2,-2}}}, {{-2,-1,0,-2,2},{0,1,0,0,-2},{-1,1,-1,0,1},{0,2,2,1,2}}, "BatchMethod" -> "Vectorized"], {{{-3,-1,-1,-2,5},{0,-7,0,-3,2},{-2,-4,2,-4,2}},{{4,3,4,3,-6},{3,7,3,6,1},{6,-6,-2,2,-6}}}, TestID -> "case-47-cfg4"]
VerificationTest[Einsum["i...,i...->...", {{{1,-1},{-1,-2}},{{-2,2},{0,-2}},{{-1,1},{-1,-1}}}, {{{0,-1},{0,0}},{{-1,2},{1,-2}},{{2,-2},{0,1}}}], {{0,3},{0,3}}, TestID -> "case-48"]
VerificationTest[Einsum["i...,i...->...", {{{1,-1},{-1,-2}},{{-2,2},{0,-2}},{{-1,1},{-1,-1}}}, {{{0,-1},{0,0}},{{-1,2},{1,-2}},{{2,-2},{0,1}}}, "Path" -> "Greedy"], {{0,3},{0,3}}, TestID -> "case-48-cfg1"]
VerificationTest[Einsum["i...,i...->...", {{{1,-1},{-1,-2}},{{-2,2},{0,-2}},{{-1,1},{-1,-1}}}, {{{0,-1},{0,0}},{{-1,2},{1,-2}},{{2,-2},{0,1}}}, "Path" -> "Sequential"], {{0,3},{0,3}}, TestID -> "case-48-cfg2"]
VerificationTest[Einsum["i...,i...->...", {{{1,-1},{-1,-2}},{{-2,2},{0,-2}},{{-1,1},{-1,-1}}}, {{{0,-1},{0,0}},{{-1,2},{1,-2}},{{2,-2},{0,1}}}, "BatchMethod" -> "Dot"], {{0,3},{0,3}}, TestID -> "case-48-cfg3"]
VerificationTest[Einsum["i...,i...->...", {{{1,-1},{-1,-2}},{{-2,2},{0,-2}},{{-1,1},{-1,-1}}}, {{{0,-1},{0,0}},{{-1,2},{1,-2}},{{2,-2},{0,1}}}, "BatchMethod" -> "Vectorized"], {{0,3},{0,3}}, TestID -> "case-48-cfg4"]
VerificationTest[Einsum["...ii->...i", {{{-1,-1,2},{-1,-2,2},{-1,-1,2}},{{1,1,2},{-2,1,1},{1,0,1}}}], {{-1,-2,2},{1,1,1}}, TestID -> "case-49"]
VerificationTest[Einsum["...ii->...i", {{{-1,-1,2},{-1,-2,2},{-1,-1,2}},{{1,1,2},{-2,1,1},{1,0,1}}}, "Path" -> "Greedy"], {{-1,-2,2},{1,1,1}}, TestID -> "case-49-cfg1"]
VerificationTest[Einsum["...ii->...i", {{{-1,-1,2},{-1,-2,2},{-1,-1,2}},{{1,1,2},{-2,1,1},{1,0,1}}}, "Path" -> "Sequential"], {{-1,-2,2},{1,1,1}}, TestID -> "case-49-cfg2"]
VerificationTest[Einsum["...ii->...i", {{{-1,-1,2},{-1,-2,2},{-1,-1,2}},{{1,1,2},{-2,1,1},{1,0,1}}}, "BatchMethod" -> "Dot"], {{-1,-2,2},{1,1,1}}, TestID -> "case-49-cfg3"]
VerificationTest[Einsum["...ii->...i", {{{-1,-1,2},{-1,-2,2},{-1,-1,2}},{{1,1,2},{-2,1,1},{1,0,1}}}, "BatchMethod" -> "Vectorized"], {{-1,-2,2},{1,1,1}}, TestID -> "case-49-cfg4"]
VerificationTest[Einsum["...,...->...", {{1,2,-1},{-1,0,1}}, {{-1,2,1},{2,1,2}}], {{-1,4,-1},{-2,0,2}}, TestID -> "case-50"]
VerificationTest[Einsum["...,...->...", {{1,2,-1},{-1,0,1}}, {{-1,2,1},{2,1,2}}, "Path" -> "Greedy"], {{-1,4,-1},{-2,0,2}}, TestID -> "case-50-cfg1"]
VerificationTest[Einsum["...,...->...", {{1,2,-1},{-1,0,1}}, {{-1,2,1},{2,1,2}}, "Path" -> "Sequential"], {{-1,4,-1},{-2,0,2}}, TestID -> "case-50-cfg2"]
VerificationTest[Einsum["...,...->...", {{1,2,-1},{-1,0,1}}, {{-1,2,1},{2,1,2}}, "BatchMethod" -> "Dot"], {{-1,4,-1},{-2,0,2}}, TestID -> "case-50-cfg3"]
VerificationTest[Einsum["...,...->...", {{1,2,-1},{-1,0,1}}, {{-1,2,1},{2,1,2}}, "BatchMethod" -> "Vectorized"], {{-1,4,-1},{-2,0,2}}, TestID -> "case-50-cfg4"]
VerificationTest[Einsum["ij...,jk...->ik...", {{{0,2},{1,-2},{-1,-1}},{{1,0},{-1,2},{2,0}}}, {{{-1,-1},{-1,-2},{0,-1},{1,1}},{{-1,-2},{0,-2},{1,-1},{2,0}},{{1,-1},{0,2},{0,-1},{-2,0}}}], {{{-2,3},{0,-2},{1,1},{4,2}},{{2,-4},{-1,-4},{-1,-2},{-5,0}}}, TestID -> "case-51"]
VerificationTest[Einsum["ij...,jk...->ik...", {{{0,2},{1,-2},{-1,-1}},{{1,0},{-1,2},{2,0}}}, {{{-1,-1},{-1,-2},{0,-1},{1,1}},{{-1,-2},{0,-2},{1,-1},{2,0}},{{1,-1},{0,2},{0,-1},{-2,0}}}, "Path" -> "Greedy"], {{{-2,3},{0,-2},{1,1},{4,2}},{{2,-4},{-1,-4},{-1,-2},{-5,0}}}, TestID -> "case-51-cfg1"]
VerificationTest[Einsum["ij...,jk...->ik...", {{{0,2},{1,-2},{-1,-1}},{{1,0},{-1,2},{2,0}}}, {{{-1,-1},{-1,-2},{0,-1},{1,1}},{{-1,-2},{0,-2},{1,-1},{2,0}},{{1,-1},{0,2},{0,-1},{-2,0}}}, "Path" -> "Sequential"], {{{-2,3},{0,-2},{1,1},{4,2}},{{2,-4},{-1,-4},{-1,-2},{-5,0}}}, TestID -> "case-51-cfg2"]
VerificationTest[Einsum["ij...,jk...->ik...", {{{0,2},{1,-2},{-1,-1}},{{1,0},{-1,2},{2,0}}}, {{{-1,-1},{-1,-2},{0,-1},{1,1}},{{-1,-2},{0,-2},{1,-1},{2,0}},{{1,-1},{0,2},{0,-1},{-2,0}}}, "BatchMethod" -> "Dot"], {{{-2,3},{0,-2},{1,1},{4,2}},{{2,-4},{-1,-4},{-1,-2},{-5,0}}}, TestID -> "case-51-cfg3"]
VerificationTest[Einsum["ij...,jk...->ik...", {{{0,2},{1,-2},{-1,-1}},{{1,0},{-1,2},{2,0}}}, {{{-1,-1},{-1,-2},{0,-1},{1,1}},{{-1,-2},{0,-2},{1,-1},{2,0}},{{1,-1},{0,2},{0,-1},{-2,0}}}, "BatchMethod" -> "Vectorized"], {{{-2,3},{0,-2},{1,1},{4,2}},{{2,-4},{-1,-4},{-1,-2},{-5,0}}}, TestID -> "case-51-cfg4"]
VerificationTest[Einsum["ab,bc,cd,de,ef,fg,gh,hi,ij->aj", {{2,1,-2},{2,1,2}}, {{2,-2},{-2,1},{2,1}}, {{2,0,2},{-2,-2,-2}}, {{-1,1},{-1,-2},{2,-1}}, {{2,-1,1},{1,1,-1}}, {{1,-2},{-1,-1},{2,-1}}, {{-2,1,0},{-1,2,1}}, {{-1,0},{2,2},{2,1}}, {{1,0},{-2,0}}], {{-168,0},{120,0}}, TestID -> "case-52"]
VerificationTest[Einsum["ab,bc,cd,de,ef,fg,gh,hi,ij->aj", {{2,1,-2},{2,1,2}}, {{2,-2},{-2,1},{2,1}}, {{2,0,2},{-2,-2,-2}}, {{-1,1},{-1,-2},{2,-1}}, {{2,-1,1},{1,1,-1}}, {{1,-2},{-1,-1},{2,-1}}, {{-2,1,0},{-1,2,1}}, {{-1,0},{2,2},{2,1}}, {{1,0},{-2,0}}, "Path" -> "Greedy"], {{-168,0},{120,0}}, TestID -> "case-52-cfg1"]
VerificationTest[Einsum["ab,bc,cd,de,ef,fg,gh,hi,ij->aj", {{2,1,-2},{2,1,2}}, {{2,-2},{-2,1},{2,1}}, {{2,0,2},{-2,-2,-2}}, {{-1,1},{-1,-2},{2,-1}}, {{2,-1,1},{1,1,-1}}, {{1,-2},{-1,-1},{2,-1}}, {{-2,1,0},{-1,2,1}}, {{-1,0},{2,2},{2,1}}, {{1,0},{-2,0}}, "Path" -> "Sequential"], {{-168,0},{120,0}}, TestID -> "case-52-cfg2"]
VerificationTest[Einsum["ab,bc,cd,de,ef,fg,gh,hi,ij->aj", {{2,1,-2},{2,1,2}}, {{2,-2},{-2,1},{2,1}}, {{2,0,2},{-2,-2,-2}}, {{-1,1},{-1,-2},{2,-1}}, {{2,-1,1},{1,1,-1}}, {{1,-2},{-1,-1},{2,-1}}, {{-2,1,0},{-1,2,1}}, {{-1,0},{2,2},{2,1}}, {{1,0},{-2,0}}, "BatchMethod" -> "Dot"], {{-168,0},{120,0}}, TestID -> "case-52-cfg3"]
VerificationTest[Einsum["ab,bc,cd,de,ef,fg,gh,hi,ij->aj", {{2,1,-2},{2,1,2}}, {{2,-2},{-2,1},{2,1}}, {{2,0,2},{-2,-2,-2}}, {{-1,1},{-1,-2},{2,-1}}, {{2,-1,1},{1,1,-1}}, {{1,-2},{-1,-1},{2,-1}}, {{-2,1,0},{-1,2,1}}, {{-1,0},{2,2},{2,1}}, {{1,0},{-2,0}}, "BatchMethod" -> "Vectorized"], {{-168,0},{120,0}}, TestID -> "case-52-cfg4"]
VerificationTest[Einsum["abc,cde,efg,gha->bdfh", {{{0,0},{-2,2}},{{-2,-2},{-1,0}}}, {{{-2,0},{-1,0}},{{-2,0},{1,0}}}, {{{-1,0},{2,1}},{{-2,-1},{1,1}}}, {{{-2,1},{-2,-2}},{{1,-1},{1,2}}}], {{{{-8,16},{8,-16}},{{0,0},{0,0}}},{{{-2,4},{2,-4}},{{7,10},{-11,-14}}}}, TestID -> "case-53"]
VerificationTest[Einsum["abc,cde,efg,gha->bdfh", {{{0,0},{-2,2}},{{-2,-2},{-1,0}}}, {{{-2,0},{-1,0}},{{-2,0},{1,0}}}, {{{-1,0},{2,1}},{{-2,-1},{1,1}}}, {{{-2,1},{-2,-2}},{{1,-1},{1,2}}}, "Path" -> "Greedy"], {{{{-8,16},{8,-16}},{{0,0},{0,0}}},{{{-2,4},{2,-4}},{{7,10},{-11,-14}}}}, TestID -> "case-53-cfg1"]
VerificationTest[Einsum["abc,cde,efg,gha->bdfh", {{{0,0},{-2,2}},{{-2,-2},{-1,0}}}, {{{-2,0},{-1,0}},{{-2,0},{1,0}}}, {{{-1,0},{2,1}},{{-2,-1},{1,1}}}, {{{-2,1},{-2,-2}},{{1,-1},{1,2}}}, "Path" -> "Sequential"], {{{{-8,16},{8,-16}},{{0,0},{0,0}}},{{{-2,4},{2,-4}},{{7,10},{-11,-14}}}}, TestID -> "case-53-cfg2"]
VerificationTest[Einsum["abc,cde,efg,gha->bdfh", {{{0,0},{-2,2}},{{-2,-2},{-1,0}}}, {{{-2,0},{-1,0}},{{-2,0},{1,0}}}, {{{-1,0},{2,1}},{{-2,-1},{1,1}}}, {{{-2,1},{-2,-2}},{{1,-1},{1,2}}}, "BatchMethod" -> "Dot"], {{{{-8,16},{8,-16}},{{0,0},{0,0}}},{{{-2,4},{2,-4}},{{7,10},{-11,-14}}}}, TestID -> "case-53-cfg3"]
VerificationTest[Einsum["abc,cde,efg,gha->bdfh", {{{0,0},{-2,2}},{{-2,-2},{-1,0}}}, {{{-2,0},{-1,0}},{{-2,0},{1,0}}}, {{{-1,0},{2,1}},{{-2,-1},{1,1}}}, {{{-2,1},{-2,-2}},{{1,-1},{1,2}}}, "BatchMethod" -> "Vectorized"], {{{{-8,16},{8,-16}},{{0,0},{0,0}}},{{{-2,4},{2,-4}},{{7,10},{-11,-14}}}}, TestID -> "case-53-cfg4"]
VerificationTest[Einsum["ea,fb,abcd,gc,hd->efgh", {{-1,2,0},{2,1,-2}}, {{-1,2,1},{2,2,2}}, {{{{-2,1,-1},{1,2,1},{2,0,0}},{{1,-1,0},{2,-1,1},{-2,2,2}},{{0,1,0},{-2,0,2},{-1,-1,1}}},{{{1,0,-1},{2,-1,-1},{-2,-1,-2}},{{-1,-2,0},{-2,-2,-2},{-2,2,1}},{{0,-1,-2},{0,0,0},{0,0,0}}},{{{-2,-1,-2},{0,0,2},{0,-1,2}},{{0,-1,2},{1,-1,2},{1,-2,0}},{{0,1,0},{-1,0,0},{0,-1,-1}}}}, {{2,2,2},{-2,1,-1}}, {{2,1,1},{1,2,-1}}], {{{{-104,-34},{9,24}},{{-188,-52},{38,22}}},{{{-78,-54},{17,-5}},{{0,108},{8,-44}}}}, TestID -> "case-54"]
VerificationTest[Einsum["ea,fb,abcd,gc,hd->efgh", {{-1,2,0},{2,1,-2}}, {{-1,2,1},{2,2,2}}, {{{{-2,1,-1},{1,2,1},{2,0,0}},{{1,-1,0},{2,-1,1},{-2,2,2}},{{0,1,0},{-2,0,2},{-1,-1,1}}},{{{1,0,-1},{2,-1,-1},{-2,-1,-2}},{{-1,-2,0},{-2,-2,-2},{-2,2,1}},{{0,-1,-2},{0,0,0},{0,0,0}}},{{{-2,-1,-2},{0,0,2},{0,-1,2}},{{0,-1,2},{1,-1,2},{1,-2,0}},{{0,1,0},{-1,0,0},{0,-1,-1}}}}, {{2,2,2},{-2,1,-1}}, {{2,1,1},{1,2,-1}}, "Path" -> "Greedy"], {{{{-104,-34},{9,24}},{{-188,-52},{38,22}}},{{{-78,-54},{17,-5}},{{0,108},{8,-44}}}}, TestID -> "case-54-cfg1"]
VerificationTest[Einsum["ea,fb,abcd,gc,hd->efgh", {{-1,2,0},{2,1,-2}}, {{-1,2,1},{2,2,2}}, {{{{-2,1,-1},{1,2,1},{2,0,0}},{{1,-1,0},{2,-1,1},{-2,2,2}},{{0,1,0},{-2,0,2},{-1,-1,1}}},{{{1,0,-1},{2,-1,-1},{-2,-1,-2}},{{-1,-2,0},{-2,-2,-2},{-2,2,1}},{{0,-1,-2},{0,0,0},{0,0,0}}},{{{-2,-1,-2},{0,0,2},{0,-1,2}},{{0,-1,2},{1,-1,2},{1,-2,0}},{{0,1,0},{-1,0,0},{0,-1,-1}}}}, {{2,2,2},{-2,1,-1}}, {{2,1,1},{1,2,-1}}, "Path" -> "Sequential"], {{{{-104,-34},{9,24}},{{-188,-52},{38,22}}},{{{-78,-54},{17,-5}},{{0,108},{8,-44}}}}, TestID -> "case-54-cfg2"]
VerificationTest[Einsum["ea,fb,abcd,gc,hd->efgh", {{-1,2,0},{2,1,-2}}, {{-1,2,1},{2,2,2}}, {{{{-2,1,-1},{1,2,1},{2,0,0}},{{1,-1,0},{2,-1,1},{-2,2,2}},{{0,1,0},{-2,0,2},{-1,-1,1}}},{{{1,0,-1},{2,-1,-1},{-2,-1,-2}},{{-1,-2,0},{-2,-2,-2},{-2,2,1}},{{0,-1,-2},{0,0,0},{0,0,0}}},{{{-2,-1,-2},{0,0,2},{0,-1,2}},{{0,-1,2},{1,-1,2},{1,-2,0}},{{0,1,0},{-1,0,0},{0,-1,-1}}}}, {{2,2,2},{-2,1,-1}}, {{2,1,1},{1,2,-1}}, "BatchMethod" -> "Dot"], {{{{-104,-34},{9,24}},{{-188,-52},{38,22}}},{{{-78,-54},{17,-5}},{{0,108},{8,-44}}}}, TestID -> "case-54-cfg3"]
VerificationTest[Einsum["ea,fb,abcd,gc,hd->efgh", {{-1,2,0},{2,1,-2}}, {{-1,2,1},{2,2,2}}, {{{{-2,1,-1},{1,2,1},{2,0,0}},{{1,-1,0},{2,-1,1},{-2,2,2}},{{0,1,0},{-2,0,2},{-1,-1,1}}},{{{1,0,-1},{2,-1,-1},{-2,-1,-2}},{{-1,-2,0},{-2,-2,-2},{-2,2,1}},{{0,-1,-2},{0,0,0},{0,0,0}}},{{{-2,-1,-2},{0,0,2},{0,-1,2}},{{0,-1,2},{1,-1,2},{1,-2,0}},{{0,1,0},{-1,0,0},{0,-1,-1}}}}, {{2,2,2},{-2,1,-1}}, {{2,1,1},{1,2,-1}}, "BatchMethod" -> "Vectorized"], {{{{-104,-34},{9,24}},{{-188,-52},{38,22}}},{{{-78,-54},{17,-5}},{{0,108},{8,-44}}}}, TestID -> "case-54-cfg4"]
VerificationTest[Einsum["bdik,acaj,ikab,ajac,ikbd->", {{{{2,-1},{-1,-1}},{{2,-2},{-1,2}}},{{{0,-2},{-2,2}},{{2,1},{-1,-2}}}}, {{{{1,2},{-1,-2}},{{-1,-1},{-1,0}},{{-1,2},{-2,1}}},{{{1,0},{2,2}},{{-1,-2},{-2,-2}},{{-1,-1},{-2,0}}}}, {{{{1,2},{-1,-1}},{{0,0},{2,0}}},{{{2,-2},{2,0}},{{2,-2},{0,0}}}}, {{{{0,-1,-2},{-2,-2,0}},{{0,0,2},{-1,0,-2}}},{{{-2,2,-1},{-2,1,2}},{{-2,0,-2},{0,-1,-1}}}}, {{{{1,2},{2,-2}},{{-1,2},{0,-1}}},{{{0,2},{0,-2}},{{0,2},{2,1}}}}], 54, TestID -> "case-55"]
VerificationTest[Einsum["bdik,acaj,ikab,ajac,ikbd->", {{{{2,-1},{-1,-1}},{{2,-2},{-1,2}}},{{{0,-2},{-2,2}},{{2,1},{-1,-2}}}}, {{{{1,2},{-1,-2}},{{-1,-1},{-1,0}},{{-1,2},{-2,1}}},{{{1,0},{2,2}},{{-1,-2},{-2,-2}},{{-1,-1},{-2,0}}}}, {{{{1,2},{-1,-1}},{{0,0},{2,0}}},{{{2,-2},{2,0}},{{2,-2},{0,0}}}}, {{{{0,-1,-2},{-2,-2,0}},{{0,0,2},{-1,0,-2}}},{{{-2,2,-1},{-2,1,2}},{{-2,0,-2},{0,-1,-1}}}}, {{{{1,2},{2,-2}},{{-1,2},{0,-1}}},{{{0,2},{0,-2}},{{0,2},{2,1}}}}, "Path" -> "Greedy"], 54, TestID -> "case-55-cfg1"]
VerificationTest[Einsum["bdik,acaj,ikab,ajac,ikbd->", {{{{2,-1},{-1,-1}},{{2,-2},{-1,2}}},{{{0,-2},{-2,2}},{{2,1},{-1,-2}}}}, {{{{1,2},{-1,-2}},{{-1,-1},{-1,0}},{{-1,2},{-2,1}}},{{{1,0},{2,2}},{{-1,-2},{-2,-2}},{{-1,-1},{-2,0}}}}, {{{{1,2},{-1,-1}},{{0,0},{2,0}}},{{{2,-2},{2,0}},{{2,-2},{0,0}}}}, {{{{0,-1,-2},{-2,-2,0}},{{0,0,2},{-1,0,-2}}},{{{-2,2,-1},{-2,1,2}},{{-2,0,-2},{0,-1,-1}}}}, {{{{1,2},{2,-2}},{{-1,2},{0,-1}}},{{{0,2},{0,-2}},{{0,2},{2,1}}}}, "Path" -> "Sequential"], 54, TestID -> "case-55-cfg2"]
VerificationTest[Einsum["bdik,acaj,ikab,ajac,ikbd->", {{{{2,-1},{-1,-1}},{{2,-2},{-1,2}}},{{{0,-2},{-2,2}},{{2,1},{-1,-2}}}}, {{{{1,2},{-1,-2}},{{-1,-1},{-1,0}},{{-1,2},{-2,1}}},{{{1,0},{2,2}},{{-1,-2},{-2,-2}},{{-1,-1},{-2,0}}}}, {{{{1,2},{-1,-1}},{{0,0},{2,0}}},{{{2,-2},{2,0}},{{2,-2},{0,0}}}}, {{{{0,-1,-2},{-2,-2,0}},{{0,0,2},{-1,0,-2}}},{{{-2,2,-1},{-2,1,2}},{{-2,0,-2},{0,-1,-1}}}}, {{{{1,2},{2,-2}},{{-1,2},{0,-1}}},{{{0,2},{0,-2}},{{0,2},{2,1}}}}, "BatchMethod" -> "Dot"], 54, TestID -> "case-55-cfg3"]
VerificationTest[Einsum["bdik,acaj,ikab,ajac,ikbd->", {{{{2,-1},{-1,-1}},{{2,-2},{-1,2}}},{{{0,-2},{-2,2}},{{2,1},{-1,-2}}}}, {{{{1,2},{-1,-2}},{{-1,-1},{-1,0}},{{-1,2},{-2,1}}},{{{1,0},{2,2}},{{-1,-2},{-2,-2}},{{-1,-1},{-2,0}}}}, {{{{1,2},{-1,-1}},{{0,0},{2,0}}},{{{2,-2},{2,0}},{{2,-2},{0,0}}}}, {{{{0,-1,-2},{-2,-2,0}},{{0,0,2},{-1,0,-2}}},{{{-2,2,-1},{-2,1,2}},{{-2,0,-2},{0,-1,-1}}}}, {{{{1,2},{2,-2}},{{-1,2},{0,-1}}},{{{0,2},{0,-2}},{{0,2},{2,1}}}}, "BatchMethod" -> "Vectorized"], 54, TestID -> "case-55-cfg4"]
VerificationTest[Einsum["ab,cd,ef->abcdef", {{-1},{0}}, {{0,1}}, {{-2,-2},{0,-2}}], {{{{{{0,0},{0,0}},{{2,2},{0,2}}}}},{{{{{0,0},{0,0}},{{0,0},{0,0}}}}}}, TestID -> "case-56"]
VerificationTest[Einsum["ab,cd,ef->abcdef", {{-1},{0}}, {{0,1}}, {{-2,-2},{0,-2}}, "Path" -> "Greedy"], {{{{{{0,0},{0,0}},{{2,2},{0,2}}}}},{{{{{0,0},{0,0}},{{0,0},{0,0}}}}}}, TestID -> "case-56-cfg1"]
VerificationTest[Einsum["ab,cd,ef->abcdef", {{-1},{0}}, {{0,1}}, {{-2,-2},{0,-2}}, "Path" -> "Sequential"], {{{{{{0,0},{0,0}},{{2,2},{0,2}}}}},{{{{{0,0},{0,0}},{{0,0},{0,0}}}}}}, TestID -> "case-56-cfg2"]
VerificationTest[Einsum["ab,cd,ef->abcdef", {{-1},{0}}, {{0,1}}, {{-2,-2},{0,-2}}, "BatchMethod" -> "Dot"], {{{{{{0,0},{0,0}},{{2,2},{0,2}}}}},{{{{{0,0},{0,0}},{{0,0},{0,0}}}}}}, TestID -> "case-56-cfg3"]
VerificationTest[Einsum["ab,cd,ef->abcdef", {{-1},{0}}, {{0,1}}, {{-2,-2},{0,-2}}, "BatchMethod" -> "Vectorized"], {{{{{{0,0},{0,0}},{{2,2},{0,2}}}}},{{{{{0,0},{0,0}},{{0,0},{0,0}}}}}}, TestID -> "case-56-cfg4"]
VerificationTest[Einsum["\[Alpha]\[Beta],\[Beta]\[Gamma]->\[Alpha]\[Gamma]", {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}], {{-3,3},{-1,5}}, TestID -> "case-57"]
VerificationTest[Einsum["\[Alpha]\[Beta],\[Beta]\[Gamma]->\[Alpha]\[Gamma]", {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}, "Path" -> "Greedy"], {{-3,3},{-1,5}}, TestID -> "case-57-cfg1"]
VerificationTest[Einsum["\[Alpha]\[Beta],\[Beta]\[Gamma]->\[Alpha]\[Gamma]", {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}, "Path" -> "Sequential"], {{-3,3},{-1,5}}, TestID -> "case-57-cfg2"]
VerificationTest[Einsum["\[Alpha]\[Beta],\[Beta]\[Gamma]->\[Alpha]\[Gamma]", {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}, "BatchMethod" -> "Dot"], {{-3,3},{-1,5}}, TestID -> "case-57-cfg3"]
VerificationTest[Einsum["\[Alpha]\[Beta],\[Beta]\[Gamma]->\[Alpha]\[Gamma]", {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}, "BatchMethod" -> "Vectorized"], {{-3,3},{-1,5}}, TestID -> "case-57-cfg4"]
VerificationTest[Einsum[{{1,2},{2,3}}->{1,3}, {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}], {{-3,3},{-1,5}}, TestID -> "case-58"]
VerificationTest[Einsum[{{1,2},{2,3}}->{1,3}, {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}, "Path" -> "Greedy"], {{-3,3},{-1,5}}, TestID -> "case-58-cfg1"]
VerificationTest[Einsum[{{1,2},{2,3}}->{1,3}, {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}, "Path" -> "Sequential"], {{-3,3},{-1,5}}, TestID -> "case-58-cfg2"]
VerificationTest[Einsum[{{1,2},{2,3}}->{1,3}, {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}, "BatchMethod" -> "Dot"], {{-3,3},{-1,5}}, TestID -> "case-58-cfg3"]
VerificationTest[Einsum[{{1,2},{2,3}}->{1,3}, {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}, "BatchMethod" -> "Vectorized"], {{-3,3},{-1,5}}, TestID -> "case-58-cfg4"]
VerificationTest[Einsum[{{"x1","bond"},{"bond","y"}}->{"y","x1"}, {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}], {{-3,-1},{3,5}}, TestID -> "case-59"]
VerificationTest[Einsum[{{"x1","bond"},{"bond","y"}}->{"y","x1"}, {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}, "Path" -> "Greedy"], {{-3,-1},{3,5}}, TestID -> "case-59-cfg1"]
VerificationTest[Einsum[{{"x1","bond"},{"bond","y"}}->{"y","x1"}, {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}, "Path" -> "Sequential"], {{-3,-1},{3,5}}, TestID -> "case-59-cfg2"]
VerificationTest[Einsum[{{"x1","bond"},{"bond","y"}}->{"y","x1"}, {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}, "BatchMethod" -> "Dot"], {{-3,-1},{3,5}}, TestID -> "case-59-cfg3"]
VerificationTest[Einsum[{{"x1","bond"},{"bond","y"}}->{"y","x1"}, {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}, "BatchMethod" -> "Vectorized"], {{-3,-1},{3,5}}, TestID -> "case-59-cfg4"]
VerificationTest[Einsum[{{i,j},{j,k}}, {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}], {{-3,3},{-1,5}}, TestID -> "case-60"]
VerificationTest[Einsum[{{i,j},{j,k}}, {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}, "Path" -> "Greedy"], {{-3,3},{-1,5}}, TestID -> "case-60-cfg1"]
VerificationTest[Einsum[{{i,j},{j,k}}, {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}, "Path" -> "Sequential"], {{-3,3},{-1,5}}, TestID -> "case-60-cfg2"]
VerificationTest[Einsum[{{i,j},{j,k}}, {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}, "BatchMethod" -> "Dot"], {{-3,3},{-1,5}}, TestID -> "case-60-cfg3"]
VerificationTest[Einsum[{{i,j},{j,k}}, {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}, "BatchMethod" -> "Vectorized"], {{-3,3},{-1,5}}, TestID -> "case-60-cfg4"]
VerificationTest[Einsum[{"ijk","ijk","ijk"}->"", {{{-2,1},{0,2},{1,2}},{{2,-2},{2,-2},{-1,-1}}}, {{{-2,1},{0,2},{1,2}},{{2,-2},{2,-2},{-1,-1}}}, {{{-2,1},{0,2},{1,2}},{{2,-2},{2,-2},{-1,-1}}}], 8, TestID -> "case-61"]
VerificationTest[Einsum[{"ijk","ijk","ijk"}->"", {{{-2,1},{0,2},{1,2}},{{2,-2},{2,-2},{-1,-1}}}, {{{-2,1},{0,2},{1,2}},{{2,-2},{2,-2},{-1,-1}}}, {{{-2,1},{0,2},{1,2}},{{2,-2},{2,-2},{-1,-1}}}, "Path" -> "Greedy"], 8, TestID -> "case-61-cfg1"]
VerificationTest[Einsum[{"ijk","ijk","ijk"}->"", {{{-2,1},{0,2},{1,2}},{{2,-2},{2,-2},{-1,-1}}}, {{{-2,1},{0,2},{1,2}},{{2,-2},{2,-2},{-1,-1}}}, {{{-2,1},{0,2},{1,2}},{{2,-2},{2,-2},{-1,-1}}}, "Path" -> "Sequential"], 8, TestID -> "case-61-cfg2"]
VerificationTest[Einsum[{"ijk","ijk","ijk"}->"", {{{-2,1},{0,2},{1,2}},{{2,-2},{2,-2},{-1,-1}}}, {{{-2,1},{0,2},{1,2}},{{2,-2},{2,-2},{-1,-1}}}, {{{-2,1},{0,2},{1,2}},{{2,-2},{2,-2},{-1,-1}}}, "BatchMethod" -> "Dot"], 8, TestID -> "case-61-cfg3"]
VerificationTest[Einsum[{"ijk","ijk","ijk"}->"", {{{-2,1},{0,2},{1,2}},{{2,-2},{2,-2},{-1,-1}}}, {{{-2,1},{0,2},{1,2}},{{2,-2},{2,-2},{-1,-1}}}, {{{-2,1},{0,2},{1,2}},{{2,-2},{2,-2},{-1,-1}}}, "BatchMethod" -> "Vectorized"], 8, TestID -> "case-61-cfg4"]
VerificationTest[Einsum["ij , jk -> ik", {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}], {{-3,3},{-1,5}}, TestID -> "case-62"]
VerificationTest[Einsum["ij , jk -> ik", {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}, "Path" -> "Greedy"], {{-3,3},{-1,5}}, TestID -> "case-62-cfg1"]
VerificationTest[Einsum["ij , jk -> ik", {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}, "Path" -> "Sequential"], {{-3,3},{-1,5}}, TestID -> "case-62-cfg2"]
VerificationTest[Einsum["ij , jk -> ik", {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}, "BatchMethod" -> "Dot"], {{-3,3},{-1,5}}, TestID -> "case-62-cfg3"]
VerificationTest[Einsum["ij , jk -> ik", {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}, "BatchMethod" -> "Vectorized"], {{-3,3},{-1,5}}, TestID -> "case-62-cfg4"]
VerificationTest[Einsum["ij,jk\[Rule]ik", {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}], {{-3,3},{-1,5}}, TestID -> "case-63"]
VerificationTest[Einsum["ij,jk\[Rule]ik", {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}, "Path" -> "Greedy"], {{-3,3},{-1,5}}, TestID -> "case-63-cfg1"]
VerificationTest[Einsum["ij,jk\[Rule]ik", {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}, "Path" -> "Sequential"], {{-3,3},{-1,5}}, TestID -> "case-63-cfg2"]
VerificationTest[Einsum["ij,jk\[Rule]ik", {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}, "BatchMethod" -> "Dot"], {{-3,3},{-1,5}}, TestID -> "case-63-cfg3"]
VerificationTest[Einsum["ij,jk\[Rule]ik", {{1,0,2},{-1,0,2}}, {{-1,-1},{0,1},{-1,2}}, "BatchMethod" -> "Vectorized"], {{-3,3},{-1,5}}, TestID -> "case-63-cfg4"]
VerificationTest[Einsum["aa,a->a", {{2}}, {1}], {2}, TestID -> "case-64"]
VerificationTest[Einsum["ffhh,hhfh,f->h", {{{{-1,-1,-2},{-1,0,2},{-1,0,0}},{{-2,1,0},{1,1,0},{-1,2,1}},{{2,1,2},{2,0,2},{1,1,0}}},{{{-1,-1,-2},{1,2,2},{0,2,1}},{{-1,1,-1},{2,1,1},{1,2,2}},{{0,-2,2},{2,0,0},{-1,-1,2}}},{{{-1,-2,2},{2,2,0},{-2,2,-1}},{{1,1,2},{-2,2,-2},{-2,-2,-1}},{{2,2,-1},{1,-1,2},{1,0,-1}}}}, {{{{-2,1,0},{-1,2,-1},{-2,-1,0}},{{-2,-1,-2},{2,2,0},{2,2,0}},{{2,1,1},{2,-1,-1},{0,1,1}}},{{{1,1,-2},{-1,-2,2},{1,0,1}},{{-2,-2,1},{2,1,2},{0,-1,0}},{{-1,-1,-2},{2,0,0},{-2,2,0}}},{{{0,1,-2},{0,1,-2},{1,1,2}},{{1,-1,-2},{2,0,1},{2,0,-2}},{{0,2,-2},{2,-2,1},{1,2,-1}}}}, {-1,-2,1}], {-8,-1,-3}, TestID -> "case-65"]
VerificationTest[Einsum["ffhh,hhfh,f->h", {{{{-1,-1,-2},{-1,0,2},{-1,0,0}},{{-2,1,0},{1,1,0},{-1,2,1}},{{2,1,2},{2,0,2},{1,1,0}}},{{{-1,-1,-2},{1,2,2},{0,2,1}},{{-1,1,-1},{2,1,1},{1,2,2}},{{0,-2,2},{2,0,0},{-1,-1,2}}},{{{-1,-2,2},{2,2,0},{-2,2,-1}},{{1,1,2},{-2,2,-2},{-2,-2,-1}},{{2,2,-1},{1,-1,2},{1,0,-1}}}}, {{{{-2,1,0},{-1,2,-1},{-2,-1,0}},{{-2,-1,-2},{2,2,0},{2,2,0}},{{2,1,1},{2,-1,-1},{0,1,1}}},{{{1,1,-2},{-1,-2,2},{1,0,1}},{{-2,-2,1},{2,1,2},{0,-1,0}},{{-1,-1,-2},{2,0,0},{-2,2,0}}},{{{0,1,-2},{0,1,-2},{1,1,2}},{{1,-1,-2},{2,0,1},{2,0,-2}},{{0,2,-2},{2,-2,1},{1,2,-1}}}}, {-1,-2,1}, "Path" -> "Greedy"], {-8,-1,-3}, TestID -> "case-65-cfg1"]
VerificationTest[Einsum["behe,aha", {{{{2,-1,-2}},{{2,1,2}},{{-2,-2,0}}}}, {{{-2,-1}},{{-1,2}}}], {0}, TestID -> "case-66"]
VerificationTest[Einsum["d,,d,deg,edd->", {0}, -2, {1}, {{{-2},{-2}}}, {{{2}},{{2}}}], 0, TestID -> "case-67"]
VerificationTest[Einsum["g,be->ebg", {0,-2}, {{2,2,1},{1,0,2}}], {{{0,-4},{0,-2}},{{0,-4},{0,0}},{{0,-2},{0,-4}}}, TestID -> "case-68"]
VerificationTest[Einsum["ccc,c,cc,,ccc->c", {{{-2,2},{2,1}},{{-2,-1},{2,1}}}, {-1,-2}, {{0,1},{1,1}}, -1, {{{-2,-2},{0,1}},{{1,0},{1,0}}}], {0,0}, TestID -> "case-69"]
VerificationTest[Einsum["ccc,c,cc,,ccc->c", {{{-2,2},{2,1}},{{-2,-1},{2,1}}}, {-1,-2}, {{0,1},{1,1}}, -1, {{{-2,-2},{0,1}},{{1,0},{1,0}}}, "Path" -> "Sequential"], {0,0}, TestID -> "case-69-cfg2"]
VerificationTest[Einsum["hhh,hhhh,hhhh,hh", {{{0,2,-1},{0,-2,-2},{-2,-2,0}},{{-2,-1,-1},{-1,2,1},{2,2,-1}},{{2,-2,-1},{-2,1,0},{2,1,-2}}}, {{{{2,-1,2},{1,-1,-1},{-1,-2,2}},{{-1,2,-2},{1,0,2},{-2,2,-1}},{{-2,-1,-1},{-1,-1,-2},{0,0,0}}},{{{1,-2,-1},{1,2,-2},{2,1,-1}},{{2,-2,2},{1,0,-1},{-1,-1,0}},{{0,2,2},{2,-1,2},{0,1,1}}},{{{0,1,-1},{-1,-2,0},{2,0,0}},{{1,2,-2},{1,-2,1},{2,2,2}},{{2,2,2},{2,-1,2},{1,-1,2}}}}, {{{{1,2,1},{2,0,2},{1,2,-1}},{{2,2,-1},{0,1,-2},{2,-2,-2}},{{1,2,-1},{1,2,-2},{-2,-1,-1}}},{{{0,2,2},{0,1,2},{2,1,1}},{{-2,-1,-1},{2,-1,-2},{2,2,-1}},{{2,0,-1},{0,0,-1},{1,1,2}}},{{{-2,-1,-1},{2,2,-1},{1,-1,0}},{{2,-1,-1},{-2,-1,0},{1,2,-1}},{{0,2,0},{0,2,2},{2,-2,2}}}}, {{1,2,0},{1,2,-1},{2,1,2}}], -16, TestID -> "case-70"]
VerificationTest[Einsum["bb,a->ba", {{1,-1,1},{0,1,1},{0,1,-2}}, {2,2}], {{2,2},{2,2},{-4,-4}}, TestID -> "case-71"]
VerificationTest[Einsum["e,->", {2}, -1], -2, TestID -> "case-72"]
VerificationTest[Einsum["bc,->", {{1,2,1},{1,2,0},{0,-2,0}}, -1], -5, TestID -> "case-73"]
VerificationTest[Einsum["bc,->", {{1,2,1},{1,2,0},{0,-2,0}}, -1, "BatchMethod" -> "Dot"], -5, TestID -> "case-73-cfg3"]
VerificationTest[Einsum["fh,eh,->", {{-2},{1}}, {{2},{1}}, 0], 0, TestID -> "case-74"]
VerificationTest[Einsum["bfh,e->eb", {{{1,1,2},{0,1,1}}}, {-1,-2}], {{-6},{-12}}, TestID -> "case-75"]
VerificationTest[Einsum["a,cbaa,cc,,->c", {2,2,1}, {{{{1,-1,0},{-1,0,0},{-1,-2,2}}},{{{1,-1,-1},{2,-2,1},{0,2,2}}}}, {{-1,1},{0,-2}}, -1, 0], {0,0}, TestID -> "case-76"]
VerificationTest[Einsum["a,e,bae,ebab,", {-1}, {0}, {{{1}}}, {{{{0,-2}},{{-1,0}}}}, -1], 0, TestID -> "case-77"]
VerificationTest[Einsum["a,e,bae,ebab,", {-1}, {0}, {{{1}}}, {{{{0,-2}},{{-1,0}}}}, -1, "BatchMethod" -> "Vectorized"], 0, TestID -> "case-77-cfg4"]
VerificationTest[Einsum["->", -2], -2, TestID -> "case-78"]
VerificationTest[Einsum["cce,c,eh->ech", {{{-2},{-2}},{{0},{-1}}}, {2,-1}, {{1}}], {{{-4},{1}}}, TestID -> "case-79"]
VerificationTest[Einsum[",bce,hbb->", -1, {{{2,-1,-2},{2,2,-1},{-2,-1,-1}},{{-1,0,0},{-1,-1,2},{-1,-2,2}},{{1,2,-1},{-2,0,0},{-2,0,1}}}, {{{2,2,1},{-1,0,-1},{1,-2,1}}}], 5, TestID -> "case-80"]
VerificationTest[Einsum["gaag,a,aaa->a", {{{{0,0},{2,-1}},{{-1,2},{-2,-2}}},{{{0,-2},{0,0}},{{-1,-2},{0,0}}}}, {1}, {{{2,1},{2,-2}},{{2,-1},{2,1}}}], {-4,-2}, TestID -> "case-81"]
VerificationTest[Einsum["gaag,a,aaa->a", {{{{0,0},{2,-1}},{{-1,2},{-2,-2}}},{{{0,-2},{0,0}},{{-1,-2},{0,0}}}}, {1}, {{{2,1},{2,-2}},{{2,-1},{2,1}}}, "Path" -> "Greedy"], {-4,-2}, TestID -> "case-81-cfg1"]
VerificationTest[Einsum["a,aaa,aaaa,aa->", {2}, {{{1,-2,2},{2,1,2},{-2,0,-2}},{{-1,0,0},{0,1,1},{1,2,-1}},{{2,1,2},{1,-1,-1},{0,0,2}}}, {{{{0,1,1},{-2,2,2},{0,1,-2}},{{-2,2,-1},{2,0,0},{1,-1,0}},{{0,1,0},{0,-2,2},{-2,2,1}}},{{{-2,-1,-2},{-1,2,2},{1,0,2}},{{-1,0,1},{-2,-2,-2},{2,1,-1}},{{-2,0,1},{0,0,-1},{1,0,2}}},{{{-2,-1,-2},{0,-2,1},{-2,-1,1}},{{-2,0,-2},{2,2,0},{1,1,-1}},{{2,-2,2},{1,-1,-1},{2,-1,2}}}}, {{-2,2,0},{2,-1,1},{2,1,0}}], 4, TestID -> "case-82"]
VerificationTest[Einsum["gh,hgg,gchh,dhh", {{2}}, {{{1}}}, {{{{-2}},{{2}}}}, {{{-2}},{{1}},{{-2}}}], {{8,-4,8},{-8,4,-8}}, TestID -> "case-83"]
VerificationTest[Einsum[",c,,,bg->", -2, {1,0,0}, -2, 0, {{-1,1},{-1,-1},{-2,0}}], 0, TestID -> "case-84"]
VerificationTest[Einsum["c->", {2,1}], 3, TestID -> "case-85"]
VerificationTest[Einsum["c->", {2,1}, "Path" -> "Sequential"], 3, TestID -> "case-85-cfg2"]
VerificationTest[Einsum[",,,a,aa->", 2, 2, 0, {1}, {{-1}}], 0, TestID -> "case-86"]
VerificationTest[Einsum["f,hbhg,->", {0}, {{{{0}},{{-2}},{{2}}}}, -1], 0, TestID -> "case-87"]
VerificationTest[Einsum["aaaa,a,,haa,h->ha", {{{{-2,1},{1,0}},{{0,-1},{1,0}}},{{{-1,-2},{-2,0}},{{-1,0},{-1,-2}}}}, {0,1}, -1, {{{-2,1},{0,-1}},{{0,0},{-1,-2}},{{2,1},{-1,2}}}, {0,2,0}], {{0,0},{0,-8},{0,0}}, TestID -> "case-88"]
VerificationTest[Einsum[",,,hgh,ghh->", 1, -2, 0, {{{1},{-1}}}, {{{-2}},{{2}}}], 0, TestID -> "case-89"]
VerificationTest[Einsum[",,,hgh,ghh->", 1, -2, 0, {{{1},{-1}}}, {{{-2}},{{2}}}, "BatchMethod" -> "Dot"], 0, TestID -> "case-89-cfg3"]
VerificationTest[Einsum["g->", {-1}], -1, TestID -> "case-90"]
VerificationTest[Einsum["a->", {-2,0,1}], -1, TestID -> "case-91"]
VerificationTest[Einsum["aabf,f,,ff->a", {{{{-2,0},{-2,-1}},{{-1,2},{0,2}},{{-2,-1},{0,2}}},{{{0,0},{0,1}},{{-2,1},{1,1}},{{1,-2},{-1,2}}},{{{0,-2},{1,-2}},{{2,1},{-1,1}},{{1,-1},{0,2}}}}, {2,-2}, 2, {{2,-1},{1,-1}}], {-36,0,12}, TestID -> "case-92"]
VerificationTest[Einsum["eegg,ef,,g,egfe->", {{{{0,1},{-1,-1}},{{0,-2},{2,1}}},{{{-2,-1},{1,-2}},{{-2,-2},{-1,2}}}}, {{2,1},{-2,1}}, 1, {0,-2}, {{{{0,0},{-2,1}},{{0,-2},{-2,2}}},{{{-2,-1},{1,0}},{{-1,-1},{0,1}}}}], -16, TestID -> "case-93"]
VerificationTest[Einsum["eegg,ef,,g,egfe->", {{{{0,1},{-1,-1}},{{0,-2},{2,1}}},{{{-2,-1},{1,-2}},{{-2,-2},{-1,2}}}}, {{2,1},{-2,1}}, 1, {0,-2}, {{{{0,0},{-2,1}},{{0,-2},{-2,2}}},{{{-2,-1},{1,0}},{{-1,-1},{0,1}}}}, "BatchMethod" -> "Vectorized"], -16, TestID -> "case-93-cfg4"]
VerificationTest[Einsum["cccc,bccc->cb", {{{{2}}}}, {{{{2}}},{{{-2}}},{{{-2}}}}], {{4,-4,-4}}, TestID -> "case-94"]
VerificationTest[Einsum["de->d", {{2},{-2}}], {2,-2}, TestID -> "case-95"]
VerificationTest[Einsum["ga,bbdb->b", {{0,1,-2},{0,-2,1}}, {{{{-1,2,-1}},{{2,1,0}},{{0,2,1}}},{{{2,1,1}},{{1,-2,-1}},{{0,0,1}}},{{{0,2,-1}},{{0,2,1}},{{1,1,0}}}}], {2,4,0}, TestID -> "case-96"]
VerificationTest[Einsum["g->", {-2}], -2, TestID -> "case-97"]
VerificationTest[Einsum["g->", {-2}, "Path" -> "Greedy"], -2, TestID -> "case-97-cfg1"]
VerificationTest[Einsum["ffff,fff,,ffff,f->", {{{{0}}}}, {{{0}}}, 1, {{{{-1}}}}, {0}], 0, TestID -> "case-98"]
VerificationTest[Einsum["c,hf,h->", {1}, {{1,0},{1,-1}}, {0,1}], 0, TestID -> "case-99"]
VerificationTest[Einsum["f,,adae,dad->ead", {-2}, -1, {{{{2,0},{2,0},{2,1}},{{-1,-1},{2,0},{-2,0}}},{{{0,0},{-2,2},{0,2}},{{1,-1},{1,0},{-2,2}}},{{{2,2},{-1,-2},{1,-2}},{{2,1},{1,2},{0,-1}}}}, {{{0,2},{-2,0},{-1,1}},{{2,-1},{1,-1},{1,2}}}], {{{0,2},{8,-2},{-2,0}},{{0,2},{-8,0},{4,-4}}}, TestID -> "case-100"]
VerificationTest[Einsum["cc,cch,hhcc,cc", {{0,0,0},{-1,2,2},{-2,2,2}}, {{{-2,0},{1,2},{-1,-2}},{{1,-2},{-1,0},{1,-1}},{{1,0},{1,2},{0,2}}}, {{{{0,-2,2},{-1,1,-1},{-2,-2,1}},{{0,0,-2},{-1,-2,2},{-2,1,0}}},{{{0,2,-1},{-2,0,2},{2,-1,1}},{{1,-1,2},{-2,1,1},{1,-1,1}}}}, {{2,2,-2},{1,1,0},{2,-1,0}}], -2, TestID -> "case-101"]
VerificationTest[Einsum["cc,cch,hhcc,cc", {{0,0,0},{-1,2,2},{-2,2,2}}, {{{-2,0},{1,2},{-1,-2}},{{1,-2},{-1,0},{1,-1}},{{1,0},{1,2},{0,2}}}, {{{{0,-2,2},{-1,1,-1},{-2,-2,1}},{{0,0,-2},{-1,-2,2},{-2,1,0}}},{{{0,2,-1},{-2,0,2},{2,-1,1}},{{1,-1,2},{-2,1,1},{1,-1,1}}}}, {{2,2,-2},{1,1,0},{2,-1,0}}, "Path" -> "Sequential"], -2, TestID -> "case-101-cfg2"]
VerificationTest[Einsum["->", 2], 2, TestID -> "case-102"]
VerificationTest[Einsum["cdah,,agac->cadhg", {{{{-1,1},{-2,0}}}}, -2, {{{{0},{1}}},{{{-2},{1}}}}], {{{{{0},{0}}},{{{4},{0}}}}}, TestID -> "case-103"]
VerificationTest[Einsum["ca,,ca,c,acc->", {{0,0,0},{-1,1,0},{1,0,-2}}, 0, {{2,-1,-1},{-1,2,0},{2,-2,2}}, {-2,2,0}, {{{1,-1,2},{2,-1,-2},{2,-1,-2}},{{1,-1,-2},{2,0,0},{-1,-1,-1}},{{-1,-1,-2},{2,2,-1},{1,-2,2}}}], 0, TestID -> "case-104"]
VerificationTest[Einsum["acca,fa,,cahc,hfah->", {{{{2},{0},{2}},{{1},{2},{-2}},{{1},{0},{1}}}}, {{0}}, -2, {{{{2,-1,0},{-2,1,2}}},{{{0,2,0},{2,2,0}}},{{{0,-2,2},{-1,1,0}}}}, {{{{2,2}}},{{{0,1}}}}], 0, TestID -> "case-105"]
VerificationTest[Einsum["acca,fa,,cahc,hfah->", {{{{2},{0},{2}},{{1},{2},{-2}},{{1},{0},{1}}}}, {{0}}, -2, {{{{2,-1,0},{-2,1,2}}},{{{0,2,0},{2,2,0}}},{{{0,-2,2},{-1,1,0}}}}, {{{{2,2}}},{{{0,1}}}}, "BatchMethod" -> "Dot"], 0, TestID -> "case-105-cfg3"]
VerificationTest[Einsum["edce,c,c,d,cgcc->cdg", {{{{-1}},{{2}},{{2}}}}, {-1}, {0}, {1,0,0}, {{{{-2}},{{2}}}}], {{{0,0},{0,0},{0,0}}}, TestID -> "case-106"]
VerificationTest[Einsum["h->h", {0}], {0}, TestID -> "case-107"]
VerificationTest[Einsum["ee,cfc,hha,->ae", {{0,1,1},{0,-1,0},{1,2,-1}}, {{{-2,1}},{{2,-2}}}, {{{0}}}, -1], {{0,0,0}}, TestID -> "case-108"]
VerificationTest[Einsum[",fba,b,eb,e->bfae", 2, {{{-2,1},{1,1}}}, {1,-1}, {{1,-2},{-2,1},{-2,0}}, {0,2,-2}], {{{{0,16,-16},{0,-8,8}}},{{{0,-4,0},{0,-4,0}}}}, TestID -> "case-109"]
VerificationTest[Einsum[",fba,b,eb,e->bfae", 2, {{{-2,1},{1,1}}}, {1,-1}, {{1,-2},{-2,1},{-2,0}}, {0,2,-2}, "BatchMethod" -> "Vectorized"], {{{{0,16,-16},{0,-8,8}}},{{{0,-4,0},{0,-4,0}}}}, TestID -> "case-109-cfg4"]
VerificationTest[Einsum["bbdd,dd->bd", {{{{1,0},{-2,1}}}}, {{-2,0},{1,1}}], {{-2,1}}, TestID -> "case-110"]
VerificationTest[Einsum["fff,ffff,ff,ffff->f", {{{-1,0,2},{1,0,-1},{-1,0,-1}},{{-1,0,1},{0,2,0},{-1,-2,2}},{{2,-2,1},{2,-2,-1},{-2,1,-1}}}, {{{{1,2,-2},{-2,0,-2},{-2,-2,0}},{{0,0,0},{2,2,-2},{2,-2,0}},{{1,0,-1},{0,0,-2},{-1,-2,1}}},{{{0,-2,1},{0,1,1},{-1,2,-2}},{{-1,-2,0},{-2,2,1},{-2,2,2}},{{-2,1,-2},{2,1,0},{-2,0,0}}},{{{0,2,-1},{-2,-2,0},{0,0,-1}},{{2,0,2},{1,-2,-1},{-2,-2,-1}},{{2,0,2},{-1,-1,1},{1,0,-1}}}}, {{-2,1,-2},{-2,-2,2},{1,2,2}}, {{{{-2,1,1},{2,-1,2},{-1,2,2}},{{0,1,2},{0,2,1},{0,2,1}},{{-1,0,0},{1,-1,-1},{0,1,-2}}},{{{2,-1,1},{1,2,-1},{-1,1,-1}},{{1,-1,1},{0,0,1},{-1,-1,-2}},{{1,1,-1},{2,1,-1},{0,1,-2}}},{{{1,1,2},{1,1,-1},{-2,2,-2}},{{0,-1,2},{-2,1,1},{-1,-2,-2}},{{1,-2,1},{-1,-2,-1},{2,0,2}}}}], {-4,0,4}, TestID -> "case-111"]
VerificationTest[Einsum["->", -2], -2, TestID -> "case-112"]
VerificationTest[Einsum["ddg,->gd", {{{-1},{1},{-2}},{{0},{-2},{0}},{{1},{1},{-1}}}, 0], {{0,0,0}}, TestID -> "case-113"]
VerificationTest[Einsum["ddg,->gd", {{{-1},{1},{-2}},{{0},{-2},{0}},{{1},{1},{-1}}}, 0, "Path" -> "Greedy"], {{0,0,0}}, TestID -> "case-113-cfg1"]
VerificationTest[Einsum["cddd,d,cdc,cd,d->dc", {{{{0,-1,2},{-1,-2,-1},{-1,0,0}},{{1,1,0},{1,-1,0},{0,-1,-1}},{{-1,0,0},{-2,2,0},{-1,-1,-1}}},{{{-1,-2,0},{-2,-1,-2},{2,0,-2}},{{1,-2,0},{1,-2,-2},{-2,2,2}},{{1,1,1},{-1,2,2},{1,2,-2}}},{{{0,2,0},{-2,-1,-1},{-1,0,2}},{{0,1,-1},{2,-2,-2},{-1,-2,-1}},{{0,1,0},{1,0,1},{0,2,2}}}}, {0,0,-2}, {{{-1,-2,0},{-1,-1,0},{1,-2,0}},{{1,1,-1},{2,2,0},{0,-2,-1}},{{0,1,0},{-2,1,-2},{2,1,-2}}}, {{1,2,-2},{-2,2,0},{2,-2,0}}, {2,0,0}], {{0,0,0},{0,0,0},{0,0,0}}, TestID -> "case-114"]
VerificationTest[Einsum["h->", {2}], 2, TestID -> "case-115"]
VerificationTest[Einsum["dbgg,bbb,gdgb,dd,", {{{{0}}},{{{1}}},{{{1}}}}, {{{1}}}, {{{{-1}},{{0}},{{-1}}}}, {{-2,2,-1},{-2,1,2},{0,1,-1}}, -1], -1, TestID -> "case-116"]
VerificationTest[Einsum["aaaa->a", {{{{2}}}}], {2}, TestID -> "case-117"]
VerificationTest[Einsum["aaaa->a", {{{{2}}}}, "Path" -> "Sequential"], {2}, TestID -> "case-117-cfg2"]
VerificationTest[Einsum["bhh,g,fg,gbfg->gfhb", {{{2,-2,-2},{-1,0,1},{1,-1,1}}}, {-1,-2}, {{1,-2}}, {{{{0,-1}}},{{{2,-1}}}}], {{{{0},{0},{0}}},{{{-8},{0},{-4}}}}, TestID -> "case-118"]
VerificationTest[Einsum["g,,gbgb,->gb", {0,1}, 1, {{{{2,-2,2},{2,0,1}},{{1,1,-1},{1,0,1}},{{2,-2,0},{-2,0,-2}}},{{{1,0,0},{2,-2,0}},{{-1,-1,-2},{-2,2,-2}},{{1,-1,0},{1,-2,-1}}}}, -2], {{0,0,0},{-4,-4,2}}, TestID -> "case-119"]
VerificationTest[Einsum["e", {-2}], {-2}, TestID -> "case-120"]
VerificationTest[Einsum["cccc,,cccc,->", {{{{2,2,-2},{-2,-2,0},{-2,0,-2}},{{0,0,2},{-2,-1,1},{2,0,0}},{{-2,0,-2},{-2,0,0},{1,-2,0}}},{{{0,-1,0},{2,-2,0},{1,0,1}},{{2,2,1},{2,-2,2},{1,-1,-1}},{{2,1,-2},{0,0,0},{2,-2,2}}},{{{-2,2,2},{-1,-2,2},{-2,-2,0}},{{-2,2,2},{0,2,2},{1,1,1}},{{2,1,2},{-2,2,2},{2,-2,-1}}}}, 0, {{{{1,-2,0},{2,2,-1},{0,2,0}},{{0,-2,0},{1,1,-2},{-1,1,0}},{{-1,1,1},{-2,2,-2},{-1,2,0}}},{{{-1,0,-1},{-2,-2,1},{-2,1,-1}},{{1,-1,-1},{2,-2,0},{-1,-2,-2}},{{2,-1,1},{-2,0,0},{-1,-1,-2}}},{{{-1,-1,-1},{-1,-2,1},{0,2,1}},{{2,-1,-2},{0,-2,2},{2,0,2}},{{2,1,1},{2,0,-2},{-2,0,0}}}}, 2], 0, TestID -> "case-121"]
VerificationTest[Einsum["cccc,,cccc,->", {{{{2,2,-2},{-2,-2,0},{-2,0,-2}},{{0,0,2},{-2,-1,1},{2,0,0}},{{-2,0,-2},{-2,0,0},{1,-2,0}}},{{{0,-1,0},{2,-2,0},{1,0,1}},{{2,2,1},{2,-2,2},{1,-1,-1}},{{2,1,-2},{0,0,0},{2,-2,2}}},{{{-2,2,2},{-1,-2,2},{-2,-2,0}},{{-2,2,2},{0,2,2},{1,1,1}},{{2,1,2},{-2,2,2},{2,-2,-1}}}}, 0, {{{{1,-2,0},{2,2,-1},{0,2,0}},{{0,-2,0},{1,1,-2},{-1,1,0}},{{-1,1,1},{-2,2,-2},{-1,2,0}}},{{{-1,0,-1},{-2,-2,1},{-2,1,-1}},{{1,-1,-1},{2,-2,0},{-1,-2,-2}},{{2,-1,1},{-2,0,0},{-1,-1,-2}}},{{{-1,-1,-1},{-1,-2,1},{0,2,1}},{{2,-1,-2},{0,-2,2},{2,0,2}},{{2,1,1},{2,0,-2},{-2,0,0}}}}, 2, "BatchMethod" -> "Dot"], 0, TestID -> "case-121-cfg3"]
VerificationTest[Einsum["cccc->", {{{{-1,-1},{-2,2}},{{-1,-1},{2,1}}},{{{1,0},{2,2}},{{2,2},{-1,0}}}}], -1, TestID -> "case-122"]
VerificationTest[Einsum["df,eg,gfde->d", {{1,0,0}}, {{1},{0},{-2}}, {{{{1,-1,0}},{{2,0,2}},{{1,-1,-1}}}}], {1}, TestID -> "case-123"]
VerificationTest[Einsum[",bb,bb,dc,f", -1, {{-2}}, {{-2}}, {{1,-2,1},{2,2,-2}}, {1,-1}], {{{-4,4},{-8,8}},{{8,-8},{-8,8}},{{-4,4},{8,-8}}}, TestID -> "case-124"]
VerificationTest[Einsum["gcg,g,gg,,->cg", {{{0,1,-1}},{{0,-1,1}},{{-2,-2,2}}}, {-2,1,0}, {{2,1,1},{1,1,1},{-1,1,2}}, 2, 0], {{0,0,0}}, TestID -> "case-125"]
VerificationTest[Einsum["gcg,g,gg,,->cg", {{{0,1,-1}},{{0,-1,1}},{{-2,-2,2}}}, {-2,1,0}, {{2,1,1},{1,1,1},{-1,1,2}}, 2, 0, "BatchMethod" -> "Vectorized"], {{0,0,0}}, TestID -> "case-125-cfg4"]
VerificationTest[Einsum["cfac,g,a", {{{{0},{0}}}}, {1,2}, {2,1}], {{0,0}}, TestID -> "case-126"]
VerificationTest[Einsum["ggd,gdd,gg", {{{-1,0,-2},{1,0,1}},{{0,2,-2},{1,-1,0}}}, {{{-2,-1,-2},{-1,2,1},{0,-2,1}},{{-2,-1,-2},{-2,1,-1},{1,1,-2}}}, {{0,-1},{-2,-2}}], 6, TestID -> "case-127"]
VerificationTest[Einsum["gece,,ccab", {{{{-1,-1},{-2,-1}},{{-1,-1},{2,2}}}}, 0, {{{{0,-1,2},{-1,1,2},{1,0,1}},{{2,-1,0},{2,1,0},{1,-2,-2}}},{{{-1,-1,0},{-1,0,2},{2,2,1}},{{-1,1,-1},{-2,2,-2},{1,-1,-1}}}}], {{{0},{0},{0}},{{0},{0},{0}},{{0},{0},{0}}}, TestID -> "case-128"]
VerificationTest[Einsum["gbb,gb,g->g", {{{0,-2,2},{-1,-1,-2},{-1,2,1}},{{-2,1,-2},{-2,1,1},{0,2,2}},{{-1,1,1},{1,2,-2},{-1,0,2}}}, {{0,2,-1},{-2,-2,-1},{2,-1,-1}}, {2,-2,1}], {-6,0,-6}, TestID -> "case-129"]
VerificationTest[Einsum["gbb,gb,g->g", {{{0,-2,2},{-1,-1,-2},{-1,2,1}},{{-2,1,-2},{-2,1,1},{0,2,2}},{{-1,1,1},{1,2,-2},{-1,0,2}}}, {{0,2,-1},{-2,-2,-1},{2,-1,-1}}, {2,-2,1}, "Path" -> "Greedy"], {-6,0,-6}, TestID -> "case-129-cfg1"]
VerificationTest[Einsum["ddd,d,,dddd->", {{{-1,0},{0,-2}},{{-1,-1},{2,1}}}, {0,-1}, 1, {{{{-2,0},{1,0}},{{-1,-2},{-2,2}}},{{{1,0},{2,-2}},{{0,0},{-2,-2}}}}], 2, TestID -> "case-130"]
VerificationTest[Einsum["h,h,hh,haa,ha->h", {-1,0}, {-2,0}, {{0,1},{-1,1}}, {{{-2,2},{0,1}},{{1,0},{1,0}}}, {{-2,-1},{-1,-2}}], {0,0}, TestID -> "case-131"]
VerificationTest[Einsum[",,,bdc->", 0, 1, 2, {{{-2},{2},{2}},{{1},{-1},{2}},{{-2},{-1},{0}}}], 0, TestID -> "case-132"]
VerificationTest[Einsum["f->f", {-2,1,1}], {-2,1,1}, TestID -> "case-133"]
VerificationTest[Einsum["f->f", {-2,1,1}, "Path" -> "Sequential"], {-2,1,1}, TestID -> "case-133-cfg2"]
VerificationTest[Einsum["he,hdaa,dddh,hhhf,eaae->fh", {{1},{-2},{-2}}, {{{{-2,-1},{1,-2}},{{0,2},{1,0}},{{2,2},{0,-2}}},{{{0,2},{2,-1}},{{2,1},{1,-1}},{{1,0},{-2,1}}},{{{-2,-2},{1,2}},{{-1,2},{1,1}},{{-2,1},{-2,-1}}}}, {{{{1,-2,1},{-1,0,-2},{-2,-1,2}},{{1,-2,-2},{1,-2,2},{2,-2,2}},{{2,0,0},{-1,2,2},{1,-2,1}}},{{{-1,-1,2},{0,1,-2},{1,-1,0}},{{2,1,2},{-1,1,2},{-1,1,-2}},{{2,1,1},{1,1,-1},{-2,-1,0}}},{{{-1,-2,-2},{2,2,1},{-1,0,-2}},{{2,0,2},{-1,-1,1},{1,-2,-2}},{{1,-2,1},{1,-1,-1},{-2,0,2}}}}, {{{{0,-2},{2,-2},{1,2}},{{0,-2},{2,-2},{-1,2}},{{-2,-2},{-1,1},{0,-1}}},{{{-1,2},{2,2},{0,1}},{{0,0},{1,1},{0,-1}},{{-2,2},{-1,1},{0,-1}}},{{{-1,1},{-1,-2},{-1,1}},{{2,0},{2,-2},{-1,-2}},{{-2,2},{-2,-2},{-2,2}}}}, {{{{-1},{0}},{{-2},{-1}}}}], {{0,6,24},{-8,6,-24}}, TestID -> "case-134"]
VerificationTest[Einsum["ffab,b,ffbb", {{{{-2,-1,0},{0,-1,1}},{{1,2,-1},{1,2,-1}}},{{{-2,-1,-2},{2,2,2}},{{-2,1,1},{1,-2,0}}}}, {-2,-2,1}, {{{{2,2,-2},{1,-1,2},{-2,2,-2}},{{-2,0,0},{-2,0,0},{-2,1,1}}},{{{2,2,-2},{1,1,1},{1,-1,1}},{{0,0,-2},{0,1,-2},{2,1,0}}}}], {4,0}, TestID -> "case-135"]
VerificationTest[Einsum["h,h->", {1,0,1}, {-1,2,0}], -1, TestID -> "case-136"]
VerificationTest[Einsum["hfff,h,hfhf,hff->", {{{{1,1,1},{-2,1,1},{-2,-1,0}},{{0,0,-1},{0,1,0},{0,1,-1}},{{-2,2,-2},{-1,0,-2},{0,2,0}}}}, {2}, {{{{0,-1,0}},{{0,2,2}},{{2,-1,-2}}}}, {{{2,1,1},{0,2,-2},{2,-2,0}}}], 8, TestID -> "case-137"]
VerificationTest[Einsum["hfff,h,hfhf,hff->", {{{{1,1,1},{-2,1,1},{-2,-1,0}},{{0,0,-1},{0,1,0},{0,1,-1}},{{-2,2,-2},{-1,0,-2},{0,2,0}}}}, {2}, {{{{0,-1,0}},{{0,2,2}},{{2,-1,-2}}}}, {{{2,1,1},{0,2,-2},{2,-2,0}}}, "BatchMethod" -> "Dot"], 8, TestID -> "case-137-cfg3"]
VerificationTest[Einsum[",fff,ff,f,ffff->f", 1, {{{-1}}}, {{0}}, {1}, {{{{2}}}}], {0}, TestID -> "case-138"]
VerificationTest[Einsum["gg,gg,,,bg->bg", {{0}}, {{0}}, -2, 2, {{-1}}], {{0}}, TestID -> "case-139"]
VerificationTest[Einsum["ccd,adca,,,ecea->", {{{0,-1,2},{2,2,0}},{{-2,-1,1},{-2,2,-2}}}, {{{{-2,-1},{2,-2}},{{2,-2},{1,1}},{{0,2},{1,0}}},{{{1,2},{1,2}},{{0,-2},{-1,0}},{{-2,0},{2,-1}}}}, 1, 1, {{{{0,0}},{{1,-2}}}}], 0, TestID -> "case-140"]
VerificationTest[Einsum["h,aa,ah,efag->gafe", {1,-2,0}, {{-2,2,-2},{0,-1,1},{1,-2,-1}}, {{0,1,1},{0,0,-2},{1,-2,1}}, {{{{-1,-2},{2,0},{-2,-2}}}}], {{{{-4}},{{0}},{{10}}},{{{-8}},{{0}},{{10}}}}, TestID -> "case-141"]
VerificationTest[Einsum["h,aa,ah,efag->gafe", {1,-2,0}, {{-2,2,-2},{0,-1,1},{1,-2,-1}}, {{0,1,1},{0,0,-2},{1,-2,1}}, {{{{-1,-2},{2,0},{-2,-2}}}}, "BatchMethod" -> "Vectorized"], {{{{-4}},{{0}},{{10}}},{{{-8}},{{0}},{{10}}}}, TestID -> "case-141-cfg4"]
VerificationTest[Einsum["fff,f,ffff->", {{{-1,-1,-1},{-2,0,-1},{1,-2,-1}},{{-2,-2,0},{-2,-1,1},{0,1,2}},{{-2,2,-2},{2,2,2},{-2,1,-2}}}, {0,-1,-2}, {{{{1,1,-1},{-2,1,-1},{-2,-1,-1}},{{2,-2,2},{2,-1,0},{-1,1,0}},{{-1,-2,2},{-2,-2,0},{1,0,0}}},{{{1,0,2},{-1,-2,-2},{2,0,-1}},{{2,2,2},{-2,-1,-1},{-2,1,1}},{{-1,2,-2},{2,-1,0},{-1,1,2}}},{{{0,-1,-2},{1,1,2},{-1,-2,2}},{{-1,1,2},{-1,0,-1},{-2,-1,0}},{{-2,0,-1},{2,0,1},{1,-1,-1}}}}], -5, TestID -> "case-142"]
VerificationTest[Einsum["ae,hh,afd,hg,fhhh", {{-2,0,1}}, {{-2}}, {{{1},{2},{-2}}}, {{1,-2}}, {{{{-2}}},{{{2}}},{{{-2}}}}], {{{24,-48},{0,0},{-12,24}}}, TestID -> "case-143"]
VerificationTest[Einsum["aa,aa,->", {{1}}, {{1}}, 2], 2, TestID -> "case-144"]
VerificationTest[Einsum["gd,dde,gdg,geg", {{0},{-2},{-1}}, {{{0,2,0}}}, {{{0,-2,-2}},{{0,0,-2}},{{0,-2,-1}}}, {{{1,0,2},{2,0,1},{2,2,2}},{{1,1,2},{0,-1,2},{0,-1,0}},{{-1,2,1},{1,2,2},{-1,-2,-1}}}], 4, TestID -> "case-145"]
VerificationTest[Einsum["gd,dde,gdg,geg", {{0},{-2},{-1}}, {{{0,2,0}}}, {{{0,-2,-2}},{{0,0,-2}},{{0,-2,-1}}}, {{{1,0,2},{2,0,1},{2,2,2}},{{1,1,2},{0,-1,2},{0,-1,0}},{{-1,2,1},{1,2,2},{-1,-2,-1}}}, "Path" -> "Greedy"], 4, TestID -> "case-145-cfg1"]
VerificationTest[Einsum["dddd,d", {{{{1}}}}, {-1}], -1, TestID -> "case-146"]
VerificationTest[Einsum[",h,ah,aca,hac->a", -1, {-2,2}, {{-2,2},{-1,1},{0,-1}}, {{{-2,-2,2}},{{2,0,2}},{{1,1,1}}}, {{{-2},{2},{-2}},{{-1},{0},{1}}}], {-24,0,2}, TestID -> "case-147"]
VerificationTest[Einsum["bgea", {{{{1},{2}},{{-1},{-1}},{{-2},{1}}}}], {{{{1,-1,-2},{2,-1,1}}}}, TestID -> "case-148"]
VerificationTest[Einsum["ebb,hh,hd,gd", {{{1,2,-1},{1,-2,-1},{2,2,-1}},{{-2,2,1},{2,-2,0},{0,0,1}},{{-2,1,-1},{2,0,2},{0,1,-2}}}, {{-2,0,-1},{2,1,-1},{2,0,-2}}, {{1,-1},{-2,2},{2,2}}, {{0,2},{1,-2},{2,-1}}], {{0,16,32},{0,24,48},{0,32,64}}, TestID -> "case-149"]
VerificationTest[Einsum["ebb,hh,hd,gd", {{{1,2,-1},{1,-2,-1},{2,2,-1}},{{-2,2,1},{2,-2,0},{0,0,1}},{{-2,1,-1},{2,0,2},{0,1,-2}}}, {{-2,0,-1},{2,1,-1},{2,0,-2}}, {{1,-1},{-2,2},{2,2}}, {{0,2},{1,-2},{2,-1}}, "Path" -> "Sequential"], {{0,16,32},{0,24,48},{0,32,64}}, TestID -> "case-149-cfg2"]
VerificationTest[Einsum["bed", {{{-2,2,2},{0,-1,2},{0,-2,-2}},{{0,2,1},{2,2,0},{2,2,2}},{{2,-2,1},{-2,-2,-2},{1,0,-2}}}], {{{-2,0,0},{2,-1,-2},{2,2,-2}},{{0,2,2},{2,2,2},{1,0,2}},{{2,-2,1},{-2,-2,0},{1,-2,-2}}}, TestID -> "case-150"]
VerificationTest[Einsum["df,,dfh,e->dfe", {{-2,1},{-2,2},{1,-1}}, 2, {{{2,0},{1,-2}},{{-2,-1},{2,1}},{{1,-2},{1,0}}}, {0,-1,1}], {{{0,8,-8},{0,2,-2}},{{0,-12,12},{0,-12,12}},{{0,2,-2},{0,2,-2}}}, TestID -> "case-151"]
VerificationTest[Einsum["fdad->daf", {{{{1,-1}},{{-1,2}}}}], {{{1}},{{2}}}, TestID -> "case-152"]
VerificationTest[Einsum["d,bbbf,ff,dfb,bde", {1,1}, {{{{0},{0}},{{1},{0}}},{{{-2},{0}},{{1},{-1}}}}, {{-1}}, {{{-1,2}},{{-1,2}}}, {{{-1,-2},{-2,-1}},{{0,1},{1,2}}}], {2,6}, TestID -> "case-153"]
VerificationTest[Einsum["d,bbbf,ff,dfb,bde", {1,1}, {{{{0},{0}},{{1},{0}}},{{{-2},{0}},{{1},{-1}}}}, {{-1}}, {{{-1,2}},{{-1,2}}}, {{{-1,-2},{-2,-1}},{{0,1},{1,2}}}, "BatchMethod" -> "Dot"], {2,6}, TestID -> "case-153-cfg3"]
VerificationTest[Einsum["g,be,bc->g", {-1}, {{0,0}}, {{-2,2,-1}}], {0}, TestID -> "case-154"]
VerificationTest[Einsum["aaa,aaa,aaa->", {{{0,-2,1},{2,-2,1},{-1,2,1}},{{1,0,-2},{2,0,2},{1,-2,0}},{{1,-1,2},{-1,-2,1},{-1,-2,1}}}, {{{1,-1,-1},{-2,0,-1},{2,0,0}},{{-1,2,0},{-2,-2,0},{2,1,-1}},{{-2,-2,1},{-2,1,0},{0,-2,1}}}, {{{0,-2,-2},{2,0,-2},{0,1,-2}},{{-2,0,-2},{0,0,2},{0,0,1}},{{-1,2,0},{0,-2,0},{2,0,-2}}}], -2, TestID -> "case-155"]
VerificationTest[Einsum[",fff->", -1, {{{0}}}], 0, TestID -> "case-156"]
VerificationTest[Einsum[",,g,gg->", -2, -2, {1,1,-1}, {{-2,-1,-1},{-2,1,-2},{-1,1,0}}], -4, TestID -> "case-157"]
VerificationTest[Einsum[",,g,gg->", -2, -2, {1,1,-1}, {{-2,-1,-1},{-2,1,-2},{-1,1,0}}, "BatchMethod" -> "Vectorized"], -4, TestID -> "case-157-cfg4"]
VerificationTest[Einsum["fe", {{-2,-1},{2,1}}], {{-2,2},{-1,1}}, TestID -> "case-158"]
VerificationTest[Einsum["ab", {{-1},{0}}], {{-1},{0}}, TestID -> "case-159"]
VerificationTest[Einsum[",d->d", 2, {-1,-2,-2}], {-2,-4,-4}, TestID -> "case-160"]
VerificationTest[Einsum["fff,,f->", {{{1}}}, -1, {-2}], 2, TestID -> "case-161"]
VerificationTest[Einsum["fff,,f->", {{{1}}}, -1, {-2}, "Path" -> "Greedy"], 2, TestID -> "case-161-cfg1"]
VerificationTest[Einsum["aaaa,aa,aaa,aaaa->a", {{{{1}}}}, {{2}}, {{{-1}}}, {{{{0}}}}], {0}, TestID -> "case-162"]
VerificationTest[Einsum["cchc,bc,,eaca->ehbc", {{{{-2,1},{-2,1},{-2,-2}},{{0,-1},{-1,-1},{1,-2}}},{{{0,1},{0,0},{2,-2}},{{-2,1},{2,-2},{-2,0}}}}, {{-2,1},{2,-2},{-2,2}}, 0, {{{{-1,-1},{-2,-1}},{{-1,0},{0,2}}},{{{2,0},{-2,1}},{{-2,2},{1,0}}}}], {{{{0,0},{0,0},{0,0}},{{0,0},{0,0},{0,0}},{{0,0},{0,0},{0,0}}},{{{0,0},{0,0},{0,0}},{{0,0},{0,0},{0,0}},{{0,0},{0,0},{0,0}}}}, TestID -> "case-163"]
VerificationTest[Einsum["cdc,c,ccdc,d,->dc", {{{2,-2,-1},{2,1,0}},{{-1,1,1},{2,0,2}},{{-1,-2,0},{1,0,1}}}, {-2,-2,2}, {{{{2,-1,-1},{-1,0,2}},{{0,-1,-1},{-1,-2,2}},{{-2,-1,-2},{2,1,0}}},{{{1,-1,2},{-1,1,-1}},{{2,2,2},{0,0,-2}},{{2,-2,-2},{1,-1,2}}},{{{-2,2,1},{-2,1,-1}},{{2,2,-2},{2,1,2}},{{-2,-2,-2},{1,-1,1}}}}, {1,2}, 1], {{-8,-4,0},{8,0,4}}, TestID -> "case-164"]
VerificationTest[Einsum["d,h,->hd", {2,-1,0}, {-1,-1}, 0], {{0,0,0},{0,0,0}}, TestID -> "case-165"]
VerificationTest[Einsum["d,h,->hd", {2,-1,0}, {-1,-1}, 0, "Path" -> "Sequential"], {{0,0,0},{0,0,0}}, TestID -> "case-165-cfg2"]
VerificationTest[Einsum["cg->", {{0},{1}}], 1, TestID -> "case-166"]
VerificationTest[Einsum[",eee,gg,ee->", -2, {{{0,1},{-1,-2}},{{-2,-2},{-2,2}}}, {{1}}, {{-2,2},{2,2}}], -8, TestID -> "case-167"]
VerificationTest[Einsum["ddd,ddd,,ddd,dddd->d", {{{1,-1},{2,-2}},{{-2,2},{2,1}}}, {{{2,2},{-1,2}},{{-2,-1},{-1,2}}}, -1, {{{1,0},{0,-1}},{{-1,-1},{0,0}}}, {{{{-1,0},{-1,2}},{{0,-2},{0,2}}},{{{0,-1},{-2,-1}},{{-1,2},{-2,0}}}}], {2,0}, TestID -> "case-168"]
VerificationTest[Einsum["c,afah,cahe->c", {-2}, {{{{2,2},{2,2},{-1,-1}},{{2,2},{2,2},{0,1}}},{{{-2,2},{2,-2},{0,2}},{{1,2},{2,0},{2,1}}},{{{0,0},{2,1},{-2,-1}},{{-1,1},{0,-2},{1,2}}}}, {{{{1,1},{0,2}},{{2,1},{-1,1}},{{-2,2},{-1,2}}}}], {-58}, TestID -> "case-169"]
VerificationTest[Einsum["c,afah,cahe->c", {-2}, {{{{2,2},{2,2},{-1,-1}},{{2,2},{2,2},{0,1}}},{{{-2,2},{2,-2},{0,2}},{{1,2},{2,0},{2,1}}},{{{0,0},{2,1},{-2,-1}},{{-1,1},{0,-2},{1,2}}}}, {{{{1,1},{0,2}},{{2,1},{-1,1}},{{-2,2},{-1,2}}}}, "BatchMethod" -> "Dot"], {-58}, TestID -> "case-169-cfg3"]
VerificationTest[Einsum["", 0], 0, TestID -> "case-170"]
VerificationTest[Einsum["bh,ahbg,a->", {{0,-2,0},{-2,0,0}}, {{{{-1,-1,2},{1,1,0}},{{2,-1,2},{0,-2,-2}},{{0,2,1},{-2,0,-1}}},{{{-1,2,1},{0,1,0}},{{-2,1,2},{1,1,-1}},{{1,-2,1},{1,0,0}}}}, {1,1}], -14, TestID -> "case-171"]
VerificationTest[Einsum["aac,afab,h", {{{-2,1,-1}}}, {{{{1,2,2}}}}, {1,-2}], {{{{-2,4}},{{1,-2}},{{-1,2}}},{{{-4,8}},{{2,-4}},{{-2,4}}},{{{-4,8}},{{2,-4}},{{-2,4}}}}, TestID -> "case-172"]
VerificationTest[Einsum["d,ddd,d,->d", {1,-2,2}, {{{-1,1,-1},{0,1,-1},{-2,-2,-2}},{{2,-1,0},{-2,-1,-1},{1,1,1}},{{2,0,2},{2,1,1},{-2,-1,1}}}, {-2,1,-2}, 2], {4,4,-8}, TestID -> "case-173"]
VerificationTest[Einsum["d,ddd,d,->d", {1,-2,2}, {{{-1,1,-1},{0,1,-1},{-2,-2,-2}},{{2,-1,0},{-2,-1,-1},{1,1,1}},{{2,0,2},{2,1,1},{-2,-1,1}}}, {-2,1,-2}, 2, "BatchMethod" -> "Vectorized"], {4,4,-8}, TestID -> "case-173-cfg4"]
VerificationTest[Einsum["ehh,b,g->g", {{{2,-2,1},{0,-2,-1},{-2,1,-1}},{{-1,0,1},{2,-2,0},{0,-1,0}},{{2,0,2},{0,0,2},{2,0,0}}}, {2,-1,1}, {0,-2,2}], {0,8,-8}, TestID -> "case-174"]
VerificationTest[Einsum[",dg->g", 0, {{2},{-2}}], {0}, TestID -> "case-175"]
VerificationTest[Einsum["dg,,dd,gag->adg", {{1}}, 1, {{2}}, {{{2},{0}}}], {{{4}},{{0}}}, TestID -> "case-176"]
VerificationTest[Einsum["efe,fa", {{{-1,0,-2},{-1,-2,-2},{0,1,2}},{{2,-2,-2},{2,1,2},{-1,-1,-1}},{{-2,1,-1},{2,-1,2},{-1,2,-1}}}, {{-2},{2},{-2}}], {16}, TestID -> "case-177"]
VerificationTest[Einsum["efe,fa", {{{-1,0,-2},{-1,-2,-2},{0,1,2}},{{2,-2,-2},{2,1,2},{-1,-1,-1}},{{-2,1,-1},{2,-1,2},{-1,2,-1}}}, {{-2},{2},{-2}}, "Path" -> "Greedy"], {16}, TestID -> "case-177-cfg1"]
VerificationTest[Einsum["a", {2,-1,-2}], {2,-1,-2}, TestID -> "case-178"]
VerificationTest[Einsum["c,bd,bd,->dbc", {0,0,1}, {{-2,1,-1},{2,1,-1},{0,-1,2}}, {{2,1,2},{-1,1,-1},{-2,-1,0}}, -1], {{{0,0,4},{0,0,2},{0,0,0}},{{0,0,-1},{0,0,-1},{0,0,-1}},{{0,0,2},{0,0,-1},{0,0,0}}}, TestID -> "case-179"]
VerificationTest[Einsum["f,->", {0,-2,2}, -2], 0, TestID -> "case-180"]
VerificationTest[Einsum[",,ecgc,gge,gge->ec", -1, -1, {{{{-2,2}},{{1,-1}}},{{{2,0}},{{-2,-2}}},{{{-1,-2}},{{2,1}}}}, {{{1,0,-2}}}, {{{2,-1,-1}}}], {{-4,-2},{0,0},{-2,2}}, TestID -> "case-181"]
VerificationTest[Einsum[",,ecgc,gge,gge->ec", -1, -1, {{{{-2,2}},{{1,-1}}},{{{2,0}},{{-2,-2}}},{{{-1,-2}},{{2,1}}}}, {{{1,0,-2}}}, {{{2,-1,-1}}}, "Path" -> "Sequential"], {{-4,-2},{0,0},{-2,2}}, TestID -> "case-181-cfg2"]
VerificationTest[Einsum["eab,aba", {{{2},{-1}}}, {{{-1,1}},{{2,2}}}], {-4}, TestID -> "case-182"]
VerificationTest[Einsum["g->", {-2,-1}], -3, TestID -> "case-183"]
VerificationTest[Einsum["h,h,hh,->h", {-2,1,2}, {0,-2,1}, {{0,1,-2},{0,-1,2},{-2,-1,0}}, -1], {0,-2,0}, TestID -> "case-184"]
VerificationTest[Einsum["ccah,,,hca->", {{{{2},{-1},{2}},{{-1},{-2},{1}},{{-1},{0},{-1}}},{{{-2},{0},{0}},{{0},{2},{1}},{{-2},{-2},{0}}},{{{-1},{-2},{2}},{{1},{-2},{1}},{{0},{-2},{0}}}}, 2, -1, {{{-1,-1,1},{1,-2,-2},{0,1,1}}}], 14, TestID -> "case-185"]
VerificationTest[Einsum["ccah,,,hca->", {{{{2},{-1},{2}},{{-1},{-2},{1}},{{-1},{0},{-1}}},{{{-2},{0},{0}},{{0},{2},{1}},{{-2},{-2},{0}}},{{{-1},{-2},{2}},{{1},{-2},{1}},{{0},{-2},{0}}}}, 2, -1, {{{-1,-1,1},{1,-2,-2},{0,1,1}}}, "BatchMethod" -> "Dot"], 14, TestID -> "case-185-cfg3"]
VerificationTest[Einsum["cdd,edd,dd,eeec->dc", {{{2,2},{2,0}},{{0,0},{-2,-1}},{{0,0},{1,-1}}}, {{{1,-1},{2,-1}}}, {{-1,1},{0,-1}}, {{{{-1,2,-2}}}}], {{2,0,0},{0,-2,2}}, TestID -> "case-186"]
VerificationTest[Einsum[",eeh,hfe,hfh->hef", 0, {{{-2},{-1},{0}},{{-2},{2},{1}},{{0},{2},{-1}}}, {{{0,0,2},{1,-1,-1}}}, {{{-2},{1}}}], {{{0,0},{0,0},{0,0}}}, TestID -> "case-187"]
VerificationTest[Einsum[",,defh,adh", 1, 2, {{{{0},{0},{2}}},{{{-1},{1},{1}}},{{{-2},{-1},{2}}}}, {{{0},{2},{0}}}], {{{-4,4,4}}}, TestID -> "case-188"]
VerificationTest[Einsum["ggg,gggg,g,gggg,->", {{{2}}}, {{{{2}}}}, {0}, {{{{2}}}}, -2], 0, TestID -> "case-189"]
VerificationTest[Einsum["ggg,gggg,g,gggg,->", {{{2}}}, {{{{2}}}}, {0}, {{{{2}}}}, -2, "BatchMethod" -> "Vectorized"], 0, TestID -> "case-189-cfg4"]
VerificationTest[Einsum["cbb,g->bg", {{{1,0},{-1,1}}}, {-2}], {{-2},{-2}}, TestID -> "case-190"]
VerificationTest[Einsum["ca,ceda->adce", {{-2,-2,1},{1,1,-2}}, {{{{2,-2,-2},{0,-1,1},{-1,-2,2}},{{0,2,-1},{0,1,2},{0,-2,-1}}},{{{2,2,-2},{1,2,-2},{0,0,-2}},{{-1,1,-1},{-1,1,2},{2,-1,-1}}}}], {{{{-4,0},{2,-1}},{{0,0},{1,-1}},{{2,0},{0,2}}},{{{4,-4},{2,1}},{{2,-2},{2,1}},{{4,4},{0,-1}}},{{{-2,-1},{4,2}},{{1,2},{4,-4}},{{2,-1},{4,2}}}}, TestID -> "case-191"]
VerificationTest[Einsum["ba,a,a,bgbb,gb->", {{-2,0}}, {0,-1}, {1,2}, {{{{2}},{{0}},{{-2}}}}, {{2},{-1},{1}}], 0, TestID -> "case-192"]
VerificationTest[Einsum[",fhb,cdh,->dhc", 0, {{{-2,-2,-1}}}, {{{0},{-2}}}, 2], {{{0}},{{0}}}, TestID -> "case-193"]
VerificationTest[Einsum[",fhb,cdh,->dhc", 0, {{{-2,-2,-1}}}, {{{0},{-2}}}, 2, "Path" -> "Greedy"], {{{0}},{{0}}}, TestID -> "case-193-cfg1"]
VerificationTest[Einsum[",bb,bb,bbbb->b", -1, {{-1}}, {{-1}}, {{{{1}}}}], {-1}, TestID -> "case-194"]
VerificationTest[Einsum["->", -1], -1, TestID -> "case-195"]
VerificationTest[Einsum["hc,hh->", {{2,-2,-1},{1,0,-2},{0,-2,1}}, {{2,0,2},{-1,1,0},{-2,0,-1}}], -2, TestID -> "case-196"]
VerificationTest[Einsum["ee,ge,eeeg,gg,->", {{0,1,0},{0,-1,-2},{2,-2,1}}, {{1,2,1},{1,1,1},{-2,-1,0}}, {{{{0,1,-1},{0,1,1},{2,2,0}},{{0,-2,1},{-1,1,0},{2,1,2}},{{0,-1,-1},{-2,1,2},{2,0,0}}},{{{-2,2,1},{0,2,-2},{-2,2,1}},{{-2,2,-1},{0,1,-2},{2,-1,-1}},{{2,2,2},{1,0,-2},{0,0,1}}},{{{2,2,0},{-1,2,2},{-1,1,2}},{{0,1,-2},{-2,-2,-2},{-2,1,-1}},{{2,0,-1},{-2,-1,1},{2,-1,2}}}}, {{-1,2,0},{-2,1,0},{2,-2,1}}, 1], -6, TestID -> "case-197"]
VerificationTest[Einsum["ee,ge,eeeg,gg,->", {{0,1,0},{0,-1,-2},{2,-2,1}}, {{1,2,1},{1,1,1},{-2,-1,0}}, {{{{0,1,-1},{0,1,1},{2,2,0}},{{0,-2,1},{-1,1,0},{2,1,2}},{{0,-1,-1},{-2,1,2},{2,0,0}}},{{{-2,2,1},{0,2,-2},{-2,2,1}},{{-2,2,-1},{0,1,-2},{2,-1,-1}},{{2,2,2},{1,0,-2},{0,0,1}}},{{{2,2,0},{-1,2,2},{-1,1,2}},{{0,1,-2},{-2,-2,-2},{-2,1,-1}},{{2,0,-1},{-2,-1,1},{2,-1,2}}}}, {{-1,2,0},{-2,1,0},{2,-2,1}}, 1, "Path" -> "Sequential"], -6, TestID -> "case-197-cfg2"]
VerificationTest[Einsum["b,,faaa,afbb,->abf", {-2,-2,0}, 0, {{{{-1,-1,2},{2,-2,-2},{0,-1,0}},{{-1,-2,-1},{1,1,-2},{-2,-2,1}},{{-2,0,2},{-2,-1,2},{2,0,-1}}},{{{-2,-1,0},{2,-1,2},{-2,1,1}},{{-1,2,-2},{1,-2,0},{0,2,1}},{{-2,-1,-1},{-2,0,2},{-2,2,1}}},{{{-2,0,1},{2,0,2},{-1,-2,-2}},{{1,-1,-2},{-1,0,2},{-1,1,0}},{{2,1,-2},{-2,-1,1},{1,2,1}}}}, {{{{2,1,0},{1,1,0},{-2,-2,-1}},{{-2,2,-2},{-2,1,2},{2,-1,2}},{{0,-1,-1},{0,-2,0},{2,-1,1}}},{{{1,2,-2},{1,0,1},{-1,-2,0}},{{-2,2,-2},{0,2,-1},{-2,-1,-2}},{{2,-2,-1},{-2,2,-1},{-1,0,0}}},{{{2,-1,-2},{-1,-2,2},{2,1,-2}},{{-1,1,-1},{2,2,0},{-2,2,0}},{{-1,1,-2},{-2,2,0},{1,2,-1}}}}, -1], {{{0,0,0},{0,0,0},{0,0,0}},{{0,0,0},{0,0,0},{0,0,0}},{{0,0,0},{0,0,0},{0,0,0}}}, TestID -> "case-198"]
VerificationTest[Einsum["ddee->", {{{{1,1},{-1,1}},{{-1,-2},{0,0}}},{{{-2,0},{0,-2}},{{-1,0},{1,1}}}}], 2, TestID -> "case-199"]
VerificationTest[Einsum["hgag,,,daa,dd->h", {{{{-1}}}}, 0, 2, {{{2}},{{2}}}, {{-2,0},{-1,-2}}], {0}, TestID -> "case-200"]
VerificationTest[Einsum["cee,ec", {{{-2,1,1},{-1,-2,-1},{1,0,2}},{{0,1,-2},{0,-1,0},{0,2,2}}}, {{1,-2},{2,-1},{-1,0}}], -7, TestID -> "case-201"]
VerificationTest[Einsum["cee,ec", {{{-2,1,1},{-1,-2,-1},{1,0,2}},{{0,1,-2},{0,-1,0},{0,2,2}}}, {{1,-2},{2,-1},{-1,0}}, "BatchMethod" -> "Dot"], -7, TestID -> "case-201-cfg3"]
VerificationTest[Einsum["g,gh->h", {0,-1}, {{1,-1},{2,-2}}], {-2,2}, TestID -> "case-202"]
VerificationTest[Einsum["gddd,dg,gd,->g", {{{{0,1,-1},{1,2,-1},{-2,-1,2}},{{-2,-2,1},{-2,-1,-2},{-1,2,-1}},{{2,2,-2},{1,0,1},{0,1,-2}}},{{{1,1,2},{0,-1,-1},{0,-1,-1}},{{1,0,-2},{2,2,-2},{2,1,0}},{{1,-2,0},{1,2,-1},{2,-2,0}}},{{{-1,1,-1},{0,-2,0},{2,2,0}},{{-2,2,1},{0,-2,-1},{-2,0,-1}},{{0,2,-1},{-1,-2,1},{2,1,0}}}}, {{-1,0,2},{0,-2,0},{2,2,-2}}, {{2,-1,1},{0,-2,2},{-1,-2,1}}, 2], {-8,16,4}, TestID -> "case-203"]
VerificationTest[Einsum["g,gggg,gggg->", {0,0}, {{{{1,2},{-2,2}},{{1,1},{1,2}}},{{{-2,1},{1,1}},{{-2,-1},{0,-1}}}}, {{{{2,2},{-1,-2}},{{1,-1},{0,1}}},{{{-2,1},{0,-1}},{{2,-1},{-2,-2}}}}], 0, TestID -> "case-204"]
VerificationTest[Einsum["", 0], 0, TestID -> "case-205"]
VerificationTest[Einsum["", 0, "BatchMethod" -> "Vectorized"], 0, TestID -> "case-205-cfg4"]
VerificationTest[Einsum["h->", {-2,0,-2}], -4, TestID -> "case-206"]
VerificationTest[Einsum["ece,eee->", {{{-1}}}, {{{1}}}], -1, TestID -> "case-207"]
VerificationTest[Einsum["hh->h", {{0,2},{0,0}}], {0,0}, TestID -> "case-208"]
VerificationTest[Einsum["fff", {{{2,2},{-1,0}},{{2,-1},{-2,0}}}], 2, TestID -> "case-209"]
VerificationTest[Einsum["fff", {{{2,2},{-1,0}},{{2,-1},{-2,0}}}, "Path" -> "Greedy"], 2, TestID -> "case-209-cfg1"]
VerificationTest[Einsum["dddd,ffg->fgd", {{{{1,1,-2},{0,-1,2},{2,-2,-2}},{{-2,-1,2},{-1,-1,-1},{0,2,-1}},{{-2,2,0},{2,2,-2},{1,-2,2}}},{{{-1,-2,-2},{2,0,0},{-1,2,-2}},{{2,-1,0},{2,0,0},{0,2,2}},{{0,0,2},{1,-2,0},{-1,1,0}}},{{{1,-2,1},{0,0,2},{0,-1,-1}},{{-1,0,2},{0,-1,1},{0,-2,-2}},{{-2,-1,1},{1,1,-1},{-2,0,1}}}}, {{{2,2},{-1,2},{0,0}},{{1,-2},{0,1},{1,0}},{{1,2},{2,0},{2,-1}}}], {{{2,0,2},{2,0,2}},{{0,0,0},{1,0,1}},{{2,0,2},{-1,0,-1}}}, TestID -> "case-210"]
VerificationTest[Einsum[",gggg,,gggg", 2, {{{{-1}}}}, 1, {{{{2}}}}], -4, TestID -> "case-211"]
VerificationTest[Einsum["gch,eee,ghgh->h", {{{0,-2}},{{0,-1}},{{0,1}}}, {{{-2}}}, {{{{2,-1},{-2,1},{-1,-1}},{{-2,-1},{-2,1},{-1,0}}},{{{0,-2},{-2,1},{-2,2}},{{1,1},{2,1},{-2,-1}}},{{{1,0},{-1,1},{0,1}},{{2,-1},{-1,2},{-2,0}}}}], {0,-2}, TestID -> "case-212"]
VerificationTest[Einsum["ecf,e,aff,eec,aae->ef", {{{-2,1,-1},{2,1,-1}},{{1,0,-1},{1,-1,-2}},{{-2,2,1},{0,1,-2}}}, {0,-1,-2}, {{{-2,1,-1},{-2,-2,2},{2,-1,1}}}, {{{-1,-1},{2,0},{-1,-1}},{{-2,-2},{-1,-1},{2,1}},{{0,0},{1,0},{-1,0}}}, {{{-1,1,2}}}], {{0,0,0},{-4,2,-3},{16,-16,4}}, TestID -> "case-213"]
VerificationTest[Einsum["ecf,e,aff,eec,aae->ef", {{{-2,1,-1},{2,1,-1}},{{1,0,-1},{1,-1,-2}},{{-2,2,1},{0,1,-2}}}, {0,-1,-2}, {{{-2,1,-1},{-2,-2,2},{2,-1,1}}}, {{{-1,-1},{2,0},{-1,-1}},{{-2,-2},{-1,-1},{2,1}},{{0,0},{1,0},{-1,0}}}, {{{-1,1,2}}}, "Path" -> "Sequential"], {{0,0,0},{-4,2,-3},{16,-16,4}}, TestID -> "case-213-cfg2"]

(* ::Section:: *)
(* 2. Optimal paths: total flops must equal an exhaustive search over all contraction orders *)

VerificationTest[Total[EinsumPath["b,f,ace,e,c,bcb->f", {{8}, {3}, {6, 6, 7}, {7}, {6}, {8, 6, 8}}, "Path" -> "Optimal"]["StepFlops"]], N[105], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-1"]
VerificationTest[Total[EinsumPath["b,f,ace,e,c,bcb->f", {{8}, {3}, {6, 6, 7}, {7}, {6}, {8, 6, 8}}, "Path" -> "Greedy"]["StepFlops"]] >= N[105] (1 - 10^-9), True, TestID -> "greedy-1"]
VerificationTest[Total[EinsumPath["cf,bf,f,aa,aa->fbc", {{8, 6}, {5, 6}, {6}, {5, 5}, {5, 5}}, "Path" -> "Optimal"]["StepFlops"]], N[281], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-2"]
VerificationTest[Total[EinsumPath["cf,bf,f,aa,aa->fbc", {{8, 6}, {5, 6}, {6}, {5, 5}, {5, 5}}, "Path" -> "Greedy"]["StepFlops"]] >= N[281] (1 - 10^-9), True, TestID -> "greedy-2"]
VerificationTest[Total[EinsumPath["aab,egb,cda,fe,d,g->df", {{6, 6, 5}, {5, 3, 5}, {5, 3, 6}, {4, 5}, {3}, {3}}, "Path" -> "Optimal"]["StepFlops"]], N[312], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-3"]
VerificationTest[Total[EinsumPath["aab,egb,cda,fe,d,g->df", {{6, 6, 5}, {5, 3, 5}, {5, 3, 6}, {4, 5}, {3}, {3}}, "Path" -> "Greedy"]["StepFlops"]] >= N[312] (1 - 10^-9), True, TestID -> "greedy-3"]
VerificationTest[Total[EinsumPath["bc,bbb,a,bb->", {{5, 7}, {5, 5, 5}, {3}, {5, 5}}, "Path" -> "Optimal"]["StepFlops"]], N[11], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-4"]
VerificationTest[Total[EinsumPath["bc,bbb,a,bb->", {{5, 7}, {5, 5, 5}, {3}, {5, 5}}, "Path" -> "Greedy"]["StepFlops"]] >= N[11] (1 - 10^-9), True, TestID -> "greedy-4"]
VerificationTest[Total[EinsumPath["de,eg,d,cb->dgb", {{8, 4}, {4, 5}, {8}, {6, 4}}, "Path" -> "Optimal"]["StepFlops"]], N[352], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-5"]
VerificationTest[Total[EinsumPath["de,eg,d,cb->dgb", {{8, 4}, {4, 5}, {8}, {6, 4}}, "Path" -> "Greedy"]["StepFlops"]] >= N[352] (1 - 10^-9), True, TestID -> "greedy-5"]
VerificationTest[Total[EinsumPath["da,ca,dbd,dd,ba,ad->", {{4, 2}, {2, 2}, {4, 6, 4}, {4, 4}, {6, 2}, {2, 4}}, "Path" -> "Optimal"]["StepFlops"]], N[74], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-6"]
VerificationTest[Total[EinsumPath["da,ca,dbd,dd,ba,ad->", {{4, 2}, {2, 2}, {4, 6, 4}, {4, 4}, {6, 2}, {2, 4}}, "Path" -> "Greedy"]["StepFlops"]] >= N[74] (1 - 10^-9), True, TestID -> "greedy-6"]
VerificationTest[Total[EinsumPath["b,ahh,dg,dc->", {{6}, {8, 4, 4}, {5, 8}, {5, 6}}, "Path" -> "Optimal"]["StepFlops"]], N[7], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-7"]
VerificationTest[Total[EinsumPath["b,ahh,dg,dc->", {{6}, {8, 4, 4}, {5, 8}, {5, 6}}, "Path" -> "Greedy"]["StepFlops"]] >= N[7] (1 - 10^-9), True, TestID -> "greedy-7"]
VerificationTest[Total[EinsumPath["cb,b,cc,ab,c,bcb->bac", {{2, 8}, {8}, {2, 2}, {4, 8}, {2}, {8, 2, 8}}, "Path" -> "Optimal"]["StepFlops"]], N[114], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-8"]
VerificationTest[Total[EinsumPath["cb,b,cc,ab,c,bcb->bac", {{2, 8}, {8}, {2, 2}, {4, 8}, {2}, {8, 2, 8}}, "Path" -> "Greedy"]["StepFlops"]] >= N[114] (1 - 10^-9), True, TestID -> "greedy-8"]
VerificationTest[Total[EinsumPath["fbg,gg,agf,gh,af,b->h", {{6, 4, 7}, {7, 7}, {3, 7, 6}, {7, 7}, {3, 6}, {4}}, "Path" -> "Optimal"]["StepFlops"]], N[378], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-9"]
VerificationTest[Total[EinsumPath["fbg,gg,agf,gh,af,b->h", {{6, 4, 7}, {7, 7}, {3, 7, 6}, {7, 7}, {3, 6}, {4}}, "Path" -> "Greedy"]["StepFlops"]] >= N[378] (1 - 10^-9), True, TestID -> "greedy-9"]
VerificationTest[Total[EinsumPath["d,h,e,ehh->he", {{4}, {8}, {2}, {2, 8, 8}}, "Path" -> "Optimal"]["StepFlops"]], N[34], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-10"]
VerificationTest[Total[EinsumPath["d,h,e,ehh->he", {{4}, {8}, {2}, {2, 8, 8}}, "Path" -> "Greedy"]["StepFlops"]] >= N[34] (1 - 10^-9), True, TestID -> "greedy-10"]
VerificationTest[Total[EinsumPath["a,d,d,gf,f->f", {{4}, {4}, {4}, {8, 7}, {7}}, "Path" -> "Optimal"]["StepFlops"]], N[19], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-11"]
VerificationTest[Total[EinsumPath["a,d,d,gf,f->f", {{4}, {4}, {4}, {8, 7}, {7}}, "Path" -> "Greedy"]["StepFlops"]] >= N[19] (1 - 10^-9), True, TestID -> "greedy-11"]
VerificationTest[Total[EinsumPath["a,bc,a,b,a->abc", {{6}, {8, 8}, {6}, {8}, {6}}, "Path" -> "Optimal"]["StepFlops"]], N[444], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-12"]
VerificationTest[Total[EinsumPath["a,bc,a,b,a->abc", {{6}, {8, 8}, {6}, {8}, {6}}, "Path" -> "Greedy"]["StepFlops"]] >= N[444] (1 - 10^-9), True, TestID -> "greedy-12"]
VerificationTest[Total[EinsumPath["ab,bb,a,cba,bb->ca", {{7, 6}, {6, 6}, {7}, {8, 6, 7}, {6, 6}}, "Path" -> "Optimal"]["StepFlops"]], N[426], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-13"]
VerificationTest[Total[EinsumPath["ab,bb,a,cba,bb->ca", {{7, 6}, {6, 6}, {7}, {8, 6, 7}, {6, 6}}, "Path" -> "Greedy"]["StepFlops"]] >= N[426] (1 - 10^-9), True, TestID -> "greedy-13"]
VerificationTest[Total[EinsumPath["agg,ffg,dfg->", {{4, 7, 7}, {8, 8, 7}, {6, 8, 7}}, "Path" -> "Optimal"]["StepFlops"]], N[63], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-14"]
VerificationTest[Total[EinsumPath["agg,ffg,dfg->", {{4, 7, 7}, {8, 8, 7}, {6, 8, 7}}, "Path" -> "Greedy"]["StepFlops"]] >= N[63] (1 - 10^-9), True, TestID -> "greedy-14"]
VerificationTest[Total[EinsumPath["c,c,aa,b->", {{6}, {6}, {3, 3}, {3}}, "Path" -> "Optimal"]["StepFlops"]], N[8], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-15"]
VerificationTest[Total[EinsumPath["c,c,aa,b->", {{6}, {6}, {3, 3}, {3}}, "Path" -> "Greedy"]["StepFlops"]] >= N[8] (1 - 10^-9), True, TestID -> "greedy-15"]
VerificationTest[Total[EinsumPath["cc,bc,ba,aa,bba->c", {{4, 4}, {5, 4}, {5, 2}, {2, 2}, {5, 5, 2}}, "Path" -> "Optimal"]["StepFlops"]], N[44], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-16"]
VerificationTest[Total[EinsumPath["cc,bc,ba,aa,bba->c", {{4, 4}, {5, 4}, {5, 2}, {2, 2}, {5, 5, 2}}, "Path" -> "Greedy"]["StepFlops"]] >= N[44] (1 - 10^-9), True, TestID -> "greedy-16"]
VerificationTest[Total[EinsumPath["c,bg,c,gd,cbg,ghd->bg", {{2}, {2, 4}, {2}, {4, 6}, {2, 2, 4}, {4, 3, 6}}, "Path" -> "Optimal"]["StepFlops"]], N[58], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-17"]
VerificationTest[Total[EinsumPath["c,bg,c,gd,cbg,ghd->bg", {{2}, {2, 4}, {2}, {4, 6}, {2, 2, 4}, {4, 3, 6}}, "Path" -> "Greedy"]["StepFlops"]] >= N[58] (1 - 10^-9), True, TestID -> "greedy-17"]
VerificationTest[Total[EinsumPath["eee,ba,bfc,aac->", {{2, 2, 2}, {2, 7}, {2, 6, 5}, {7, 7, 5}}, "Path" -> "Optimal"]["StepFlops"]], N[81], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-18"]
VerificationTest[Total[EinsumPath["eee,ba,bfc,aac->", {{2, 2, 2}, {2, 7}, {2, 6, 5}, {7, 7, 5}}, "Path" -> "Greedy"]["StepFlops"]] >= N[81] (1 - 10^-9), True, TestID -> "greedy-18"]
VerificationTest[Total[EinsumPath["cfd,ad,fa->dfc", {{8, 3, 4}, {6, 4}, {3, 6}}, "Path" -> "Optimal"]["StepFlops"]], N[168], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-19"]
VerificationTest[Total[EinsumPath["cfd,ad,fa->dfc", {{8, 3, 4}, {6, 4}, {3, 6}}, "Path" -> "Greedy"]["StepFlops"]] >= N[168] (1 - 10^-9), True, TestID -> "greedy-19"]
VerificationTest[Total[EinsumPath["d,b,e,ca,dd->", {{5}, {4}, {4}, {6, 4}, {5, 5}}, "Path" -> "Optimal"]["StepFlops"]], N[8], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-20"]
VerificationTest[Total[EinsumPath["d,b,e,ca,dd->", {{5}, {4}, {4}, {6, 4}, {5, 5}}, "Path" -> "Greedy"]["StepFlops"]] >= N[8] (1 - 10^-9), True, TestID -> "greedy-20"]
VerificationTest[Total[EinsumPath["f,fbf,f->b", {{2}, {2, 2, 2}, {2}}, "Path" -> "Optimal"]["StepFlops"]], N[6], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-21"]
VerificationTest[Total[EinsumPath["f,fbf,f->b", {{2}, {2, 2, 2}, {2}}, "Path" -> "Greedy"]["StepFlops"]] >= N[6] (1 - 10^-9), True, TestID -> "greedy-21"]
VerificationTest[Total[EinsumPath["daf,age,gfc,fa,e->ag", {{3, 3, 8}, {3, 4, 8}, {4, 8, 5}, {8, 3}, {8}}, "Path" -> "Optimal"]["StepFlops"]], N[228], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-22"]
VerificationTest[Total[EinsumPath["daf,age,gfc,fa,e->ag", {{3, 3, 8}, {3, 4, 8}, {4, 8, 5}, {8, 3}, {8}}, "Path" -> "Greedy"]["StepFlops"]] >= N[228] (1 - 10^-9), True, TestID -> "greedy-22"]
VerificationTest[Total[EinsumPath["d,a,bca,bdc,dda->d", {{5}, {7}, {6, 8, 7}, {6, 5, 8}, {5, 5, 7}}, "Path" -> "Optimal"]["StepFlops"]], N[1755], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-23"]
VerificationTest[Total[EinsumPath["d,a,bca,bdc,dda->d", {{5}, {7}, {6, 8, 7}, {6, 5, 8}, {5, 5, 7}}, "Path" -> "Greedy"]["StepFlops"]] >= N[1755] (1 - 10^-9), True, TestID -> "greedy-23"]
VerificationTest[Total[EinsumPath["bca,ab,bb,b,bca->ca", {{8, 7, 3}, {3, 8}, {8, 8}, {8}, {8, 7, 3}}, "Path" -> "Optimal"]["StepFlops"]], N[368], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-24"]
VerificationTest[Total[EinsumPath["bca,ab,bb,b,bca->ca", {{8, 7, 3}, {3, 8}, {8, 8}, {8}, {8, 7, 3}}, "Path" -> "Greedy"]["StepFlops"]] >= N[368] (1 - 10^-9), True, TestID -> "greedy-24"]
VerificationTest[Total[EinsumPath["fa,f,gab->fag", {{8, 7}, {8}, {4, 7, 4}}, "Path" -> "Optimal"]["StepFlops"]], N[280], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-25"]
VerificationTest[Total[EinsumPath["fa,f,gab->fag", {{8, 7}, {8}, {4, 7, 4}}, "Path" -> "Greedy"]["StepFlops"]] >= N[280] (1 - 10^-9), True, TestID -> "greedy-25"]
VerificationTest[Total[EinsumPath["b,eh,hg,bdh->", {{2}, {6, 2}, {2, 2}, {2, 2, 2}}, "Path" -> "Optimal"]["StepFlops"]], N[8], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-26"]
VerificationTest[Total[EinsumPath["b,eh,hg,bdh->", {{2}, {6, 2}, {2, 2}, {2, 2, 2}}, "Path" -> "Greedy"]["StepFlops"]] >= N[8] (1 - 10^-9), True, TestID -> "greedy-26"]
VerificationTest[Total[EinsumPath["b,b,abc->acb", {{3}, {3}, {5, 3, 2}}, "Path" -> "Optimal"]["StepFlops"]], N[33], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-27"]
VerificationTest[Total[EinsumPath["b,b,abc->acb", {{3}, {3}, {5, 3, 2}}, "Path" -> "Greedy"]["StepFlops"]] >= N[33] (1 - 10^-9), True, TestID -> "greedy-27"]
VerificationTest[Total[EinsumPath["ad,h,ga,b->gab", {{3, 3}, {3}, {7, 3}, {8}}, "Path" -> "Optimal"]["StepFlops"]], N[192], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-28"]
VerificationTest[Total[EinsumPath["ad,h,ga,b->gab", {{3, 3}, {3}, {7, 3}, {8}}, "Path" -> "Greedy"]["StepFlops"]] >= N[192] (1 - 10^-9), True, TestID -> "greedy-28"]
VerificationTest[Total[EinsumPath["b,acb,bbb->cab", {{7}, {6, 3, 7}, {7, 7, 7}}, "Path" -> "Optimal"]["StepFlops"]], N[133], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-29"]
VerificationTest[Total[EinsumPath["b,acb,bbb->cab", {{7}, {6, 3, 7}, {7, 7, 7}}, "Path" -> "Greedy"]["StepFlops"]] >= N[133] (1 - 10^-9), True, TestID -> "greedy-29"]
VerificationTest[Total[EinsumPath["b,c,dda,c,dac,bb->c", {{4}, {3}, {3, 3, 8}, {3}, {3, 8, 3}, {4, 4}}, "Path" -> "Optimal"]["StepFlops"]], N[85], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-30"]
VerificationTest[Total[EinsumPath["b,c,dda,c,dac,bb->c", {{4}, {3}, {3, 3, 8}, {3}, {3, 8, 3}, {4, 4}}, "Path" -> "Greedy"]["StepFlops"]] >= N[85] (1 - 10^-9), True, TestID -> "greedy-30"]
VerificationTest[Total[EinsumPath["ggh,gfc,ffh,ccc,a->fag", {{8, 8, 2}, {8, 7, 3}, {7, 7, 2}, {3, 3, 3}, {2}}, "Path" -> "Optimal"]["StepFlops"]], N[448], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-31"]
VerificationTest[Total[EinsumPath["ggh,gfc,ffh,ccc,a->fag", {{8, 8, 2}, {8, 7, 3}, {7, 7, 2}, {3, 3, 3}, {2}}, "Path" -> "Greedy"]["StepFlops"]] >= N[448] (1 - 10^-9), True, TestID -> "greedy-31"]
VerificationTest[Total[EinsumPath["d,a,f,dc,abd,cee->e", {{8}, {8}, {3}, {8, 7}, {8, 4, 8}, {7, 6, 6}}, "Path" -> "Optimal"]["StepFlops"]], N[176], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-32"]
VerificationTest[Total[EinsumPath["d,a,f,dc,abd,cee->e", {{8}, {8}, {3}, {8, 7}, {8, 4, 8}, {7, 6, 6}}, "Path" -> "Greedy"]["StepFlops"]] >= N[176] (1 - 10^-9), True, TestID -> "greedy-32"]
VerificationTest[Total[EinsumPath["a,df,a->adf", {{3}, {4, 6}, {3}}, "Path" -> "Optimal"]["StepFlops"]], N[75], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-33"]
VerificationTest[Total[EinsumPath["a,df,a->adf", {{3}, {4, 6}, {3}}, "Path" -> "Greedy"]["StepFlops"]] >= N[75] (1 - 10^-9), True, TestID -> "greedy-33"]
VerificationTest[Total[EinsumPath["ddf,faf,cd->", {{5, 5, 2}, {2, 8, 2}, {5, 5}}, "Path" -> "Optimal"]["StepFlops"]], N[12], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-34"]
VerificationTest[Total[EinsumPath["ddf,faf,cd->", {{5, 5, 2}, {2, 8, 2}, {5, 5}}, "Path" -> "Greedy"]["StepFlops"]] >= N[12] (1 - 10^-9), True, TestID -> "greedy-34"]
VerificationTest[Total[EinsumPath["d,bb,a,e,ad,ed->ba", {{5}, {6, 6}, {2}, {7}, {2, 5}, {7, 5}}, "Path" -> "Optimal"]["StepFlops"]], N[64], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-35"]
VerificationTest[Total[EinsumPath["d,bb,a,e,ad,ed->ba", {{5}, {6, 6}, {2}, {7}, {2, 5}, {7, 5}}, "Path" -> "Greedy"]["StepFlops"]] >= N[64] (1 - 10^-9), True, TestID -> "greedy-35"]
VerificationTest[Total[EinsumPath["eec,ad,c,f->def", {{2, 2, 7}, {3, 6}, {7}, {7}}, "Path" -> "Optimal"]["StepFlops"]], N[110], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-36"]
VerificationTest[Total[EinsumPath["eec,ad,c,f->def", {{2, 2, 7}, {3, 6}, {7}, {7}}, "Path" -> "Greedy"]["StepFlops"]] >= N[110] (1 - 10^-9), True, TestID -> "greedy-36"]
VerificationTest[Total[EinsumPath["bbc,c,bcc,acb,cab->cab", {{3, 3, 7}, {7}, {3, 7, 7}, {4, 7, 3}, {7, 4, 3}}, "Path" -> "Optimal"]["StepFlops"]], N[210], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-37"]
VerificationTest[Total[EinsumPath["bbc,c,bcc,acb,cab->cab", {{3, 3, 7}, {7}, {3, 7, 7}, {4, 7, 3}, {7, 4, 3}}, "Path" -> "Greedy"]["StepFlops"]] >= N[210] (1 - 10^-9), True, TestID -> "greedy-37"]
VerificationTest[Total[EinsumPath["ce,b,dg,cc,gc->cbg", {{6, 4}, {3}, {4, 3}, {6, 6}, {3, 6}}, "Path" -> "Optimal"]["StepFlops"]], N[87], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-38"]
VerificationTest[Total[EinsumPath["ce,b,dg,cc,gc->cbg", {{6, 4}, {3}, {4, 3}, {6, 6}, {3, 6}}, "Path" -> "Greedy"]["StepFlops"]] >= N[87] (1 - 10^-9), True, TestID -> "greedy-38"]
VerificationTest[Total[EinsumPath["daa,e,b,ca->", {{4, 3, 3}, {5}, {4}, {8, 3}}, "Path" -> "Optimal"]["StepFlops"]], N[5], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-39"]
VerificationTest[Total[EinsumPath["daa,e,b,ca->", {{4, 3, 3}, {5}, {4}, {8, 3}}, "Path" -> "Greedy"]["StepFlops"]] >= N[5] (1 - 10^-9), True, TestID -> "greedy-39"]
VerificationTest[Total[EinsumPath["b,cd,ffd,b->f", {{6}, {5, 7}, {6, 6, 7}, {6}}, "Path" -> "Optimal"]["StepFlops"]], N[54], SameTest -> (Abs[#1 - #2] <= 10^-9 Abs[#2] &), TestID -> "path-40"]
VerificationTest[Total[EinsumPath["b,cd,ffd,b->f", {{6}, {5, 7}, {6, 6, 7}, {6}}, "Path" -> "Greedy"]["StepFlops"]] >= N[54] (1 - 10^-9), True, TestID -> "greedy-40"]

(* ::Section:: *)
(* 3. Random machine-precision tests against the brute-force reference *)

SeedRandom[20261011];
$refSpecs = {
  {"ij,jk->ik", {{3, 4}, {4, 5}}}, {"bij,bjk->bik", {{6, 3, 4}, {6, 4, 2}}}, {"bij,bjk->bik", {{40, 2, 2}, {40, 2, 2}}},
  {"ijk,ijk,ijk->", {{3, 4, 2}, {3, 4, 2}, {3, 4, 2}}}, {"ai,bi,ci->abc", {{3, 5}, {2, 5}, {4, 5}}},
  {"ij,jk,jl->ikl", {{2, 3}, {3, 4}, {3, 2}}}, {"iij->j", {{3, 3, 4}}}, {"ii,ii,ij->j", {{3, 3}, {3, 3}, {3, 2}}},
  {"abc,cd,dbe->ae", {{2, 3, 4}, {4, 2}, {2, 3, 2}}}, {"ab,bc,cd,da->", {{3, 4}, {4, 2}, {2, 5}, {5, 3}}},
  {"aib,bjc,ckd,dla->ijkl", {{2, 2, 3}, {3, 2, 2}, {2, 2, 3}, {3, 2, 2}}}, {"ij,ij,ij,ij->i", {{4, 3}, {4, 3}, {4, 3}, {4, 3}}},
  {"bi,bj,bk->bijk", {{5, 2}, {5, 3}, {5, 2}}}, {"xyz,yz->x", {{2, 3, 4}, {3, 4}}}, {"ijk,kji->", {{2, 3, 4}, {4, 3, 2}}},
  (* batched contractions with no free label on one or both sides ("Reduce" steps when both) *)
  {"kh,kh->h", {{5, 4}, {5, 4}}}, {"kh,khn->hn", {{5, 4}, {5, 4, 3}}}, {"khn,hkn->kh", {{3, 4, 5}, {4, 3, 5}}},
  {"kh,hkn->nh", {{3, 4}, {4, 3, 2}}}, {"khn,kh->nh", {{3, 4, 2}, {3, 4}}}, {"kh,kh,kh->h", {{5, 4}, {5, 4}, {5, 4}}}};
Do[
  With[{spec = s[[1]], ts = RandomReal[{-1, 1}, #] & /@ s[[2]], cts = RandomComplex[{-1 - I, 1 + I}, #] & /@ s[[2]]},
    VerificationTest[maxDiff[Einsum[spec, Sequence @@ ts], refEinsum[spec, Sequence @@ ts]] < 10^-10, True, TestID -> "ref-real-" <> spec];
    VerificationTest[maxDiff[Einsum[spec, Sequence @@ cts], refEinsum[spec, Sequence @@ cts]] < 10^-10, True, TestID -> "ref-complex-" <> spec];
    VerificationTest[maxDiff[Einsum[spec, Sequence @@ ts, "BatchMethod" -> "Vectorized"], refEinsum[spec, Sequence @@ ts]] < 10^-10, True, TestID -> "ref-vec-" <> spec];
    VerificationTest[maxDiff[Einsum[spec, Sequence @@ ts, "BatchMethod" -> "Dot"], refEinsum[spec, Sequence @@ ts]] < 10^-10, True, TestID -> "ref-dot-" <> spec]],
  {s, $refSpecs}];

(* results stay packed for packed input *)
VerificationTest[Developer`PackedArrayQ[Einsum["bij,bjk->bik", RandomReal[1, {50, 3, 3}], RandomReal[1, {50, 3, 3}]]], True, TestID -> "packed-vec"]
VerificationTest[Developer`PackedArrayQ[Einsum["bij,bjk->bik", RandomReal[1, {5, 40, 40}], RandomReal[1, {5, 40, 40}]]], True, TestID -> "packed-dot"]
VerificationTest[Developer`PackedArrayQ[Einsum["ijk,ijk,ijk->ij", Sequence @@ RandomReal[1, {3, 4, 5, 6}]]], True, TestID -> "packed-hyper"]
VerificationTest[Developer`PackedArrayQ[Einsum["khn,hkn->kh", RandomReal[1, {6, 5, 4}], RandomReal[1, {5, 6, 4}]]], True, TestID -> "packed-reduce"]

(* the batch label is not the first one: multiply in place and sum, instead of transposing both operands *)
VerificationTest[#["Type"] & /@ EinsumFunction["kh,kh->h", {{5, 4}, {5, 4}}]["Plan"]["Steps"], {"Reduce"}, TestID -> "reduce-used"]
VerificationTest[#["Type"] & /@ EinsumFunction["khn,hkn->kh", {{5, 4, 3}, {4, 5, 3}}]["Plan"]["Steps"], {"Reduce"}, TestID -> "reduce-used-permuted"]
VerificationTest[#["Type"] & /@ EinsumFunction["kh,khn->hn", {{5, 4}, {5, 4, 3}}]["Plan"]["Steps"], {"Batch"}, TestID -> "reduce-not-with-free-label"]
VerificationTest[#["Type"] & /@ EinsumFunction["bi,bi->b", {{5, 4}, {5, 4}}]["Plan"]["Steps"], {"Batch"}, TestID -> "reduce-not-needed"]

(* agreement with TensorContract / Dot on larger random data *)
With[{a = RandomReal[1, {20, 30}], b = RandomReal[1, {30, 40}], c = RandomReal[1, {40, 10}]},
  VerificationTest[maxDiff[Einsum["ij,jk,kl->il", a, b, c], a . b . c] < 10^-9, True, TestID -> "chain-dot"]];
With[{t = RandomReal[1, {4, 5, 6}], m = RandomReal[1, {6, 5}]},
  VerificationTest[maxDiff[Einsum["ijk,kj->i", t, m], TensorContract[TensorProduct[t, m], {{2, 5}, {3, 4}}]] < 10^-9, True, TestID -> "tensorcontract"]];

(* symbolic and sparse inputs *)
VerificationTest[Einsum["ij,jk->ik", Array[a, {2, 3}], Array[b, {3, 2}]], Array[a, {2, 3}] . Array[b, {3, 2}], TestID -> "symbolic-dot"]
VerificationTest[Einsum["ii", Array[a, {3, 3}]], Tr[Array[a, {3, 3}]], TestID -> "symbolic-trace"]
VerificationTest[Expand[Einsum["i,i,i->", {x, y}, {x, y}, {x, y}]], x^3 + y^3, TestID -> "symbolic-hyper"]
With[{s = SparseArray[{{1, 2} -> 1., {3, 1} -> 2.}, {3, 3}], d = RandomReal[1, {3, 4}]},
  VerificationTest[maxDiff[Einsum["ij,jk->ik", s, d], Normal[s] . d] < 10^-12, True, TestID -> "sparse-dot"];
  VerificationTest[maxDiff[Einsum["ij,ij->i", s, Normal[s]], Total[Normal[s]^2, {2}]] < 10^-12, True, TestID -> "sparse-hadamard"]];

(* ::Section:: *)
(* 4. Syntax variants *)

With[{m = {{1, 2}, {3, 4}}, n = {{0, 1}, {1, 1}}},
  VerificationTest[Einsum[{{"i", "j"}, {"j", "k"}} -> {"i", "k"}, m, n], m . n, TestID -> "list-strings"];
  VerificationTest[Einsum[{{1, 2}, {2, 3}} -> {3, 1}, m, n], Transpose[m . n], TestID -> "list-integers"];
  VerificationTest[Einsum[{{"bond1", "x"}, {"x", "bond2"}}, m, n], m . n, TestID -> "list-implicit"];
  VerificationTest[Einsum["\[Alpha]\[Beta],\[Beta]\[Gamma]->\[Alpha]\[Gamma]", m, n], m . n, TestID -> "greek"];
  VerificationTest[Einsum["ij,jk\[RightArrow]ik", m, n], m . n, TestID -> "arrow"];
  VerificationTest[Einsum[" i j , j k -> i k ", m, n], m . n, TestID -> "spaces"];
  VerificationTest[Einsum["ij,jk", m, n], m . n, TestID -> "implicit"];
  VerificationTest[Einsum["ji", m], Transpose[m], TestID -> "implicit-transpose"];
  VerificationTest[Einsum["...ij,...jk->...ik", {m, n}, n], {m . n, n . n}, TestID -> "ellipsis"];
  VerificationTest[Einsum["ij,jk->ik", m, n, "Path" -> {{1, 2}}], m . n, TestID -> "explicit-path"];
  VerificationTest[Einsum["ij,jk->ik", m, n, "Cache" -> False], m . n, TestID -> "nocache"]];

(* ::Section:: *)
(* 5. Errors *)

With[{m = {{1, 2}, {3, 4}}},
  VerificationTest[Einsum["ij,jk->>ik", m, m], $Failed, {Einsum::spec}, TestID -> "err-spec"];
  VerificationTest[Einsum["ij,jk->ik", m], $Failed, {Einsum::nargs}, TestID -> "err-nargs"];
  VerificationTest[Einsum["ijk,jk->ik", m, m], $Failed, {Einsum::rank}, TestID -> "err-rank"];
  VerificationTest[Einsum["ij,jk->ik", m, IdentityMatrix[3]], $Failed, {Einsum::dim}, TestID -> "err-dim"];
  VerificationTest[Einsum["ij->ii", m], $Failed, {Einsum::outrep}, TestID -> "err-outrep"];
  VerificationTest[Einsum["ij->iz", m], $Failed, {Einsum::outnf}, TestID -> "err-outnf"];
  VerificationTest[Einsum["...i->i", m], $Failed, {Einsum::ellout}, TestID -> "err-ellout"];
  VerificationTest[Einsum["ij,jk,kl->il", m, m, m, "Path" -> {{1, 2}}], $Failed, {Einsum::path}, TestID -> "err-path"];
  VerificationTest[Einsum["ij,jk->ik", {{1, 2}, {3}}, m], $Failed, {Einsum::array}, TestID -> "err-array"];
  VerificationTest[Einsum["i->", {1, 2}]; Einsum["i->", {{3}, {4, 5}}], $Failed, {Einsum::array}, TestID -> "err-array-cached"];
  VerificationTest[Einsum["ii->i", {{1, 2, 3}}], $Failed, {Einsum::dim}, TestID -> "err-diag-broadcast"];
  VerificationTest[Einsum["ij,jk->ik", m, m, "Path" -> "Foo"], $Failed, {Einsum::path}, TestID -> "err-path-2"];
  VerificationTest[Einsum["ij->ji", m, "Foo" -> 1], Transpose[m], {Einsum::optx}, TestID -> "warn-unknown-option"]];

(* compound expressions are scalars, even though Dimensions[a + b] == {2} *)
With[{m = {{1, 2}, {3, 4}}},
  VerificationTest[Einsum[",ij->ij", Sqrt[2], m], Sqrt[2] m, TestID -> "scalar-sqrt"];
  VerificationTest[Einsum[",i,i->", a + b, {1, 2}, {3, 4}], 11 (a + b), TestID -> "scalar-plus"];
  VerificationTest[EinsumFunction[",ij->ij", {{}, {2, 2}}][Sin[x], m], Sin[x] m, TestID -> "scalar-einsumfunction"]];

(* ::Section:: *)
(* 6. EinsumPath, EinsumFunction, cache *)

VerificationTest[EinsumPath["ij,jk,kl->il", {{2, 30}, {30, 40}, {40, 3}}]["Path"], {{1, 2}, {1, 2}}, TestID -> "einsumpath-path"]
VerificationTest[EinsumPath["ij,jk,kl->il", {{2, 30}, {30, 40}, {40, 3}}]["Flops"], 2640., TestID -> "einsumpath-flops"]
(* B.C first costs 2*40*30 + 30*2*30 = 4200 flops, A.B first would cost 30*2*40 + 30*40*30 = 38400 *)
VerificationTest[EinsumPath["ij,jk,kl->il", {{30, 2}, {2, 40}, {40, 30}}]["Contractions"], {"jk,kl->jl", "ij,jl->il"}, TestID -> "einsumpath-contractions"]
With[{ef = EinsumFunction["bij,bjk->bik", {{4, 3, 2}, {4, 2, 5}}], x = RandomReal[1, {4, 3, 2}], y = RandomReal[1, {4, 2, 5}]},
  VerificationTest[maxDiff[ef[x, y], Table[x[[b]] . y[[b]], {b, 4}]] < 10^-12, True, TestID -> "einsumfunction"];
  VerificationTest[ef[y, x], $Failed, {Einsum::mismatch}, TestID -> "einsumfunction-mismatch"];
  VerificationTest[ef["Path"], {{1, 2}}, TestID -> "einsumfunction-path"];
  VerificationTest[!FreeQ[ToBoxes[ef], s_String /; StringContainsQ[s, "Spec"]], True, TestID -> "einsumfunction-summarybox"]];
VerificationTest[EinsumClearCache[]; Einsum["ij,jk->ik", {{1}}, {{2}}], {{2}}, TestID -> "clear-cache"]

(* ::Section:: *)
(* 7. Visualisation *)

VerificationTest[Head[EinsumDiagram["ai,ibj,jck,kd->abcd"]], Graphics, TestID -> "diagram-mps"]
VerificationTest[Head[EinsumDiagram["ijk,ijk,ijk->"]], Graphics, TestID -> "diagram-hyper"]
VerificationTest[Head[EinsumDiagram["iij,jk,k->i", {{3, 3, 4}, {4, 5}, {5}}, "ShowPath" -> True]], Graphics, TestID -> "diagram-path"]
VerificationTest[Head[EinsumDiagram["ab,bc,ca->", "Layout" -> "Circle", "TensorNames" -> {"X", "Y", "Z"}]], Graphics, TestID -> "diagram-circle"]
VerificationTest[Head[EinsumDiagram["ij,kl->ijkl", "Layout" -> "Line"]], Graphics, TestID -> "diagram-line"]
VerificationTest[Length[EinsumDiagram["ij,jk,kl,lm->im", {{2, 3}, {3, 4}, {4, 5}, {5, 6}}, "Steps" -> True]], 4, TestID -> "diagram-steps"]
VerificationTest[Head[EinsumTree["ai,bi,ci->abc", {{3, 4}, {5, 4}, {6, 4}}]], Graphics, TestID -> "tree"]
VerificationTest[With[{psi = RandomReal[1, {2, 3}]}, Head[EinsumDiagram["ai,bi->ab", psi, psi]]], Graphics, TestID -> "diagram-symbol-names"]
VerificationTest[With[{opts = {"ShowPath" -> True, "Layout" -> "Circle"}}, Head[EinsumDiagram["ij,jk,ki->", {{2, 3}, {3, 4}, {4, 2}}, opts]]], Graphics, TestID -> "diagram-options-variable"]
VerificationTest[With[{opts = {"ShowPath" -> True}}, Head[EinsumDiagram["ij,jk,ki->", {{2, 3}, {3, 4}, {4, 2}}, Sequence @@ opts]]], Graphics, TestID -> "diagram-options-sequence"]
VerificationTest[Module[{n0 = Length[Names["Summa`Private`ms$*"]]}, Do[EinsumPath["ij,jk,kl,lm->im", {{2, 3}, {3, 4}, {4, 5}, {5, 6}}], {20}]; Length[Names["Summa`Private`ms$*"]] - n0], 0, TestID -> "no-temporary-leak"]
VerificationTest[Developer`PackedArrayQ[Einsum["bij,bjk->bik", RandomReal[1, {500, 3, 4}], RandomReal[1, {500, 4, 5}], "BatchMethod" -> "Vectorized"]], True, TestID -> "packed-vec-table"]

(* ---------------------------------------------------------------- the banner and the update check, without the network *)
(* the answer of GitHub read from a saved one (LatestRelease.json, a release 0.9.0 made up in the form of GitHub's answer; its text is UTF-8); the line
   of a newer release (the next patch of the version loaded); the once-a-day rule in a temporary directory; loading in a
   script, which never checks; the setting typed before the package is loaded *)
VerificationTest[Summa`Private`newerVersionQ @@@ {{"0.10.0", "0.9.0"}, {"0.9.0", "0.10.0"}, {"v0.9.0", "0.9.0"}, {"1.0.0", "0.99.99"},
    {"0.9.1", "0.9.0"}, {"v0.3.0-rc1", "0.9.0"}, {"0.3", "0.9.0"}, {"version 0.3.0", "0.9.0"}},
  {True, False, False, True, True, False, False, False}, TestID -> "update check: versions compared number by number"]
latestAnswer = FromCharacterCode[BinaryReadList[FileNameJoin[{testDir, "LatestRelease.json"}]], "UTF-8"];
latestRelease = <|"Version" -> "0.9.0", "Paclet" -> "https://github.com/n4sd4q/Summa/releases/download/v0.9.0/Summa-0.9.0.paclet",
   "Page" -> "https://github.com/n4sd4q/Summa/releases/tag/v0.9.0"|>;
VerificationTest[{Max[ToCharacterCode[latestAnswer]] > 127, Summa`Private`latestReleaseOf[latestAnswer]},
  {True, latestRelease}, TestID -> "update check: the latest release read from an answer of GitHub (text beyond ASCII)"]
VerificationTest[Summa`Private`latestReleaseOf /@ {
    StringReplace[latestAnswer, "\"draft\": false" -> "\"draft\": true"],
    StringReplace[latestAnswer, "\"prerelease\": false" -> "\"prerelease\": true"],
    StringReplace[latestAnswer, "\"tag_name\": \"v0.9.0\"" -> "\"tag_name\": \"v0.3.0-rc1\""],
    StringReplace[latestAnswer, "github.com/n4sd4q/Summa/releases/download" -> "example.com/releases/download"],
    StringReplace[latestAnswer, "/Summa-0.9.0.paclet\"" -> "/a\\\"]; Quit[]; (\\\".paclet\""],
    "{\"message\": \"API rate limit exceeded\", \"documentation_url\": \"https://docs.github.com/rest\"}", "<html>offline</html>", $Failed},
  ConstantArray[$Failed, 8], TestID -> "update check: no release for a draft, a pre-release, a malformed tag, a paclet elsewhere or with a quote, an error"]
nextVersion = StringRiffle[ToString /@ (Summa`Private`versionNumbers[$SummaVersion] + {0, 0, 1}), "."];
newerRelease = Summa`Private`latestReleaseOf[StringReplace[latestAnswer, "0.9.0" -> nextVersion]];
VerificationTest[With[{paclet = "https://github.com/n4sd4q/Summa/releases/download/v" <> nextVersion <> "/Summa-" <> nextVersion <> ".paclet"},
   {Summa`Private`newerVersionQ[newerRelease["Version"], $SummaVersion],
    Summa`Private`newerVersionQ[latestRelease["Version"], $SummaVersion],
    Cases[Summa`Private`loadBanner[], Column[lines_List, ___] :> Length[lines], Infinity],
    Cases[Summa`Private`loadBanner[newerRelease], Column[lines_List, ___] :> Length[lines], Infinity],
    Cases[Summa`Private`updateNotice[newerRelease], Hyperlink[_, url_] :> url, Infinity] === {"https://github.com/n4sd4q/Summa/releases/tag/v" <> nextVersion},
    Cases[Summa`Private`updateNotice[newerRelease], Defer[e_] :> HoldForm[e], Infinity] === {HoldForm[PacletInstall[paclet]]},
    Summa`Private`updateNoticeText[newerRelease] === "Summa " <> nextVersion <> " is available (" <> $SummaVersion <>
      " is loaded): PacletInstall[\"" <> paclet <> "\"]"}],
  {True, False, {2}, {3}, True, True, True}, TestID -> "update check: the line of a newer release under the banner, and as text"]
VerificationTest[Module[{dir = CreateDirectory[], r},
   r = {Summa`Private`updateCheckDueQ[FileNameJoin[{dir, "a"}], "2026-11-10"], Summa`Private`updateCheckDueQ[FileNameJoin[{dir, "a"}], "2026-11-10"],
     Summa`Private`updateCheckDueQ[FileNameJoin[{dir, "a"}], "2026-11-11"], StringTrim[ReadString[FileNameJoin[{dir, "a", "LastUpdateCheck.txt"}]]],
     Quiet[Summa`Private`updateCheckDueQ[FileNameJoin[{dir, "a", "LastUpdateCheck.txt", "b"}], "2026-11-10"]]};
   DeleteDirectory[dir, DeleteContents -> True]; r],
  {True, False, True, "2026-11-11", True}, TestID -> "update check: at most once a day; a date that cannot be kept means a check"]
(* in fresh kernels (scripts): loading prints nothing and asks nothing; $SummaUpdateCheck = False typed before loading is the
   package's setting and the symbol typed is removed; loading again keeps the setting *)
freshKernel[code_String] := Module[{file = FileNameJoin[{$TemporaryDirectory, "summa_check_" <> ToString[RandomInteger[10^9]] <> ".wl"}], out},
   Export[file, "PacletDirectoryLoad[" <> ToString[FileNameJoin[{root, "Summa"}], InputForm] <> "];\n" <> code, "Text"];
   out = RunProcess[{First[$CommandLine], "-script", file}, "StandardOutput"]; DeleteFile[file]; StringTrim[out]];
VerificationTest[{freshKernel["Needs[\"Summa`\"];"],
   freshKernel["$SummaUpdateCheck = False;\nNeeds[\"Summa`\"];\nPrint[ToString[{Summa`$SummaUpdateCheck, Names[\"Global`$SummaUpdateCheck\"]}, InputForm]];"],
   freshKernel["Needs[\"Summa`\"];\n$SummaUpdateCheck = False;\nGet[\"Summa`\"];\nPrint[ToString[$SummaUpdateCheck, InputForm]];"]},
  {"", "{False, {}}", "False"}, TestID -> "update check: a script loads the package printing nothing; the setting typed before loading is kept"]
