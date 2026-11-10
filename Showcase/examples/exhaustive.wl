allPaths[1] = {{}};
allPaths[k_] := Join @@ Table[Prepend[#, p] & /@ allPaths[k - 1],
   {p, Subsets[Range[k], {2}]}];
costs = EinsumPath[spec5, dims5, "Path" -> #]["Flops"] & /@ allPaths[5];
{Length[costs], Min[costs], EinsumPath[spec5, dims5]["Flops"]}