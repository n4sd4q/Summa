# Changelog

The versions are MAJOR.MINOR.PATCH (semantic versioning): a major version may change the results of code written for the
previous one, a minor version only adds, a patch fixes. Changes to the documents alone need no release.

## 1.0.0 (2026-11-10)

The first public release.

- `Einsum` with the syntax of `numpy.einsum` (implicit output, ellipsis and broadcasting, Unicode labels, the arrow →) and a
  list syntax with labels of any kind; indices repeated any number of times, within a tensor (diagonals, traces) and
  across tensors (hyperedges, batch indices shared by three or more tensors).
- The order of the contractions: an exact search over subsets up to eight tensors (fourteen on request), greedy beyond;
  `EinsumPath` gives its flops, the naive flops, the speed-up and the largest intermediate.
- The kernels: BLAS `Dot`, batched contractions (a loop of `Dot` or broadcasting on packed arrays, by a cost model),
  broadcasting products, and a product with `Total` in place for two operands with the same indices; plans cached;
  `EinsumFunction` precompiles an einsum for fixed shapes.
- The drawings: `EinsumDiagram` (bonds, open legs, traces, summed indices, hyperedges, the order of the contractions, one
  frame per step) and `EinsumTree` (the contraction tree with the cost of every step).
- In a notebook, a banner (version, license, how to cite, links) and, at most once a day, a check for a newer release on
  GitHub (`$SummaUpdateCheck`, `SummaUpdateCheck[]`; `SECURITY.md`).
- The paclet in `Summa/`, installed with one line from the GitHub release; the documents: a website, a showcase and a
  manual (PDF, every output computed), a guided tour (`Summa/Examples.nb`), a wiki; 735 tests.
