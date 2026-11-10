SeedRandom[3]; {fa, fb, fc} = RandomReal[1, {3, 40, 8}];
cp = Einsum["ai,bi,ci->abc", fa, fb, fc];
reference = Sum[Outer[Times, fa[[All, i]], fb[[All, i]], fc[[All, i]]], {i, 8}];
{Dimensions[cp], Max[Abs[cp - reference]] < 10^-12}