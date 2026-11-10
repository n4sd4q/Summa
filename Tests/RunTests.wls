#!/usr/bin/env wolframscript
(* Runs the test suite (math -script Tests/RunTests.wls): Tests/SummaTests.wlt; exits with status 0 if every test passes. *)
reports = TestReport[FileNameJoin[{DirectoryName[$InputFileName], #}]] & /@ {"SummaTests.wlt"};
Print[Total[#["TestsSucceededCount"] & /@ reports], " passed, ", Total[#["TestsFailedCount"] & /@ reports], " failed (",
  Round[Total[#["TimeElapsed"] & /@ reports], 0.1], ")"];
Scan[Print["FAILED: ", #["TestID"], "\n   expected ", #["ExpectedOutput"], "\n   got      ", #["ActualOutput"]] &,
  Flatten[Values /@ Values[#["TestsFailed"]] & /@ reports]];
Exit[If[AllTrue[reports, #["AllTestsSucceeded"] &], 0, 1]];
