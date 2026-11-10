SeedRandom[3];
xs = RandomInteger[{-9, 9}, {50, 3, 4}]; ys = RandomInteger[{-9, 9}, {50, 4, 2}];
Table[Einsum["bij,bjk->bik", xs, ys, "BatchMethod" -> b] ==
  MapThread[Dot, {xs, ys}], {b, {Automatic, "Dot", "Vectorized"}}]