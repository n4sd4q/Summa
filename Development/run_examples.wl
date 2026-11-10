(* Runs the examples of a document and writes, for each, its code and its output.
     SRC=<examples.wl> OUT=<outdir> wolfram -script Development/run_examples.wl
   The examples file is a sequence of blocks, each starting with a line  (* ::Example:: name *), or  (* ::Example:: name text *)
   for an output shown as text, or  (* ::Example:: name tex *)  for an output shown as a formula; the blocks are evaluated in
   order in one session, in the context Global`. For each block: outdir/name.wl (the code, verbatim) and its output, which
   is one of
     outdir/name.pdf   a picture: Graphics (EinsumDiagram, EinsumTree), a list of Graphics (the frames of "Steps" -> True, three
                       in a row), or the summary box of an EinsumFunction, as a notebook shows it;
     outdir/name.txt   text: strings, associations, rules, True/False, $Failed, and every output of a block that gave messages
                       (the messages first, as a notebook prints them, then the result);
     outdir/name.tex   a formula (TeXForm): numbers, symbolic expressions, flat lists of them, MatrixForm.
   A block whose result is Null has no output file. The outputs are deterministic, so that running the examples again gives
   the same files: real numbers are shown with six significant digits, as a notebook shows them, and the dates written into
   the PDF files are fixed. The names of this script live in the context DocsRunner`, so that the examples can use any
   symbol. *)

Begin["DocsRunner`"];
{src, out} = {Environment["SRC"], Environment["OUT"]};
root = ParentDirectory[DirectoryName[$InputFileName]];
PacletDirectoryLoad[FileNameJoin[{root, "Summa"}]];
Needs["Summa`"];   (* the context before the code is parsed *)
SetOptions[$Output, PageWidth -> Infinity];   (* messages on one line each; the box of the output breaks them *)

(* real numbers with six significant digits, as a notebook shows them: 2640., 5.45455, 1.13855*^8. In text the numbers
   are rounded (InputForm then writes the shortest digits), so that the lines are broken where they are as wide as shown *)
round6[x_Real] := If[x == 0, 0., N[Round[x, 10^(Floor[Log10[Abs[x]]] - 5)]]];
shortReal[x_Real] := ToString[NumberForm[x, 6, NumberFormat -> (If[#3 === "", #1, #1 <> "*^" <> #3] &)]];
(* the numbers are made at once (/; True), since the values of an association are not evaluated again after a replacement *)
shortNumbers[e_] := e /. {x_Real :> With[{r = round6[x]}, r /; True],
    z_Complex /; Head[Re[z]] === Real :> With[{r = Complex[round6[Re[z]], round6[Im[z]]]}, r /; True]};
toText[s_String] := s;
(* a table as a notebook shows it, in columns, without the empty lines between its rows *)
toText[t_TableForm] := StringRiffle[DeleteCases[StringSplit[ToString[t /. x_Real :> With[{s = shortReal[x]}, s /; True], OutputForm,
      PageWidth -> Infinity, CharacterEncoding -> "Unicode"], "\n"], _?(StringTrim[#] === "" &)], "\n"];
toText[e_] := ToString[shortNumbers[e], InputForm, PageWidth -> 80, CharacterEncoding -> "Unicode"];

(* LaTeX: TeXForm, with the entries of the arrays a[i, j] of the examples written a_{ij} *)
docPost[t_String] := StringReplace[t, {
    RegularExpression["(?<![A-Za-z\\\\])([a-zA-Z])\\(([0-9]),([0-9])\\)"] :> "$1_{$2$3}",
    RegularExpression["(?<![A-Za-z\\\\])([a-zA-Z])\\(([0-9])\\)"] :> "$1_{$2}"}];
toTeX[e_] := docPost[ToString[TeXForm[e]]];

(* pictures: the PDF of the front end, with its creation and modification dates fixed; a date keeps its length, so that the
   offsets of the cross-reference table stay right *)
fixedDate[d_String] := With[{p = If[StringStartsQ[d, "D:"], "D:", ""]}, p <> StringPadRight["20261101000000Z", StringLength[d] - StringLength[p], "0"]];
fixDates[file_String] := Module[{s = FromCharacterCode[Normal[ReadByteArray[file]]]},
  s = StringReplace[s, "/" ~~ k : ("CreationDate" | "ModDate") ~~ " (" ~~ d : Except[")"] .. ~~ ")" :> "/" <> k <> " (" <> fixedDate[d] <> ")"];
  BinaryWrite[file, ToCharacterCode[s]]; Close[file]];
exportPicture[file_String, g_] := (Export[file, g, "PDF"]; fixDates[file]);
picture[g_Graphics | g_Graphics3D] := g;
picture[gs : {__Graphics}] := Grid[Partition[gs, UpTo[3]], Spacings -> {1.5, 1}];
picture[ef_EinsumFunction] := ef;
pictureQ[e_] := MatchQ[e, _Graphics | _Graphics3D | {__Graphics} | EinsumFunction[_Association]];
(* text, unless the result is a number, an expression, a flat list of them, or MatrixForm: TeXForm would draw a list of
   lists as a matrix, and a list of matrices as one block matrix *)
textQ[e_] := MatchQ[e, _String | _Association | True | False | $Failed | _Rule | _RuleDelayed | _Symbol | _TableForm] ||
   (ListQ[e] && ! FreeQ[e, _String | _Association | _Rule | True | False | $Failed, {1, Infinity}]) ||
   (ListQ[e] && ! FreeQ[e, _List, {1, Infinity}]);

(* code shown with the characters it stands for: \[Alpha] as the letter (Development/style.tex typesets them) *)
shown[code_] := StringReplace[code, RegularExpression["\\\\\\[([A-Za-z]+)\\]"] :> ToExpression["\"\\[$1]\""]];

text = Import[src, "Text"];
blocks = StringCases[text, RegularExpression["\\(\\* ::Example:: (\\w+)( text| tex)? \\*\\)\\n([\\s\\S]*?)(?=\\(\\* ::Example::|\\z)"] :>
    {"$1", StringTrim["$2"], StringTrim["$3"]}];
If[! DuplicateFreeQ[blocks[[All, 1]]],
  Print["duplicate example names: ", Select[Tally[blocks[[All, 1]]], #[[2]] > 1 &][[All, 1]]]; Exit[1]];
If[! DirectoryQ[out], CreateDirectory[out]];
End[];

Do[
  With[{name = DocsRunner`blk[[1]], asText = DocsRunner`blk[[2]] === "text", asTeX = DocsRunner`blk[[2]] === "tex",
    code = DocsRunner`blk[[3]], out = DocsRunner`out},
   (* the output of an earlier run, which may have been of another kind *)
   Scan[If[FileExistsQ[#], DeleteFile[#]] &, FileNameJoin[{out, name <> #}] & /@ {".tex", ".txt", ".pdf"}];
   Export[FileNameJoin[{out, name <> ".wl"}], DocsRunner`shown[code], "Text", CharacterEncoding -> "UTF8"];
   DocsRunner`ed = EvaluationData[ToExpression[code]];
   DocsRunner`res = DocsRunner`ed["Result"];
   DocsRunner`msgs = StringReplace[#, RegularExpression["^(\\S+::\\S+) : "] -> "$1: "] & /@ DocsRunner`ed["MessagesText"];
   Which[
    DocsRunner`msgs =!= {},
     Export[FileNameJoin[{out, name <> ".txt"}], StringRiffle[Join[DocsRunner`msgs,
        If[DocsRunner`res === Null, {}, {DocsRunner`toText[DocsRunner`res]}]], "\n"], "Text", CharacterEncoding -> "UTF8"],
    DocsRunner`res === Null, Null,
    asText, Export[FileNameJoin[{out, name <> ".txt"}], DocsRunner`toText[DocsRunner`res], "Text", CharacterEncoding -> "UTF8"],
    asTeX, Export[FileNameJoin[{out, name <> ".tex"}], DocsRunner`toTeX[DocsRunner`res], "Text", CharacterEncoding -> "UTF8"],
    DocsRunner`pictureQ[DocsRunner`res], DocsRunner`exportPicture[FileNameJoin[{out, name <> ".pdf"}], DocsRunner`picture[DocsRunner`res]],
    DocsRunner`textQ[DocsRunner`res], Export[FileNameJoin[{out, name <> ".txt"}], DocsRunner`toText[DocsRunner`res], "Text", CharacterEncoding -> "UTF8"],
    True, Export[FileNameJoin[{out, name <> ".tex"}], DocsRunner`toTeX[DocsRunner`res], "Text", CharacterEncoding -> "UTF8"]];
   Print[name, ": ", If[DocsRunner`pictureQ[DocsRunner`res], "(picture)",
     StringTake[StringReplace[DocsRunner`toText[DocsRunner`res], "\n" -> " "], UpTo[90]]]]],
  {DocsRunner`blk, DocsRunner`blocks}];
