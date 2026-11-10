Einsum["aij,bjk->abik", pauli, pauli] ==
 Einsum["ab,ik->abik", IdentityMatrix[3], IdentityMatrix[2]] +
  I Einsum["abc,cik->abik", LeviCivitaTensor[3], pauli]