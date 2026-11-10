# Summa — notes for Claude Code

A Wolfram Language package for Einstein summation with the syntax of numpy.einsum (see `README.md`). Author: Nazzareno
Africani (SISSA). Code, comments and documents in English. Personal notes of a developer (resume point, local workflow) go in
`Internal/` and `CLAUDE.local.md`, which are not versioned.

## Layout
- `Summa/` — the paclet: `PacletInfo.wl`, `Kernel/Summa.wl` (context ``Summa` ``; the banner and the update check at its end,
  as FunctionalDiagrams and FermiWick; `SECURITY.md` describes the only access to the network), `Examples.nb` (an asset).
- `Tests/SummaTests.wlt`, `Tests/RunTests.wls` — `wolfram -script Tests/RunTests.wls`; every test must pass. The expected
  values of the data-driven tests were computed with `numpy.einsum`; `Tests/LatestRelease.json` is an answer of GitHub (a
  release 0.9.0 made up in its form) for the tests of the update check, which need no network.
- `Examples.wl` — the guided tour; `Summa/Examples.nb` is generated from it by `wolfram -script Development/make_notebook.wl`
  (saved with Visible -> True). Edit the `.wl`, never the `.nb`. `Examples/Benchmarks.wl` times Einsum on your machine.
- `Showcase/` and `Documentation/` — LaTeX sources of the showcase and of the manual; their examples (`examples.wl`) are run
  by `Development/run_examples.wl` (code, output as formula, text or picture); `build_pdf.sh`, `build_manual.sh` typeset.
  Common style: `Development/style.tex` on `n4sd4q.sty` and `n4sd4q-palette.tex` (the Sunset colours).
- `README.md` — its first example is checked by `wolfram -script Development/check_markdown.wl README.md "A first example"`;
  its pictures are drawn by `Development/make_readme_pictures.wl` (`Documentation/readme_*.png`).
- `Media/` — the demo video `demo.mp4` (1920×1080, 60 fps, H.264, about 50 s), its looping preview `demo_preview.webp`
  (960×540, at the top of the README, linking the video) and its poster `demo_poster.png` (the title card, which is also the
  end card, so that the video loops without a seam), made by `python3 Development/make_demo_video.py` (about ten minutes,
  most of it the WebP; `--frames` writes frames to `build/video/frames`, `--poster` only the poster). Its cards are one
  notebook session: cells of the README and computed examples of the showcase (`Showcase/examples`), code and outputs,
  never typed by hand. Run it again when those change, and look at the frames.
- `wiki/` — the GitHub wiki, mirrored by `.github/workflows/wiki.yml` on every push to main that touches it (edit the pages
  here, never on GitHub); every page is checked by `Development/check_markdown.wl wiki/Page.md` (`--fill` writes the
  outputs where a page has `?`). Wiki and README math: no `\,` (`\thinspace`), no `<` or `>` (`\lt`, `\gt`), no `)_`,
  `]_`, `}_` or `+_` (GitHub reads them as emphasis), braces as `\\{ \\}`; formulas on several lines in ```` ```math ````.
- `index.html` — the website (GitHub Pages serves main: https://n4sd4q.github.io/Summa/), **generated** by
  `python3 Development/make_site.py` from the README, `Summa/PacletInfo.wl`, `CITATION.cff` and the PDFs; never edit it.
  `.nojekyll` lets Pages serve the files as they are.
- The common look of the packages: `Development/n4sd4q.sty`, `n4sd4q-palette.tex`, `family.css`, `palette.json` and `Logo/`
  are copies of the files of the hub (github.com/n4sd4q/n4sd4q.github.io): change them there, then copy.
- `Development/check_docs.sh` — runs every documented command again in fresh kernels (showcase, manual, tour, README, wiki)
  and checks the site; it must pass before a commit that touches the kernel or the documents.

## Rules
- Commit after each step, with a clear message. Speed matters: results must not change.
- Every command shown in the documents gives exactly the output shown after it (computed by the scripts, never typed).
- After a change: tests, then rebuild the showcase and the manual and look at the pages, then README, CHANGELOG, site.
- The README links the PDFs on GitHub Pages, so that they open in the browser; pictures need a white background.

## Releases
- Semantic versioning. The version is the same in `Summa/PacletInfo.wl`, `$SummaVersion`, `CITATION.cff` (with
  `date-released`), the install lines (README, manual, wiki `Installation.md`), the title lines of the showcase and the
  manual, `wiki/_Footer.md` and `CHANGELOG.md`.
- The paclet: from a clean checkout, a copy of `Summa/` with `LICENSE` and `NOTICE` added, then `CreatePacletArchive` of
  that copy (the license travels with the package); test it unzipped with `PacletDirectoryLoad`,
  never with `PacletInstall` on the author's machine. Then the tag vX.Y.Z and the GitHub release with the paclet and the two
  PDFs; `python3 Development/make_site.py` after every change of the README or the version.
