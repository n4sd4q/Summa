SeedRandom[4]; tensorA = RandomReal[{-1, 1}, {8, 2, 8}];
transfer = EinsumFunction["ab,asc,bsd->cd", {{8, 8}, {8, 2, 8}, {8, 2, 8}}]