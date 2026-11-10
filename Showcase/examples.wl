(* ::Example:: load *)
Needs["Summa`"]

(* ::Example:: first *)
m = {{1, 2}, {3, 4}}; n = {{0, 1}, {1, 1}};
Einsum["ij,jk->ik", m, n]

(* ::Example:: firstcheck *)
Einsum["ij,jk->ik", m, n] == m . n

(* ::Example:: onematrix *)
{Einsum["ij->ji", m], Einsum["ii->", m], Einsum["ii->i", m], Einsum["ij->i", m],
 Einsum["ij->", m]}

(* ::Example:: vectors *)
{Einsum["i,i->", {1, 2}, {3, 4}], Einsum["i,j->ij", {1, 2}, {3, 4}]}

(* ::Example:: implicit *)
{Einsum["ij,jk", m, n] == m . n, Einsum["ba", m] == Transpose[m], Einsum["ii", m]}

(* ::Example:: diagonals text *)
digits = Array[100 #1 + 10 #2 + #3 &, {3, 3, 3}];
{Einsum["iij->ij", digits], Einsum["iii->i", digits]}

(* ::Example:: ellipsis *)
SeedRandom[1];
stackA = RandomInteger[9, {5, 2, 3}]; stackB = RandomInteger[9, {3, 4}];
Dimensions[Einsum["...ij,...jk->...ik", stackA, stackB]]

(* ::Example:: broadcast *)
Einsum["...i,...i->...", {{1, 2}, {3, 4}, {5, 6}}, {{1, 1}}]

(* ::Example:: scalars *)
{Einsum[",ij->ij", Sqrt[2], m], Einsum[",i,i->", a + b, {1, 2}, {3, 4}]}

(* ::Example:: listsyntax *)
Einsum[{{"bond1", "x"}, {"x", "bond2"}} -> {"bond2", "bond1"}, m, n]

(* ::Example:: unicode *)
Einsum["\[Alpha]\[Beta], \[Beta]\[Gamma] \[RightArrow] \[Gamma]\[Alpha]", m, n]

(* ::Example:: threevectors *)
Einsum["i,i,i->", Array[x, 2], Array[y, 2], Array[z, 2]]

(* ::Example:: tensorcontract *)
TensorContract[TensorProduct[Array[x, 2], Array[y, 2], Array[z, 2]], {{1, 2, 3}}] ==
 Einsum["i,i,i->", Array[x, 2], Array[y, 2], Array[z, 2]]

(* ::Example:: quadraticforms *)
rows = {{1, 0}, {0, 1}, {1, 1}}; q = {{2, 1}, {1, 3}};
Einsum["bi,ij,bj->b", rows, q, rows]

(* ::Example:: batchmatmul *)
SeedRandom[2]; xs = RandomReal[1, {1000, 3, 4}]; ys = RandomReal[1, {1000, 4, 2}];
Einsum["bij,bjk->bik", xs, ys] == MapThread[Dot, {xs, ys}]

(* ::Example:: cp *)
SeedRandom[3]; {fa, fb, fc} = RandomReal[1, {3, 40, 8}];
cp = Einsum["ai,bi,ci->abc", fa, fb, fc];
reference = Sum[Outer[Times, fa[[All, i]], fb[[All, i]], fc[[All, i]]], {i, 8}];
{Dimensions[cp], Max[Abs[cp - reference]] < 10^-12}

(* ::Example:: cpcost *)
{Times @@ Flatten[Dimensions /@ {fa, fb, fc}],
 EinsumPath["ai,bi,ci->abc", fa, fb, fc]["Flops"]}

(* ::Example:: rowdots *)
Einsum["ij,ij->i", m, n]

(* ::Example:: chain *)
EinsumPath["ij,jk,kl->il", {{1000, 10}, {10, 1000}, {1000, 10}}]

(* ::Example:: chainbad *)
EinsumPath["ij,jk,kl->il", {{1000, 10}, {10, 1000}, {1000, 10}},
  "Path" -> {{1, 2}, {1, 2}}][[{"Contractions", "Flops"}]]

(* ::Example:: strategies *)
spec5 = "ab,ge,gac,dbf,abe->";
dims5 = {{50, 20}, {20, 50}, {20, 50, 5}, {10, 20, 20}, {50, 20, 50}};
AssociationMap[EinsumPath[spec5, dims5, "Path" -> #]["Flops"] &,
 {"Optimal", "Greedy", "Sequential", {{1, 5}, {1, 2}, {1, 2}, {1, 2}}}]

(* ::Example:: mpsnorm *)
mpsSpec = "pa,aqb,brc,cs,pA,AqB,BrC,Cs->";
mpsDims = {{2, 64}, {64, 2, 64}, {64, 2, 64}, {64, 2},
   {2, 64}, {64, 2, 64}, {64, 2, 64}, {64, 2}};
EinsumPath[mpsSpec, mpsDims][[{"Contractions", "Flops", "NaiveFlops", "Speedup",
   "LargestIntermediate"}]]

(* ::Example:: mpsgeneral *)
mps[L_] := Module[{ket = Table[{\[Alpha][k - 1], \[Sigma][k], \[Alpha][k]}, {k, L}]},
  ket[[1]] = Rest[ket[[1]]]; ket[[L]] = Most[ket[[L]]];
  Join[ket, ket /. \[Alpha] -> \[Beta]] -> {}];
mpsShapes[L_, d_, \[Chi]_] := Join[#, #] &[Table[Which[k == 1, {d, \[Chi]}, k == L, {\[Chi], d},
     True, {\[Chi], d, \[Chi]}], {k, L}]];
mps[3]

(* ::Example:: mpstable *)
TableForm[Table[{L, EinsumPath[mps[L], mpsShapes[L, 2, 16]]["Flops"],
    EinsumPath[mps[L], mpsShapes[L, 2, 16], "Path" -> "Sequential"]["Flops"]},
   {L, {4, 8, 12, 16, 20}}],
 TableHeadings -> {None, {"L", "Automatic", "Sequential"}}]

(* ::Example:: diagrammps *)
EinsumDiagram["ai,ibj,jck,kd->abcd"]

(* ::Example:: diagramkinds *)
EinsumDiagram["iijx,jkh,kh,lh->l", ImageSize -> 300]

(* ::Example:: diagrampath *)
EinsumDiagram[mpsSpec, mpsDims, "ShowPath" -> True]

(* ::Example:: diagramsteps *)
EinsumDiagram["ab,bc,ca->", {{2, 8}, {8, 4}, {4, 2}}, "Steps" -> True,
 ImageSize -> 220]

(* ::Example:: tree *)
EinsumTree["ij,jk,kl->il", {{1000, 10}, {10, 1000}, {1000, 10}}, ImageSize -> 320]

(* ::Example:: efdefine *)
SeedRandom[4]; tensorA = RandomReal[{-1, 1}, {8, 2, 8}];
transfer = EinsumFunction["ab,asc,bsd->cd", {{8, 8}, {8, 2, 8}, {8, 2, 8}}]

(* ::Example:: efproperties *)
{transfer["Contractions"], transfer["Flops"]}

(* ::Example:: efloop *)
step[x_] := #/Norm[#] &[transfer[x, tensorA, tensorA]];
fixedPoint = Nest[step, IdentityMatrix[8], 300];
transferMatrix = ArrayReshape[Einsum["asc,bsd->abcd", tensorA, tensorA], {64, 64}];
{Norm[transfer[fixedPoint, tensorA, tensorA]],
 Max[Abs[Eigenvalues[transferMatrix]]]}

(* ::Example:: symbolic *)
MatrixForm[Einsum["ij,jk->ik", Array[a, {2, 2}], Array[b, {2, 2}]]]

(* ::Example:: cross *)
Einsum["ijk,j,k->i", LeviCivitaTensor[3], Array[u, 3], Array[v, 3]]

(* ::Example:: epsilondelta *)
With[{\[Epsilon] = LeviCivitaTensor[3], \[Delta] = IdentityMatrix[3]},
 Einsum["ijk,imn->jkmn", \[Epsilon], \[Epsilon]] ==
  Einsum["jm,kn->jkmn", \[Delta], \[Delta]] - Einsum["jn,km->jkmn", \[Delta], \[Delta]]]

(* ::Example:: pauli *)
pauli = PauliMatrix /@ {1, 2, 3};
MatrixForm[Einsum["aij,ajk->ik", pauli, pauli]]

(* ::Example:: pauliproduct *)
Einsum["aij,bjk->abik", pauli, pauli] ==
 Einsum["ab,ik->abik", IdentityMatrix[3], IdentityMatrix[2]] +
  I Einsum["abc,cik->abik", LeviCivitaTensor[3], pauli]

(* ::Example:: sparse *)
ring = SparseArray[{Band[{1, 2}] -> 1., Band[{2, 1}] -> 1., {1, 1000} -> 1.,
    {1000, 1} -> 1.}, {1000, 1000}];
ring2 = Einsum["ij,jk->ik", ring, ring];
{Head[ring2], Length[ring2["NonzeroValues"]]}

(* ::Example:: ising *)
lattice = "ab,bc,de,ef,gh,hi,ad,be,cf,dg,eh,fi->";
EinsumDiagram[lattice, "TensorNames" -> ConstantArray["W", 12], ImageSize -> 340]

(* ::Example:: isingz *)
boltzmann = {{x, 1/x}, {1/x, x}};
zIsing = Expand[Einsum[lattice, Sequence @@ ConstantArray[boltzmann, 12]]]

(* ::Example:: isingcheck *)
bonds = Characters /@ StringSplit[StringDrop[lattice, -2], ","];
weight[s_] := With[{c = AssociationThread[Characters["abcdefghi"], s]},
   Times @@ (x^(c[#1] c[#2]) & @@@ bonds)];
Expand[zIsing - Sum[weight[s], {s, Tuples[{1, -1}, 9]}]]

(* ::Example:: aklt *)
aklt = Transpose[{Sqrt[2/3] {{0, 1}, {0, 0}}, -Sqrt[1/3] {{1, 0}, {0, -1}},
    -Sqrt[2/3] {{0, 0}, {1, 0}}}, {2, 1, 3}];
akltRing[L_, ops_ : {}] := Join[
   Table[{\[Alpha][k], \[Sigma][k], \[Alpha][Mod[k, L] + 1]}, {k, L}],
   Table[{\[Beta][k], If[MemberQ[ops, k], \[Tau][k], \[Sigma][k]], \[Beta][Mod[k, L] + 1]}, {k, L}],
   ({\[Sigma][#], \[Tau][#]} &) /@ ops] -> {};
Table[Einsum[akltRing[L], Sequence @@ ConstantArray[aklt, 2 L]], {L, 2, 7}]

(* ::Example:: akltnorm *)
Table[1 + 3 (-1/3)^L, {L, 2, 7}]

(* ::Example:: akltcorrelation *)
sz = DiagonalMatrix[{1, 0, -1}];
Table[Einsum[akltRing[10, {1, 1 + r}], Sequence @@ ConstantArray[aklt, 20], sz, sz]/
   Einsum[akltRing[10], Sequence @@ ConstantArray[aklt, 20]], {r, 4}]

(* ::Example:: kubomodel *)
nk = 400; ks = 2. Pi Range[0, nk - 1]/nk; \[Omega]s = Range[0., 4., 0.01]; \[Eta] = 0.05;
h[k_] := (1 + 0.6 Cos[k]) PauliMatrix[1] + 0.6 Sin[k] PauliMatrix[2] +
   0.4 PauliMatrix[3];
current[k_] := -0.6 Sin[k] PauliMatrix[1] + 0.6 Cos[k] PauliMatrix[2];
bands[k_] := Transpose[SortBy[Transpose[Eigensystem[h[k]]], First]];
{energies, states} = Transpose[bands /@ ks];
Dimensions /@ {energies, states}

(* ::Example:: kubocurrents *)
bandCurrents = Einsum["kni,kij,kmj->knm", Conjugate[states], current /@ ks, states];
Dimensions[bandCurrents]

(* ::Example:: kuboweights *)
f = UnitStep[-energies]; e = energies;
weights = Table[With[{de = e[[k, m]] - e[[k, n]]},
    If[n == m, 0. \[Omega]s, (f[[k, n]] - f[[k, m]])/de/(\[Omega]s - de + I \[Eta])]],
   {k, nk}, {n, 2}, {m, 2}];
Dimensions[weights]

(* ::Example:: kubo *)
conductivity = I/nk Einsum["knm,kmn,knmw->w", bandCurrents, bandCurrents, weights];
ListLinePlot[Transpose[{\[Omega]s, Re[conductivity]}], Frame -> True,
 FrameLabel -> {"\[Omega]", "Re \[Sigma](\[Omega])"}, PlotStyle -> RGBColor["#8E3032"],
 PlotRange -> All, ImageSize -> 360]

(* ::Example:: kubocheck *)
writtenOut = I/nk Sum[
    bandCurrents[[k, n, m]] bandCurrents[[k, m, n]] weights[[k, n, m]],
    {k, nk}, {n, 2}, {m, 2}];
Max[Abs[conductivity - writtenOut]] < 10^-12

(* ::Example:: kubopath *)
EinsumPath["knm,kmn,knmw->w", bandCurrents, bandCurrents, weights][[
 {"Contractions", "Flops", "NaiveFlops"}]]

(* ::Example:: propagators *)
propagators[z_] := Inverse[z IdentityMatrix[2] - h[#]] & /@ ks;
{z1, z2, z3} = {0.3 + 0.1 I, -0.2 + 0.2 I, 1. + 0.1 I};
loop = Einsum["kab,kbc,kca->k", propagators[z1], propagators[z2], propagators[z3]];
Max[Abs[loop - Total[1/((z1 - e) (z2 - e) (z3 - e)), {2}]]] < 10^-12

(* ::Example:: kernels *)
kernel[s_] := s["Type"] <>
   If[KeyExistsQ[s, "Method"], " (" <> s["Method"] <> ")", ""];
kernels[spec_, dims_] := {spec, ToString[dims],
   StringRiffle[kernel /@ EinsumFunction[spec, dims]["Plan"]["Steps"], ", "]};
TableForm[kernels @@@ {{"ij,jk->ik", {{300, 300}, {300, 300}}},
    {"ijk,kj->i", {{40, 40, 40}, {40, 40}}},
    {"bij,bjk->bik", {{200, 64, 64}, {200, 64, 64}}},
    {"bij,bjk->bik", {{20000, 4, 4}, {20000, 4, 4}}},
    {"kh,kh->h", {{100, 100}, {100, 100}}}, {"ij,j->ij", {{100, 100}, {100}}},
    {"ijk,ijk,ijk->", {{10, 10, 10}, {10, 10, 10}, {10, 10, 10}}}},
 TableHeadings -> {None, {"spec", "dimensions", "kernels"}}]

(* ::Example:: exhaustive *)
allPaths[1] = {{}};
allPaths[k_] := Join @@ Table[Prepend[#, p] & /@ allPaths[k - 1],
   {p, Subsets[Range[k], {2}]}];
costs = EinsumPath[spec5, dims5, "Path" -> #]["Flops"] & /@ allPaths[5];
{Length[costs], Min[costs], EinsumPath[spec5, dims5]["Flops"]}

(* ::Example:: explicitsum *)
SeedRandom[5]; {ta, tb, tc} = RandomInteger[{-5, 5}, {3, 3, 4, 3}];
Einsum["iaj,jbk,kci->abc", ta, tb, tc] ==
 Table[Sum[ta[[i, a, j]] tb[[j, b, k]] tc[[k, c, i]], {i, 3}, {j, 3}, {k, 3}],
  {a, 4}, {b, 4}, {c, 4}]
