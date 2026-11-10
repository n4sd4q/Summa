aklt = Transpose[{Sqrt[2/3] {{0, 1}, {0, 0}}, -Sqrt[1/3] {{1, 0}, {0, -1}},
    -Sqrt[2/3] {{0, 0}, {1, 0}}}, {2, 1, 3}];
akltRing[L_, ops_ : {}] := Join[
   Table[{α[k], σ[k], α[Mod[k, L] + 1]}, {k, L}],
   Table[{β[k], If[MemberQ[ops, k], τ[k], σ[k]], β[Mod[k, L] + 1]}, {k, L}],
   ({σ[#], τ[#]} &) /@ ops] -> {};
Table[Einsum[akltRing[L], Sequence @@ ConstantArray[aklt, 2 L]], {L, 2, 7}]