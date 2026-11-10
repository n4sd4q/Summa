With[{ϵ = LeviCivitaTensor[3], δ = IdentityMatrix[3]},
 Einsum["ijk,imn->jkmn", ϵ, ϵ] ==
  Einsum["jm,kn->jkmn", δ, δ] - Einsum["jn,km->jkmn", δ, δ]]