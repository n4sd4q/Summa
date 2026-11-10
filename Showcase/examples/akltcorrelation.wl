sz = DiagonalMatrix[{1, 0, -1}];
Table[Einsum[akltRing[10, {1, 1 + r}], Sequence @@ ConstantArray[aklt, 20], sz, sz]/
   Einsum[akltRing[10], Sequence @@ ConstantArray[aklt, 20]], {r, 4}]