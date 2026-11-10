TableForm[Table[{L, EinsumPath[mps[L], mpsShapes[L, 2, 16]]["Flops"],
    EinsumPath[mps[L], mpsShapes[L, 2, 16], "Path" -> "Sequential"]["Flops"]},
   {L, {4, 8, 12, 16, 20}}],
 TableHeadings -> {None, {"L", "Automatic", "Sequential"}}]