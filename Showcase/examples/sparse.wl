ring = SparseArray[{Band[{1, 2}] -> 1., Band[{2, 1}] -> 1., {1, 1000} -> 1.,
    {1000, 1} -> 1.}, {1000, 1000}];
ring2 = Einsum["ij,jk->ik", ring, ring];
{Head[ring2], Length[ring2["NonzeroValues"]]}