spec5 = "ab,ge,gac,dbf,abe->";
dims5 = {{50, 20}, {20, 50}, {20, 50, 5}, {10, 20, 20}, {50, 20, 50}};
AssociationMap[EinsumPath[spec5, dims5, "Path" -> #]["Flops"] &,
 {"Optimal", "Greedy", "Sequential", {{1, 5}, {1, 2}, {1, 2}, {1, 2}}}]