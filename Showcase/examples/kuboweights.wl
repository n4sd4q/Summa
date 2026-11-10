f = UnitStep[-energies]; e = energies;
weights = Table[With[{de = e[[k, m]] - e[[k, n]]},
    If[n == m, 0. ωs, (f[[k, n]] - f[[k, m]])/de/(ωs - de + I η)]],
   {k, nk}, {n, 2}, {m, 2}];
Dimensions[weights]