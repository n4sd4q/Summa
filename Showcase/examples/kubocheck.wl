writtenOut = I/nk Sum[
    bandCurrents[[k, n, m]] bandCurrents[[k, m, n]] weights[[k, n, m]],
    {k, nk}, {n, 2}, {m, 2}];
Max[Abs[conductivity - writtenOut]] < 10^-12