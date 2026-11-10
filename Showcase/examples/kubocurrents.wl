bandCurrents = Einsum["kni,kij,kmj->knm", Conjugate[states], current /@ ks, states];
Dimensions[bandCurrents]