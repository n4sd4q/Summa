SeedRandom[4]; bx = RandomInteger[9, {4, 3, 2}]; by = RandomInteger[9, {4, 2, 5}];
ef[bx, by] == Table[bx[[b]] . by[[b]], {b, 4}]