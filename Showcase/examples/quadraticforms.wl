rows = {{1, 0}, {0, 1}, {1, 1}}; q = {{2, 1}, {1, 3}};
Einsum["bi,ij,bj->b", rows, q, rows]