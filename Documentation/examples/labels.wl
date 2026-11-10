m = {{1, 2}, {3, 4}}; n = {{0, 1}, {1, 1}};
{Einsum["ij,jk->ik", m, n], Einsum[" i j , j k -> i k ", m, n],
 Einsum["αβ,βγ→αγ", m, n]}