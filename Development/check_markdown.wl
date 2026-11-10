(* Checks the code of a Markdown page (README.md, wiki/NAME.md): its ```mathematica blocks run in order, in one fresh kernel
   with the paclet of this repository, and each must give what the page shows after it, before the next block: a display
   formula $$...$$ is compared with TeXForm of the result (written as GitHub needs it: \\{ for \{), a ```math block (formulas
   on several lines, matrices: GitHub leaves its backslashes alone) with TeXForm as it is, a ```text block with the result as a
   terminal prints it (ToString); a block followed by none of them shows no output (a picture, a definition). A block after
   the line <!-- not run --> is skipped (installation lines, paths). A block that prints a message fails.
     wolfram -script Development/check_markdown.wl README.md "A first example"   the blocks of one section (## title)
     wolfram -script Development/check_markdown.wl wiki/NAME.md                    the whole page
     ... --fill   writes the outputs where the page has "?" in place of the formula or of the text, then checks *)
root = ParentDirectory[DirectoryName[$InputFileName]];
PacletDirectoryLoad[FileNameJoin[{root, "Summa"}]]; Needs["Summa`"];
args = If[Length[$ScriptCommandLine] > 1, Rest[$ScriptCommandLine], $CommandLine];   (* wolfram -script fills only $CommandLine *)
fill = MemberQ[args, "--fill"];
file = First[Select[args, StringEndsQ[#, ".md"] &]];
title = SelectFirst[args, ! StringEndsQ[#, ".md"] && ! StringStartsQ[#, "-"] && FileNameTake[#] =!= "check_markdown.wl" &&
     ! StringContainsQ[#, "/"] && ! StringContainsQ[ToLowerCase[#], "wolfram"] && # =!= "-script" &, None];
page = Import[file, "Text", CharacterEncoding -> "UTF8"];
text = If[StringQ[title], First[StringCases[page, "\n## " <> title <> "\n" ~~ x : Shortest[___] ~~ ("\n## " | EndOfString) :> x], ""], page];
tex[e_] := ToString[TeXForm[e]];
toGitHub[t_String] := StringReplace[t, {"\\{" -> "\\\\{", "\\}" -> "\\\\}", "\\," -> "\\thinspace "}];
fromGitHub[t_String] := StringReplace[t, {"\\\\{" -> "\\{", "\\\\}" -> "\\}", "\\thinspace " -> "\\,"}];
pieces = StringSplit[text, "```mathematica\n" -> "\[Bullet]BLOCK\[Bullet]"];
blocks = {};
Do[If[pieces[[k]] === "\[Bullet]BLOCK\[Bullet]",
   With[{body = pieces[[k + 1]], before = If[k > 1, pieces[[k - 1]], ""]},
    With[{code = First[StringSplit[body, "```", 2]], after = Last[StringSplit[body, "```", 2]]},
     AppendTo[blocks, <|"Code" -> code, "Skip" -> StringEndsQ[StringTrim[before], "<!-- not run -->"],
       "Formula" -> First[StringCases[after, StartOfString ~~ Whitespace ~~ "$$" ~~ f : Shortest[__] ~~ "$$" :> f], None],
       "Math" -> First[StringCases[after, StartOfString ~~ Whitespace ~~ "```math\n" ~~ t : Shortest[___] ~~ "```" :> t], None],
       "Text" -> First[StringCases[after, StartOfString ~~ Whitespace ~~ "```text\n" ~~ t : Shortest[___] ~~ "```" :> t], None]|>]]]],
  {k, Length[pieces]}];
fail = 0; filled = page;
put[code_, kind_, got_] := (filled = StringReplace[filled, code <> "```\n\n" <> kind <> "?" <> If[kind === "$$", "$$", "\n```"] ->
     code <> "```\n\n" <> kind <> got <> If[kind === "$$", "$$", "\n```"], 1]);
Do[With[{b = blocks[[n]]},
   If[b["Skip"], Continue[]];
   Module[{res = Check[ToExpression[b["Code"]], $Failed], got},
    Which[
     res === $Failed, fail++; Print["FAIL ", FileNameTake[file], " block ", n, ": messages"],
     StringQ[b["Formula"]], got = tex[res];
      Which[fill && StringTrim[b["Formula"]] === "?", put[b["Code"], "$$", toGitHub[got]],
       StringDelete[got, Whitespace] =!= StringDelete[fromGitHub[b["Formula"]], Whitespace],
        fail++; Print["FAIL ", FileNameTake[file], " block ", n, "\n  page:  ", fromGitHub[b["Formula"]], "\n  gives: ", got]],
     StringQ[b["Math"]], got = tex[res];
      Which[fill && StringTrim[b["Math"]] === "?", put[b["Code"], "```math\n", got],
       StringDelete[got, Whitespace] =!= StringDelete[b["Math"], Whitespace],
        fail++; Print["FAIL ", FileNameTake[file], " block ", n, "\n  page:  ", b["Math"], "\n  gives: ", got]],
     StringQ[b["Text"]], got = StringTrim[ToString[res]];
      Which[fill && StringTrim[b["Text"]] === "?", put[b["Code"], "```text\n", got],
       got =!= StringTrim[b["Text"]], fail++; Print["FAIL ", FileNameTake[file], " block ", n, "\n  page:  ", StringTrim[b["Text"]], "\n  gives: ", got]],
     True, Null]]],
  {n, Length[blocks]}];
If[fill && filled =!= page, Export[file, filled, "Text", CharacterEncoding -> "UTF8"]; Print["filled ", FileNameTake[file]]];
Print[If[fail == 0, "ok   ", "FAIL "], FileNameTake[file], If[StringQ[title], " (" <> title <> ")", ""], ": ",
  Count[blocks, b_ /; ! b["Skip"]], " blocks", If[fail == 0, "", ", " <> ToString[fail] <> " differ"]];
Exit[If[fail == 0, 0, 1]];
