step[x_] := #/Norm[#] &[transfer[x, tensorA, tensorA]];
fixedPoint = Nest[step, IdentityMatrix[8], 300];
transferMatrix = ArrayReshape[Einsum["asc,bsd->abcd", tensorA, tensorA], {64, 64}];
{Norm[transfer[fixedPoint, tensorA, tensorA]],
 Max[Abs[Eigenvalues[transferMatrix]]]}