chain = StringRiffle[Table[FromCharacterCode[{96 + k, 97 + k}], {k, 15}], ","] <>
   "->ap";
EinsumPath[chain, ConstantArray[{2, 2}, 15], "Path" -> "Optimal"]["Method"]