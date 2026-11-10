(* Paclet description: PacletDirectoryLoad["/path/to/Summa"]; Needs["Summa`"] *)
Paclet[
  Name -> "Summa",
  Version -> "1.0.0",
  MathematicaVersion -> "11.3+",
  Description -> "Fast Einstein summation (einsum) with optimal contraction paths, hyperedges (indices shared by any number of tensors), batched BLAS kernels, plan caching and tensor-network diagrams.",
  Creator -> "Nazzareno Africani (with Claude)",
  License -> "GPL-3.0-or-later",
  Extensions -> {
    {"Kernel", Root -> "Kernel", Context -> "Summa`"}
  }
]
