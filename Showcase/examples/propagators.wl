propagators[z_] := Inverse[z IdentityMatrix[2] - h[#]] & /@ ks;
{z1, z2, z3} = {0.3 + 0.1 I, -0.2 + 0.2 I, 1. + 0.1 I};
loop = Einsum["kab,kbc,kca->k", propagators[z1], propagators[z2], propagators[z3]];
Max[Abs[loop - Total[1/((z1 - e) (z2 - e) (z3 - e)), {2}]]] < 10^-12