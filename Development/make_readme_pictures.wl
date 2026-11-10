(* Draws the pictures of the first example of README.md, Documentation/readme_NAME.png: the drawings of Summa (EinsumDiagram,
   EinsumTree) of the einsums of the example, on a white page (legible on light and dark pages), at twice the resolution of the
   screen. Run it again when the example changes:   wolfram -script Development/make_readme_pictures.wl *)
root = ParentDirectory[DirectoryName[$InputFileName]];
PacletDirectoryLoad[FileNameJoin[{root, "Summa"}]]; Needs["Summa`"];
mps = "pa,aqb,brc,cs,pA,AqB,BrC,Cs->";
dims = {{2, 32}, {32, 2, 32}, {32, 2, 32}, {32, 2}, {2, 32}, {32, 2, 32}, {32, 2, 32}, {32, 2}};
pictures = {"hyperedge" -> EinsumDiagram["ai,bi,ci->abc"], "mps" -> EinsumDiagram[mps], "tree" -> EinsumTree[mps, dims]};
Do[With[{file = FileNameJoin[{root, "Documentation", "readme_" <> First[p] <> ".png"}]},
   Export[file, Last[p], Background -> White, ImageResolution -> 192]; Print[FileNameTake[file, -2]]], {p, pictures}];
