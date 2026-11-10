SeedRandom[5]; {ta, tb, tc} = RandomInteger[{-5, 5}, {3, 3, 4, 3}];
Einsum["iaj,jbk,kci->abc", ta, tb, tc] ==
 Table[Sum[ta[[i, a, j]] tb[[j, b, k]] tc[[k, c, i]], {i, 3}, {j, 3}, {k, 3}],
  {a, 4}, {b, 4}, {c, 4}]