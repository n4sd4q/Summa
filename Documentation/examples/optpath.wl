SeedRandom[2]; {ma, mb, mc} = RandomInteger[{-9, 9}, {3, 4, 4}];
Table[Einsum["ij,jk,kl->il", ma, mb, mc, "Path" -> p] == ma . mb . mc,
 {p, {Automatic, "Optimal", "Greedy", "Sequential", {{2, 3}, {1, 2}}}}]