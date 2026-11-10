(* Draws the pictures of the wiki, wiki/images/NAME.png. A picture is the result of the block of code just before the line
   <p align="center"><img src="images/NAME.png" ...> (or ![...](images/NAME.png)) of a page: the blocks of the page run in order, as Development/check_markdown.wl runs them (the
   blocks after <!-- not run --> are skipped), each page in a context of its own, and the result is exported on a white
   page (legible on light and dark pages), at twice the resolution of the screen. Run it again when the code of a picture
   changes:
     wolfram -script Development/make_wiki_pictures.wl                every page with pictures
     wolfram -script Development/make_wiki_pictures.wl Diagrams.md    the pages named *)
root = ParentDirectory[DirectoryName[$InputFileName]];
PacletDirectoryLoad[FileNameJoin[{root, "Summa"}]]; Needs["Summa`"];
args = If[Length[$ScriptCommandLine] > 1, Rest[$ScriptCommandLine], $CommandLine];   (* wolfram -script fills only $CommandLine *)
wiki = FileNameJoin[{root, "wiki"}];
named = FileNameTake /@ Select[args, StringEndsQ[#, ".md"] &];
pages = If[named === {}, FileNames["*.md", wiki], FileNameJoin[{wiki, #}] & /@ named];
images = FileNameJoin[{wiki, "images"}];
If[! DirectoryQ[images], CreateDirectory[images]];
Do[
  Module[{text = Import[page, "Text", CharacterEncoding -> "UTF8"], pieces},
   If[! StringContainsQ[text, "images/"], Continue[]];
   pieces = StringSplit[text, "```mathematica\n", All];
   Block[{$Context = "WikiPage" <> ToString[Hash[page]] <> "`", $ContextPath = {"Summa`", "System`"}},
    Do[
     With[{code = First[StringSplit[pieces[[j]], "```", 2]], after = Last[StringSplit[pieces[[j]], "```", 2]]},
      If[! StringEndsQ[StringTrim[pieces[[j - 1]]], "<!-- not run -->"],
       With[{result = ToExpression[code],
         name = First[StringCases[after, StartOfString ~~ Whitespace ~~ ("![" | "<p align=\"center\"><img ") ~~ Shortest[___] ~~
              ("](images/" | "src=\"images/") ~~ n : Shortest[__] ~~ ".png" :> n], None]},
        If[StringQ[name],
         Export[FileNameJoin[{images, name <> ".png"}], result, Background -> White, ImageResolution -> 192];
         Print[FileNameTake[page], ": images/", name, ".png"]]]]],
     {j, 2, Length[pieces]}]]],
  {page, pages}];
