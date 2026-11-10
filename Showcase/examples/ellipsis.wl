SeedRandom[1];
stackA = RandomInteger[9, {5, 2, 3}]; stackB = RandomInteger[9, {3, 4}];
Dimensions[Einsum["...ij,...jk->...ik", stackA, stackB]]