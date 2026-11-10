kernel[s_] := s["Type"] <>
   If[KeyExistsQ[s, "Method"], " (" <> s["Method"] <> ")", ""];
kernels[spec_, dims_] := {spec, ToString[dims],
   StringRiffle[kernel /@ EinsumFunction[spec, dims]["Plan"]["Steps"], ", "]};
TableForm[kernels @@@ {{"ij,jk->ik", {{300, 300}, {300, 300}}},
    {"ijk,kj->i", {{40, 40, 40}, {40, 40}}},
    {"bij,bjk->bik", {{200, 64, 64}, {200, 64, 64}}},
    {"bij,bjk->bik", {{20000, 4, 4}, {20000, 4, 4}}},
    {"kh,kh->h", {{100, 100}, {100, 100}}}, {"ij,j->ij", {{100, 100}, {100}}},
    {"ijk,ijk,ijk->", {{10, 10, 10}, {10, 10, 10}, {10, 10, 10}}}},
 TableHeadings -> {None, {"spec", "dimensions", "kernels"}}]