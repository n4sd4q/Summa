(* Draws the pictures of the first example of README.md: its code blocks are run in order, in one kernel with the paclet of
   this repository, and the result of every block followed by a picture <img src="Documentation/readme_NAME.png" ...> is
   exported to that file, on a white page (legible on light and dark pages), at twice the resolution of the screen: the
   pictures are always those of the code shown. Run it again when the example changes:
     wolfram -script Development/make_readme_pictures.wl *)
root = ParentDirectory[DirectoryName[$InputFileName]];
PacletDirectoryLoad[FileNameJoin[{root, "Summa"}]]; Needs["Summa`"];
readme = Import[FileNameJoin[{root, "README.md"}], "Text", CharacterEncoding -> "UTF8"];
section = First[StringCases[readme, "\n## A first example\n" ~~ x : Shortest[___] ~~ "\n## " :> x]];
pieces = StringSplit[section, "```mathematica\n"];
blocks = ({First[StringSplit[#, "```", 2]], First[StringCases[Last[StringSplit[#, "```", 2]],
       StartOfString ~~ Whitespace ~~ "<p" ~~ Shortest[___] ~~ "src=\"" ~~ f : Shortest[___] ~~ "\"" :> f], None]} &) /@ Rest[pieces];
(* a pure function, so that the names of the README's code (a, b, ...) meet no variable of this script *)
Scan[Function[{block$}, With[{res$ = ToExpression[First[block$]], picture$ = Last[block$]},
    If[StringQ[picture$], Export[FileNameJoin[{root, picture$}], res$, Background -> White, ImageResolution -> 192]; Print[picture$]]]], blocks];
