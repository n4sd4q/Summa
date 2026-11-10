mpsSpec = "pa,aqb,brc,cs,pA,AqB,BrC,Cs->";
mpsDims = {{2, 64}, {64, 2, 64}, {64, 2, 64}, {64, 2},
   {2, 64}, {64, 2, 64}, {64, 2, 64}, {64, 2}};
EinsumPath[mpsSpec, mpsDims][[{"Contractions", "Flops", "NaiveFlops", "Speedup",
   "LargestIntermediate"}]]