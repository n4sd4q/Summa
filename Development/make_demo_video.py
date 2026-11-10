#!/usr/bin/env python3
"""The demo video of the package: Media/demo.mp4 (1920 x 1080, 60 fps, H.264; its first frame, the one a player shows
before it plays, is the title card in full view), its looping preview for the README,
Media/demo_preview.webp (960 x 540, 60 fps; its first frame, the one shown where animated images do not play, is a card
in full view), and its poster, Media/demo_poster.png (that title card: the website shows it until the video plays).

Nothing in it is written by hand: it is one notebook session, its cells typed one after the other on five cards (CARDS),
each card a capability with two to four examples, and every cell, with its output, is a code block of the section "A
first example" of README.md (with what the README shows after it, which Development/check_markdown.wl keeps equal to
what Summa gives) or a computed example of the showcase (Showcase/examples/NAME.wl, and NAME.tex, NAME.txt or NAME.pdf,
written by Development/run_examples.wl). Formulas (a ```math block, a $$...$$ line with GitHub's escapes undone, a .tex)
are typeset by pdflatex in mathpazo, a little larger than the code, as a notebook shows them; text (a ```text block, a
.txt) in the font of the code, as large; the summary box of an EinsumFunction (a .pdf) drawn as large; the pictures of
the README, Documentation/readme_*.png (drawn by Mathematica, Development/make_readme_pictures.wl, on white), their
white margins trimmed, at the widths the README gives them times one factor. Each card: a short caption (the capability,
then its examples), the cells typed as in a notebook (In[n]:= and Out[n]= numbered as the session numbers them, the cell
brackets on the right, Mathematica's colours, named characters as their letters), each followed by its output and a
short pause; a card taller than the frame scrolls as a notebook follows what is typed, and settles with no row cut. The
long block of the Kubo formula is pasted in up to its einsum, which is typed with the line after it. The LaTeX elements
go through pdflatex and pdftocairo (one PNG per element, transparent), the frames are put together with PIL (at 1920 x
1080; the preview is reduced from them) and encoded by ffmpeg. The logo of the first and the last card is drawn again in
every frame from the geometry of Logo/Summa_logo.svg (read from the file: the sigma of a sum drawn as a tensor network,
five nodes joined by four bonds, the one being summed in the tint): on the title card a soft swell runs once along the
sigma, from its first node to its last, the bonds and the nodes swelling a little as it passes; on the closing card the
logo draws itself: the nodes pop in one after the other along the sigma as a pen draws the white bonds, and the bond in
the tint comes last, joining two nodes already in place. Needs pdflatex (TeX Live: mathpazo, Source Code Pro),
pdftocairo (poppler), python3 with PIL, ffmpeg with libx264. Run from any folder:
    python3 Development/make_demo_video.py            (all three files, a few minutes: most of it the WebP)
    python3 Development/make_demo_video.py --frames   (also a few frames as PNG in build/video/frames, to look at;
                                                      with --only-frames, nothing else)
    python3 Development/make_demo_video.py --poster   (only the poster, a few seconds)
"""
import concurrent.futures
import functools
import math
import multiprocessing
import os
import re
import subprocess
import sys
import unicodedata
import xml.etree.ElementTree as ET

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "build", "video")
MEDIA = os.path.join(ROOT, "Media")
W, H, FPS = 1920, 1080, 60
# Every length in pixels below (fonts, margins, gaps, line widths, brackets) is written for a frame 1280 px wide and
# scaled by S, so that a frame of another size is the same picture, only sharper
S = W / 1280


def px(v):
    """A length in pixels of a frame 1280 px wide, in pixels of this frame."""
    return v * S


def ipx(v):
    """The same, in whole pixels."""
    return int(math.floor(v * S + 0.5))


# The preview: an animated WebP, which can run at 60 fps (a GIF cannot: its delays are in hundredths of a second, so
# 50 fps at most, and browsers slow down delays below 0.02 s), in full colour; GitHub shows it in the README as a plain
# <img>, and it plays wherever WebP does (every current browser, the GitHub apps)
PREVIEW_W, PREVIEW_H, PREVIEW_FPS, PREVIEW_QUALITY = 960, 540, 60, 90
# the LaTeX pages are drawn for a frame 16 cm wide: 120 px to the centimetre
DPI = W / (16 / 2.54)
PT = DPI / 72.27        # pixels to the TeX point
BORDER = 3.0            # the border of every LaTeX element (pt, the option of standalone)

# the colours of the package ("Sunset", Development/n4sd4q-palette.tex): the solid accent of the titles and the band;
# those of the logo (the gradient of its badge, white and the light tint) are read from Logo/Summa_logo.svg
ACCENT = (142, 48, 50)
MUTED = (89, 99, 110)
WHITE = (255, 255, 255)
# Mathematica's colours in an input cell: comments and strings grey, undefined symbols blue, the variables of a Sum
# green, the rest (the system's symbols, the package's, those already given a value) black
CODE_COLORS = {"comment": (140, 140, 140), "string": (110, 110, 110), "symbol": (36, 74, 170), "local": (52, 128, 84),
               "plain": (0, 0, 0)}
LABEL = (70, 96, 140)        # In[n]:= and Out[n]=
BRACKET = (150, 172, 200)    # the cell brackets on the right


# ---------------------------------------------------------------------------------------------------------------------
# the example of the README

def readme_section():
    text = open(os.path.join(ROOT, "README.md"), encoding="utf-8").read()
    parts = re.split(r"^## A first example\s*$", text, maxsplit=1, flags=re.M)
    if len(parts) < 2:
        sys.exit('README.md has no section "## A first example"')
    return re.split(r"^## ", parts[1], maxsplit=1, flags=re.M)[0]


def from_github(tex):
    """A formula of the README as LaTeX: the escapes it needs on GitHub (whose Markdown runs before MathJax) undone."""
    tex = tex.replace("\\\\{", "\\{").replace("\\\\}", "\\}").replace("^{\\ast}", "^*")
    tex = re.sub(r"\\thinspace(?![A-Za-z])", r"\\,", tex)
    tex = re.sub(r"\\lt(?![A-Za-z])", "<", tex)
    return re.sub(r"\\gt(?![A-Za-z])", ">", tex).strip()


README_STEP = re.compile(r"```mathematica\n(?P<code>.*?)```|```math\n(?P<math>.*?)```|```text\n(?P<text>.*?)```"
                         r"|^\$\$(?P<tex>[^\n]*?)\$\$[ \t]*$|<img src=\"(?P<src>[^\"]+)\"[^>]*?\bwidth=\"(?P<width>\d+)\"",
                         re.S | re.M)


def readme_blocks():
    """The code blocks of "A first example", each with what the README shows after it: [code, output], the output
    ("tex", LaTeX) for a formula (a ```math block, not escaped, or a $$...$$ line), ("text", text) for a ```text block,
    ("picture", path, width in the README) for a picture, None for none."""
    blocks = []
    for m in README_STEP.finditer(readme_section()):
        if m.group("code") is not None:
            blocks.append([m.group("code").strip("\n"), None])
        elif blocks and blocks[-1][1] is None:
            if m.group("math") is not None:
                blocks[-1][1] = ("tex", "\n".join(line for line in m.group("math").split("\n") if line.strip()))
            elif m.group("tex") is not None:
                blocks[-1][1] = ("tex", from_github(m.group("tex")))
            elif m.group("text") is not None:
                blocks[-1][1] = ("text", m.group("text").strip("\n"))
            else:
                blocks[-1][1] = ("picture", os.path.join(ROOT, m.group("src")), int(m.group("width")))
    return blocks


# the cards of the video, one after the other: a heading (the capability), a second line (its examples), and the cells
# of a notebook session typed one after the other, each with its output: ("readme", code) is the block of the README's
# first example with that code in it (with "paste": the lines before the one with that code are pasted in at once, the
# rest is typed); ("showcase", name) is the example name of the showcase, Showcase/examples/name.wl, with the output the
# showcase computed (name.tex, name.txt or name.pdf). The cells make one session, in this order: each uses only the
# values that the cells before it give, as in the README and in the showcase. A block of the README that no card shows is
# named when the script runs.
CARDS = [
    ("Indices as on paper", "products, a transpose, a trace, a diagonal, sums",
     [("readme", 'Needs["Summa`"]'), ("showcase", "first"), ("showcase", "vectors"), ("showcase", "onematrix")]),
    ("An index in any number of tensors", r"$\sum_i x_iy_iz_i$, a batch index $b$, the hyperedge of a CP decomposition",
     [("showcase", "threevectors"), ("showcase", "batchmatmul"), ("readme", 'EinsumDiagram["ai,bi,ci->abc"]')]),
    ("A Kubo formula, as it is written", r"$\sigma(\omega)$: $k$, $n$ and $m$ each in three tensors, one einsum",
     [("readme", 'Einsum["knm', "paste")]),
    ("Tensor networks: the order matters", "the MPS drawn, its flops against the naive sum, its tree",
     [("readme", "EinsumDiagram[mps]"), ("readme", "EinsumPath["), ("readme", "EinsumTree[")]),
    ("Fast in loops", "EinsumFunction: batched products, a transfer matrix, its flops",
     [("readme", "EinsumFunction["), ("showcase", "efdefine"), ("showcase", "efproperties")]),
]
SHOWCASE = os.path.join(ROOT, "Showcase", "examples")


def showcase_example(name):
    """The code of the example `name` of the showcase and its output, as Development/run_examples.wl wrote them: ("tex",
    LaTeX), ("text", text) or ("pdf", path), None for none. An example has one output file; when a file of another kind
    is left from an earlier run, the newest is its output."""
    path = os.path.join(SHOWCASE, name + ".wl")
    if not os.path.exists(path):
        sys.exit("Showcase/examples/%s.wl not found: run Showcase/build_pdf.sh" % name)
    code = open(path, encoding="utf-8").read().strip("\n")
    found = [(os.path.getmtime(f), ext, f) for ext in ("pdf", "txt", "tex")
             for f in [os.path.join(SHOWCASE, "%s.%s" % (name, ext))] if os.path.exists(f)]
    if not found:
        return code, None
    _, ext, f = max(found)
    if ext == "pdf":
        return code, ("pdf", f)
    return code, ("tex" if ext == "tex" else "text", open(f, encoding="utf-8").read().strip("\n"))


def cards_cells():
    """The cells of every card: [[(code, output, the code from whose line on the cell is typed, or None)]], the outputs
    as readme_blocks and showcase_example give them."""
    blocks = readme_blocks()
    used, cards = set(), []
    for head, _, cells in CARDS:
        out = []
        for source, key, *paste in cells:
            if source == "readme":
                found = [k for k, (code, _) in enumerate(blocks) if key in code]
                if len(found) != 1:
                    sys.exit('README.md, "A first example": %s code block with %s (the card "%s")'
                             % ("no" if not found else "more than one", key, head))
                used.add(found[0])
                code, output = blocks[found[0]]
                if output is None and not code.startswith("Needs["):
                    sys.exit('README.md, "A first example": the block with %s is followed by no output' % key)
            else:
                code, output = showcase_example(key)
            out.append((code, output, key if paste else None))
        cards.append(out)
    for k, (code, _) in enumerate(blocks):
        if k not in used:
            print("not in the video: the block of the README that starts with %s" % code.split("\n")[0][:60])
    return cards


def out_name(k, j):
    """The name of the output of the cell j of the card k."""
    return "o%d_%d" % (k, j)


# ---------------------------------------------------------------------------------------------------------------------
# the pictures: LaTeX elements, one page each, and the pictures of the README

PREAMBLE = r"""\documentclass[12pt,multi=elem,border=%gpt]{standalone}
\usepackage[T1]{fontenc}
\usepackage[sc]{mathpazo}
\usepackage[scale=0.9]{sourcecodepro}
\usepackage{amsmath,xcolor}
\definecolor{accent}{HTML}{%02X%02X%02X}\definecolor{muted}{HTML}{%02X%02X%02X}
\newsavebox{\elembox}
\begin{document}
""" % ((BORDER,) + ACCENT + MUTED)

# the outputs, a little larger than the code, as a notebook shows them
OUTPUT_SIZE = r"\fontsize{8.5}{10.5}\selectfont"


def text_tex(text):
    """A text output of the README (a ```text block) as LaTeX, line by line, to be set in the font of the code."""
    special = {"\\": r"\textbackslash{}", "{": r"\{", "}": r"\}", "$": r"\$", "&": r"\&", "#": r"\#", "%": r"\%",
               "_": r"\_", "^": r"\textasciicircum{}", "~": r"\textasciitilde{}", " ": r"\ "}
    lines = ["".join(special.get(ch, ch) for ch in line) for line in text.split("\n")]
    return lines[0] if len(lines) == 1 else r"\begin{tabular}[t]{@{}l@{}}%s\end{tabular}" % r"\\".join(lines)


def elements(cards):
    """name -> LaTeX of every element of the video typeset by pdflatex (the pictures are not)."""
    e = {}
    # title and end card
    e["name"] = r"{\color{accent}\fontsize{30}{36}\selectfont\bfseries Summa}"
    e["tagline"] = r"{\fontsize{16}{20}\selectfont Fast Einstein summation}"
    e["url"] = r"{\color{accent}\fontsize{15}{19}\selectfont\ttfamily n4sd4q.github.io/Summa}"
    # the captions of the cards and the outputs of their cells (formulas in display style, as $$...$$)
    for k, ((head, line, _), cells) in enumerate(zip(CARDS, cards), 1):
        e["h%d" % k] = r"{\color{accent}\fontsize{19}{23}\selectfont\bfseries %s}" % head
        e["s%d" % k] = r"{\color{muted}\fontsize{13}{16}\selectfont %s}" % line
        for j, (_, out, _) in enumerate(cells):
            if out and out[0] == "tex":
                e[out_name(k, j)] = r"{%s$\displaystyle %s$}" % (OUTPUT_SIZE, out[1])
            elif out and out[0] == "text":
                e[out_name(k, j)] = r"{%s\ttfamily %s}" % (OUTPUT_SIZE, text_tex(out[1]))
    return e


def render_elements(cards):
    """Typeset every element and return (name -> RGBA image, transparent, 120 px to the cm; name -> the height of its
    baseline from the top of the image, px)."""
    os.makedirs(BUILD, exist_ok=True)
    els = elements(cards)
    names = list(els)
    with open(os.path.join(BUILD, "elements.tex"), "w", encoding="utf-8") as fh:
        fh.write(PREAMBLE)
        for name in names:
            # each element in a box, its height and depth written to the log: where its baseline is
            fh.write("%% %s\n\\begin{elem}\\sbox{\\elembox}{%s}\\typeout{ELEMBOX %s \\the\\ht\\elembox\\space\\the\\dp\\elembox}"
                     "\\usebox{\\elembox}\\end{elem}\n" % (name, els[name], name))
        fh.write("\\end{document}\n")
    env = dict(os.environ, max_print_line="100000")
    run = subprocess.run(["pdflatex", "-interaction=nonstopmode", "-halt-on-error", "elements.tex"], cwd=BUILD,
                         capture_output=True, text=True, env=env)
    if run.returncode:
        sys.exit("pdflatex failed:\n" + run.stdout[-3000:])
    baselines = {m.group(1): (BORDER + float(m.group(2))) * PT
                 for m in re.finditer(r"^ELEMBOX (\S+) ([0-9.]+)pt ([0-9.]+)pt$", run.stdout, re.M)}
    pngs = os.path.join(BUILD, "png")
    os.makedirs(pngs, exist_ok=True)
    images = {}

    def page(i, name):
        subprocess.run(["pdftocairo", "-png", "-transp", "-r", "%.4f" % DPI, "-f", str(i), "-l", str(i), "-singlefile",
                        os.path.join(BUILD, "elements.pdf"), os.path.join(pngs, name)], check=True)

    # one pdftocairo per page, several at a time
    with concurrent.futures.ThreadPoolExecutor(max_workers=os.cpu_count() or 1) as pool:
        list(pool.map(page, range(1, len(names) + 1), names))
    for name in names:
        images[name] = Image.open(os.path.join(pngs, name) + ".png").convert("RGBA")
        box = images[name].getchannel("A").getbbox()
        if box and (box[0] == 0 or box[1] == 0 or box[2] == images[name].width or box[3] == images[name].height):
            print("warning: element %s is cut at the edge of its page" % name)
    return images, baselines


@functools.lru_cache(maxsize=None)
def trimmed(path):
    """A picture of the README, its white margins cut away (and a hair of white kept around the drawing), with the width
    of the whole picture: the README gives its width with the margins."""
    img = Image.open(path).convert("RGB")
    box = ImageChops.difference(img, Image.new("RGB", img.size, WHITE)).getbbox()
    if box is None:
        sys.exit("%s is blank" % os.path.relpath(path, ROOT))
    keep = max(1, round(img.width / 400))
    box = (max(0, box[0] - keep), max(0, box[1] - keep), min(img.width, box[2] + keep), min(img.height, box[3] + keep))
    return img.crop(box), img.width


def picture(path, width, scale):
    """The picture as an element: its drawing at `width` px of the README (the width of the whole picture there) times
    `scale` (px of a frame 1280 px wide), reduced in one step from the picture of Mathematica (twice the resolution of a
    screen, so that it stays sharp), opaque on white, with a transparent border as wide as that of the LaTeX elements;
    and the height of its middle from its top, where Out[n]= sits (a notebook centres the label of a graphic on it)."""
    img, whole = trimmed(path)
    f = px(width * scale) / whole
    size = (max(1, round(img.width * f)), max(1, round(img.height * f)))
    border = round(BORDER * PT)
    out = Image.new("RGBA", (size[0] + 2 * border, size[1] + 2 * border), (255, 255, 255, 0))
    out.paste(img.resize(size, Image.LANCZOS), (border, border))
    return out, border + size[1] / 2 + px(5)


def add_pictures(el, base, cards, scale):
    """The pictures of the README into el and base, at the factor `scale` (picture)."""
    for k, cells in enumerate(cards, 1):
        for j, (_, out, _) in enumerate(cells):
            if out and out[0] == "picture":
                el[out_name(k, j)], base[out_name(k, j)] = picture(out[1], out[2], scale)


# the pictures of the showcase are drawn at this fraction of the scale of the LaTeX elements: the text of the summary box
# of an EinsumFunction is then as large as that of the formulas, a little larger than the code
PDF_SCALE = 0.9


def add_pdfs(el, base, cards):
    """The pictures of the showcase (the summary box of an EinsumFunction, as a notebook shows it) into el and base, at
    PDF_SCALE; transparent around, with the border of the LaTeX elements; Out[n]= on their middle."""
    pngs = os.path.join(BUILD, "png")
    os.makedirs(pngs, exist_ok=True)
    for k, cells in enumerate(cards, 1):
        for j, (_, out, _) in enumerate(cells):
            if out and out[0] == "pdf":
                name = out_name(k, j)
                subprocess.run(["pdftocairo", "-png", "-transp", "-r", "%.4f" % (PDF_SCALE * DPI), "-singlefile", out[1],
                                os.path.join(pngs, name)], check=True)
                img = Image.open(os.path.join(pngs, name) + ".png").convert("RGBA")
                border = round(BORDER * PT)
                el[name] = Image.new("RGBA", (img.width + 2 * border, img.height + 2 * border), (255, 255, 255, 0))
                el[name].paste(img, (border, border))
                base[name] = border + img.height / 2 + px(5)


# ---------------------------------------------------------------------------------------------------------------------
# code, typed as in a notebook

def font(name, size):
    path = subprocess.run(["kpsewhich", name], capture_output=True, text=True).stdout.strip()
    if not path:
        sys.exit("font %s not found (TeX Live package sourcecodepro)" % name)
    return ImageFont.truetype(path, size)


def package_names():
    """The public names of the package (those with a usage message), black in an input cell once it is loaded."""
    names = set()
    kernel = os.path.join(ROOT, "Summa", "Kernel")
    for f in sorted(os.listdir(kernel)):
        if f.endswith(".wl"):
            text = open(os.path.join(kernel, f), encoding="utf-8").read()
            names |= set(re.findall(r"^(?:Summa`)?([A-Za-z$][A-Za-z0-9$]*)::usage", text, re.M))
    return names


NAME = r"[A-Za-z$\u0370-\u03ff][A-Za-z0-9$\u0370-\u03ff]*"
SYSTEM_LETTERS = {"C", "D", "E", "I", "K", "N", "O"}      # the system's symbols of one letter (I, D, ...)
TOKEN = re.compile(r"\(\*.*?\*\)|\"(?:[^\"\\]|\\.)*\"|" + NAME + r"|\d+|.", re.S)


def bracket_end(code, i):
    """The position after the bracket that closes the one opened at i."""
    depth = 0
    for m in TOKEN.finditer(code, i):
        if m.group(0) in "[({":
            depth += 1
        elif m.group(0) in "])}":
            depth -= 1
            if depth == 0:
                return m.end()
    return len(code)


def notebook_text(code):
    """The code as a notebook shows it: a named character (\\[Omega], \\[CapitalSigma]) as its letter."""
    def letter(m):
        try:
            return unicodedata.lookup("GREEK %s LETTER %s" % ("CAPITAL" if m.group(1) else "SMALL", m.group(2).upper()))
        except KeyError:
            return m.group(0)
    return re.sub(r"\\\[(Capital)?([A-Za-z]+)\]", letter, code)


def colours(code, known):
    """The colour of each character of the code, and the names it gives a value to. `known`: the names with a value
    (the package's once it is loaded, those set by the cells before); other names of one letter, or lower case, are
    undefined; the iterators of a Table, Sum, Do or Product are local inside it, and so are the pattern variables of a
    definition (f[x_] := ...) in its line."""
    local = []      # (start, end, names)
    for m in re.finditer(r"\b(?:Table|Sum|Do|Product)\[", code):
        end = bracket_end(code, m.end() - 1)
        local.append((m.start(), end, set(re.findall(r",\s*\{\s*(" + NAME + r")\s*,", code[m.end():end]))))
    for m in re.finditer(r"^(.*?):=.*$", code, re.M):
        local.append((m.start(), m.end(), set(re.findall("(" + NAME + ")(?=_)", m.group(1)))))
    out = []
    for m in TOKEN.finditer(code):
        t = m.group(0)
        if t.startswith("(*"):
            kind = "comment"
        elif t.startswith('"'):
            kind = "string"
        elif re.match(NAME, t):
            if any(a <= m.start() < b and t in names for a, b, names in local):
                kind = "local"
            elif t in known or t in SYSTEM_LETTERS or (re.match(r"\$?[A-Z][A-Za-z0-9]+$", t) and len(t.lstrip("$")) > 1):
                kind = "plain"
            else:
                kind = "symbol"
        else:
            kind = "plain"
        out.extend([CODE_COLORS[kind]] * len(t))
    # the names given a value: a = ..., {a, b} = ..., also after a semicolon
    assigned = set()
    for m in re.finditer(r"(?:^|;)\s*(\{[^{}=]*\}|" + NAME + r")\s*=(?!=)", code, re.M):
        assigned |= set(re.findall(NAME, m.group(1)))
    return out, assigned


def expressions(code):
    """The number of expressions of a cell: a notebook evaluates each line that ends one on its own, with its own number
    (In[n]:= is that of the first one, Out[n]= that of the one that gives the output)."""
    flat = re.sub(r"\(\*.*?\*\)|\"(?:[^\"\\]|\\.)*\"", "0", code, flags=re.S)
    n = depth = 0
    for line in flat.split("\n"):
        depth += sum(line.count(b) for b in "[({") - sum(line.count(b) for b in "])}")
        if depth == 0 and line.strip():
            n += 1
    return n


def wrap(code, cols, indent=2):
    """The row and column of each character of the code (and of its end) in a cell `cols` characters wide: a line too
    long is wrapped as a notebook wraps it, where the nesting is least deep (after a comma, before a binary operator),
    the rest indented by `indent`."""
    pos, row = [], 0
    for line in code.split("\n"):
        start, ind = 0, 0
        while len(line) - start + ind > cols:
            best, depth, instr = None, 0, False
            for j in range(start, len(line)):
                ch = line[j]
                if ch == '"':
                    instr = not instr
                if instr:
                    continue
                if j > start + 1 and j - start + ind <= cols and line[j - 1] == " " and (
                        line[j - 2] == "," or (line[j] in "+-" and line[j + 1:j + 2] == " ") or line.startswith("**", j)):
                    if best is None or depth <= best[0]:
                        best = (depth, j)
                depth += (ch in "[({") - (ch in "])}")
            if best is None:
                break
            pos.extend((row, ind + k) for k in range(best[1] - start))
            row, start, ind = row + 1, best[1], indent
        pos.extend((row, ind + k) for k in range(len(line) - start + 1))      # with the newline (or the end)
        row += 1
    return pos


class CodeCell:
    """An input cell: the code, coloured, at (x, y) (the top of its first row), wrapped to the width of the cell."""

    def __init__(self, code, known, fnt, x, y, line_height, cols):
        self.code, self.font, self.x, self.y, self.lh = code, fnt, x, y, line_height
        self.colours, self.assigned = colours(code, known)
        self.pos = wrap(code, cols)
        self.advance = fnt.getlength("M")
        self.rows = self.pos[-1][0] + 1
        self.height = self.rows * line_height
        self.ascent = px(21)     # from the top of a row to the baseline

    def baseline(self, row):
        return self.y + row * self.lh + self.ascent

    def draw(self, draw, n, cursor=False):
        """Draw the first n characters; with the cursor after them."""
        run, last = "", None
        for i in range(n + 1):
            key = (self.pos[i][0], self.colours[i]) if i < n and self.code[i] != "\n" else None
            if key != last or (key and self.pos[i][1] != self.pos[i - 1][1] + 1):
                if run.strip():
                    row, col = self.pos[i - len(run)]
                    draw.text((self.x + col * self.advance, self.baseline(row)), run, font=self.font, fill=last[1], anchor="ls")
                run = ""
            if key:
                run += self.code[i]
            last = key
        if cursor:
            if n and self.code[n - 1] != "\n":
                row, col = self.pos[n - 1][0], self.pos[n - 1][1] + 1
            else:
                row, col = self.pos[n]
            cx, base = self.x + col * self.advance + px(1), self.baseline(row)
            draw.rectangle([cx, base - px(16), cx + ipx(2) - 1, base + px(5)], fill=ACCENT)


# ---------------------------------------------------------------------------------------------------------------------
# frames

def ease(u):
    u = min(max(u, 0.0), 1.0)
    return u * u * (3 - 2 * u)


def ease_out(u):
    """Quick at first, then settling: the fade-in of the elements."""
    u = min(max(u, 0.0), 1.0)
    return 1 - (1 - u) ** 3


def ease_out_back(u, overshoot=1.6):
    """Like ease_out, a little beyond 1 before settling: the logo popping in."""
    u = min(max(u, 0.0), 1.0) - 1
    return 1 + (overshoot + 1) * u ** 3 + overshoot * u ** 2


def smootherstep(u):
    """0 to 1 with zero slope and zero curvature at both ends."""
    u = min(max(u, 0.0), 1.0)
    return u * u * u * (u * (6 * u - 15) + 10)


def glide(u, ramp=0.3):
    """0 to 1 for u from 0 to 1, as a pen moves: its speed rises from rest (smootherstep, over the fraction `ramp` of
    the time), holds, and falls back to rest over the last `ramp`."""
    u = min(max(u, 0.0), 1.0)
    rise = lambda x: x ** 6 - 3 * x ** 5 + 2.5 * x ** 4       # the integral of smootherstep from 0 to x
    if u < ramp:
        p = ramp * rise(u / ramp)
    elif u <= 1 - ramp:
        p = ramp / 2 + u - ramp
    else:
        p = 1 - ramp - ramp * rise((1 - u) / ramp)
    return p / (1 - ramp)


def bump(u):
    """0 at u = 0 and 1, up to 1 in the middle, with zero slope at both ends: a pulse."""
    return 16 * u * u * (1 - u) * (1 - u) if 0 < u < 1 else 0.0


def with_alpha(img, a):
    if a >= 1:
        return img
    out = img.copy()
    out.putalpha(img.getchannel("A").point(lambda v: int(v * a)))
    return out


class Item:
    """An image on the frame from time t0, fading in (and rising a few pixels), until t1 (or the end of its scene)."""

    def __init__(self, img, x, y, t0=0.0, fade=0.28, t1=None, rise=px(10)):
        self.img, self.x, self.y, self.t0, self.fade, self.t1, self.rise = img, x, y, t0, fade, t1, rise

    def draw(self, frame, t, dy=0):
        if t < self.t0 or (self.t1 is not None and t >= self.t1):
            return
        a = ease_out((t - self.t0) / self.fade) if self.fade else 1
        y = int(round(self.y - dy + (1 - a) * self.rise))
        if y > frame.height or y + self.img.height < 0:
            return
        paste_clipped(frame, with_alpha(self.img, a), int(round(self.x)), y)


# ---------------------------------------------------------------------------------------------------------------------
# the logo, from Logo/Summa_logo.svg

def _colour(v):
    return tuple(int(v[i:i + 2], 16) for i in (1, 3, 5))


class Logo:
    """The geometry of Logo/Summa_logo.svg, in units of its 128 x 128 picture: the badge (a rounded square in a
    gradient, a soft white light, a faint white edge), the nodes (discs) and the bonds (lines with round ends) that join
    them, and the sigma they make: the path of the bonds through the nodes from its top end (the top right node) to its
    other end. The nodes and the bonds are kept in that order, each bond from its node nearer the start to the other,
    with the arc length along the sigma at which it starts (s0); the bonds in the colour of the nodes are the ink, the
    one in another colour (the tint) is the bond being summed."""
    STYLE = ("fill", "stroke", "stroke-width", "stroke-linecap", "stroke-opacity", "fill-opacity")

    def __init__(self, path):
        root = ET.parse(path).getroot()
        tag = lambda e: e.tag.rsplit("}", 1)[-1]
        if root.get("viewBox") != "0 0 128 128":
            sys.exit("Logo/Summa_logo.svg: a viewBox of 128 x 128 expected")
        rects, lines, circles = [], [], []

        def walk(e, inherited):
            # the attributes of an element, with the style it inherits from its groups
            attrs = dict(inherited, **e.attrib)
            t = tag(e)
            if t == "linearGradient":
                stops = [_colour(s.get("stop-color")) for s in e if tag(s) == "stop"]
                self.start, self.end = stops[0], stops[-1]
                self.axis = tuple(float(e.get(k)) for k in ("x1", "y1", "x2", "y2"))
            elif t == "radialGradient":
                stops = [s for s in e if tag(s) == "stop"]
                self.light = tuple(float(e.get(k)) for k in ("cx", "cy", "r")) + (float(stops[0].get("stop-opacity")),)
            elif t == "rect":
                rects.append(attrs)
            elif t == "line":
                lines.append(attrs)
            elif t == "circle":
                circles.append(attrs)
            for child in e:
                walk(child, {k: v for k, v in attrs.items() if k in self.STYLE})

        walk(root, {})
        self.radius = float(rects[0]["rx"])
        edge = next(r for r in rects if r.get("stroke"))
        self.edge = (float(edge["x"]), float(edge["rx"]), float(edge["stroke-width"]), float(edge["stroke-opacity"]))
        nodes = [dict(c=(float(c["cx"]), float(c["cy"])), r=float(c["r"]), colour=_colour(c["fill"])) for c in circles]

        def node(x, y):
            k = min(range(len(nodes)), key=lambda i: math.dist(nodes[i]["c"], (x, y)))
            if math.dist(nodes[k]["c"], (x, y)) > 1e-6:
                sys.exit("Logo/Summa_logo.svg: a bond does not end on the centre of a node")
            return k

        bonds = []
        for e in lines:
            if e.get("stroke-linecap") != "round":
                sys.exit("Logo/Summa_logo.svg: the bonds are drawn here with round ends")
            bonds.append(dict(ends={node(float(e["x1"]), float(e["y1"])), node(float(e["x2"]), float(e["y2"]))},
                              colour=_colour(e["stroke"]), width=float(e["stroke-width"])))
        # the sigma: a path through every node, from its top end
        degree = [sum(k in b["ends"] for b in bonds) for k in range(len(nodes))]
        if len(bonds) != len(nodes) - 1 or sorted(degree) != [1, 1] + [2] * (len(nodes) - 2):
            sys.exit("Logo/Summa_logo.svg: the bonds do not make one path through the nodes")
        order = [min((k for k in range(len(nodes)) if degree[k] == 1), key=lambda k: (nodes[k]["c"][1], -nodes[k]["c"][0]))]
        self.bonds, left, s = [], list(bonds), 0.0
        while left:
            b = next(b for b in left if order[-1] in b["ends"])
            left.remove(b)
            order.append(next(iter(b["ends"] - {order[-1]})))
            length = math.dist(nodes[order[-2]]["c"], nodes[order[-1]]["c"])
            self.bonds.append(dict(a=len(order) - 2, b=len(order) - 1, colour=b["colour"], width=b["width"], s0=s,
                                   length=length))
            s += length
        self.nodes = [nodes[k] for k in order]
        self.length = s
        for k, n in enumerate(self.nodes):
            n["s"] = sum(b["length"] for b in self.bonds[:k])
        self.ink = self.nodes[0]["colour"]
        if any(n["colour"] != self.ink for n in self.nodes) or [b["colour"] == self.ink for b in self.bonds].count(False) != 1:
            sys.exit("Logo/Summa_logo.svg: the nodes and all the bonds but one in one colour expected")
        # the layers, in the order of the SVG: the bonds of the ink, the bond in the tint, the nodes
        self.layers = [("bonds", self.ink), ("bonds", next(b["colour"] for b in self.bonds if b["colour"] != self.ink)),
                       ("nodes", self.ink)]


LOGO = Logo(os.path.join(ROOT, "Logo", "Summa_logo.svg"))
LOGO_SUPERSAMPLE = 4     # the logo is drawn this many times larger and reduced, for smooth edges


@functools.lru_cache(maxsize=64)
def badge_image(big):
    """The badge of the logo at `big` px, without the drawing: the rounded square in the gradient of the SVG (its
    axis from the top left to the bottom right), under the soft white light of its radial gradient (falling linearly to
    none), and the faint white edge. Both gradients are smooth: they are computed on a grid of 256 x 256 (two points per
    unit) and enlarged. The badge does not move: one image per size, the same in every frame."""
    f = big / 128.0
    n = 256
    units = [(i + 0.5) * 128.0 / n for i in range(n)]
    x1, y1, x2, y2 = LOGO.axis
    ax, ay = x2 - x1, y2 - y1
    along = bytes(min(255, max(0, int(255 * ((x - x1) * ax + (y - y1) * ay) / (ax * ax + ay * ay) + 0.5)))
                  for y in units for x in units)
    cx, cy, r, opacity = LOGO.light
    light = bytes(int(255 * opacity * max(0.0, 1 - math.hypot(x - cx, y - cy) / r) + 0.5) for y in units for x in units)
    along = Image.frombytes("L", (n, n), along).resize((big, big), Image.BILINEAR)
    light = Image.frombytes("L", (n, n), light).resize((big, big), Image.BILINEAR)
    white = Image.new("L", (big, big), 255)
    badge = Image.composite(Image.new("RGBA", (big, big), LOGO.end + (255,)),
                            Image.new("RGBA", (big, big), LOGO.start + (255,)), along)
    badge.alpha_composite(Image.merge("RGBA", (white, white, white, light)))
    # the edge: a stroke centred on a rounded square inset by x (rx), here from the outline of the badge inwards
    x, rx, width, opacity = LOGO.edge
    edge = Image.new("L", (big, big), 0)
    ImageDraw.Draw(edge).rounded_rectangle([(x - width / 2) * f, (x - width / 2) * f, big - 1 - (x - width / 2) * f,
                                            big - 1 - (x - width / 2) * f], radius=int(round((rx + width / 2) * f)),
                                           outline=round(opacity * 255), width=int(round(width * f)))
    badge.alpha_composite(Image.merge("RGBA", (white, white, white, edge)))
    shape = Image.new("L", (big, big), 0)
    ImageDraw.Draw(shape).rounded_rectangle([0, 0, big - 1, big - 1], radius=int(round(LOGO.radius * f)), fill=255)
    badge.putalpha(shape)
    return badge


# the swell that runs along the sigma on the title card: how far it reaches on either side of its crest (units of the
# logo), how much thicker a bond is under its crest, how much larger a node
SWELL_REACH, SWELL_BOND, SWELL_NODE = 32.0, 0.3, 0.18


def swell(x):
    """The swell at the distance x (along the sigma) from its crest: 1 there, 0 from SWELL_REACH on."""
    return bump(x / (2 * SWELL_REACH) + 0.5)


class LogoState:
    """What the logo shows: how much of each bond is drawn (the fraction from its node nearer the start of the sigma),
    how large each node is (1 in place), where the crest of the swell is (arc length along the sigma; None: no swell).
    At rest, the logo of the SVG."""

    def __init__(self, fronts=None, nodes=None, crest=None):
        self.fronts = fronts or [1.0] * len(LOGO.bonds)
        self.nodes = nodes or [1.0] * len(LOGO.nodes)
        on = crest is not None and -SWELL_REACH < crest < LOGO.length + SWELL_REACH
        self.crest = crest if on else None

    def key(self):
        return tuple(round(v, 4) for v in self.fronts + self.nodes) + (None if self.crest is None else round(self.crest, 4),)


REST = LogoState().key()


@functools.lru_cache(maxsize=8)
def rest_logo(size):
    return draw_logo(size, LogoState())


def logo_image(size, state):
    return rest_logo(size) if state.key() == REST else draw_logo(size, state)


def draw_logo(size, state):
    """The logo at `size` px in the state `state`, drawn LOGO_SUPERSAMPLE times larger and reduced. Its shapes are
    painted through one mask for each layer of the SVG (the bonds of the ink, the bond in the tint, the nodes), so that
    overlapping shapes of one layer make one shape."""
    big = size * LOGO_SUPERSAMPLE
    f = big / 128.0
    img = badge_image(big).copy()
    # PIL fills every pixel whose centre is on a shape or on its outline: one pixel more across than the shape; every
    # outline is drawn half a pixel (of the large picture) inside
    inset = 0.5 / f

    def T(x, y):
        # PIL puts the centre of a pixel at its integer coordinates; SVG at half-integers
        return x * f - 0.5, y * f - 0.5

    def disc(d, x, y, r):
        (X, Y), R = T(x, y), (r - inset) * f
        if R > 0:
            d.ellipse([X - R, Y - R, X + R, Y + R], fill=255)

    def bond(d, b, front):
        """The bond from its first node to the fraction `front` of its length, with round ends; under the swell, its
        width follows the swell along it."""
        end = front * b["length"]
        if end < 0.01:
            return
        (xa, ya), (xb, yb) = LOGO.nodes[b["a"]]["c"], LOGO.nodes[b["b"]]["c"]
        tx, ty = (xb - xa) / b["length"], (yb - ya) / b["length"]
        crest = state.crest
        swelling = crest is not None and b["s0"] - SWELL_REACH < crest < b["s0"] + end + SWELL_REACH
        hw = (lambda s: b["width"] / 2 * (1 + SWELL_BOND * swell(b["s0"] + s - crest))) if swelling else (lambda s: b["width"] / 2)
        n = max(1, int(math.ceil(end / 0.25))) if swelling else 1
        samples = [end * k / n for k in range(n + 1)]
        left = [T(xa + tx * s - ty * (hw(s) - inset), ya + ty * s + tx * (hw(s) - inset)) for s in samples]
        right = [T(xa + tx * s + ty * (hw(s) - inset), ya + ty * s - tx * (hw(s) - inset)) for s in samples]
        d.polygon(left + right[::-1], fill=255)
        for s in (0.0, end):
            disc(d, xa + tx * s, ya + ty * s, hw(s))

    for kind, colour in LOGO.layers:
        mask = Image.new("L", (big, big), 0)
        d = ImageDraw.Draw(mask)
        if kind == "bonds":
            for b, front in zip(LOGO.bonds, state.fronts):
                if b["colour"] == colour:
                    bond(d, b, front)
        else:
            for n, g in zip(LOGO.nodes, state.nodes):
                if g > 0.02 and n["colour"] == colour:
                    disc(d, n["c"][0], n["c"][1], n["r"] * g)
        img.paste(colour + (255,), (0, 0, big, big), mask)
    return img.resize((size, size), Image.LANCZOS)


class Swell:
    """The title card: the logo at rest, then from `start` a soft swell runs once along the sigma, from before its
    first node to beyond its last (its crest gliding: a soft start, an even run, a soft stop), each bond growing a
    little thicker and each node a little larger as it passes; the logo is at rest again when it has gone."""

    def __init__(self, start, duration=1.4):
        self.start, self.duration = start, duration

    def state(self, t):
        u = (t - self.start) / self.duration
        if u <= 0 or u >= 1:
            return LogoState()
        crest = -SWELL_REACH + glide(u, 0.25) * (LOGO.length + 2 * SWELL_REACH)
        return LogoState(nodes=[1 + SWELL_NODE * swell(n["s"] - crest) for n in LOGO.nodes], crest=crest)


PULSE, PULSE_TIME = 0.16, 0.34      # how much a node swells when the bond in the tint reaches it, and for how long


class DrawIn:
    """The closing card: the logo draws itself along the sigma. From `start` a pen draws the bonds of the ink in the
    order of the sigma, a run of bonds that follow one another in one stroke (a soft start, a glide, a soft stop), and
    the nodes pop in (a little beyond their size and back) one after the other as it goes: the first node of a stroke
    just before the pen sets off from it, every other as the pen reaches it. The bond in the tint, the one being summed,
    comes last: its stroke joins two nodes already in place, and the node it reaches swells a little as it arrives."""

    def __init__(self, start, gap=0.07, pop=0.36, lead=0.12):
        self.pop = pop
        ink = [k for k, b in enumerate(LOGO.bonds) if b["colour"] == LOGO.ink]
        runs = []
        for k in ink:
            if runs and runs[-1][-1] == k - 1:
                runs[-1].append(k)
            else:
                runs.append([k])
        strokes = runs + [[k] for k, b in enumerate(LOGO.bonds) if b["colour"] != LOGO.ink]
        self.strokes, t = [], start + lead
        self.appear = [None] * len(LOGO.nodes)
        self.pulses = []
        for run in strokes:
            length = sum(LOGO.bonds[k]["length"] for k in run)
            duration = 0.16 + length / 210
            self.strokes.append(dict(bonds=run, t0=t, duration=duration, length=length))
            first = LOGO.bonds[run[0]]["a"]
            if self.appear[first] is None:
                self.appear[first] = t - lead
            # each node of the stroke pops in as the pen reaches it (a moment before its centre)
            s = 0.0
            for k in run:
                s += LOGO.bonds[k]["length"]
                arrive = t + duration * self.when(s / length)
                node = LOGO.bonds[k]["b"]
                if self.appear[node] is None:
                    self.appear[node] = arrive - 0.06
                else:
                    self.pulses.append((node, arrive - 0.04))
            t += duration + gap
        self.end = t - gap

    @staticmethod
    def when(p):
        """The fraction of the time of a stroke at which the pen has drawn the fraction p of it."""
        lo, hi = 0.0, 1.0
        for _ in range(40):
            mid = (lo + hi) / 2
            lo, hi = (mid, hi) if glide(mid) < p else (lo, mid)
        return hi

    def state(self, t):
        fronts = [0.0] * len(LOGO.bonds)
        for st in self.strokes:
            drawn = glide((t - st["t0"]) / st["duration"]) * st["length"]
            for k in st["bonds"]:
                b = LOGO.bonds[k]
                fronts[k] = min(max(drawn, 0.0), b["length"]) / b["length"]
                drawn -= b["length"]
        nodes = []
        for i, a in enumerate(self.appear):
            if t < a:
                g = 0.0
            elif t < a + self.pop:
                g = max(0.0, ease_out_back((t - a) / self.pop, 1.2))
            else:
                g = 1.0
            nodes.append(g + sum(PULSE * bump((t - w) / PULSE_TIME) for k, w in self.pulses if k == i))
        return LogoState(fronts=fronts, nodes=nodes)


class LogoItem:
    """The logo, alive: it pops in (scaled up from 80%, a little beyond its size and back) at t0, then animates
    (`anim`, a Swell or a DrawIn: its state at each time)."""

    def __init__(self, size, x, y, t0=0.0, fade=0.45, anim=None):
        self.size, self.x, self.y, self.t0, self.fade, self.anim = size, x, y, t0, fade, anim

    def draw(self, frame, t, dy=0):
        if t < self.t0:
            return
        u = (t - self.t0) / self.fade if self.fade else 1.0
        scale = 0.8 + 0.2 * ease_out_back(u)
        size = max(ipx(8), int(round(self.size * scale)))
        img = with_alpha(logo_image(size, self.anim.state(t) if self.anim else LogoState()), ease_out(1.6 * u))
        paste_clipped(frame, img, int(round(self.x + (self.size - size) / 2)), int(round(self.y - dy + (self.size - size) / 2)))


def paste_clipped(frame, img, x, y):
    top, bottom = max(0, -y), min(img.height, frame.height - y)
    if bottom > top:
        frame.alpha_composite(img.crop((0, top, img.width, bottom)), (x, y + top))


def blank():
    frame = Image.new("RGBA", (W, H), WHITE + (255,))
    ImageDraw.Draw(frame).rectangle([0, H - ipx(6), W, H], fill=ACCENT)   # the band at the foot
    return frame


def fade_to_white(frame, a):
    """a = 1: the frame; a = 0: white (the accent band stays)."""
    if a >= 1:
        return frame
    return Image.blend(blank(), frame, a)


class Scene:
    def __init__(self, duration, items=(), draw=None, fade_out=0.22, full=0.0):
        self.duration, self.items, self.custom, self.fade_out = duration, list(items), draw, fade_out
        self.full = full        # from this time on, everything of the scene is in view

    def frame(self, t):
        frame = blank()
        if self.custom:
            self.custom(frame, t)
        for item in self.items:
            item.draw(frame, t)
        if self.fade_out and t > self.duration - self.fade_out:
            a = (self.duration - t) / self.fade_out
            shift = int(round(px(36) * (1 - a) ** 2))
            if shift:
                moved = blank()
                moved.paste(frame.crop((shift, 0, W, H - ipx(6))), (0, 0))
                frame = moved
            frame = fade_to_white(frame, a)
        return frame


def centred(img, y):
    return (W - img.width) / 2, y


def title_scene(el, duration, parts, anim, fade_out=0.3, shown=False):
    """The logo and, under it, the elements `parts` (the name, the tagline or the address of the site), stacked in the
    middle; the logo animated by `anim` (Swell, DrawIn). With `shown`, the card is in full view from its first frame (the
    first frame of the video, which a player shows before it plays) instead of building up."""
    size = round(2.6 / 2.54 * DPI)
    slot = size + 2 * BORDER * PT                 # the logo as tall as an element 2.6 cm high
    gaps = {"name": px(26), "tagline": px(12), "url": px(30)}
    height = slot + sum(el[p].height + gaps[p] for p in parts)
    y = (H - height) / 2 - px(8)
    times = {"name": 0.25, "tagline": 0.45, "url": 0.7}
    items = [LogoItem(size, (W - size) / 2, y + (slot - size) / 2, 0.0, fade=0 if shown else 0.45, anim=anim)]
    y += slot
    for p in parts:
        y += gaps[p]
        x, _ = centred(el[p], y)
        items.append(Item(el[p], x, y, 0.0 if shown else times[p], fade=0 if shown else 0.35))
        y += el[p].height
    return Scene(duration, items, fade_out=fade_out)


def caption_lines(el, base):
    """The baselines of the headings and of their second lines, the same on every card (the top of the tallest heading
    44 px from the top, as in the cards of FunctionalDiagrams), and the top of the space left under them."""
    heads = [k for k in el if re.match(r"h\d+$", k)]
    subs = [k for k in el if re.match(r"s\d+$", k)]
    head = px(44) + max(base[k] for k in heads)
    sub = head + max(el[k].height - base[k] for k in heads) + px(2) + max(base[k] for k in subs)
    return head, sub, sub + max(el[k].height - base[k] for k in subs) + px(30)


class Card:
    """One card: its caption (top left: the heading and its second line), then its cells typed one after the other and
    evaluated, each followed by its output, as in a notebook: In[n]:= on the left of an input cell once it is evaluated,
    Out[n]= on the left of the output, and on the right a bracket for each cell and one around the group of an input
    with its output; a short pause after each output before the next cell. A cell whose first lines are pasted in shows
    them at once and types the rest. The cells and their outputs are left-aligned with the caption, a little above the
    middle of the height left under it. When they are taller than that height, they start at its top and scroll up as a
    notebook follows what is typed and evaluated: when a cell is about to be typed, or an output appears, below the foot
    of the space, they scroll until it ends there, or a little further, so that the top of the window (under the caption,
    its edges softened) falls between two rows of code, or just above an output, and cuts nothing."""
    X_CODE, LH, CELL_GAP, OUT_GAP = px(122), px(30), px(24), px(18)
    X_BRACKET, X_GROUP = W - ipx(36), W - ipx(27)     # the cell brackets, and those of the groups
    FOOT = px(40)                                     # the cells end at least this far above the foot of the frame
    SCROLL_TIME, EDGE = 0.7, ipx(6)                   # how long a scroll lasts (s), how soft the edges of the window
    READ = 0.9                                        # the pause after an output, before the next cell (s)

    def __init__(self, el, base, k, cells, session, hold, start=0.45):
        """cells: [(code, name of the output element or None, the code from whose line on the cell is typed, or None:
        all of it)]; session: the number of the next input line and the names with a value, carried from card to
        card."""
        self.codefont = font("SourceCodePro-Medium.otf", px(18))
        self.labelfont = font("SourceCodePro-Regular.otf", px(14))
        cols = int((self.X_BRACKET - px(16) - self.X_CODE) / self.codefont.getlength("M"))
        border = BORDER * PT
        head, sub, top = caption_lines(el, base)
        h, s = "h%d" % k, "s%d" % k
        self.items = [Item(el[h], self.X_CODE - border, head - base[h], 0.0, fade=0.22),
                      Item(el[s], self.X_CODE - border, sub - base[s], 0.07, fade=0.22)]
        self.caption_right = self.X_CODE - 2 * border + max(el[h].width, el[s].width)
        # the cells, laid out from 0 and then moved down to their place
        self.cells, t, y = [], start, 0.0
        self.outputs = []       # (name, width, height, height of its input cell) of the outputs, as they show
        for i, (code, out, typed) in enumerate(cells):
            code = notebook_text(code)
            cell = CodeCell(code, session["known"], self.codefont, self.X_CODE, y, self.LH, cols)
            n = expressions(code)
            # the lines before the one with `typed` are there at once (pasted in); the rest is typed
            pre = code.rfind("\n", 0, code.index(typed)) + 1 if typed else 0
            typing = min(1.15, max(0.55, (len(code) - pre) / 150))
            c = dict(cell=cell, n=session["line"], t0=t, pre=pre, cps=(len(code) - pre) / typing, t_eval=t + typing + 0.15,
                     top=y - px(8))
            session["line"] += n
            session["known"] |= cell.assigned
            if re.search(r"Needs\[\"Summa`\"\]", code):
                # the names of the package have a value from the next cell on
                session["known"] |= package_names()
            y += cell.height
            c["input_bottom"] = y + px(2)
            t = c["t_eval"] + 0.25
            c["out"] = None
            if out:
                y += self.OUT_GAP
                img = el[out]
                self.outputs.append((out, img.width - 2 * border, img.height - 2 * border, cell.height))
                # Out[n]= with the number of the last expression, on the baseline of the output
                c["out"] = (Item(img, self.X_CODE - border, y, t, fade=0.3), session["line"] - 1, base[out])
                y += img.height - 2 * border
                t += 0.3 + (self.READ if i < len(cells) - 1 else 0)
            c["bottom"] = y + px(6)
            y += self.CELL_GAP
            self.cells.append(c)
        self.height = y - self.CELL_GAP
        self.room = (H - self.FOOT - top, self.X_BRACKET - px(16) - self.X_CODE)     # the space for the cells
        self.pasted = any(c["pre"] for c in self.cells)
        scrolls = self.height > self.room[0] + 0.5
        dy = top if scrolls else top + (self.room[0] - self.height) * 0.32
        for c in self.cells:
            c["cell"].y += dy
            for key in ("top", "input_bottom", "bottom"):
                c[key] += dy
            if c["out"]:
                c["out"][0].y += dy - border
        self.full, self.moves, self.scroll = t, [], 0
        if scrolls:
            self.window = (int(round(top - px(28))), H - ipx(6))
            self.plan_scroll()
            if self.moves:
                self.full = max(t, self.moves[-1][0] + self.SCROLL_TIME)
            ramp = [int(255 * smootherstep((r + 0.5) / self.EDGE) + 0.5) for r in range(self.EDGE)]
            rows = ramp + [255] * (self.window[1] - self.window[0] - 2 * self.EDGE) + ramp[::-1]
            self.mask = Image.frombytes("L", (1, len(rows)), bytes(rows)).resize((W, len(rows)), Image.NEAREST)
        self.duration = self.full + hold

    def plan_scroll(self):
        """The scrolls of a card taller than its space: (start, from, to), in px."""
        top, foot, border = self.window[0], H - self.FOOT, BORDER * PT
        # where the window can open: on a row of code, or just above an output
        stops = sorted({c["cell"].y + r * self.LH - top - px(1) for c in self.cells for r in range(c["cell"].rows)} |
                       {c["out"][0].y + border - top - self.EDGE - px(1) for c in self.cells if c["out"]})
        # (when, the bottom that must come in view, the top that must stay in view): each cell a little before it is
        # typed, each output as it appears
        events = []
        for c in self.cells:
            events.append((c["t0"] - self.SCROLL_TIME / 2, c["input_bottom"], c["cell"].y))
            if c["out"]:
                events.append((c["out"][0].t0, c["bottom"], c["out"][0].y + border))
        s, last = 0, -1e9
        for when, bottom, keep in events:
            need = bottom - foot
            if need <= s:
                continue
            fit = [v for v in stops if need <= v <= keep - top - self.EDGE]
            new = int(math.ceil(min(fit) if fit else need))
            start = max(when, last + self.SCROLL_TIME)
            self.moves.append((start, s, new))
            s, last = new, start
        self.scroll = s

    def offset(self, t):
        """How far the cells are scrolled at the time t (whole px)."""
        s = 0.0
        for start, a, b in self.moves:
            if t < start:
                break
            s = a + (b - a) * smootherstep((t - start) / self.SCROLL_TIME)
        return int(round(s))

    def check(self, k):
        if self.caption_right > W - self.X_CODE + 0.5:
            print("warning: the caption of card %d runs beyond the margin on the right" % k)
        if self.scroll:
            # every output, with the last two rows of its input, comes in view
            for name, _, height, cell in self.outputs:
                if height + self.OUT_GAP + min(cell, 2 * self.LH) > self.room[0] + 0.5:
                    print("warning: the output %s and the rows above it do not fit the space of card %d" % (name, k))
        elif self.height > self.room[0] + 0.5:
            print("warning: the cells of card %d run %.0f px below their space" % (k, self.height - self.room[0]))
        for name, width, _, _ in self.outputs:
            if width > self.room[1] + 0.5:
                print("warning: the output %s runs into the cell brackets" % name)

    def draw(self, frame, t):
        for item in self.items:
            item.draw(frame, t)
        if not self.scroll:
            self.draw_cells(frame, t)
            return
        # the cells on a white page as tall as they need, seen through the window, scrolled by whole pixels
        page = Image.new("RGBA", (W, H + self.scroll), WHITE + (255,))
        self.draw_cells(page, t)
        s = self.offset(t)
        top, bottom = self.window
        frame.paste(page.crop((0, top + s, W, bottom + s)), (0, top), self.mask)

    def draw_cells(self, frame, t):
        d = ImageDraw.Draw(frame)
        for c in self.cells:
            if t < c["t0"]:
                break
            cell = c["cell"]
            n = min(len(cell.code), c["pre"] + int((t - c["t0"]) * c["cps"]))
            typing = t < c["t_eval"]
            blink = n < len(cell.code) or int(t * 2.2) % 2 == 0
            cell.draw(d, n, cursor=typing and blink)
            if t >= c["t_eval"]:
                self.label(d, "In[%d]:=" % c["n"], cell.baseline(0), LABEL)
            self.bracket(d, self.X_BRACKET, c["top"], c["input_bottom"])
            if c["out"] and t >= c["out"][0].t0:
                item, number, base = c["out"]
                item.draw(frame, t)
                a = ease((t - item.t0) / 0.3)
                colour = tuple(int(255 - (255 - v) * a) for v in LABEL)
                rise = (1 - ease_out((t - item.t0) / item.fade)) * item.rise
                self.label(d, "Out[%d]=" % number, item.y + base + rise, colour)
                self.bracket(d, self.X_BRACKET, item.y + BORDER * PT - px(6), c["bottom"],
                             colour=tuple(int(255 - (255 - v) * a) for v in BRACKET))
                self.bracket(d, self.X_GROUP, c["top"], c["bottom"])

    def label(self, d, text, baseline, colour):
        """In[n]:= or Out[n]=, right-aligned before the cells, on the baseline given."""
        d.text((self.X_CODE - px(12), baseline), text, font=self.labelfont, fill=colour, anchor="rs")

    @staticmethod
    def bracket(d, x, top, bottom, colour=BRACKET):
        d.line([x, top, x, bottom], fill=colour, width=ipx(1))
        d.line([x - ipx(5), top, x, top], fill=colour, width=ipx(1))
        d.line([x - ipx(5), bottom, x, bottom], fill=colour, width=ipx(1))


# ---------------------------------------------------------------------------------------------------------------------

# how long the outputs of each card stay in full view at its end (s)
HOLDS = [2.4, 2.8, 3.4, 3.4, 2.6]
# the pictures of the README: as large as the README shows them times one factor (px of a frame 1280 px wide for a px
# of the README), the largest with which every picture, with its input cell (at most its last two rows) and the gap
# between them, fills at most PICTURE_FILL of the height left under the caption and is no wider than the cells; at most
# PICTURE_MAX, so that a card holds several cells
PICTURE_FILL, PICTURE_MAX = 0.9, 1.2


def card_cells(cards, k):
    """The cells of the card k for Card: the code, the name of its output, the code from whose line on it is typed."""
    return [(code, out_name(k, j) if out else None, typed) for j, (code, out, typed) in enumerate(cards[k - 1])]


def fit_pictures(el, base, cards):
    """Put the pictures of the README into el and base, scaled as PICTURE_FILL and PICTURE_MAX say; the factor."""
    add_pictures(el, base, cards, 1.0)
    pictures = {out_name(k, j) for k, cells in enumerate(cards, 1) for j, (_, out, _) in enumerate(cells)
                if out and out[0] == "picture"}
    scale, session = PICTURE_MAX, {"line": 1, "known": set()}
    for k in range(1, len(cards) + 1):
        card = Card(el, base, k, card_cells(cards, k), session, 0)
        for name, width, height, cell in card.outputs:
            if name in pictures:
                scale = min(scale, (PICTURE_FILL * card.room[0] - min(cell, 2 * Card.LH) - Card.OUT_GAP) / height,
                            card.room[1] / width)
    add_pictures(el, base, cards, scale)
    return scale


def timeline(el, base, cards, preview=False):
    """The scenes: the title card, the cards (the first with the line that loads the package), the closing card. The
    preview has no title card, shorter holds, and its closing card fades out (it loops)."""
    session = {"line": 1, "known": set()}
    scenes = []
    for k in range(1, len(cards) + 1):
        card = Card(el, base, k, card_cells(cards, k), session, HOLDS[k - 1] - (0.7 if preview else 0))
        if not preview:
            card.check(k)
        scenes.append(Scene(card.duration, draw=card.draw, full=card.full))
    # the closing card is the title card, so that the last frame of the video is its first and the loop has no seam
    end = title_scene(el, 2.9 if preview else 3.5, ["name", "tagline", "url"], DrawIn(0.2), fade_out=0.22 if preview else 0)
    if preview:
        return scenes + [end]
    # the title card in full view from the first frame, which a player shows before the video plays
    title = title_scene(el, 2.6, ["name", "tagline", "url"], Swell(0.35), shown=True)
    return [title] + scenes + [end]


def preview_start(first):
    """The preview loops from this time (s) of its first card, when all of it is in view: the first frame of the
    preview, the one seen by visitors who do not play animated images and in link previews, is that card (not the white
    frame before it builds up); its build-up, after the closing card, closes the loop on that frame."""
    return first.full + 0.2


_JOB = None    # (scenes, size) of the frames being drawn, read by the worker processes (inherited by fork)


def _frame_bytes(job):
    i, t = job
    scenes, size = _JOB
    f = scenes[i].frame(t).convert("RGB")
    return (f if size is None else f.resize(size, Image.LANCZOS)).tobytes()


def frame_times(scenes, fps, start=0.0):
    """The (scene, time) of every frame; with `start` (s, in the first scene), a loop shown from there: the frames from
    that time to the end, then those before it."""
    times = [(i, k / fps) for i, scene in enumerate(scenes) for k in range(int(round(scene.duration * fps)))]
    k0 = int(round(start * fps))
    return times[k0:] + times[:k0]


def frames(scenes, fps, size=None, start=0.0):
    """The frames of the scenes one after the other (frame_times), as raw RGB bytes. Each frame depends only on its
    time: they are drawn by several processes (fork) at once, in order, where fork is available."""
    global _JOB
    times = frame_times(scenes, fps, start)
    _JOB = (scenes, size)
    if "fork" not in multiprocessing.get_all_start_methods():
        yield from map(_frame_bytes, times)
        return
    with multiprocessing.get_context("fork").Pool(os.cpu_count() or 1) as pool:
        yield from pool.imap(_frame_bytes, times, chunksize=4)


def encode(scenes, fps, args, size=None, start=0.0):
    w, h = size or (W, H)
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (w, h),
           "-r", str(fps), "-i", "-"] + args
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    for f in frames(scenes, fps, size, start):
        proc.stdin.write(f)
    proc.stdin.close()
    if proc.wait():
        sys.exit("ffmpeg failed")


def write_preview(scenes, path):
    """The looping preview, from preview_start, as an animated WebP at PREVIEW_FPS (written by PIL): a run of identical
    frames (a card in full view) is one frame, held as long; each frame is stored lossy or lossless, whichever is smaller
    (allow_mixed), so that the fades stay small and the lines of the cards sharp."""
    size, kept, counts = (PREVIEW_W, PREVIEW_H), [], []
    for f in frames(scenes, PREVIEW_FPS, size, preview_start(scenes[0])):
        if kept and f == kept[-1]:
            counts[-1] += 1
        else:
            kept.append(f)
            counts.append(1)
    # the delays in milliseconds, rounded so that they add up to the time of the frames (16 or 17 ms at 60 fps)
    durations, k = [], 0
    for c in counts:
        durations.append(round((k + c) * 1000 / PREVIEW_FPS) - round(k * 1000 / PREVIEW_FPS))
        k += c
    images = [Image.frombytes("RGB", size, f) for f in kept]
    images[0].save(path, save_all=True, append_images=images[1:], duration=durations, loop=0, minimize_size=True,
                   allow_mixed=True, quality=PREVIEW_QUALITY, method=6)


def write_poster(video):
    # the poster: the title card, the first frame of the video, so that nothing jumps when it starts (256 colours: the
    # gradient of the badge under its light shows bands with fewer)
    video[0].frame(0).convert("RGB").quantize(colors=256, method=Image.MEDIANCUT).save(
        os.path.join(MEDIA, "demo_poster.png"), optimize=True)


def main():
    os.makedirs(BUILD, exist_ok=True)
    os.makedirs(MEDIA, exist_ok=True)
    cards = cards_cells()
    el, base = render_elements(cards)
    add_pdfs(el, base, cards)
    scale = fit_pictures(el, base, cards)
    video = timeline(el, base, cards)
    total = sum(s.duration for s in video)
    print("video: %.1f s in %d scenes; the pictures at %.2f times their width in the README" % (total, len(video), scale))
    if "--poster" in sys.argv:
        write_poster(video)
        return
    preview = timeline(el, base, cards, preview=True)
    if "--frames" in sys.argv:
        out = os.path.join(BUILD, "frames")
        os.makedirs(out, exist_ok=True)
        for i, s in enumerate(video):
            for u in (0.55, 0.9):
                s.frame(u * s.duration).convert("RGB").save(os.path.join(out, "scene%d_%02d.png" % (i, round(u * 100))))
        for i, s in enumerate(preview):
            s.frame(0.9 * s.duration).convert("RGB").resize((PREVIEW_W, PREVIEW_H), Image.LANCZOS).save(os.path.join(out, "preview%d.png" % i))
        preview[0].frame(preview_start(preview[0])).convert("RGB").resize((PREVIEW_W, PREVIEW_H), Image.LANCZOS).save(
            os.path.join(out, "preview_first.png"))
        video[0].frame(0).convert("RGB").save(os.path.join(out, "scene0_first.png"))
        # the last frame of the video, the same as its first
        i, t = frame_times(video, FPS)[-1]
        video[i].frame(t).convert("RGB").save(os.path.join(out, "scene%d_last.png" % i))
        print("frames in", out)
        if "--only-frames" in sys.argv:
            return
    mp4 = os.path.join(MEDIA, "demo.mp4")
    encode(video, FPS, ["-c:v", "libx264", "-preset", "veryslow", "-crf", "20", "-tune", "animation", "-pix_fmt", "yuv420p",
                        "-movflags", "+faststart", mp4])
    write_poster(video)
    first = preview[0]
    if not preview_start(first) < first.duration - first.fade_out:
        print("warning: the first frame of the preview is not its first card in full view (preview_start)")
    webp = os.path.join(MEDIA, "demo_preview.webp")
    write_preview(preview, webp)
    for path, length in ((mp4, total), (webp, sum(s.duration for s in preview)), (os.path.join(MEDIA, "demo_poster.png"), 0)):
        print("%s: %.0f kB%s" % (os.path.relpath(path, ROOT), os.path.getsize(path) / 1024, ", %.1f s" % length if length else ""))


if __name__ == "__main__":
    main()
