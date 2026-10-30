(* ::Package:: *)

(* Benchmarks for Einsum`.  Run from a notebook:   Get["/path/to/Einsum/Examples/Benchmarks.wl"]
   or from a terminal:  wolframscript -file Benchmarks.wl
   Each line compares Einsum (cached plan, and precompiled EinsumFunction) with a hand-written
   Mathematica equivalent, and checks that the results agree. *)

If[!MemberQ[$Packages, "Einsum`"],
  Get[FileNameJoin[{DirectoryName[$InputFileName], "..", "Kernel", "Einsum.wl"}]]];

SetAttributes[time, HoldAll];
time[expr_] := First[RepeatedTiming[expr;]];
fmt[t_] := Which[t < 10^-3, ToString[NumberForm[10^6 t, 3]] <> " \[Mu]s",
  t < 1, ToString[NumberForm[10^3 t, 3]] <> " ms", True, ToString[NumberForm[t, 3]] <> " s"];

SetAttributes[bench, HoldAll];
bench[name_, spec_, tensors_List, reference_] := Module[{ts = tensors, ef, tE, tF, tR, rE, rR},
  ef = EinsumFunction[spec, Dimensions /@ ts];
  rE = Einsum[spec, Sequence @@ ts];       (* first call builds and caches the plan *)
  rR = reference;
  tE = time[Einsum[spec, Sequence @@ ts]];
  tF = time[ef @@ ts];
  tR = time[reference];
  {name, spec, fmt[tE], fmt[tF], fmt[tR], NumberForm[tR/tE, 3],
   If[Max[Abs[Flatten[{N[rE - rR]}]]] < 10^-8 Max[1, Max[Abs[Flatten[{N[rR]}]]]], "\[Checkmark]", "MISMATCH"]}];

SeedRandom[1];
results = {
  With[{a = RandomReal[1, {1000, 10}], b = RandomReal[1, {10, 1000}], c = RandomReal[1, {1000, 10}]},
    bench["matrix chain (order matters)", "ij,jk,kl->il", {a, b, c}, a . b . c]],
  With[{a = RandomReal[1, {300, 300}], b = RandomReal[1, {300, 300}]},
    bench["plain matrix product", "ij,jk->ik", {a, b}, a . b]],
  With[{a = RandomReal[1, {20000, 4, 4}], b = RandomReal[1, {20000, 4, 4}]},
    bench["batched 4x4 matmul (b = 2\[CenterDot]10^4)", "bij,bjk->bik", {a, b}, MapThread[Dot, {a, b}]]],
  With[{a = RandomReal[1, {200, 64, 64}], b = RandomReal[1, {200, 64, 64}]},
    bench["batched 64x64 matmul (b = 200)", "bij,bjk->bik", {a, b}, MapThread[Dot, {a, b}]]],
  With[{a = RandomReal[1, {100, 100, 100}], b = RandomReal[1, {100, 100, 100}], c = RandomReal[1, {100, 100, 100}]},
    bench["hyperedge: triple Hadamard sum", "ijk,ijk,ijk->", {a, b, c}, Total[a b c, 3]]],
  With[{a = RandomReal[1, {60, 16}], b = RandomReal[1, {60, 16}], c = RandomReal[1, {60, 16}]},
    bench["hyperedge: CP reconstruction", "ai,bi,ci->abc", {a, b, c},
      Total[Table[Outer[Times, a[[All, r]], b[[All, r]], c[[All, r]]], {r, 16}]]]],
  With[{t = RandomReal[1, {40, 40, 40}], m = RandomReal[1, {40, 40}]},
    bench["contract two indices", "ijk,kj->i", {t, m}, TensorContract[TensorProduct[t, m], {{2, 5}, {3, 4}}]]],
  With[{m = RandomReal[1, {2000, 2000}]},
    bench["diagonal", "ii->i", {m}, Diagonal[m]]],
  With[{x = RandomReal[1, {5000, 64}], w = RandomReal[1, {64, 64}]},
    bench["batched quadratic form", "bi,ij,bj->b", {x, w, x}, Total[(x . w) x, {2}]]]
};

Print[Grid[Prepend[results, Style[#, Bold] & /@ {"case", "spec", "Einsum", "EinsumFunction", "reference", "speed-up", "ok"}],
  Frame -> All, Alignment -> Left, Background -> {None, {LightGray}}]];

(* MPS norm with 8 tensors: only feasible with a good contraction order *)
Module[{d = 2, chi = 64, A1, A2, A3, A4, spec, t},
  A1 = RandomReal[1, {d, chi}]; A2 = RandomReal[1, {chi, d, chi}]; A3 = RandomReal[1, {chi, d, chi}]; A4 = RandomReal[1, {chi, d}];
  spec = "pa,aqb,brc,cs,pA,AqB,BrC,Cs->";
  t = time[Einsum[spec, A1, A2, A3, A4, A1, A2, A3, A4]];
  Print["MPS norm (4 sites, chi = 64): ", fmt[t], "   ", EinsumPath[spec, A1, A2, A3, A4, A1, A2, A3, A4][[{"Flops", "NaiveFlops", "Speedup"}]]];
];
