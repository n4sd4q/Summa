bonds = Characters /@ StringSplit[StringDrop[lattice, -2], ","];
weight[s_] := With[{c = AssociationThread[Characters["abcdefghi"], s]},
   Times @@ (x^(c[#1] c[#2]) & @@@ bonds)];
Expand[zIsing - Sum[weight[s], {s, Tuples[{1, -1}, 9]}]]