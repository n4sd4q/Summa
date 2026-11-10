boltzmann = {{x, 1/x}, {1/x, x}};
zIsing = Expand[Einsum[lattice, Sequence @@ ConstantArray[boltzmann, 12]]]