conductivity = I/nk Einsum["knm,kmn,knmw->w", bandCurrents, bandCurrents, weights];
ListLinePlot[Transpose[{ωs, Re[conductivity]}], Frame -> True,
 FrameLabel -> {"ω", "Re σ(ω)"}, PlotStyle -> RGBColor["#8E3032"],
 PlotRange -> All, ImageSize -> 360]