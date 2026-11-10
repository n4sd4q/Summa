SeedRandom[2]; xs = RandomReal[1, {1000, 3, 4}]; ys = RandomReal[1, {1000, 4, 2}];
Einsum["bij,bjk->bik", xs, ys] == MapThread[Dot, {xs, ys}]