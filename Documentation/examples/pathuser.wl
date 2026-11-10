userPath = EinsumPath["ij,jk,kl->il", {{2, 30}, {30, 40}, {40, 3}},
   "Path" -> {{2, 3}, {1, 2}}];
userPath[[{"Path", "Method", "Contractions", "StepFlops", "Flops"}]]