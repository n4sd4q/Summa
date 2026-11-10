(* ::Package:: *)

(* :Title: Einsum *)
(* :Context: Summa` *)
(* :Package Version: 1.0.0 *)
(* :Mathematica Version: 11.3 *)
(* :Summary:
     Fast Einstein summation (einsum) for the Wolfram Language.
     - numpy-compatible string syntax ("ij,jk->ik", implicit output, "...", Unicode labels)
       plus a list syntax with arbitrary expressions as labels;
     - indices may be repeated ANY number of times: inside one tensor (diagonals, traces)
       and across tensors (hyperedges / batch indices shared by 3, 4, ... tensors);
     - contraction order optimised automatically (exact subset DP or greedy);
     - every pairwise contraction is lowered to BLAS (Dot) or to vectorised kernels
       (batched contractions, broadcasting), with transposes avoided whenever possible;
     - contraction plans are cached; EinsumFunction precompiles an einsum for fixed shapes;
     - EinsumDiagram / EinsumTree draw the tensor network and the contraction tree.
*)

BeginPackage["Summa`"];

(* $SummaUpdateCheck keeps its setting: the package's own when the package is loaded again, or that of the symbol made
   by typing the name before the package was first loaded (a symbol of Global` or of another context), which is removed
   before the package's symbol is made, so that neither shadows the other. The symbols are named by strings, since a name
   in this code would make the package's symbol at once *)
With[{Summa`Private`others = Select[Names["*`$SummaUpdateCheck"], StringContainsQ[#, "`"] && ! StringStartsQ[#, "Summa`"] &]},
  With[{Summa`Private`setting = Join @@ (If[ToExpression[#, InputForm, ValueQ], {ToExpression[#]}, {}] &) /@ Summa`Private`others},
   Scan[Quiet[Remove[#]] &, Summa`Private`others];
   If[Summa`Private`setting =!= {} && ! ToExpression["Summa`$SummaUpdateCheck", InputForm, ValueQ],
    ToExpression["Summa`$SummaUpdateCheck = " <> ToString[Last[Summa`Private`setting], InputForm]]]]];

$SummaVersion::usage = "$SummaVersion is the version of Summa.";
SummaUpdateCheck::usage = "SummaUpdateCheck[] asks GitHub (api.github.com) for the latest release of Summa and gives \
<|\"InstalledVersion\" -> ..., \"LatestVersion\" -> ..., \"InstallLine\" -> ...|>, the version loaded, the latest release and the \
PacletInstall line of its paclet; when the latest release is newer, it also prints that line. It gives $Failed, with a message, when \
the release cannot be read. Loading Summa in a notebook does the same check by itself, at most once a day (see $SummaUpdateCheck).";
$SummaUpdateCheck::usage = "$SummaUpdateCheck is True (the default) when loading Summa in a notebook checks for a newer \
release: at most once a day, in the background, it asks GitHub (api.github.com) for the latest release and, if it is newer than \
$SummaVersion, adds to the banner the PacletInstall line of that release; any failure is silent, and scripts never check. Set \
$SummaUpdateCheck = False before Needs[\"Summa`\"] (in init.m to turn it off for good) to load without it. \
SummaUpdateCheck[] checks by hand.";

Summa`Einsum::usage =
"Einsum[\"spec\", t1, t2, \[Ellipsis]] evaluates the Einstein summation described by the numpy-style string spec, e.g. \"ij,jk->ik\", \"bij,bjk->bik\", \"ijk,ijk,ijk->\", \"ii->i\", \"...ij,...jk->...ik\". Without \"->\" the output contains the indices appearing exactly once, in alphabetical order.
Einsum[{{i,j},{j,k}} -> {i,k}, t1, t2] uses arbitrary expressions as index labels.
Indices can be repeated any number of times, within a tensor and across tensors. The contraction order is optimised and each pairwise contraction is mapped to BLAS or to vectorised kernels. Options: \"Path\" (Automatic, \"Optimal\", \"Greedy\", \"Sequential\" or a list of pairs), \"BatchMethod\" (Automatic, \"Dot\", \"Vectorized\"), \"Cache\" (True).";

Summa`EinsumPath::usage =
"EinsumPath[spec, t1, t2, \[Ellipsis]] or EinsumPath[spec, {dims1, dims2, \[Ellipsis]}] returns an Association describing the contraction path chosen for the einsum and its cost (flops, speed-up over the naive sum, largest intermediate).";

Summa`EinsumFunction::usage =
"EinsumFunction[spec, {dims1, dims2, \[Ellipsis]}] precompiles the einsum for tensors of the given dimensions. Apply it as ef[t1, t2, \[Ellipsis]]. Properties: ef[\"Path\"], ef[\"Flops\"], ef[\"Speedup\"], ef[\"Diagram\"], ef[\"Tree\"], ef[\"Properties\"].";

Summa`EinsumDiagram::usage =
"EinsumDiagram[spec] draws the tensor network of an einsum: tensors are nodes, contracted indices are bonds, output indices are open legs, indices shared by three or more tensors are drawn as hyperedges (COPY-tensor dots), traces as loops and summed-out indices as legs ending in a small circle.
EinsumDiagram[spec, t1, \[Ellipsis]] or EinsumDiagram[spec, {dims1, \[Ellipsis]}] also shows dimensions. Options: \"ShowPath\" -> True numbers the bonds in contraction order, \"Steps\" -> True returns one frame per pairwise contraction, \"Layout\", \"TensorNames\", \"Highlight\", \"ShowDimensions\".";

Summa`EinsumTree::usage =
"EinsumTree[spec, t1, \[Ellipsis]] or EinsumTree[spec, {dims1, \[Ellipsis]}] draws the contraction tree chosen by the optimiser, with the indices and the cost of every intermediate.";

Summa`EinsumClearCache::usage =
"EinsumClearCache[] empties the cache of contraction plans used by Einsum.";

Begin["`Private`"];

$SummaVersion = "1.0.0";

(* ::Section:: *)
(* Messages and error handling *)

Einsum::spec = "Invalid einsum specification `1`.";
Einsum::nargs = "The specification has `1` operand(s) but `2` tensor(s) were given.";
Einsum::rank = "Operand `1` has rank `2` but its subscript has `3` indices.";
Einsum::ellrank = "Operand `1` has rank `2`, smaller than the `3` explicit indices of its subscript.";
Einsum::ell = "The ellipsis can appear at most once in each subscript.";
Einsum::ellout = "The inputs have broadcast (ellipsis) dimensions, so the output subscript must contain \"...\".";
Einsum::dim = "Index `1` has incompatible dimensions `2`.";
Einsum::outrep = "Output index `1` appears more than once.";
Einsum::outnf = "Output index `1` does not appear in any input.";
Einsum::path = "Invalid contraction path `1`. Use Automatic, \"Optimal\", \"Greedy\", \"Sequential\" or a complete list of position pairs {{i, j}, \[Ellipsis]}.";
Einsum::array = "Operand `1` is not a rectangular array.";
Einsum::mismatch = "The tensors have dimensions `1`, but the EinsumFunction was compiled for `2`.";
Einsum::optbig = "The exact path search is exponential and `1` tensors exceed the limit of `2`; using \"Greedy\" instead.";

SetAttributes[fail, HoldFirst];
fail[msg_, args___] := (Message[msg, args]; Throw[$Failed, $einsumTag]);

(* ::Section:: *)
(* Parsing *)

(* Parsed specification: <|"Terms" -> {term..}, "Output" -> term | Automatic, "Type" -> "Char" | "Expr"|>
   where a term is a list of labels, possibly containing the marker ellipsisMark. *)

$ellipsisChar = "\[Ellipsis]";

splitComma[s_String] := Module[{p},
  p = Join[{0}, First /@ StringPosition[s, ","], {StringLength[s] + 1}];
  Table[StringTake[s, {p[[k]] + 1, p[[k + 1]] - 1}], {k, Length[p] - 1}]
];

tokenizeTerm[t_String, spec_] := Module[{chars},
  chars = Characters[StringReplace[t, "..." -> $ellipsisChar]];
  If[Count[chars, $ellipsisChar] > 1, fail[Einsum::ell]];
  If[MemberQ[chars, "." | "-" | ">" | ","], fail[Einsum::spec, spec]];
  Replace[chars, $ellipsisChar -> ellipsisMark, {1}]
];

parseSpec[s_String] := Module[{str, pos, lhs, rhs},
  str = StringReplace[s, {"\[Rule]" -> "->", "\[RightArrow]" -> "->", "\[LongRightArrow]" -> "->",
     $ellipsisChar -> "...", " " -> "", "\t" -> "", "\n" -> ""}];
  pos = StringPosition[str, "->"];
  Which[
    pos === {}, lhs = str; rhs = Automatic,
    Length[pos] == 1, lhs = StringTake[str, pos[[1, 1]] - 1]; rhs = StringDrop[str, pos[[1, 2]]],
    True, fail[Einsum::spec, s]
  ];
  <|"Terms" -> (tokenizeTerm[#, s] & /@ splitComma[lhs]),
    "Output" -> If[rhs === Automatic, Automatic, tokenizeTerm[rhs, s]],
    "Type" -> "Char"|>
];

listTerm[t_String, spec_] := tokenizeTerm[t, spec];
listTerm[t_List, spec_] := Module[{r},
  If[AnyTrue[t, ListQ], fail[Einsum::spec, spec]];
  r = Replace[t, ("..." | $ellipsisChar) -> ellipsisMark, {1}];
  If[Count[r, ellipsisMark] > 1, fail[Einsum::ell]];
  r
];
listTerm[_, spec_] := fail[Einsum::spec, spec];

parseSpec[Rule[l_String, r_String]] := parseSpec[l <> "->" <> r];
parseSpec[Rule[ins_List, out_]] := <|
  "Terms" -> (listTerm[#, ins -> out] & /@ ins),
  "Output" -> If[out === Automatic, Automatic, listTerm[out, ins -> out]],
  "Type" -> If[AllTrue[ins, StringQ] && (out === Automatic || StringQ[out]), "Char", "Expr"]|>;
parseSpec[ins_List] := parseSpec[ins -> Automatic];
parseSpec[other_] := fail[Einsum::spec, other];

(* ::Section:: *)
(* Resolution: ellipsis expansion, implicit output, integer label ids *)

expandEll[term_List, ells_List] := Join @@ Replace[term, {ellipsisMark -> ells, x_ :> {x}}, {1}];

labelSort[labs_List, "Char"] := SortBy[labs, ToCharacterCode];
labelSort[labs_List, _] := Sort[labs];

displayLabel[ellLabel[j_]] := $ellipsisChar <> ToString[j];
displayLabel[x_] := x;

(* Returns <|"Inputs" -> {{id..}..}, "Output" -> {id..}, "Names" -> {label..}, "Type" -> ...|>.
   Ids are 1..m in order of first appearance in the inputs. *)
resolveSpec[parsed_Association, ranks_List] := Module[
  {terms = parsed["Terms"], outT = parsed["Output"], n, nEll, maxEll, ells, inputs, all, out, labs, idOf},
  n = Length[terms];
  If[n =!= Length[ranks], fail[Einsum::nargs, n, Length[ranks]]];
  nEll = Table[
    With[{ne = Count[terms[[k]], Except[ellipsisMark]]},
      If[MemberQ[terms[[k]], ellipsisMark],
        If[ranks[[k]] < ne, fail[Einsum::ellrank, k, ranks[[k]], ne]]; ranks[[k]] - ne,
        If[ranks[[k]] =!= ne, fail[Einsum::rank, k, ranks[[k]], ne]]; 0]],
    {k, n}];
  maxEll = Max[0, nEll];
  ells = Table[ellLabel[j], {j, maxEll}];
  inputs = Table[expandEll[terms[[k]], Take[ells, -nEll[[k]]]], {k, n}];
  all = Join @@ inputs;
  out = If[outT === Automatic,
    Join[ells, labelSort[Cases[Tally[all], {l_, 1} /; Head[l] =!= ellLabel :> l], parsed["Type"]]],
    If[maxEll > 0 && FreeQ[outT, ellipsisMark], fail[Einsum::ellout]];
    expandEll[outT, ells]];
  If[Length[DeleteDuplicates[out]] < Length[out],
    fail[Einsum::outrep, displayLabel[First[Cases[Tally[out], {l_, c_} /; c > 1 :> l]]]]];
  labs = DeleteDuplicates[all];
  idOf = AssociationThread[labs -> Range[Length[labs]]];
  Scan[If[!KeyExistsQ[idOf, #], fail[Einsum::outnf, displayLabel[#]]] &, out];
  <|"Inputs" -> Map[idOf, inputs, {2}], "Output" -> (idOf /@ out),
    "Names" -> (displayLabel /@ labs), "Type" -> parsed["Type"]|>
];

(* Dimension of every label, with numpy-style broadcasting of size-1 axes.
   Returns {dims, squeeze} where squeeze[[k]] lists the axes of operand k that are broadcast. *)
resolveDims[ids_List, shapes_List, names_List] := Module[{m = Length[names], n = Length[ids], occ, dims, sq},
  occ = Table[{}, {m}];
  Do[occ[[ids[[k, j]]]] = Append[occ[[ids[[k, j]]]], shapes[[k, j]]], {k, n}, {j, Length[ids[[k]]]}];
  dims = Table[
    With[{ds = DeleteDuplicates[occ[[l]]]},
      With[{dm = Max[ds]},
        If[Complement[ds, {1, dm}] =!= {}, fail[Einsum::dim, names[[l]], Sort[ds]]];
        dm]],
    {l, m}];
  Do[
    Scan[Function[l, With[{ds = DeleteDuplicates[Pick[shapes[[k]], ids[[k]], l]]},
        If[Length[ds] > 1, fail[Einsum::dim, names[[l]], Sort[ds]]]]],
      Cases[Tally[ids[[k]]], {l_, c_} /; c > 1 :> l]],
    {k, n}];
  sq = Table[Select[Range[Length[ids[[k]]]], shapes[[k, #]] == 1 && dims[[ids[[k, #]]]] > 1 &], {k, n}];
  {dims, sq}
];

(* Per-operand preprocessing: drop broadcast axes, take generalised diagonals of repeated labels
   (Transpose with repeated levels) and sum out labels used nowhere else. *)
prepInstr[lab_List, shape_List, sqPos_List, keepQ_] := Module[{l2, s2, u, diag, keepLabs, sumLv},
  l2 = If[sqPos === {}, lab, Delete[lab, List /@ sqPos]];
  s2 = If[sqPos === {}, shape, Delete[shape, List /@ sqPos]];
  u = DeleteDuplicates[l2];
  diag = If[Length[u] < Length[l2], Flatten[Position[u, #] & /@ l2], None];
  keepLabs = Select[u, keepQ];
  sumLv = Reverse[Sort[Flatten[Position[u, #] & /@ Complement[u, keepLabs]]]];
  <|"Squeeze" -> If[sqPos === {}, None, s2], "Diag" -> diag, "Sum" -> sumLv, "Labels" -> keepLabs|>
];

(* ::Section:: *)
(* Contraction paths *)

(* A path is given in SSA form: a list of pairs {a, b}; tensors 1..n are the inputs and step s
   creates tensor n+s. User paths use the numpy/opt_einsum "linear" convention instead. *)

$optimalLimit = 8;   (* Automatic: exact DP up to this many tensors, greedy beyond *)
$optimalMax = 14;    (* "Optimal" is O(3^n) in top-level code: fall back to greedy beyond this *)

lowBit[s_Integer] := 2^IntegerExponent[s, 2];

(* Exact minimisation of the total flop count by dynamic programming over subsets of tensors
   (O(3^n)). keep[S] = labels of the tensor obtained by contracting the subset S: those that are
   still needed by the tensors outside S or by the output -- this is what turns indices shared by
   three or more tensors into batch indices. *)
optimalPath[sets_List, dims_List, out_List] := Module[
  {n = Length[sets], labs, nl, posArr, dl, tmask, omask, full, uu, keep, cost, best, low, rest, sub,
   a, b, c, ms, next = Length[sets], steps = {}, build},
  labs = Union[Join @@ sets, out];
  nl = Length[labs];
  posArr = ConstantArray[0, Max[1, Length[dims]]];
  Scan[(posArr[[labs[[#]]]] = #) &, Range[nl]];
  dl = N[dims[[labs]]];
  tmask = Table[Total[2^(posArr[[sets[[t]]]] - 1)], {t, n}];
  omask = Total[2^(posArr[[out]] - 1)];
  full = 2^n - 1;
  uu = ConstantArray[0, full];
  Do[low = lowBit[s]; uu[[s]] = BitOr[If[s == low, 0, uu[[s - low]]], tmask[[IntegerExponent[s, 2] + 1]]], {s, full}];
  keep = Table[BitAnd[uu[[s]], BitOr[If[s == full, 0, uu[[full - s]]], omask]], {s, full}];
  ms[mask_] := ms[mask] = Times @@ Pick[dl, Reverse[IntegerDigits[mask, 2, nl]], 1];
  cost = ConstantArray[0., full];
  best = ConstantArray[0, full];
  Do[
    low = lowBit[s];
    If[s != low,
      rest = s - low; sub = rest; cost[[s]] = $MaxMachineNumber;
      While[True,
        sub = BitAnd[sub - 1, rest];
        a = low + sub; b = s - a;
        c = cost[[a]] + cost[[b]] + ms[BitOr[keep[[a]], keep[[b]]]];
        If[c < cost[[s]], cost[[s]] = c; best[[s]] = a];
        If[sub == 0, Break[]]
      ]
    ],
    {s, full}];
  build[s_] := If[s == lowBit[s], IntegerExponent[s, 2] + 1,
    Module[{x = build[best[[s]]], y = build[s - best[[s]]]}, next++; AppendTo[steps, {x, y}]; next]];
  build[full];
  (* self-referential local definitions would keep the Module temporaries alive: Clear (not ClearAll,
     which would also drop the Temporary attribute) lets the kernel remove them *)
  With[{res = steps}, Clear[ms, build]; res]
];

(* Greedy (opt_einsum style): repeatedly contract the pair sharing an index that minimises
   size(result) - size(a) - size(b), ties broken by flops; outer products only when unavoidable. *)
greedyPath[sets_List, dims_List, out_List] := Module[
  {n = Length[sets], lab, cnt, isOut, sz, keepOf, pc, cand = {}, alive, steps = {}, next, a, b, k},
  Do[lab[i] = sets[[i]], {i, n}];
  cnt = ConstantArray[0, Max[1, Length[dims]]];
  Scan[(cnt[[#]] += 1) &, Join @@ sets];
  isOut = ConstantArray[False, Max[1, Length[dims]]];
  Scan[(isOut[[#]] = True) &, out];
  sz[l_List] := Times @@ dims[[l]];
  keepOf[la_List, lb_List] := Select[Union[la, lb],
    (isOut[[#]] || cnt[[#]] - Boole[MemberQ[la, #]] - Boole[MemberQ[lb, #]] > 0) &];
  pc[x_, y_] := With[{kk = keepOf[lab[x], lab[y]]},
    {N[sz[kk] - sz[lab[x]] - sz[lab[y]]], N[sz[Union[lab[x], lab[y]]]], x, y}];
  Do[If[Intersection[lab[i], lab[j]] =!= {}, AppendTo[cand, pc[i, j]]], {i, n - 1}, {j, i + 1, n}];
  alive = Range[n]; next = n;
  While[Length[alive] > 1,
    If[cand === {},
      {a, b} = Sort[Take[SortBy[alive, sz[lab[#]] &], 2]],
      {a, b} = Sort[cand][[1, 3 ;; 4]]];
    k = keepOf[lab[a], lab[b]];
    Scan[(cnt[[#]] -= 1) &, lab[a]]; Scan[(cnt[[#]] -= 1) &, lab[b]]; Scan[(cnt[[#]] += 1) &, k];
    next++; lab[next] = k; AppendTo[steps, {a, b}];
    alive = Append[DeleteCases[alive, a | b], next];
    cand = Select[cand, !MemberQ[{a, b}, #[[3]]] && !MemberQ[{a, b}, #[[4]]] &];
    Do[If[w =!= next && Intersection[k, lab[w]] =!= {}, AppendTo[cand, pc[w, next]]], {w, alive}]
  ];
  steps
];

sequentialPath[n_Integer] := Table[{If[k == 1, 1, n + k - 1], k + 1}, {k, n - 1}];

linearToSSA[path_List, n_Integer] := Module[{cur = Range[n], next = n, steps = {}, p, q},
  Do[
    {p, q} = pr;
    If[!(1 <= p <= Length[cur] && 1 <= q <= Length[cur] && p != q), fail[Einsum::path, path]];
    next++; AppendTo[steps, {cur[[p]], cur[[q]]}];
    cur = Append[Delete[cur, {{p}, {q}}], next],
    {pr, path}];
  If[Length[cur] != 1, fail[Einsum::path, path]];
  steps
];

ssaToLinear[steps_List, n_Integer] := Module[{cur = Range[n], next = n, res = {}, p, q},
  Do[
    p = firstPos[cur, st[[1]]];
    q = firstPos[cur, st[[2]]];
    AppendTo[res, Sort[{p, q}]];
    next++; cur = Append[Delete[cur, {{p}, {q}}], next],
    {st, steps}];
  res
];

choosePath[sets_List, dims_List, out_List, spec_] := With[{n = Length[sets]},
  Which[
    !MatchQ[spec, Automatic | "Optimal" | "Greedy" | "Sequential" | False | {} | {{_Integer, _Integer} ..}],
      fail[Einsum::path, spec],
    MatchQ[spec, {{_Integer, _Integer} ..}], {linearToSSA[spec, n], "User"},
    spec === {} && n == 1, {{}, "User"},
    n <= 1, {{}, "Trivial"},
    n == 2, {{{1, 2}}, "Trivial"},
    spec === Automatic, If[n <= $optimalLimit,
      {optimalPath[sets, dims, out], "Optimal"}, {greedyPath[sets, dims, out], "Greedy"}],
    spec === "Optimal" && n > $optimalMax, Message[Einsum::optbig, n, $optimalMax]; {greedyPath[sets, dims, out], "Greedy"},
    spec === "Optimal", {optimalPath[sets, dims, out], "Optimal"},
    spec === "Greedy", {greedyPath[sets, dims, out], "Greedy"},
    spec === "Sequential" || spec === False, {sequentialPath[n], "Sequential"},
    True, fail[Einsum::path, spec]
  ]
];

(* ::Section:: *)
(* Plan: lowering every pairwise contraction to a kernel *)

firstPos[l_List, x_] := First[First[Position[l, x, {1}, 1]]];
argMin[l_List] := firstPos[l, Min[l]];

(* Transpose permutation (Mathematica convention) turning label order cur into target *)
permFor[cur_List, target_List] := If[cur === target, None, Flatten[Position[target, #] & /@ cur]];

(* Cost model choosing between a loop of BLAS calls and vectorised broadcasting for batched
   contractions  C[b,i,k] = Sum_j L[b,i,j] R[b,j,k]  (rough timings in microseconds). *)
batchMethod[nb_, ni_, nj_, nk_, bmeth_] := Switch[bmeth,
  "Dot", "Dot",
  "Vectorized", "Vec",
  _, With[{f = N[ni nj nk], it = If[nj == 1, 1, Min[ni, nk]]},
    If[nb (2. + 0.0005 f) < 3. it + 0.003 nb f, "Dot", "Vec"]]
];

(* Broadcasting products (no summed index, one label set contained in the other) *)
smallBig[which_, ls_List, lB_List, dims_List] := Module[{k = Length[ls], pre, suf},
  pre = Take[lB, k]; suf = Take[lB, -k];
  Which[
    Sort[ls] === Sort[pre],
      {<|"Type" -> "Prefix", "Small" -> which, "PermSmall" -> permFor[ls, pre]|>, lB},
    Sort[ls] === Sort[suf],
      {<|"Type" -> "Suffix", "Small" -> which, "PermSmall" -> permFor[ls, suf],
        "Rep" -> dims[[Take[lB, Length[lB] - k]]]|>, lB},
    True, None
  ]
];

broadcastInstr[la_List, lb_List, fa_List, fb_List, dims_List, final_] := Which[
  fa === {} && fb === {},
    If[final =!= None && lb === final && la =!= final,
      {<|"Type" -> "Hadamard", "PermA" -> permFor[la, lb], "PermB" -> None|>, lb},
      {<|"Type" -> "Hadamard", "PermA" -> None, "PermB" -> permFor[lb, la]|>, la}],
  fa === {}, smallBig["A", la, lb, dims],
  True, smallBig["B", lb, la, dims]
];

(* General pairwise contraction  L[batch, freeL, con] x R[batch, con, freeR] -> [batch, freeL, freeR].
   All 2 x 2 x 2 choices of operand order / batch-label order / contracted-label order are scored by
   the amount of data that must be transposed (plus the final transpose on the last step). *)
pairInstr[la_List, lb_List, bat_List, con_List, fa_List, fb_List, dims_List, final_, bmeth_] := Module[
  {szA, szB, szR, batOrders, conOrders, cands, best, nb, ni, nj, nk},
  szA = Times @@ dims[[la]]; szB = Times @@ dims[[lb]];
  szR = Times @@ dims[[Join[bat, fa, fb]]];
  batOrders = DeleteDuplicates[{bat, Select[lb, MemberQ[bat, #] &]}];
  conOrders = DeleteDuplicates[{con, Select[lb, MemberQ[con, #] &]}];
  cands = Flatten[Table[
      Module[{lL, lR, fL, fR, sL, sR, tL, tR, ro, cost},
        {lL, lR, fL, fR, sL, sR} = If[swap, {lb, la, fb, fa, szB, szA}, {la, lb, fa, fb, szA, szB}];
        tL = Join[bo, fL, co]; tR = Join[bo, co, fR]; ro = Join[bo, fL, fR];
        cost = If[tL === lL, 0, sL] + If[tR === lR, 0, sR] + If[final =!= None && ro =!= final, szR, 0];
        {cost, swap, lL, lR, tL, tR, ro, fL, fR, bo, co}],
      {swap, {False, True}}, {bo, batOrders}, {co, conOrders}], 2];
  best = cands[[argMin[cands[[All, 1]]]]];
  nb = Times @@ dims[[best[[10]]]];
  ni = Times @@ dims[[best[[8]]]]; nj = Times @@ dims[[best[[11]]]]; nk = Times @@ dims[[best[[9]]]];
  If[nb == 1,
    {<|"Type" -> "Dot", "Swap" -> best[[2]], "PermL" -> permFor[best[[3]], best[[5]]],
       "PermR" -> permFor[best[[4]], best[[6]]], "ShapeL" -> {ni, nj}, "ShapeR" -> {nj, nk},
       "Dims" -> dims[[best[[7]]]]|>, best[[7]]},
    {<|"Type" -> "Batch", "Swap" -> best[[2]], "PermL" -> permFor[best[[3]], best[[5]]],
       "PermR" -> permFor[best[[4]], best[[6]]], "ShapeL" -> {nb, ni, nj}, "ShapeR" -> {nb, nj, nk},
       "Dims" -> dims[[best[[7]]]], "Method" -> batchMethod[nb, ni, nj, nk, bmeth]|>, best[[7]]}
  ]
];

(* Batched contraction of two operands with the same labels ("kh,kh->h", "khn,hkn->kh"): the batched matrix product
   would transpose both to put the batch labels first; instead, multiply them in the layout of one of them (the one whose
   remaining labels are already in the final order, if any) and sum the contracted levels. Used only when the batched
   product would transpose an operand. With a free label on one side the batched product (BLAS) is faster. *)
reduceInstr[la_List, lb_List, bat_List, con_List, fa_List, fb_List, dims_List, final_, bmeth_] := Module[
  {pb, small, lB, lS, keep},
  pb = pairInstr[la, lb, bat, con, fa, fb, dims, final, bmeth];
  {small, lB, lS} = If[final =!= None && Select[lb, !MemberQ[con, #] &] === final, {"A", lb, la}, {"B", la, lb}];
  keep = Select[lB, !MemberQ[con, #] &];
  If[pb[[1]]["PermL"] === None && pb[[1]]["PermR"] === None, pb,
    {<|"Type" -> "Reduce", "Small" -> small, "PermSmall" -> permFor[lS, lB],
       "SumPos" -> Reverse[Sort[Flatten[Position[lB, #] & /@ con]]]|>, keep}]
];

stepInstruction[la0_List, lb0_List, kset_List, dims_List, final_, bmeth_] := Module[
  {sa, sb, la, lb, bat, con, fa, fb, r = None},
  (* labels living only in one operand and not needed afterwards: sum them first *)
  sa = Select[la0, !MemberQ[lb0, #] && !MemberQ[kset, #] &];
  sb = Select[lb0, !MemberQ[la0, #] && !MemberQ[kset, #] &];
  la = Select[la0, !MemberQ[sa, #] &];
  lb = Select[lb0, !MemberQ[sb, #] &];
  Which[
    la === {} || lb === {},
      r = {<|"Type" -> "Scale"|>, If[la === {}, lb, la]},
    True,
      bat = Select[la, MemberQ[lb, #] && MemberQ[kset, #] &];
      con = Select[la, MemberQ[lb, #] && !MemberQ[kset, #] &];
      fa = Select[la, !MemberQ[lb, #] &];
      fb = Select[lb, !MemberQ[la, #] &];
      If[con === {} && (fa === {} || fb === {}), r = broadcastInstr[la, lb, fa, fb, dims, final]];
      If[r === None && bat =!= {} && con =!= {} && fa === {} && fb === {} && bmeth === Automatic,
        r = reduceInstr[la, lb, bat, con, fa, fb, dims, final, bmeth]];
      If[r === None, r = pairInstr[la, lb, bat, con, fa, fb, dims, final, bmeth]]
  ];
  {Join[<|"SumA" -> Reverse[Sort[Flatten[Position[la0, #] & /@ sa]]],
          "SumB" -> Reverse[Sort[Flatten[Position[lb0, #] & /@ sb]]]|>, r[[1]]], r[[2]]}
];

buildSteps[sets_List, ssa_List, dims_List, out_List, bmeth_] := Module[
  {n = Length[sets], ord, cnt, steps = {}, la, lb, kset, res, a, b},
  ord = Join[sets, ConstantArray[{}, Length[ssa]]];
  cnt = ConstantArray[0, Max[1, Length[dims]]];
  Scan[(cnt[[#]] += 1) &, Join @@ sets];
  Do[
    {a, b} = ssa[[s]];
    la = ord[[a]]; lb = ord[[b]];
    kset = Select[DeleteDuplicates[Join[la, lb]],
      (MemberQ[out, #] || cnt[[#]] - Boole[MemberQ[la, #]] - Boole[MemberQ[lb, #]] > 0) &];
    res = stepInstruction[la, lb, kset, dims, If[s == Length[ssa], out, None], bmeth];
    Scan[(cnt[[#]] -= 1) &, la]; Scan[(cnt[[#]] -= 1) &, lb]; Scan[(cnt[[#]] += 1) &, res[[2]]];
    ord[[n + s]] = res[[2]];
    AppendTo[steps, Join[res[[1]], <|
      "In" -> {a, b}, "Out" -> n + s, "LA" -> la, "LB" -> lb, "Labels" -> res[[2]],
      "Contracted" -> Complement[Union[la, lb], res[[2]]],
      "Flops" -> N[Times @@ dims[[Union[la, lb]]]], "Size" -> N[Times @@ dims[[res[[2]]]]]|>]],
    {s, Length[ssa]}];
  {steps, ord[[n + Length[ssa]]]}
];

makePlan[spec_, shapes_List, pathSpec_, bmeth_] := Module[
  {parsed, res, ids, out, names, n, dims, sq, tcount, keepQ, pre, sets, ssa, method, steps, finalOrder,
   prepFlops},
  parsed = parseSpec[spec];
  res = resolveSpec[parsed, Length /@ shapes];
  ids = res["Inputs"]; out = res["Output"]; names = res["Names"]; n = Length[ids];
  {dims, sq} = resolveDims[ids, shapes, names];
  tcount = ConstantArray[0, Max[1, Length[names]]];
  Do[Scan[(tcount[[#]] += 1) &,
      DeleteDuplicates[If[sq[[k]] === {}, ids[[k]], Delete[ids[[k]], List /@ sq[[k]]]]]], {k, n}];
  keepQ[l_] := MemberQ[out, l] || tcount[[l]] >= 2;
  pre = Table[prepInstr[ids[[k]], shapes[[k]], sq[[k]], keepQ], {k, n}];
  sets = #["Labels"] & /@ pre;
  {ssa, method} = choosePath[sets, dims, out, pathSpec];
  {steps, finalOrder} = buildSteps[sets, ssa, dims, out, bmeth];
  prepFlops = Total[Table[
    If[pre[[k]]["Diag"] =!= None || pre[[k]]["Sum"] =!= {}, N[Times @@ shapes[[k]]], 0.], {k, n}]];
  <|"Spec" -> spec, "Shapes" -> shapes, "Names" -> names, "Inputs" -> ids, "Output" -> out,
    "Dims" -> dims, "Type" -> res["Type"], "Pre" -> pre, "Sets" -> sets, "SSA" -> ssa, "Method" -> method,
    "Steps" -> steps, "Final" -> n + Length[ssa], "FinalPerm" -> permFor[finalOrder, out],
    "Flops" -> prepFlops + Total[(#["Flops"] &) /@ steps],
    "NaiveFlops" -> N[Times @@ dims] Max[1, n - 1],
    "LargestIntermediate" -> Max[0., (#["Size"] &) /@ steps]|>
];

(* ::Section:: *)
(* Execution *)

pack[x_List] := If[Developer`PackedArrayQ[x], x, Developer`ToPackedArray[x]];
pack[x_] := x;

dense[x_SparseArray] := Normal[x];
dense[x_] := x;

tp[x_, None] := x;
tp[x_, p_List] := Transpose[x, p];

rs[x_, {}] := If[ListQ[x] || Head[x] === SparseArray, First[Flatten[Normal[x]]], x];
rs[x_, d_List] := If[Dimensions[x] === d, x, ArrayReshape[x, d]];

sumLv[x_, {}] := x;
sumLv[x_, lv_List] := Fold[Total[#1, {#2}] &, x, lv];

prepTensor[t_, p_Association] := Module[{x = t},
  If[p["Squeeze"] =!= None, x = rs[x, p["Squeeze"]]];
  If[p["Diag"] =!= None, x = Transpose[dense[x], p["Diag"]]];
  sumLv[x, p["Sum"]]
];

(* Batched contraction C[b,i,k] = Sum_j x[b,i,j] y[b,j,k]; the result may be returned with any shape
   whose flattened order is that of {nb, ni, nk}. *)
batchContract[x_, y_, "Dot"] := Developer`ToPackedArray[MapThread[Dot, {x, y}]];
batchContract[x_, y_, "Vec"] := Module[{nb, ni, nj, nk, u, v},
  {nb, ni, nj} = Dimensions[x]; nk = Last[Dimensions[y]];
  Which[
    nj == 1,
      u = ArrayReshape[x, {nb, ni}]; v = ArrayReshape[y, {nb, nk}];
      Which[
        ni == 1 && nk == 1, Flatten[u] Flatten[v],
        ni == 1, v Flatten[u],
        nk == 1, u Flatten[v],
        True, u Transpose[ConstantArray[v, ni], {2, 1, 3}]],
    ni == 1, Total[x[[All, 1]] y, {2}],
    nk == 1, Total[y[[All, All, 1]] Transpose[x, {1, 3, 2}], {2}],
    ni <= nk, Transpose[Developer`ToPackedArray[Table[Total[x[[All, i]] y, {2}], {i, ni}]], {2, 1, 3}],
    True, With[{xt = Transpose[x, {1, 3, 2}]},
      Transpose[Developer`ToPackedArray[Table[Total[y[[All, All, k]] xt, {2}], {k, nk}]], {3, 1, 2}]]
  ]
];

runStep[st_Association, x0_, y0_] := Module[{x = sumLv[x0, st["SumA"]], y = sumLv[y0, st["SumB"]], l, r},
  Switch[st["Type"],
    "Scale", x y,
    "Hadamard", dense[tp[x, st["PermA"]]] dense[tp[y, st["PermB"]]],
    "Prefix", If[st["Small"] === "A",
      dense[tp[x, st["PermSmall"]]] dense[y],
      dense[tp[y, st["PermSmall"]]] dense[x]],
    "Reduce", If[st["Small"] === "A",
      sumLv[dense[tp[x, st["PermSmall"]]] dense[y], st["SumPos"]],
      sumLv[dense[tp[y, st["PermSmall"]]] dense[x], st["SumPos"]]],
    "Suffix", If[st["Small"] === "A",
      dense[y] ConstantArray[dense[tp[x, st["PermSmall"]]], st["Rep"]],
      dense[x] ConstantArray[dense[tp[y, st["PermSmall"]]], st["Rep"]]],
    "Dot",
      {l, r} = If[st["Swap"], {y, x}, {x, y}];
      rs[rs[tp[l, st["PermL"]], st["ShapeL"]] . rs[tp[r, st["PermR"]], st["ShapeR"]], st["Dims"]],
    "Batch",
      {l, r} = If[st["Swap"], {y, x}, {x, y}];
      rs[batchContract[rs[dense[tp[l, st["PermL"]]], st["ShapeL"]], rs[dense[tp[r, st["PermR"]]], st["ShapeR"]],
        st["Method"]], st["Dims"]]
  ]
];

runPlan[plan_Association, ts_List] := Module[{n = Length[ts], slots, pre = plan["Pre"]},
  slots = ConstantArray[Null, n + Length[plan["Steps"]]];
  Do[slots[[k]] = prepTensor[pack[ts[[k]]], pre[[k]]], {k, n}];
  Scan[
    Function[st,
      slots[[st["Out"]]] = runStep[st, slots[[st["In"][[1]]]], slots[[st["In"][[2]]]]];
      slots[[st["In"][[1]]]] = Null; slots[[st["In"][[2]]]] = Null],
    plan["Steps"]];
  tp[slots[[plan["Final"]]], plan["FinalPerm"]]
];

(* ::Section:: *)
(* Public interface *)

(* Only lists and SparseArrays are tensors: any other expression (Sqrt[2], a + b, ...) is a scalar,
   even though Dimensions[a + b] would be {2}. Packed arrays are rectangular by construction. *)
shapeOf[x_List] := Dimensions[x];
shapeOf[x_SparseArray] := Dimensions[x];
shapeOf[_] := {};
checkArrays[ts_List] := Do[
  With[{t = ts[[k]]},
    If[(ListQ[t] || Head[t] === SparseArray) && !(Developer`PackedArrayQ[t] || ArrayQ[t]), fail[Einsum::array, k]]],
  {k, Length[ts]}];

shapeListQ[x_] := MatchQ[x, {{___Integer?NonNegative} ..}];

$planCache = <||>;
$planCacheMax = 2000;

EinsumClearCache[] := ($planCache = <||>;);

cachedPlan[key_List, ts_List] := Module[{p = Lookup[$planCache, Key[key], None]},
  If[p === None,
    p = makePlan @@ key;
    If[Length[$planCache] >= $planCacheMax, $planCache = <||>];
    AssociateTo[$planCache, key -> p]];
  p
];

Options[Einsum] = {"Path" -> Automatic, "BatchMethod" -> Automatic, "Cache" -> True};

(* Options are split off by looking only at the heads of the trailing arguments: matching the tensors
   against OptionsPattern[] would make the pattern matcher inspect (and possibly unpack) large arrays. *)
optionQ[_Rule | _RuleDelayed] := True;
optionQ[_] := False;
splitOptions[all_List] := Module[{k = Length[all]},
  While[k > 0 && optionQ[all[[k]]], k--];
  {Take[all, k], Drop[all, k]}];

(* unknown options get one message and are dropped, so that OptionValue does not complain about them again *)
checkOptions[f_Symbol, opts_List] := Select[opts,
  If[MemberQ[ToString /@ First /@ Options[f], ToString[First[#]]], True, Message[f::optx, First[#], HoldForm[f]]; False] &];

Einsum[spec_, args___] := Catch[
  Module[{tensors, opts, key, plan},
    {tensors, opts} = splitOptions[{args}];
    If[opts =!= {}, opts = checkOptions[Einsum, opts]];
    tensors = pack /@ tensors;   (* packed inputs make the validation below O(1) *)
    checkArrays[tensors];
    key = {spec, shapeOf /@ tensors, OptionValue[Einsum, opts, "Path"], OptionValue[Einsum, opts, "BatchMethod"]};
    plan = If[TrueQ[OptionValue[Einsum, opts, "Cache"]], cachedPlan[key, tensors], makePlan @@ key];
    runPlan[plan, tensors]],
  $einsumTag];

shapesFromArgs[spec_, args_List] := Module[{nop = Length[parseSpec[spec]["Terms"]]},
  If[Length[args] == 1 && ListQ[args[[1]]] && Length[args[[1]]] == nop && shapeListQ[args[[1]]],
    args[[1]],
    checkArrays[args]; shapeOf /@ args]
];

labelStr[x_String] := x;
labelStr[x_] := ToString[x, InputForm];
compactQ[names_List] := AllTrue[names, StringQ[#] && StringLength[#] == 1 &];
termStr[ids_List, names_List, compact_] := If[compact,
  StringJoin[labelStr /@ names[[ids]]],
  "{" <> StringRiffle[labelStr /@ names[[ids]], ","] <> "}"];
specString[plan_Association] := With[{c = compactQ[plan["Names"]]},
  StringRiffle[termStr[#, plan["Names"], c] & /@ plan["Inputs"], ","] <> "->" <> termStr[plan["Output"], plan["Names"], c]];
stepString[st_Association, names_List, c_] :=
  termStr[st["LA"], names, c] <> "," <> termStr[st["LB"], names, c] <> "->" <> termStr[st["Labels"], names, c];

pathReport[plan_Association] := With[{c = compactQ[plan["Names"]], n = Length[plan["Inputs"]]},
  <|"Spec" -> specString[plan],
    "Path" -> ssaToLinear[plan["SSA"], n],
    "Method" -> plan["Method"],
    "Contractions" -> (stepString[#, plan["Names"], c] & /@ plan["Steps"]),
    "StepFlops" -> (#["Flops"] & /@ plan["Steps"]),
    "Flops" -> plan["Flops"],
    "NaiveFlops" -> plan["NaiveFlops"],
    "Speedup" -> plan["NaiveFlops"]/Max[plan["Flops"], 1.],
    "LargestIntermediate" -> plan["LargestIntermediate"]|>
];

Options[EinsumPath] = {"Path" -> Automatic};

EinsumPath[spec_, args___] := Catch[
  Module[{tensors, opts},
    {tensors, opts} = splitOptions[{args}];
    If[opts =!= {}, opts = checkOptions[EinsumPath, opts]];
    pathReport[makePlan[spec, shapesFromArgs[spec, tensors], OptionValue[EinsumPath, opts, "Path"], Automatic]]],
  $einsumTag];

Options[EinsumFunction] = {"Path" -> Automatic, "BatchMethod" -> Automatic};

EinsumFunction[spec : (_String | _Rule | _List), shapes_?shapeListQ, opts : OptionsPattern[]] := Catch[
  EinsumFunction[<|"Plan" -> makePlan[spec, shapes, OptionValue["Path"], OptionValue["BatchMethod"]]|>],
  $einsumTag];

EinsumFunction[a_Association]["Properties"] :=
  {"Spec", "Shapes", "Path", "Method", "Flops", "NaiveFlops", "Speedup", "LargestIntermediate",
   "Contractions", "Diagram", "Tree", "Plan"};
EinsumFunction[a_Association]["Plan"] := a["Plan"];
EinsumFunction[a_Association]["Shapes"] := a["Plan"]["Shapes"];
EinsumFunction[a_Association]["Diagram"] := Summa`EinsumDiagram[a["Plan"]["Spec"], a["Plan"]["Shapes"], "ShowPath" -> True];
EinsumFunction[a_Association]["Tree"] := Summa`EinsumTree[a["Plan"]["Spec"], a["Plan"]["Shapes"]];
EinsumFunction[a_Association][prop : ("Spec" | "Path" | "Method" | "Flops" | "NaiveFlops" | "Speedup" |
    "LargestIntermediate" | "Contractions")] := pathReport[a["Plan"]][prop];
EinsumFunction[a_Association][ts___] := Catch[
  With[{plan = a["Plan"], tensors = pack /@ {ts}},
    checkArrays[tensors];
    If[(shapeOf /@ tensors) =!= plan["Shapes"],
      fail[Einsum::mismatch, shapeOf /@ tensors, plan["Shapes"]]];
    runPlan[plan, tensors]],
  $einsumTag];

(* ::Section:: *)
(* Visualization *)

(* ::Subsection:: *)
(* Styling and formatting helpers *)

$tensorPalette = {RGBColor[0.62, 0.76, 0.91], RGBColor[0.99, 0.76, 0.53], RGBColor[0.66, 0.86, 0.62],
   RGBColor[0.96, 0.65, 0.65], RGBColor[0.79, 0.70, 0.89], RGBColor[0.84, 0.74, 0.66],
   RGBColor[0.97, 0.76, 0.88], RGBColor[0.82, 0.82, 0.82], RGBColor[0.89, 0.89, 0.56], RGBColor[0.60, 0.87, 0.90]};
$intermediateColor = RGBColor[0.88, 0.89, 0.93];
$bondColor = GrayLevel[0.22];
$openColor = RGBColor[0.10, 0.40, 0.72];
$hyperColor = RGBColor[0.47, 0.22, 0.62];
$sumColor = GrayLevel[0.5];
$accentColor = RGBColor[0.85, 0.32, 0.10];
$tensorRadius = 0.2;

tensorColor[k_Integer] := $tensorPalette[[Mod[k - 1, Length[$tensorPalette]] + 1]];
nameColors[tnames_List] := With[{u = DeleteDuplicates[tnames]},
  tensorColor[firstPos[u, #]] & /@ tnames];
defaultTensorName[k_Integer] := If[k <= 26, FromCharacterCode[64 + k], "T" <> ToString[k]];

$supDigits = {"\:2070", "\:00b9", "\:00b2", "\:00b3", "\:2074", "\:2075", "\:2076", "\:2077", "\:2078", "\:2079"};
intOrReal[m_] := If[m == Round[m], ToString[Round[m]], ToString[m]];
fmtNum[x_?NumericQ] := Module[{e, m},
  If[x < 10^4, ToString[Round[x]],
    e = Floor[Log10[N[x]]]; m = Round[N[x]/10^e, 0.1];
    If[m >= 10., m = m/10; e = e + 1];
    intOrReal[m] <> "\[CenterDot]10" <> StringJoin[$supDigits[[IntegerDigits[e] + 1]]]]];
fmtNum[x_] := ToString[x];
fmtRatio[x_?NumericQ] := If[x < 100, intOrReal[Round[N[x], 0.1]], fmtNum[x]] <> "\[Times]";

(* ::Subsection:: *)
(* Geometry *)

unitV[v_] := With[{nv = Norm[v]}, If[nv < 10.^-12, {1., 0.}, v/nv]];
perpV[v_] := {-v[[2]], v[[1]]};
dirV[th_] := {Cos[th], Sin[th]};
angleV[v_] := If[Norm[v] < 10.^-12, 0., ArcTan[v[[1]], v[[2]]]];
modAngle[x_] := x - 2. Pi Floor[x/(2. Pi)];
cross2[u_, v_] := u[[1]] v[[2]] - u[[2]] v[[1]];
segDist[pt_, p_, q_] := Module[{v = q - p, t},
  t = If[v.v < 10.^-12, 0., Min[1., Max[0., (pt - p).v/(v.v)]]];
  Norm[pt - (p + t v)]];
minMat[a_, b_] := (a + b - Abs[a - b])/2;
argMax[l_List] := argMin[-l];

(* cubic Bezier equivalent to the quadratic arc through p, q with perpendicular offset off *)
arcPts[p_, q_, off_] := With[{c = (p + q)/2 + off perpV[unitV[q - p]]}, {p, p + 2/3 (c - p), q + 2/3 (c - q), q}];
arcMid[p_, q_, off_] := (p + q)/2 + off/2 perpV[unitV[q - p]];

(* spread k dangling items over the angular gaps left by the neighbours (largest gaps first) *)
fanAngles[nbr_List, k_Integer] := Which[
  k == 0, {},
  nbr === {}, Table[N[Pi - 2 Pi (j - 1)/k], {j, k}],
  True, Module[{as = Sort[modAngle /@ N[nbr]], sizes, cnt, pick},
    sizes = Append[Rest[as] - Most[as], First[as] + 2. Pi - Last[as]];
    cnt = ConstantArray[0, Length[as]];
    Do[pick = argMax[sizes/(cnt + 1) + 10.^-6 Sin[as + sizes/2]]; cnt[[pick]] += 1, {k}];
    Flatten[Table[as[[g]] + sizes[[g]] j/(cnt[[g]] + 1), {g, Length[as]}, {j, cnt[[g]]}]]]
];

collisionOffset[p_, q_, obs_List] := Module[{ds, k},
  If[obs === {}, 0.,
    ds = segDist[#, p, q] & /@ obs; k = argMin[ds];
    If[ds[[k]] < 0.25, If[cross2[q - p, obs[[k]] - p] > 0, -0.5, 0.5], 0.]]];

(* ::Subsection:: *)
(* Layout: classical MDS on graph distances + stress majorisation (SMACOF) *)

stressLayout[nn_Integer, edges_List] := Which[
  nn == 1, {{0., 0.}},
  edges === {}, Table[{2.4 (k - 1), 0.}, {k, nn}],
  True, stressLayout0[nn, edges]
];

stressLayout0[nn_Integer, edges_List] := Module[
  {big = 10.^6, d, fin, dinf, jm, bm, es, ord, x, w, vp, sq, dist, bx, len},
  d = ConstantArray[big, {nn, nn}];
  Do[d[[i, i]] = 0., {i, nn}];
  Scan[(d[[#[[1]], #[[2]]]] = 1.; d[[#[[2]], #[[1]]]] = 1.) &, edges];
  Do[d = minMat[d, Outer[Plus, d[[All, k]], d[[k]]]], {k, nn}];
  fin = Select[Flatten[d], # < big/2 &];
  dinf = Max[2.2, Max[fin] + 1.2];
  d = Map[If[# > big/2, dinf, #] &, d, {2}];
  jm = IdentityMatrix[nn] - 1./nn;
  bm = -0.5 jm . (d^2) . jm;
  bm = (bm + Transpose[bm])/2;
  es = Re[Eigensystem[bm]];
  ord = Ordering[es[[1]], -2];
  x = Transpose[es[[2, ord]]] . DiagonalMatrix[Sqrt[Max[#, 0.] & /@ es[[1, ord]]]];
  (* break symmetric degeneracies (coincident points) with a small golden-angle jitter *)
  With[{sq0 = Total[x^2, {2}]},
    If[Min[Sqrt[Abs[Outer[Plus, sq0, sq0] - 2 x . Transpose[x]]] + 10. IdentityMatrix[nn]] < 0.05,
      x = x + 0.05 Table[{Cos[2.39996 k], Sin[2.39996 k]}, {k, nn}]]];
  w = Table[If[i == j, 0., 1./d[[i, j]]^2], {i, nn}, {j, nn}];
  (* pseudo-inverse of the weighted Laplacian (null space = constants): (V + J/n)^-1 - J/n *)
  vp = Inverse[DiagonalMatrix[Total[w, {2}]] - w + 1./nn] - 1./nn;
  Do[
    sq = Total[x^2, {2}];
    dist = Sqrt[Abs[Outer[Plus, sq, sq] - 2 x . Transpose[x]]] + 10.^-9;
    bx = -w d/dist;
    bx = bx - DiagonalMatrix[Diagonal[bx]];
    bx = bx - DiagonalMatrix[Total[bx, {2}]];
    x = vp . (bx . x),
    {120}];
  x = (# - Mean[x]) & /@ x;
  (* align bond directions with the axes (4-fold circular mean), then make the drawing wider than tall *)
  With[{ang = (angleV[x[[#[[2]]]] - x[[#[[1]]]]] &) /@ edges},
    With[{sx = Total[Cos[4 ang]], sy = Total[Sin[4 ang]]},
      If[sx^2 + sy^2 > 10.^-6,
        With[{phi = ArcTan[sx, sy]/4}, x = x . {{Cos[phi], -Sin[phi]}, {Sin[phi], Cos[phi]}}]]]];
  If[Max[x[[All, 2]]] - Min[x[[All, 2]]] > 1.15 (Max[x[[All, 1]]] - Min[x[[All, 1]]]), x = x . {{0., -1.}, {1., 0.}}];
  If[x[[1, 1]] > 0, x = x . {{-1., 0.}, {0., 1.}}];
  len = Mean[(Norm[x[[#[[1]]]] - x[[#[[2]]]]] &) /@ edges];
  x/Max[len, 10.^-6]
];

fixedLayout[spec_, nt_Integer, hyperTensors_List] := Module[{tpos, cen, used = {}, hpos},
  tpos = Which[
    spec === "Circle", Which[nt == 1, {{0., 0.}}, nt == 2, {{-0.6, 0.}, {0.6, 0.}},
      True, With[{r = 0.62/Sin[Pi/nt]}, Table[r dirV[Pi/2 - 2. Pi (k - 1)/nt], {k, nt}]]],
    spec === "Line", Table[{1.3 (k - 1), 0.}, {k, nt}],
    MatrixQ[spec, NumericQ] && Dimensions[spec] === {nt, 2}, N[spec],
    True, stressLayout[nt, {}]];
  cen = Mean[tpos];
  hpos = Table[
    Module[{c0 = Mean[tpos[[ht]]], c, k = 0},
      If[Min[Norm[c0 - #] & /@ tpos] < 0.3,
        c0 = c0 + 0.55 unitV[If[Norm[c0 - cen] < 10.^-6, {0., -1.}, c0 - cen]]];
      c = c0;
      (* several hyperedges on the same tensors: stack them at increasing distance, alternating sides *)
      While[used =!= {} && Min[Norm[c - #] & /@ used] < 0.25, k++; c = c0 + {0., 0.38 (-1)^k Ceiling[k/2]}];
      AppendTo[used, c]; c],
    {ht, hyperTensors}];
  Join[tpos, hpos]
];

(* ::Subsection:: *)
(* Network analysis *)

(* For every label id: {kind, tensors carrying it (with multiplicity), in output?}.
   Every label is a COPY tensor whose legs are its occurrences (+1 if it is an output index):
   2 legs = plain wire (bond / open leg / trace), 1 leg = summed out, 3+ legs = hyperedge. *)
labelInfo[tl_List, out_List, m_Integer] := Module[{occ = Table[{}, {m}]},
  Do[occ[[tl[[t, s]]]] = Append[occ[[tl[[t, s]]]], t], {t, Length[tl]}, {s, Length[tl[[t]]]}];
  Table[
    With[{o = occ[[l]], isOut = MemberQ[out, l]},
      With[{legs = Length[o] + Boole[isOut]},
        {Which[
           legs >= 3, "Hyper",
           legs == 2 && isOut, "Open",
           legs == 2 && o[[1]] === o[[2]], "Trace",
           legs == 2, "Bond",
           legs == 1 && !isOut, "Sum",
           True, "None"], o, isOut}]],
    {l, m}]
];

layoutGraph[info_List, nt_Integer] := Module[{hyper, edges = {}},
  hyper = Flatten[Position[info[[All, 1]], "Hyper"]];
  Do[
    Which[
      info[[l, 1]] === "Bond", AppendTo[edges, Sort[info[[l, 2]]]],
      info[[l, 1]] === "Hyper", With[{h = nt + firstPos[hyper, l]},
        Scan[AppendTo[edges, {#, h}] &, DeleteDuplicates[info[[l, 2]]]]]],
    {l, Length[info]}];
  {hyper, DeleteDuplicates[edges]}
];

(* ::Subsection:: *)
(* Rendering of a tensor network *)

renderNetwork[tl_List, out_List, names_List, dims_, tnames_List, tcols_List, tpos_List, hposA_, opt_Association] := Module[
  {nt = Length[tl], m = Length[names], info, hyper, hnode, nodePos, edges = {}, dang = {}, nbrAng, groups,
   edgeP = {}, dangP = {}, nodeP = {}, labP = {}, badgeP = {}, bbox = {}, mini, showDims, badges, highlight,
   present, dmin, dmax, lw, lab, tip, addBadge, drawDangling, r = $tensorRadius, xs, ys, xr, yr, isz},
  mini = TrueQ[opt["Mini"]];
  showDims = TrueQ[opt["ShowDims"]] && dims =!= None;
  badges = opt["Badges"];
  highlight = opt["Highlight"];
  info = labelInfo[tl, out, m];
  hyper = Flatten[Position[info[[All, 1]], "Hyper"]];
  hnode[l_] := nt + firstPos[hyper, l];
  nodePos = Join[N[tpos], N[hposA[#]] & /@ hyper];

  (* line widths grow with log(dimension) *)
  present = Select[Range[m], info[[#, 1]] =!= "None" &];
  {dmin, dmax} = If[dims === None || present === {}, {1, 1}, {Min[#], Max[#]} &[Max[#, 1] & /@ dims[[present]]]];
  lw[l_] := Which[mini, 1., dims === None || dmax <= dmin, 1.7,
    True, 1.1 + 2.4 (Log[N[Max[dims[[l]], 1]]] - Log[N[dmin]])/(Log[N[dmax]] - Log[N[dmin]])];
  lab[l_, col_] := If[showDims,
    Row[{Style[names[[l]], 11, col], Style[" " <> ToString[dims[[l]]], 8, GrayLevel[0.45]]}],
    Style[names[[l]], 11, col]];
  tip[l_, what_String] := StringJoin[labelStr[names[[l]]],
    If[dims === None, "", " (dim " <> ToString[dims[[l]]] <> ")"], ": ", what];
  addBadge[l_, p_] := If[!mini && KeyExistsQ[badges, l],
    AppendTo[badgeP, {$accentColor, Disk[p + {0.17, 0.13}, 0.075],
      Text[Style[ToString[badges[l]], 8, Bold, White], p + {0.17, 0.13}]}]];

  (* edges between nodes and dangling items attached to a single node *)
  Do[
    With[{kind = info[[l, 1]], o = info[[l, 2]], isOut = info[[l, 3]]},
      Switch[kind,
        "Bond", AppendTo[edges, {o[[1]], o[[2]], l, "Bond"}],
        "Hyper",
          Scan[AppendTo[edges, {#, hnode[l], l, "Spoke"}] &, o];
          AppendTo[dang, {hnode[l], If[isOut, "Open", "HLabel"], l}],
        "Open", AppendTo[dang, {o[[1]], "Open", l}],
        "Trace", AppendTo[dang, {o[[1]], "Trace", l}],
        "Sum", AppendTo[dang, {o[[1]], "Sum", l}],
        _, Null]],
    {l, m}];

  groups = GatherBy[edges, Sort[#[[1 ;; 2]]] &];
  Do[
    With[{g = groups[[gi]], ng = Length[groups[[gi]]]},
      Do[
        Module[{e = g[[j]], u, v, p, q, off, mid, col},
          {u, v} = Sort[e[[1 ;; 2]]];
          p = nodePos[[u]]; q = nodePos[[v]];
          off = If[ng > 1, (j - (ng + 1)/2) Min[0.45, 1.2/ng], collisionOffset[p, q, Delete[nodePos, {{u}, {v}}]]];
          col = If[e[[4]] === "Spoke", $hyperColor, $bondColor];
          AppendTo[edgeP, Tooltip[
            {col, AbsoluteThickness[lw[e[[3]]]], If[off == 0, Line[{p, q}], BezierCurve[arcPts[p, q, off]]]},
            tip[e[[3]], If[e[[4]] === "Spoke",
              "hyperedge shared by " <> ToString[Length[DeleteDuplicates[info[[e[[3]], 2]]]]] <> " tensor(s)" <>
                If[info[[e[[3]], 3]], ", kept in the output", ", summed"],
              "contracted"]]]];
          mid = arcMid[p, q, off];
          AppendTo[bbox, mid];
          If[e[[4]] === "Bond" && !mini,
            AppendTo[labP, Text[lab[e[[3]], $bondColor], mid, Background -> White]];
            addBadge[e[[3]], mid]]],
        {j, ng}]],
    {gi, Length[groups]}];

  nbrAng = Table[{}, {Length[nodePos]}];
  Scan[
    Function[pr,
      If[pr[[1]] =!= pr[[2]],
        nbrAng[[pr[[1]]]] = Append[nbrAng[[pr[[1]]]], angleV[nodePos[[pr[[2]]]] - nodePos[[pr[[1]]]]]];
        nbrAng[[pr[[2]]]] = Append[nbrAng[[pr[[2]]]], angleV[nodePos[[pr[[1]]]] - nodePos[[pr[[2]]]]]]]],
    DeleteDuplicates[Sort[#[[1 ;; 2]]] & /@ edges]];

  drawDangling[{node_, kind_, l_}, th_] := Module[{p = nodePos[[node]], d = dirV[th], isT = node <= nt, len, e, lp},
    Switch[kind,
      "Open",
        len = If[isT, 0.62, 0.5]; e = p + len d; lp = p + (len + 0.15) d;
        AppendTo[dangP, Tooltip[{$openColor, AbsoluteThickness[lw[l]], Line[{p, e}]}, tip[l, "open index (output)"]]];
        If[!mini, AppendTo[labP, Text[lab[l, $openColor], lp, Background -> White]]];
        AppendTo[bbox, lp],
      "Sum",
        e = p + 0.48 d; lp = p + 0.64 d;
        AppendTo[dangP, Tooltip[{$sumColor, AbsoluteThickness[lw[l]], Dashing[{0.012, 0.008}], Line[{p, e}],
          Dashing[{}], AbsoluteThickness[1], White, Disk[e, 0.045], $sumColor, Circle[e, 0.045]},
          tip[l, "summed out (contracted with a vector of ones)"]]];
        If[!mini, AppendTo[labP, Text[lab[l, $sumColor], lp, Background -> White]]];
        AppendTo[bbox, lp],
      "Trace",
        lp = p + 0.7 d;
        AppendTo[dangP, Tooltip[{$bondColor, AbsoluteThickness[lw[l]],
          BezierCurve[{p, p + 0.85 dirV[th - 0.5], p + 0.85 dirV[th + 0.5], p}]}, tip[l, "trace"]]];
        If[!mini, AppendTo[labP, Text[lab[l, $bondColor], lp, Background -> White]]; addBadge[l, lp]];
        AppendTo[bbox, lp],
      "HLabel",
        lp = p + 0.2 d;
        If[!mini, AppendTo[labP, Text[lab[l, $hyperColor], lp, Background -> White]]; addBadge[l, lp]];
        AppendTo[bbox, lp],
      _, Null]];

  Do[
    With[{items = Select[dang, #[[1]] == node &]},
      If[items =!= {},
        With[{angs = fanAngles[nbrAng[[node]], Length[items]]},
          Do[drawDangling[items[[i]], angs[[i]]], {i, Length[items]}]]]],
    {node, Length[nodePos]}];

  (* nodes *)
  Do[AppendTo[nodeP, Tooltip[{$hyperColor, Disk[nodePos[[nt + h]], If[mini, 0.07, 0.06]]},
      tip[hyper[[h]], "hyperedge (COPY tensor)"]]], {h, Length[hyper]}];
  Do[
    With[{p = nodePos[[t]], hl = MemberQ[highlight, t]},
      AppendTo[nodeP, Tooltip[
        {EdgeForm[Directive[If[hl, $accentColor, GrayLevel[0.25]], AbsoluteThickness[If[hl, 3.5, 1.2]]]],
         FaceForm[tcols[[t]]], Disk[p, r]},
        labelStr[tnames[[t]]] <> "[" <> StringRiffle[labelStr /@ names[[tl[[t]]]], ","] <> "]"]];
      If[!mini, AppendTo[nodeP, Text[Style[tnames[[t]], If[StringLength[labelStr[tnames[[t]]]] > 3, 9, 12], Bold,
        GrayLevel[0.1]], p]]]],
    {t, nt}];

  xs = Join[nodePos[[All, 1]], bbox[[All, 1]]]; ys = Join[nodePos[[All, 2]], bbox[[All, 2]]];
  If[bbox === {}, xs = nodePos[[All, 1]]; ys = nodePos[[All, 2]]];
  {xr, yr} = If[MatchQ[opt["PlotRange"], {{_?NumericQ, _?NumericQ}, {_?NumericQ, _?NumericQ}}], opt["PlotRange"],
    {{Min[xs] - 0.3, Max[xs] + 0.3}, {Min[ys] - 0.3, Max[ys] + 0.3}}];
  isz = Replace[opt["ImageSize"], Automatic :> If[mini, {Automatic, 36}, Min[720, Max[220, 100 (xr[[2]] - xr[[1]] + 0.3)]]]];
  Graphics[{edgeP, dangP, nodeP, labP, badgeP},
    PlotRange -> {xr, yr},
    AspectRatio -> Automatic, ImageSize -> isz, Background -> opt["Background"],
    PlotLabel -> If[opt["Title"] === None || mini, None, opt["Title"]]]
];

(* ::Subsection:: *)
(* EinsumDiagram, EinsumTree *)

(* Arguments are held only to read the names of symbols passed as tensors; they are then evaluated
   (so Sequence @@ opts and option lists stored in variables work) and options are recognised by value. *)
splitHeld[{}] := {{}, {}, {}};
splitHeld[held_List] := Module[{parts, names, vals, nms, isOpt},
  parts = Function[h, {ReleaseHold[h]}] /@ held;
  names = Replace[#, {HoldComplete[s_Symbol] :> SymbolName[Unevaluated[s]], _ -> None}] & /@ held;
  vals = Join @@ parts;
  nms = Join @@ MapThread[If[Length[#1] == 1, {#2}, ConstantArray[None, Length[#1]]] &, {parts, names}];
  isOpt = (optionQ[#] || (ListQ[#] && # =!= {} && AllTrue[#, optionQ])) & /@ vals;
  {Pick[vals, isOpt, False], Pick[nms, isOpt, False], Flatten[Pick[vals, isOpt]]}
];

argsToShapes[vals_List, nop_Integer] := Which[
  vals === {}, {None, False},
  Length[vals] == 1 && ListQ[vals[[1]]] && Length[vals[[1]]] == nop && shapeListQ[vals[[1]]], {vals[[1]], True},
  Length[vals] == nop, checkArrays[vals]; {shapeOf /@ vals, False},
  True, fail[Einsum::nargs, nop, Length[vals]]
];

specRanks[parsed_Association] :=
  (Count[#, Except[ellipsisMark]] + Boole[MemberQ[#, ellipsisMark]]) & /@ parsed["Terms"];

tensorNames[spec_, symNames_List, shapesMode_, nop_Integer] := If[ListQ[spec] && Length[spec] == nop, spec,
  Table[If[!shapesMode && k <= Length[symNames] && StringQ[symNames[[k]]], symNames[[k]], defaultTensorName[k]], {k, nop}]];

mergedName[x_, y_, j_] := With[{sx = labelStr[x], sy = labelStr[y]},
  If[StringLength[sx] + StringLength[sy] <= 4, sx <> sy, "#" <> ToString[j]]];

Options[EinsumDiagram] = {"TensorNames" -> Automatic, "ShowDimensions" -> Automatic, "ShowPath" -> False,
  "Path" -> Automatic, "Layout" -> Automatic, "Highlight" -> {}, "Steps" -> False, "DefaultDimension" -> 8,
  ImageSize -> Automatic, Background -> White};
SetAttributes[EinsumDiagram, HoldRest];

EinsumDiagram[spec_, args___] := Catch[
  Module[{held = Map[HoldComplete, Unevaluated[{args}]]}, diagramMain[spec, Sequence @@ splitHeld[held]]],
  $einsumTag];

diagramMain[spec_, vals_List, symNames_List, opts_List] := Module[
  {o, parsed, nop, shapes, shapesMode, res, ids, out, names, dims = None, tnames, tcols, info, hyper, edges,
   pos, tpos, hposA, plan = None, badges = <||>, showDims},
  o[name_] := OptionValue[EinsumDiagram, opts, name];
  parsed = parseSpec[spec];
  nop = Length[parsed["Terms"]];
  {shapes, shapesMode} = argsToShapes[vals, nop];
  res = resolveSpec[parsed, If[shapes === None, specRanks[parsed], Length /@ shapes]];
  ids = res["Inputs"]; out = res["Output"]; names = res["Names"];
  If[shapes =!= None, dims = First[resolveDims[ids, shapes, names]]];
  tnames = tensorNames[o["TensorNames"], symNames, shapesMode, nop];
  tcols = nameColors[tnames];
  If[TrueQ[o["ShowPath"]] || TrueQ[o["Steps"]],
    plan = makePlan[spec,
      If[shapes === None, ConstantArray[o["DefaultDimension"], #] & /@ specRanks[parsed], shapes], o["Path"], Automatic];
    badges = Association @@ Flatten[Table[(# -> j) & /@ plan["Steps"][[j]]["Contracted"], {j, Length[plan["Steps"]]}]]];
  info = labelInfo[ids, out, Length[names]];
  {hyper, edges} = layoutGraph[info, nop];
  pos = If[o["Layout"] === Automatic, stressLayout[nop + Length[hyper], edges],
    fixedLayout[o["Layout"], nop, DeleteDuplicates[info[[#, 2]]] & /@ hyper]];
  tpos = Take[pos, nop];
  hposA = If[hyper === {}, <||>, AssociationThread[hyper -> Drop[pos, nop]]];
  showDims = dims =!= None && o["ShowDimensions"] =!= False;
  If[TrueQ[o["Steps"]],
    stepFrames[plan, ids, out, names, dims, tnames, tcols, tpos, hposA, showDims, o[ImageSize], o[Background]],
    renderNetwork[ids, out, names, dims, tnames, tcols, tpos, hposA,
      <|"ShowDims" -> showDims, "Badges" -> If[TrueQ[o["ShowPath"]], badges, <||>], "Highlight" -> o["Highlight"],
        "ImageSize" -> o[ImageSize], "Background" -> o[Background], "Mini" -> False, "Title" -> None|>]]
];

(* One frame per pairwise contraction (the pair contracted next is highlighted). Intermediate tensors sit
   at the centroid of their constituents; all frames share the same plot range so they can be animated. *)
stepFrames[plan_, ids_, out_, names_, dims_, tnames_, tcols_, tpos_, hposA_, showDims_, isz_, bg_] := Module[
  {n = Length[ids], steps = plan["Steps"], s, lab, nm, col, mem, alive, specs = {}, title, frames, rngs, xr, yr},
  s = Length[steps];
  Do[lab[k] = ids[[k]]; nm[k] = tnames[[k]]; col[k] = tcols[[k]]; mem[k] = {k}, {k, n}];
  alive = Range[n];
  Do[
    title = If[j <= s,
      With[{a = steps[[j]]["In"][[1]], b = steps[[j]]["In"][[2]]},
        Row[{Style["step " <> ToString[j] <> "/" <> ToString[s] <> "   ", Bold], nm[a], " \[CenterDot] ", nm[b],
          " \[RightArrow] ", mergedName[nm[a], nm[b], j], "     flops " <> fmtNum[steps[[j]]["Flops"]]}]],
      Row[{Style["result   ", Bold], "total flops " <> fmtNum[plan["Flops"]]}]];
    AppendTo[specs, {lab /@ alive, nm /@ alive, col /@ alive, (Mean[tpos[[mem[#]]]] &) /@ alive,
      If[j <= s, Flatten[Position[alive, #] & /@ steps[[j]]["In"]], {}], title}];
    If[j <= s,
      With[{a = steps[[j]]["In"][[1]], b = steps[[j]]["In"][[2]], new = n + j},
        lab[new] = steps[[j]]["Labels"];
        nm[new] = mergedName[nm[a], nm[b], j];
        col[new] = $intermediateColor;
        mem[new] = Join[mem[a], mem[b]];
        alive = Append[DeleteCases[alive, a | b], new]]],
    {j, s + 1}];
  frames[pr_] := Function[sp, renderNetwork[sp[[1]], out, names, dims, sp[[2]], sp[[3]], sp[[4]], hposA,
      <|"ShowDims" -> showDims, "Badges" -> <||>, "Highlight" -> sp[[5]], "ImageSize" -> isz,
        "Background" -> bg, "Mini" -> False, "Title" -> sp[[6]], "PlotRange" -> pr|>]] /@ specs;
  rngs = Cases[#, HoldPattern[PlotRange -> r_] :> r, {1}][[1]] & /@ frames[Automatic];
  xr = {Min[rngs[[All, 1, 1]]], Max[rngs[[All, 1, 2]]]};
  yr = {Min[rngs[[All, 2, 1]]], Max[rngs[[All, 2, 2]]]};
  frames[{xr, yr}]
];

Options[EinsumTree] = {"TensorNames" -> Automatic, "Path" -> Automatic, "DefaultDimension" -> 8,
  ImageSize -> Automatic, Background -> White};
SetAttributes[EinsumTree, HoldRest];

EinsumTree[spec_, args___] := Catch[
  Module[{held = Map[HoldComplete, Unevaluated[{args}]]}, treeMain[spec, Sequence @@ splitHeld[held]]],
  $einsumTag];

treeMain[spec_, vals_List, symNames_List, opts_List] := Module[{o, parsed, nop, shapes, shapesMode, plan, tnames},
  o[name_] := OptionValue[EinsumTree, opts, name];
  parsed = parseSpec[spec]; nop = Length[parsed["Terms"]];
  {shapes, shapesMode} = argsToShapes[vals, nop];
  plan = makePlan[spec,
    If[shapes === None, ConstantArray[o["DefaultDimension"], #] & /@ specRanks[parsed], shapes], o["Path"], Automatic];
  tnames = tensorNames[o["TensorNames"], symNames, shapesMode, nop];
  treeGraphics[plan, tnames, nameColors[tnames], shapes =!= None, o[ImageSize], o[Background]]
];

treeGraphics[plan_, tnames_, tcols_, known_, isz_, bg_] := Module[
  {n = Length[plan["Inputs"]], steps = plan["Steps"], s, names = plan["Names"], c, kids, xs, hs, order = {}, dfs,
   pos, prims = {}, title, width},
  s = Length[steps]; c = compactQ[names];
  kids[id_] := steps[[id - n]]["In"];
  dfs[id_] := If[id <= n, AppendTo[order, id], Scan[dfs, kids[id]]];
  dfs[n + s];
  Clear[dfs];
  xs = ConstantArray[0., n + s]; hs = ConstantArray[0, n + s];
  Do[xs[[order[[k]]]] = 1.5 (k - 1.), {k, Length[order]}];
  Do[xs[[n + j]] = Mean[xs[[kids[n + j]]]]; hs[[n + j]] = 1 + Max[hs[[kids[n + j]]]], {j, s}];
  pos[id_] := {xs[[id]], -1.3 hs[[id]]};
  Do[Scan[AppendTo[prims, {GrayLevel[0.6], AbsoluteThickness[1.6], Line[{pos[#], pos[n + j]}]}] &, kids[n + j]], {j, s}];
  Do[AppendTo[prims, {
      Tooltip[{EdgeForm[Directive[GrayLevel[0.25], AbsoluteThickness[1.2]]], FaceForm[tcols[[t]]], Disk[pos[t], 0.3]},
        "dimensions " <> ToString[plan["Shapes"][[t]]]],
      Text[Style[tnames[[t]], 12, Bold, GrayLevel[0.1]], pos[t]],
      Text[Style[termStr[plan["Inputs"][[t]], names, c], 10, GrayLevel[0.3]], pos[t] + {0., 0.5}]}], {t, n}];
  Do[
    With[{st = steps[[j]], p = pos[n + j]},
      Module[{l1, l2, l3, wd},
        l1 = termStr[st["Labels"], names, c];
        If[st["Labels"] === {}, l1 = "scalar"];
        l2 = If[st["Contracted"] === {},
          If[Intersection[st["LA"], st["LB"]] === {}, "\[CircleTimes] outer", "\[SmallCircle] batch"],
          "\[Sum] " <> termStr[st["Contracted"], names, c]];
        l3 = If[known, fmtNum[st["Flops"]] <> " flops", ""];
        wd = Max[1.0, 0.12 Max[StringLength /@ {l1, l2, l3}] + 0.4];
        AppendTo[prims, {
          EdgeForm[Directive[If[j == s, $accentColor, GrayLevel[0.45]], AbsoluteThickness[If[j == s, 2, 1]]]],
          FaceForm[If[j == s, RGBColor[1., 0.96, 0.9], White]],
          Rectangle[p - {wd/2, 0.45}, p + {wd/2, 0.45}, RoundingRadius -> 0.12],
          Text[Column[Join[{Style[l1, 11, Bold, GrayLevel[0.1]], Style[l2, 9, GrayLevel[0.35]]},
            If[known, {Style[l3, 9, $accentColor]}, {}]], Alignment -> Center, Spacings -> 0.15], p]}]]],
    {j, s}];
  title = If[known,
    Row[{specString[plan], "     flops ", fmtNum[plan["Flops"]], "  (naive ", fmtNum[plan["NaiveFlops"]],
      ", speed-up ", fmtRatio[plan["NaiveFlops"]/Max[plan["Flops"], 1.]], ")     largest intermediate ",
      fmtNum[plan["LargestIntermediate"]]}],
    specString[plan]];
  (* the title on one line when it fits the width of the tree (about 5.4 points a character at size 10, the costs about
     75 characters), else the costs on a second line, so that a small tree does not cut its title *)
  width = If[isz === Automatic, Min[860, Max[260, 80 (1.5 n + 0.5)]], isz];
  If[known && NumericQ[width] && 5.4 (StringLength[specString[plan]] + 75) + 30 > width,
   title = Column[{specString[plan], Row[{"flops ", fmtNum[plan["Flops"]], "  (naive ", fmtNum[plan["NaiveFlops"]],
       ", speed-up ", fmtRatio[plan["NaiveFlops"]/Max[plan["Flops"], 1.]], ")"}],
      Row[{"largest intermediate ", fmtNum[plan["LargestIntermediate"]]}]}, Alignment -> Center, Spacings -> 0.2]];
  Graphics[prims, ImageSize -> width,
    Background -> bg, PlotLabel -> Style[title, 10], PlotRangePadding -> Scaled[0.08], AspectRatio -> Automatic]
];

(* ::Subsection:: *)
(* Summary box of EinsumFunction *)

$genericIcon = Graphics[{GrayLevel[0.35], AbsoluteThickness[1.2], Line[{{0, 0}, {1, 0}}], Line[{{0, 0}, {0, -0.6}}],
  Line[{{1, 0}, {1, -0.6}}], EdgeForm[GrayLevel[0.3]], FaceForm[tensorColor[1]], Disk[{0, 0}, 0.25],
  FaceForm[tensorColor[2]], Disk[{1, 0}, 0.25]}, ImageSize -> {Automatic, 36}];

miniIcon[plan_Association] := Module[{ids = plan["Inputs"], out = plan["Output"], nop, info, hyper, edges, pos},
  nop = Length[ids];
  info = labelInfo[ids, out, Length[plan["Names"]]];
  {hyper, edges} = layoutGraph[info, nop];
  pos = stressLayout[nop + Length[hyper], edges];
  renderNetwork[ids, out, plan["Names"], None, Table[defaultTensorName[k], {k, nop}], Table[tensorColor[k], {k, nop}],
    Take[pos, nop], If[hyper === {}, <||>, AssociationThread[hyper -> Drop[pos, nop]]],
    <|"Mini" -> True, "ShowDims" -> False, "Badges" -> <||>, "Highlight" -> {}, "ImageSize" -> {Automatic, 36},
      "Background" -> None, "Title" -> None|>]
];

EinsumFunction /: MakeBoxes[ef : EinsumFunction[a_Association], fmt_] /; KeyExistsQ[a, "Plan"] :=
  Module[{p = a["Plan"], icon},
    icon = Quiet[Check[If[Length[p["Inputs"]] <= 12, miniIcon[p], $genericIcon], $genericIcon]];
    BoxForm`ArrangeSummaryBox[EinsumFunction, ef, icon,
      {{BoxForm`SummaryItem[{"Spec: ", specString[p]}]},
       {BoxForm`SummaryItem[{"Flops: ", fmtNum[p["Flops"]]}]}},
      {{BoxForm`SummaryItem[{"Shapes: ", p["Shapes"]}]},
       {BoxForm`SummaryItem[{"Naive flops: ", fmtNum[p["NaiveFlops"]]}]},
       {BoxForm`SummaryItem[{"Speed-up: ", fmtRatio[p["NaiveFlops"]/Max[p["Flops"], 1.]]}]},
       {BoxForm`SummaryItem[{"Largest intermediate: ", fmtNum[p["LargestIntermediate"]]}]},
       {BoxForm`SummaryItem[{"Path (" <> p["Method"] <> "): ", ssaToLinear[p["SSA"], Length[p["Inputs"]]]}]}},
      fmt, "Interpretable" -> Automatic]];

(* ========================================================================================== *)
(*  11. The banner and the update check                                                       *)
(* ========================================================================================== *)

(* the banner shown when the package is loaded in a notebook (as FunctionalDiagrams and FermiWick do): the logo (the small
   badge of Logo/Summa_logo_small.svg, on the gradient of the package, y upwards), the attribution
   "Summa, by Nazzareno Africani" word for word (term (b) of NOTICE), the version, license, how to cite, with links to
   the repository and the website; printed by the end of this file only when $Notebooks *)
$suStart = RGBColor[91/255, 24/255, 70/255]; $suEnd = RGBColor[194/255, 71/255, 30/255];
$suAccent = RGBColor[142/255, 48/255, 50/255]; $suTint = RGBColor[255/255, 203/255, 164/255];
(* a colour for light notebooks and one for dark notebooks (LightDarkSwitched, Mathematica 14.3 or later) *)
lightDarkColor[light_, dark_] := If[Names["System`LightDarkSwitched"] =!= {}, Symbol["LightDarkSwitched"][light, dark], light];
badgePoints[] := With[{r = 28.}, Join @@ MapThread[Function[{c, a0}, Table[c + r {Cos[a], Sin[a]}, {a, a0, a0 + Pi/2, Pi/16}]],
     {{{128 - r, r}, {128 - r, 128 - r}, {r, 128 - r}, {r, r}}, {-Pi/2, 0, Pi/2, Pi}}]];
(* the sigma of a sum as a tensor network: five tensors joined by bonds, the bond being contracted in the tint *)
packageLogo[size_: 30] := Module[{pts = badgePoints[], v = {{94, 98}, {36, 98}, {66, 64}, {36, 30}, {94, 30}}},
   Graphics[{
     Polygon[pts, VertexColors -> (Blend[{$suStart, $suEnd}, (#[[1]] + 128 - #[[2]])/256] & /@ pts)],
     {EdgeForm[{White, Opacity[0.16], Thickness[2/128]}], FaceForm[None], Polygon[badgePoints[]]},
     CapForm["Round"], Thickness[10/128], White, Line[{v[[1]], v[[2]]}], Line[{v[[3]], v[[4]], v[[5]]}],
     $suTint, Line[{v[[2]], v[[3]]}], White, Disk[#, 10] & /@ v},
    PlotRange -> {{0, 128}, {0, 128}}, PlotRangePadding -> None, ImagePadding -> None, ImageSize -> size,
    BaselinePosition -> Scaled[0.2]]];
$repositoryURL = "https://github.com/n4sd4q/Summa";
$websiteURL = "https://n4sd4q.github.io/Summa/";
(* the name in the accent of the logo (its tint in a dark notebook), the rest in grey; U+2010 (a hyphen, not a minus
   sign), U+00B7 and U+00A0 by character code, so that the file stays plain ASCII. Each group is unbreakable and ends with
   its separator, so that in a narrow window the lines wrap after a separator, never before one *)
bannerDot[] := With[{nbsp = FromCharacterCode[160]}, nbsp <> nbsp <> FromCharacterCode[183] <> nbsp <> " "];
bannerGroup[items__] := Style[Row[{items}], LineBreakWithin -> False];
bannerAccent[] := lightDarkColor[$suAccent, $suTint];
bannerGrey[] := lightDarkColor[GrayLevel[0.45], GrayLevel[0.6]];
loadBanner[release_ : None] :=
  Module[{dot = bannerDot[], group = bannerGroup, accent = bannerAccent[], grey = bannerGrey[], file = $repositoryURL <> "/blob/main/"},
   Style[Grid[{{packageLogo[30],
       Column[{
         Row[{group[Style["Summa", Bold, 14, accent], Style[", by Nazzareno Africani", 14, accent], Style[dot, 12, grey]],
           Style["fast Einstein summation", 12, grey]}],
         Style[Row[{group["version " <> $SummaVersion, dot],
             group[StringReplace["GPL-3.0-or-later", "-" -> FromCharacterCode[8208]], dot],
             group["please cite it: ", Hyperlink["CITATION.cff", file <> "CITATION.cff"], dot],
             group[Hyperlink["GitHub", $repositoryURL], dot],
             Hyperlink["Website", $websiteURL]}], 11, grey],
         If[AssociationQ[release], updateNotice[release], Nothing]},
        Spacings -> 0.1]}},
      Alignment -> {Left, Center}, Spacings -> {0.7, 0}], FontFamily -> "Source Sans Pro", LineIndent -> 0]];

(* the update check. In a notebook (never in a script), at most once a day, the package asks GitHub for its latest release
   in the background (URLSubmit: loading never waits for the network) and, if it is newer than the version loaded, the
   banner gets a third line with the PacletInstall line of its paclet. Any failure (offline, a proxy, a time limit, the rate
   limit of GitHub, an answer without the fields) is silent. The handler of the answer runs after the evaluation that
   loaded the package: it writes the banner again in its own cell, found by a tag given to it at load, without moving the
   selection. SummaUpdateCheck[] asks by hand, and waits for the answer *)
$latestReleaseURL = "https://api.github.com/repos/n4sd4q/Summa/releases/latest";
latestReleaseRequest[] := HTTPRequest[$latestReleaseURL, <|"Headers" -> {"Accept" -> "application/vnd.github+json"}|>];
$updateCheckDirectory := FileNameJoin[{$UserBaseDirectory, "ApplicationData", "Summa"}];
updateCheckDate[] := DateString[{"Year", "-", "Month", "-", "Day"}];
networkOptions[f_, opts_List] := FilterRules[opts, Options[f]];

(* the numbers of a version "0.10.0" or of a tag "v0.10.0"; $Failed for anything else (a pre-release "v0.3.0-rc1") *)
versionNumbers[s_String] := If[StringMatchQ[s, RegularExpression["v?[0-9]+\\.[0-9]+\\.[0-9]+"]],
   FromDigits /@ StringSplit[StringReplace[s, StartOfString ~~ "v" -> ""], "."], $Failed];
versionNumbers[_] := $Failed;
(* whether version a is newer than version b, number by number (0.10.0 is newer than 0.9.0) *)
newerVersionQ[a_, b_] := With[{x = versionNumbers[a], y = versionNumbers[b]}, ListQ[x] && ListQ[y] && Order[y, x] === 1];

(* the latest release in the answer of GitHub (JSON): <|"Version" -> "0.2.0", "Paclet" -> url of its .paclet, "Page" -> url
   of its page|>, or $Failed for a draft or a pre-release, a malformed tag or no paclet of this repository. ImportString
   reads bytes: the text is encoded in UTF-8 first. The paclet's address must be one of this repository's downloads, made
   of plain characters, since it is shown inside a line of code to copy *)
latestReleaseOf[body_String] := Module[{json, tag, version, paclets},
   json = Quiet[ImportString[FromCharacterCode[ToCharacterCode[body, "UTF8"]], "RawJSON"]];
   If[! AssociationQ[json], Return[$Failed]];
   tag = Lookup[json, "tag_name"];
   If[TrueQ[Lookup[json, "draft"]] || TrueQ[Lookup[json, "prerelease"]] || ! ListQ[versionNumbers[tag]], Return[$Failed]];
   version = StringReplace[tag, StartOfString ~~ "v" -> ""];
   paclets = Cases[Lookup[json, "assets", {}], KeyValuePattern["browser_download_url" -> url_String] /;
       StringMatchQ[url, RegularExpression[StringReplace[$repositoryURL, "." -> "\\."] <> "/releases/download/" <>
          StringReplace[tag, "." -> "\\."] <> "/[A-Za-z0-9._-]+\\.paclet"]] :> url];
   If[paclets === {}, $Failed,
    <|"Version" -> version, "Paclet" -> First[paclets], "Page" -> $repositoryURL <> "/releases/tag/" <> tag|>]];
latestReleaseOf[_] := $Failed;
installLine[release_Association] := "PacletInstall[\"" <> release["Paclet"] <> "\"]";

(* the third line of the banner: the newer version, a link to its page and the line that installs it, as code to copy *)
updateNotice[release_Association] := With[{dot = bannerDot[], group = bannerGroup},
   Style[Row[{group[Style["version " <> release["Version"] <> " is available", Bold, bannerAccent[]], dot],
      group[Hyperlink["what is new", release["Page"]], dot],
      With[{url = release["Paclet"]}, Style[Defer[PacletInstall[url]], ShowStringCharacters -> True,
        PrivateFontOptions -> {"OperatorSubstitution" -> False}]]}], 11, bannerGrey[]]];
updateNoticeText[release_Association] :=
  "Summa " <> release["Version"] <> " is available (" <> $SummaVersion <> " is loaded): " <> installLine[release];

(* whether the check at load is due today: the file LastUpdateCheck.txt of dir holds the date of the last check; the date of
   today is written into it before asking. Any error reading or writing it: the check is due *)
updateCheckDueQ[dir_String, today_String] := Module[{file = FileNameJoin[{dir, "LastUpdateCheck.txt"}], last, stream},
   last = Quiet[ReadString[file]];
   If[StringQ[last] && StringTrim[last] === today, Return[False]];
   Quiet[If[! DirectoryQ[dir], CreateDirectory[dir, CreateIntermediateDirectories -> True]];
    stream = OpenWrite[file];
    If[Head[stream] === OutputStream, WriteString[stream, today <> "\n"]; Close[stream]]];
   True];

$updateCheckTask = None;
submitUpdateCheck[nb_, tag_String] := Quiet[
   $updateCheckTask = URLSubmit[latestReleaseRequest[],
     HandlerFunctions -> <|"TaskFinished" -> (showUpdateNotice[nb, tag, #] &)|>,
     HandlerFunctionsKeys -> {"StatusCode", "Body"}, Sequence @@ networkOptions[URLSubmit, {TimeConstraint -> 30}]]];
showUpdateNotice[nb_, tag_String, answer_] := Quiet[Module[{release, cells},
    release = If[Lookup[answer, "StatusCode"] === 200, latestReleaseOf[Lookup[answer, "Body"]], $Failed];
    If[AssociationQ[release] && newerVersionQ[release["Version"], $SummaVersion],
     cells = Cells[nb, CellTags -> tag];
     If[ListQ[cells] && Length[cells] == 1,
      NotebookWrite[First[cells], ReplacePart[NotebookRead[First[cells]], 1 -> BoxData[ToBoxes[loadBanner[release]]]]]]]]];

SummaUpdateCheck::latest = "The latest release could not be read from GitHub (`1`).";
SummaUpdateCheck[] := Module[{response, status, release},
   response = Quiet[URLRead[latestReleaseRequest[], Sequence @@ networkOptions[URLRead, {TimeConstraint -> 10}]]];
   status = If[Head[response] === HTTPResponse, response["StatusCode"], None];
   release = If[status === 200, latestReleaseOf[response["Body"]], $Failed];
   If[! AssociationQ[release],
    Message[SummaUpdateCheck::latest, Which[status === None, "no answer", status =!= 200, "status " <> ToString[status],
       True, "no release with a paclet in the answer"]];
    $Failed,
    If[newerVersionQ[release["Version"], $SummaVersion],
     Print[If[TrueQ[$Notebooks], Style[updateNotice[release], FontFamily -> "Source Sans Pro"], updateNoticeText[release]]]];
    <|"InstalledVersion" -> $SummaVersion, "LatestVersion" -> release["Version"], "InstallLine" -> installLine[release]|>]];

(* the check at load is on unless $SummaUpdateCheck was set before loading (kept by the start of the package) *)
If[! ValueQ[$SummaUpdateCheck], $SummaUpdateCheck = True];

(* in a notebook (not in scripts, which stay quiet), the banner, and the update check when it is due *)
If[TrueQ[$Notebooks],
  If[$SummaUpdateCheck =!= False && $AllowInternet =!= False && updateCheckDueQ[$updateCheckDirectory, updateCheckDate[]],
   With[{tag = "SummaBanner" <> ToString[Round[10^6 AbsoluteTime[]]]},
    CellPrint[ExpressionCell[loadBanner[], "Print", CellTags -> tag]];
    submitUpdateCheck[EvaluationNotebook[], tag]],
   Print[loadBanner[]]]];

End[];

EndPackage[];
