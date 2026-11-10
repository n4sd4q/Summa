pauli = PauliMatrix /@ {1, 2, 3};
MatrixForm[Einsum["aij,ajk->ik", pauli, pauli]]