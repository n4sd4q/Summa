(* Writes the guided tour as a notebook: Examples.wl (cells marked (* ::Title:: *), (* ::Section:: *), (* ::Text:: *), ...,
   and code) -> Summa/Examples.nb, an asset of the paclet:
     NotebookOpen[PacletObject["Summa"]["AssetLocation", "Examples"]]
   Edit Examples.wl, never the notebook. The notebook is saved visible (Visible -> True).
     math -script Development/make_notebook.wl *)

root = ParentDirectory[DirectoryName[$InputFileName]];
text = Import[FileNameJoin[{root, "Examples.wl"}], "Text", CharacterEncoding -> "UTF8"];
text = StringDelete[text, StartOfString ~~ "(* ::Package:: *)" ~~ Whitespace];
(*chunks separated by blank lines; a marked chunk is (* ::Style:: *) followed by (*content*)*)
chunks = Select[StringTrim /@ StringSplit[text, RegularExpression["\\n\\s*\\n"]], # =!= "" &];
cell[ch_String] :=
  With[{m = StringCases[ch, RegularExpression["^\\(\\* ::(\\w+):: \\*\\)\\s*\\(\\*([\\s\\S]*)\\*\\)$"] :> {"$1", "$2"}]},
   If[m =!= {}, Cell[StringTrim[m[[1, 2]]], m[[1, 1]]], Cell[ch, "Input"]]];
cells = cell /@ chunks;
nb = Notebook[cells, Visible -> True, WindowTitle -> "Summa \[Dash] guided tour", StyleDefinitions -> "Default.nb"];
file = FileNameJoin[{root, "Summa", "Examples.nb"}];
Put[nb, file];
(*check: the file reads back as a visible notebook*)
back = Get[file];
Print["Summa/Examples.nb: ", Length[cells], " cells, ", Count[cells, Cell[_, "Input"]], " input; visible: ",
  TrueQ[Visible /. Rest[List @@ back] /. Visible -> True]];
