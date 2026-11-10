mps[L_] := Module[{ket = Table[{α[k - 1], σ[k], α[k]}, {k, L}]},
  ket[[1]] = Rest[ket[[1]]]; ket[[L]] = Most[ket[[L]]];
  Join[ket, ket /. α -> β] -> {}];
mpsShapes[L_, d_, χ_] := Join[#, #] &[Table[Which[k == 1, {d, χ}, k == L, {χ, d},
     True, {χ, d, χ}], {k, L}]];
mps[3]