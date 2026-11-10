(* ::Example:: load *)
Needs["Summa`"]

(* ::Example:: version *)
{$SummaVersion, $SummaUpdateCheck}

(* ::Example:: labels *)
m = {{1, 2}, {3, 4}}; n = {{0, 1}, {1, 1}};
{Einsum["ij,jk->ik", m, n], Einsum[" i j , j k -> i k ", m, n],
 Einsum["\[Alpha]\[Beta],\[Beta]\[Gamma]\[RightArrow]\[Alpha]\[Gamma]", m, n]}

(* ::Example:: casesensitive *)
Einsum["iI,iI->", m, n] == Total[m n, 2]

(* ::Example:: implicitorder *)
{EinsumPath["iB,ia", {{2, 3}, {2, 4}}]["Spec"],
 EinsumPath[{{x, 2}, {2, "y"}}, {{2, 3}, {3, 4}}]["Spec"]}

(* ::Example:: ellipsisimplicit *)
SeedRandom[1];
s1 = RandomInteger[9, {6, 5, 2, 3}]; s2 = RandomInteger[9, {5, 3, 4}];
{Dimensions[Einsum["...ij,...jk", s1, s2]],
 Dimensions[Einsum["i...,i...->...", m, n]]}

(* ::Example:: broadcastrule *)
Einsum["ij,ij->ij", {{1, 2}, {3, 4}, {5, 6}}, {{10, 100}}]

(* ::Example:: diagonalsame *)
Einsum["ii->i", {{1, 2, 3}}]

(* ::Example:: scalar *)
{Einsum[",->", 2, 3], Einsum["ij,->ij", m, x], Einsum["i->", {a, b, c}]}

(* ::Example:: forms *)
{Einsum[{"ij", "jk"} -> "ki", m, n], Einsum["ij" -> "ji", m],
 Einsum[{{1, 2}, {2, 3}} -> {3, 1}, m, n], Einsum[{{"row", "col"}}, m]}

(* ::Example:: optpath *)
SeedRandom[2]; {ma, mb, mc} = RandomInteger[{-9, 9}, {3, 4, 4}];
Table[Einsum["ij,jk,kl->il", ma, mb, mc, "Path" -> p] == ma . mb . mc,
 {p, {Automatic, "Optimal", "Greedy", "Sequential", {{2, 3}, {1, 2}}}}]

(* ::Example:: optbatch *)
SeedRandom[3];
xs = RandomInteger[{-9, 9}, {50, 3, 4}]; ys = RandomInteger[{-9, 9}, {50, 4, 2}];
Table[Einsum["bij,bjk->bik", xs, ys, "BatchMethod" -> b] ==
  MapThread[Dot, {xs, ys}], {b, {Automatic, "Dot", "Vectorized"}}]

(* ::Example:: optcache *)
Einsum["ij,jk->ik", m, n, "Cache" -> False]

(* ::Example:: optunknown *)
Einsum["ij->ji", m, "Foo" -> 1]

(* ::Example:: path *)
EinsumPath["ij,jk,kl->il", {{2, 30}, {30, 40}, {40, 3}}]

(* ::Example:: pathtensors *)
EinsumPath["ij,jk,kl->il", RandomReal[1, {2, 30}], RandomReal[1, {30, 40}],
   RandomReal[1, {40, 3}]] ===
 EinsumPath["ij,jk,kl->il", {{2, 30}, {30, 40}, {40, 3}}]

(* ::Example:: pathuser *)
userPath = EinsumPath["ij,jk,kl->il", {{2, 30}, {30, 40}, {40, 3}},
   "Path" -> {{2, 3}, {1, 2}}];
userPath[[{"Path", "Method", "Contractions", "StepFlops", "Flops"}]]

(* ::Example:: pathtrivial *)
{EinsumPath["ij,jk->ik", {{2, 3}, {3, 4}}]["Method"],
 EinsumPath["iij->j", {{3, 3, 4}}][[{"Flops", "NaiveFlops"}]]}

(* ::Example:: efsummary *)
ef = EinsumFunction["bij,bjk->bik", {{4, 3, 2}, {4, 2, 5}}]

(* ::Example:: efapply *)
SeedRandom[4]; bx = RandomInteger[9, {4, 3, 2}]; by = RandomInteger[9, {4, 2, 5}];
ef[bx, by] == Table[bx[[b]] . by[[b]], {b, 4}]

(* ::Example:: efproperties *)
ef["Properties"]

(* ::Example:: efvalues *)
AssociationMap[ef, {"Spec", "Shapes", "Path", "Method", "Flops", "NaiveFlops",
  "Speedup", "LargestIntermediate", "Contractions"}]

(* ::Example:: efplan *)
Keys[ef["Plan"]]

(* ::Example:: efmismatch *)
ef[by, bx]

(* ::Example:: efscalar *)
EinsumFunction[",ij->ij", {{}, {2, 2}}][Sin[x], m]

(* ::Example:: efdiagram *)
ef["Diagram"]

(* ::Example:: diagramplain *)
EinsumDiagram["ai,bi,ci->abci", ImageSize -> 260]

(* ::Example:: diagramcircle *)
EinsumDiagram["ab,bc,ca->", "Layout" -> "Circle", "TensorNames" -> {"X", "Y", "Z"}]

(* ::Example:: diagramline *)
EinsumDiagram["ij,jk,kl->il", "Layout" -> "Line"]

(* ::Example:: diagramcoordinates *)
EinsumDiagram["ab,bc,cd,da->", "Layout" -> {{0, 0}, {1.4, 0}, {1.4, 1.4}, {0, 1.4}},
 "Highlight" -> {1, 3}]

(* ::Example:: diagramsymbols *)
SeedRandom[5]; psi = RandomReal[1, {2, 30}];
EinsumDiagram["ai,bi->ab", psi, psi]

(* ::Example:: diagramdimensions *)
EinsumDiagram["ij,jk,kl->il", {{2, 300}, {300, 40}, {40, 3}}, "ShowPath" -> True,
 "ShowDimensions" -> False]

(* ::Example:: diagramdefault *)
EinsumDiagram["ij,jk,kl->il", "ShowPath" -> True, "DefaultDimension" -> 2]

(* ::Example:: diagramsteps *)
frames = EinsumDiagram["ij,jk,kl->il", {{2, 30}, {30, 40}, {40, 3}},
   "Steps" -> True];
{Length[frames], Head /@ frames}

(* ::Example:: tree *)
EinsumTree["ai,bi,ci->abc", {{30, 4}, {50, 4}, {60, 4}}, ImageSize -> 320]

(* ::Example:: treenodims *)
EinsumTree["ab,bc,cd,de->ae", "TensorNames" -> {"P", "Q", "R", "S"},
 ImageSize -> 360]

(* ::Example:: clearcache *)
EinsumClearCache[]

(* ::Example:: errspec *)
Einsum["ij,jk->>ik", m, n]

(* ::Example:: errnargs *)
Einsum["ij,jk->ik", m]

(* ::Example:: errrank *)
Einsum["ijk,jk->ik", m, n]

(* ::Example:: errellrank *)
Einsum["...ijk->k", m]

(* ::Example:: errell *)
Einsum["...i...->i", m]

(* ::Example:: errellout *)
Einsum["...i->i", m]

(* ::Example:: errdim *)
Einsum["ij,jk->ik", m, IdentityMatrix[3]]

(* ::Example:: erroutrep *)
Einsum["ij->ii", m]

(* ::Example:: erroutnf *)
Einsum["ij->iz", m]

(* ::Example:: errpath *)
Einsum["ij,jk,kl->il", m, n, m, "Path" -> {{1, 2}}]

(* ::Example:: errarray *)
Einsum["ij,jk->ik", {{1, 2}, {3}}, n]

(* ::Example:: erroptbig *)
chain = StringRiffle[Table[FromCharacterCode[{96 + k, 97 + k}], {k, 15}], ","] <>
   "->ap";
EinsumPath[chain, ConstantArray[{2, 2}, 15], "Path" -> "Optimal"]["Method"]

(* ::Example:: packed *)
Developer`PackedArrayQ /@
 {Einsum["ij,jk->ik", RandomReal[1, {3, 3}], RandomReal[1, {3, 3}]],
  Einsum["i,j->ij", Range[3], Range[4]]}
