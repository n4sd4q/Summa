SeedRandom[1];
s1 = RandomInteger[9, {6, 5, 2, 3}]; s2 = RandomInteger[9, {5, 3, 4}];
{Dimensions[Einsum["...ij,...jk", s1, s2]],
 Dimensions[Einsum["i...,i...->...", m, n]]}