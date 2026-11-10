frames = EinsumDiagram["ij,jk,kl->il", {{2, 30}, {30, 40}, {40, 3}},
   "Steps" -> True];
{Length[frames], Head /@ frames}