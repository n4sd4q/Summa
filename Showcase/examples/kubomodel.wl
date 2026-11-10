nk = 400; ks = 2. Pi Range[0, nk - 1]/nk; ωs = Range[0., 4., 0.01]; η = 0.05;
h[k_] := (1 + 0.6 Cos[k]) PauliMatrix[1] + 0.6 Sin[k] PauliMatrix[2] +
   0.4 PauliMatrix[3];
current[k_] := -0.6 Sin[k] PauliMatrix[1] + 0.6 Cos[k] PauliMatrix[2];
bands[k_] := Transpose[SortBy[Transpose[Eigensystem[h[k]]], First]];
{energies, states} = Transpose[bands /@ ks];
Dimensions /@ {energies, states}