"""Writes index.html, the website of Summa (GitHub Pages serves the main branch: https://n4sd4q.github.io/Summa/),
from the sources of every fact on it: README.md (tagline, what it does, the first example, installation, scope, checks,
related software, the documents), Summa/PacletInfo.wl (version, requirement, license), CITATION.cff (date, how to cite),
the PDFs (pages). Its look is the common one of the packages: Development/family.css and Development/palette.json are copies
of the files of the hub (https://github.com/n4sd4q/n4sd4q.github.io, design/). The formulas are typeset by pdflatex and
written into the page as SVG in the colour of the text, so that they read on light and dark pages; the page loads nothing
from elsewhere.

    python3 Development/make_site.py            # writes index.html
    python3 Development/make_site.py --check    # exits with 1 if index.html is not what the sources give
"""
import hashlib, html, json, math, os, re, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = "https://github.com/n4sd4q/Summa"
SITE = "https://n4sd4q.github.io/Summa/"
HUB = "https://n4sd4q.github.io/"
NAME = "Summa"


def read(*p):
    with open(os.path.join(ROOT, *p), encoding="utf-8") as f:
        return f.read()


def need(pattern, text, what, flags=re.S):
    m = re.search(pattern, text, flags)
    if not m:
        sys.exit("make_site.py: cannot find %s in the sources" % what)
    return m


# ------------------------------------------------------------------------------------------------ colours
def rgb(h):
    return [int(h[i:i + 2], 16) for i in (1, 3, 5)]


def mix(a, b, t):
    return "#" + "".join("%02X" % round(t * x + (1 - t) * y) for x, y in zip(rgb(a), rgb(b)))


def rgba(h, alpha):
    return "rgba(%d, %d, %d, %s)" % (*rgb(h), alpha)


def stylesheet():
    pal = json.loads(read("Development", "palette.json"))
    o = next(x for x in pal[NAME] if x["label"] == pal["chosen"][NAME])
    s, e, a, t = o["start"], o["end"], o["accent"], o["tint"]
    light = {"accent": a, "accent-soft": mix(a, "#ffffff", 0.09), "link": a, "code-name": a, "focus": a, "tint": t,
             "hero-1": s, "hero-2": e, "hero-text-2": mix(t, "#ffffff", 0.5), "glow": rgba(t, 0.24),
             "bar": rgba(mix(s, "#000000", 0.92), 0.94), "primary-bg": "#ffffff", "primary-text": s, "primary-hover": mix(t, "#ffffff", 0.18)}
    dark = {"accent": t, "accent-soft": mix(t, "#0b141d", 0.16), "link": t, "code-name": t, "focus": t, "tint": t,
            "hero-1": mix(s, "#000000", 0.78), "hero-2": mix(e, "#000000", 0.62), "hero-text-2": mix(t, "#ffffff", 0.62),
            "glow": rgba(t, 0.16), "bar": rgba(mix(s, "#000000", 0.7), 0.94), "primary-bg": t,
            "primary-text": mix(s, "#000000", 0.6), "primary-hover": mix(t, "#ffffff", 0.7)}
    css = read("Development", "family.css")
    css = css.replace("/*ACCENT-LIGHT*/", " ".join("--%s: %s;" % kv for kv in light.items()))
    css = css.replace("/*ACCENT-DARK*/", " ".join("--%s: %s;" % kv for kv in dark.items()))
    block = css[css.index(':root[data-theme="dark"] {') + len(':root[data-theme="dark"] {'):]
    block = block[:block.index("\n}")]
    css = css.replace("/*DARK-COPY*/", " ".join(l.strip() for l in block.strip().splitlines()))
    return css, s


# ------------------------------------------------------------------------------------------------ formulas
class Formulas:
    """every formula of the page, typeset in one run of pdflatex, one page each, and written as SVG"""

    def __init__(self):
        self.items = []

    def add(self, tex, display):
        key = "m" + hashlib.sha1((("D" if display else "T") + tex).encode()).hexdigest()[:8]
        if key not in [k for k, _, _ in self.items]:
            self.items.append((key, tex, display))
        return "\0%s\0" % key

    def render(self):
        out = {}
        if not self.items:
            return out
        with tempfile.TemporaryDirectory() as tmp:
            body = []
            for k, (key, tex, display) in enumerate(self.items):
                style = "\\displaystyle" if display else "\\textstyle"
                body.append("\\setbox0=\\hbox{$%s %s$}\\pdfpagewidth=\\dimexpr\\wd0+2pt\\relax\\pdfpageheight=\\dimexpr\\ht0+\\dp0+2pt\\relax"
                            "\\immediate\\write16{DIM %d \\the\\wd0 x\\the\\ht0 x\\the\\dp0}"
                            "\\shipout\\vbox{\\kern1pt\\hbox{\\kern1pt\\box0\\kern1pt}\\kern1pt}" % (style, tex, k))
            doc = ("\\documentclass{article}\\usepackage[T1]{fontenc}\\usepackage[sc]{mathpazo}\\usepackage{amsmath,amssymb,bm}"
                   "\\hoffset=-1in\\voffset=-1in\\topskip=0pt\\begin{document}\n" + "\n".join(body) + "\n\\end{document}\n")
            with open(os.path.join(tmp, "f.tex"), "w") as f:
                f.write(doc)
            run = subprocess.run(["pdflatex", "-interaction=nonstopmode", "-halt-on-error", "f.tex"], cwd=tmp, capture_output=True, text=True)
            if run.returncode != 0:
                sys.exit("make_site.py: pdflatex failed on the formulas:\n" + run.stdout[-1500:])
            dims = {int(m.group(1)): [float(x) for x in m.groups()[1:]] for m in
                    re.finditer(r"DIM (\d+) ([\d.]+)ptx([\d.]+)ptx([\d.]+)pt", run.stdout)}
            for k, (key, tex, display) in enumerate(self.items):
                svgfile = os.path.join(tmp, "f%d.svg" % k)
                subprocess.run(["pdftocairo", "-svg", "-f", str(k + 1), "-l", str(k + 1), os.path.join(tmp, "f.pdf"), svgfile], check=True)
                svg = open(svgfile).read()
                svg = svg[svg.index("<svg"):]
                svg = re.sub(r'(id="|href="#|url\(#)([^"\)]+)', lambda m: m.group(1) + key + "-" + m.group(2), svg)
                svg = re.sub(r'fill="rgb\(0%, ?0%, ?0%\)"', 'fill="currentColor"', svg)
                svg = re.sub(r'stroke="rgb\(0%, ?0%, ?0%\)"', 'stroke="currentColor"', svg)
                wd, ht, dp = dims[k]
                scale = 0.118 if display else 0.104      # em per pt: the formula a little larger than the text around it
                h, w, v = (ht + dp + 2) * scale, (wd + 2) * scale, -(dp + 1) * scale
                svg = re.sub(r'<svg ([^>]*?)width="[^"]*" height="[^"]*"',
                             lambda m: '<svg %swidth="%.3fem" height="%.3fem" role="img" aria-label="%s" style="vertical-align: %.3fem"'
                             % (m.group(1), w, h, html.escape(tex, quote=True), v), svg, count=1)
                out[key] = svg.strip()
        return out


# ------------------------------------------------------------------------------------------------ Markdown, the little the README uses
def link_target(url):
    if url.startswith(SITE) and url != SITE:
        return url[len(SITE):]                                # a file served by Pages next to the page
    if re.match(r"https?://|#", url):
        return url
    if url.endswith(".pdf") or url.endswith(".svg"):
        return url                                            # served by Pages
    return REPO + ("/tree/main/" if "." not in os.path.basename(url) else "/blob/main/") + url


def inline(text, fx):
    """[text](url) (its text may hold code), then **bold**, `code` and ``code``, $math$; everything else escaped"""
    out, pos = [], 0
    for m in re.finditer(r"\[((?:[^\[\]`]|`[^`]*`)+)\]\(([^)\s]+)\)", text):
        out.append(spans(text[pos:m.start()], fx))
        out.append('<a href="%s">%s</a>' % (html.escape(link_target(m.group(2))), spans(m.group(1), fx)))
        pos = m.end()
    out.append(spans(text[pos:], fx))
    return "".join(out)


def spans(text, fx):
    parts, pos = [], 0
    pattern = re.compile(r"``\s?(.+?)\s?``|`([^`]+)`|\$([^$]+)\$")
    for m in pattern.finditer(text):
        parts.append(("t", text[pos:m.start()]))
        if m.group(3) is not None:
            parts.append(("m", m.group(3)))
        else:
            parts.append(("c", m.group(1) if m.group(1) is not None else m.group(2)))
        pos = m.end()
    parts.append(("t", text[pos:]))
    out = []
    for kind, s in parts:
        if kind == "c":
            out.append("<code>%s</code>" % html.escape(s))
        elif kind == "m":
            out.append(fx.add(from_github(s), False))
        else:
            s = html.escape(s, quote=False)
            s = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", s)
            out.append(s)
    return "".join(out)


def from_github(tex):
    """the formulas as GitHub needs them written in a README, back to plain LaTeX"""
    return tex.replace("^{\\ast}", "^*").replace("\\\\{", "\\{").replace("\\\\}", "\\}").replace("\\thinspace ", "\\,")


def blocks(md):
    """paragraphs, code blocks, display formulas and HTML lines, in order"""
    out, para = [], []
    lines = md.split("\n")
    i = 0
    flush = lambda: (out.append(("p", " ".join(para))), para.clear()) if para else None
    while i < len(lines):
        l = lines[i]
        if l.startswith("```"):
            flush(); j = i + 1
            while not lines[j].startswith("```"):
                j += 1
            lang, content = l[3:].strip(), "\n".join(lines[i + 1:j])
            out.append(("mathblock" if lang == "math" else "text" if lang == "text" else "code", content)); i = j + 1; continue
        if l.startswith("$$"):
            flush(); j = i
            while not lines[j].rstrip().endswith("$$") or (j == i and lines[j].strip() == "$$"):
                j += 1
            out.append(("math", " ".join(lines[i:j + 1]).strip()[2:-2])); i = j + 1; continue
        if l.startswith("<p") or l.startswith("<img"):
            flush(); j = i
            while "</p>" not in lines[j] and not lines[j].rstrip().endswith(">"):
                j += 1
            out.append(("html", "\n".join(lines[i:j + 1]))); i = j + 1; continue
        if l.startswith("- "):
            flush(); items = [l[2:].strip()]; i += 1
            while i < len(lines) and (lines[i].startswith("- ") or lines[i].startswith("  ")) and lines[i].strip():
                if lines[i].startswith("- "):
                    items.append(lines[i][2:].strip())
                else:
                    items[-1] += " " + lines[i].strip()
                i += 1
            out.append(("list", items)); continue
        if not l.strip():
            flush()
        else:
            para.append(l.strip())
        i += 1
    flush()
    return out


def section(readme, title):
    return need(r"\n## %s\n(.*?)(?=\n## |\Z)" % re.escape(title), readme, "the section " + title).group(1)


# ------------------------------------------------------------------------------------------------ the page
ICONS = {
    "GITHUB": '<svg viewBox="0 0 16 16" aria-hidden="true" focusable="false"><path fill="currentColor" d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8z"/></svg>',
    "MOON": '<svg class="moon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M20.5 14.2A8.5 8.5 0 0 1 9.8 3.5a8.5 8.5 0 1 0 10.7 10.7z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/></svg>',
    "SUN": '<svg class="sun" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><g fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><circle cx="12" cy="12" r="4.2"/><path d="M12 2.5v2.2M12 19.3v2.2M2.5 12h2.2M19.3 12h2.2M5.3 5.3l1.6 1.6M17.1 17.1l1.6 1.6M5.3 18.7l1.6-1.6M17.1 6.9l1.6-1.6"/></g></svg>',
    # the mark of the hub (a plaquette of four sites), for the link to all the packages
    "HUB": '<svg viewBox="22 22 84 84" aria-hidden="true" focusable="false"><g fill="none" stroke="currentColor" stroke-linecap="round"><path d="M36 36H92V92H36Z" stroke-width="7"/><path d="M47 81 L50 82 L52 82 L53 80 L52 77 L51 74 L51 71 L52 70 L55 71 L58 72 L61 72 L63 72 L63 69 L61 66 L60 63 L61 61 L63 60 L66 61 L69 63 L72 63 L72 61 L72 58 L71 55 L70 52 L71 51 L74 51 L77 52 L80 53 L82 52 L82 50 L81 47" stroke-width="6" stroke-linejoin="round" opacity="0.8"/></g><g fill="currentColor"><circle cx="36" cy="36" r="10"/><circle cx="92" cy="36" r="10"/><circle cx="92" cy="92" r="10"/><circle cx="36" cy="92" r="10"/></g></svg>',
    "COPY": '<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><g fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"><rect x="8.5" y="8.5" width="12" height="12" rx="2.2"/><path d="M15.5 8.5V5.7a2.2 2.2 0 0 0-2.2-2.2H5.7a2.2 2.2 0 0 0-2.2 2.2v7.6a2.2 2.2 0 0 0 2.2 2.2h2.8"/></g></svg>',
}


def wave(width=150, height=18, waves=4.5, margin=3):
    return "M " + " L ".join("%.2f %.2f" % (margin + (width - 2 * margin) * k / 120,
                                             height / 2 - (height / 2 - margin) * math.sin(2 * math.pi * waves * k / 120)) for k in range(121))


def code_html(code):
    """Wolfram Language with comments, strings and the names of the package marked"""
    names = set(re.findall(r'^([A-Za-z$][A-Za-z0-9$]*)::usage', read(NAME, "Kernel", "Summa.wl"), re.M))
    out, pos = [], 0
    for m in re.finditer(r'\(\*.*?\*\)|"(?:[^"\\]|\\.)*"|[A-Za-z$][A-Za-z0-9$]*', code, re.S):
        out.append(html.escape(code[pos:m.start()]))
        t = m.group(0)
        if t.startswith("(*"):
            out.append('<span class="tok-c">%s</span>' % html.escape(t))
        elif t.startswith('"'):
            out.append('<span class="tok-s">%s</span>' % html.escape(t))
        elif t in names:
            out.append('<span class="tok-f">%s</span>' % html.escape(t))
        else:
            out.append(html.escape(t))
        pos = m.end()
    out.append(html.escape(code[pos:]))
    return "".join(out)


class Ids:
    n = 0

    def next(self):
        self.n += 1
        return "c%d" % self.n


def copyable(code, ids, label="Copy"):
    i = ids.next()
    return ('<div class="oneliner"><pre id="%s"><code>%s</code></pre><button class="copy" type="button" data-copy="%s" aria-label="%s">%s'
            '<span class="label">Copy</span></button></div>' % (i, code_html(code), i, html.escape(label), ICONS["COPY"]))


def render_flow(items, fx, ids, install=False):
    out = []
    for kind, s in items:
        if kind == "p":
            out.append("<p>%s</p>" % inline(s, fx))
        elif kind == "code":
            out.append(copyable(s, ids) if install else
                       '<div class="codecard"><pre><code>%s</code></pre></div>' % code_html(s))
        elif kind == "math":
            out.append('<div class="formula">%s</div>' % fx.add(from_github(s), True))
        elif kind == "mathblock":
            out.append('<div class="formula">%s</div>' % fx.add(" ".join(s.split()), True))
        elif kind == "text":
            out.append('<div class="formula"><code>%s</code></div>' % html.escape(s))
        elif kind == "list":
            out.append('<ul class="bullets">%s</ul>' % "".join("<li>%s</li>" % inline(x, fx) for x in s))
        elif kind == "html":
            src = need(r'src="([^"]+)"', s, "a picture").group(1)
            alt = re.sub(r"\s+", " ", need(r'alt="([^"]+)"', s, "the alternative text of a picture").group(1))
            width = need(r'width="(\d+)"', s, "the width of a picture").group(1)
            out.append('<figure class="picture">%s</figure>' % (inline_svg(src, width, alt) if src.endswith(".svg") else
                       '<img class="paper" src="%s" width="%s" style="width: %spx" alt="%s">' % (html.escape(src), width, width, html.escape(alt))))
    return "\n".join(out)


def inline_svg(src, width, alt):
    """a picture of the README (ink in currentColor, drawn by make_readme_picture.py) inlined in the page, so that its ink
    takes the colour of the text in both themes: without its own style, its ids prefixed so as not to meet those of the
    formulas"""
    svg = open(os.path.join(ROOT, src), encoding="utf-8").read()
    prefix = re.sub(r"\W", "-", os.path.splitext(os.path.basename(src))[0]) + "-"
    svg = re.sub(r"<\?xml[^>]*>\s*", "", svg)
    svg = re.sub(r"<style>.*?</style>\s*", "", svg, flags=re.S)
    svg = svg.replace('id="', 'id="' + prefix).replace('href="#', 'href="#' + prefix).replace("url(#", "url(#" + prefix)
    svg = re.sub(r'<svg([^>]*?) width="[^"]*" height="[^"]*"', r'<svg\1', svg, count=1)
    return svg.replace("<svg", '<svg role="img" aria-label="%s" style="display: block; width: %spx; max-width: 100%%; height: auto; '
                       'margin: 0 auto"' % (html.escape(alt), width), 1)


def pages(pdf):
    out = subprocess.run(["pdfinfo", os.path.join(ROOT, pdf)], capture_output=True, text=True).stdout
    return int(need(r"Pages:\s+(\d+)", out, "the pages of " + pdf).group(1))


def build():
    readme = read("README.md")
    paclet = read(NAME, "PacletInfo.wl")
    cff = read("CITATION.cff")
    fx, ids = Formulas(), Ids()
    css, start = stylesheet()
    version = need(r'"Version" -> "([^"]+)"', paclet, "the version").group(1)
    requirement = need(r'"WolframVersion" -> "([\d.]+)\+"', paclet, "the Wolfram version").group(1)
    license_ = need(r'"License" -> "([^"]+)"', paclet, "the license").group(1)
    date = need(r"date-released: (\S+)", cff, "the release date").group(1)
    tests = need(r"tests-(\d+)%20passed", readme, "the number of tests").group(1)
    tagline, subline = need(r"<b>(.*?)</b><br>\s*(.*?)\n</p>", readme, "the tagline").groups()
    tagline_short = "Fast Einstein summation"
    lead = need(r"</p>\n\n(Summa contracts tensors.*?)\n\n(?:<p align=\"center\">.*?</p>\n\n)?## What it does", readme,
                "the opening paragraph").group(1)
    # the demo video (Development/make_demo_video.py), under the hero, when it is there
    has_demo = os.path.exists(os.path.join(ROOT, "Media", "demo.mp4"))
    demo = ('<div class="demo"><div class="wrap"><figure><div class="screen">'
            '<video id="demo" muted loop playsinline controls preload="metadata" width="1920" height="1080" '
            'poster="Media/demo_poster.png" aria-label="The demo video of Summa">'
            '<source src="Media/demo.mp4" type="video/mp4"><a href="Media/demo.mp4">The demo video (MP4)</a></video>'
            '</div></figure></div></div>\n') if has_demo else ""
    what_md = section(readme, "What it does")
    items = re.findall(r"^- \*\*(.+?)\*\* (.*?)(?=^- |\n\n)", what_md, re.S | re.M)
    after = need(r"\n\n(Every result is checked.*?)\n\n", what_md, "the sentence after the list").group(1)
    what = "".join("<li><strong>%s</strong><span>%s</span></li>" % (inline(a.rstrip("."), fx), inline(" ".join(b.split()), fx)) for a, b in items)
    example = render_flow(blocks(section(readme, "A first example")), fx, ids)
    install = render_flow(blocks(section(readme, "Installation")), fx, ids, install=True)
    checks = section(readme, "Checks").strip()
    related = section(readme, "Related software").strip()
    doc_rows = re.findall(r"^\| \[(.+?)\]\((.+?)\)(?: \(PDF\))? \| (.+?) \|$", section(readme, "Documentation"), re.M)
    docs = []
    for name_, url, what_ in doc_rows:
        if url == SITE:
            continue                                          # the row of the website itself
        url = link_target(url) if url.startswith(SITE) else url  # the PDFs: the README links them on Pages
        kind = (("PDF, %d pages" % pages(url)) if os.path.exists(os.path.join(ROOT, url)) else "PDF") if url.endswith(".pdf") else ("notebook" if url.endswith(".wl") else
                ("GitHub wiki" if url.endswith("/wiki") else "Markdown"))
        docs.append('<a class="doc" href="%s"><strong>%s</strong><span>%s</span><small>%s</small></a>'
                    % (html.escape(link_target(url)), html.escape(name_), inline(what_, fx), kind))
    year = date[:4]
    bibtex = ("@software{africani_summa,\n  author  = {Africani, Nazzareno},\n  title   = {{Summa}: %s},\n  version = {%s},\n"
              "  year    = {%s},\n  url     = {%s}\n}" % (need(r'title: "Summa: (.*?)"', cff, "the title").group(1), version, year, REPO))
    showcase = "Showcase/Summa_Showcase.pdf"
    manual = "Documentation/Summa_Manual.pdf"
    body = f'''<div class="topbar"><div class="wrap">
<a class="brand" href="#top"><img src="Logo/Summa_logo_white.svg" width="30" height="30" alt="">{NAME}</a>
<nav aria-label="Sections"><ul class="navlinks"><li><a href="#what">What it does</a></li><li><a href="#example">Example</a></li>
<li><a href="#install">Install</a></li><li><a href="#docs">Documentation</a></li><li><a href="#cite">Cite</a></li></ul></nav>
<a class="iconbtn" href="{HUB}" aria-label="All the packages of the author">{ICONS["HUB"]}<span class="label">All packages</span></a>
<a class="iconbtn" href="{REPO}" aria-label="The repository on GitHub">{ICONS["GITHUB"]}<span class="label">GitHub</span></a>
<button class="iconbtn theme" id="theme" type="button" aria-label="Switch between the light and the dark theme">{ICONS["MOON"]}{ICONS["SUN"]}</button>
</div></div>
<header class="hero{" with-demo" if has_demo else ""}"><div class="wrap">
<img class="hero-logo" src="Logo/Summa_logo_white.svg" width="92" height="92" alt="The logo of Summa: the sigma of a sum drawn as a tensor network">
<h1>{NAME}</h1>
<p class="tagline">{html.escape(tagline_short)}</p>
<p class="subline">{html.escape(subline[:1].upper() + subline[1:])}, in the Wolfram Language</p>
<svg class="wave" viewBox="0 0 150 18" aria-hidden="true" focusable="false"><path d="{wave()}" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>
<div class="actions"><a class="btn btn-primary" href="#install">Install</a><a class="btn btn-ghost" href="{showcase}">Showcase <small>PDF</small></a>
<a class="btn btn-ghost" href="{manual}">Manual <small>PDF</small></a><a class="btn btn-ghost" href="{REPO}">{ICONS["GITHUB"]}GitHub</a></div>
<ul class="facts"><li>Version {version} ({date})</li><li>Mathematica {requirement} or later</li><li><a href="{REPO}/tree/main/Tests">{tests} tests pass</a></li><li>{license_}</li></ul>
</div></header>
{demo}<main id="main">
<section id="what" aria-labelledby="what-title"><div class="wrap"><h2 id="what-title">What it does</h2>
<p class="lead">{inline(" ".join(lead.split()), fx)}</p><ul class="list">{what}</ul>
<p class="note">{inline(after, fx)}</p></div></section>
<section id="example" class="band" aria-labelledby="example-title"><div class="wrap"><h2 id="example-title">A first example</h2>
<div class="flow">{example}</div></div></section>
<section id="install" aria-labelledby="install-title"><div class="wrap"><h2 id="install-title">Installation</h2>
<div class="flow">{install}</div></div></section>
<section id="docs" class="band" aria-labelledby="docs-title"><div class="wrap"><h2 id="docs-title">Documentation</h2>
<div class="docs">{"".join(docs)}</div></div></section>
<section id="checks" aria-labelledby="checks-title"><div class="wrap duo">
<div><h2 id="checks-title">Checks</h2>{render_flow(blocks(checks), fx, ids)}</div>
<div><h2>Related software</h2>{render_flow(blocks(related), fx, ids)}</div></div></section>
<section id="cite" class="band" aria-labelledby="cite-title"><div class="wrap"><h2 id="cite-title">How to cite</h2>
<p>If you use {NAME} in published work, please cite it (<a href="{REPO}/blob/main/CITATION.cff">CITATION.cff</a>):</p>
{copyable(bibtex, ids, "Copy the BibTeX entry")}</div></section>
</main>
<footer><div class="wrap foot"><div class="who"><img src="Logo/Summa_logo.svg" width="36" height="36" alt=""><div><strong>{NAME}</strong>Nazzareno Africani, SISSA, Trieste</div></div>
<ul><li><a href="{REPO}">GitHub</a></li><li><a href="{REPO}/blob/main/CHANGELOG.md">Changelog</a></li><li><a href="{HUB}">All the packages</a></li></ul>
<p class="license">{inline(section(readme, "License").strip(), fx)}</p></div></footer>'''
    svgs = fx.render()
    body = re.sub("\0(m[0-9a-f]{8})\0", lambda m: svgs[m.group(1)], body)
    description = "%s: %s in the Wolfram Language." % (NAME, tagline)
    page = f'''<!doctype html>
<!-- The website of Summa, generated by Development/make_site.py from README.md, Summa/PacletInfo.wl, CITATION.cff and
     the PDFs, with the common look of the packages (Development/family.css): edit those, then run python3 Development/make_site.py. -->
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(NAME + ": " + tagline_short)}</title>
<meta name="description" content="{html.escape(description)}">
<link rel="canonical" href="{SITE}">
<link rel="icon" href="Logo/Summa_logo_small.svg" type="image/svg+xml">
<meta name="color-scheme" content="light dark">
<meta name="theme-color" content="{start}">
<meta property="og:type" content="website"><meta property="og:title" content="{html.escape(NAME + ": " + tagline_short)}">
<meta property="og:description" content="{html.escape(description)}"><meta property="og:url" content="{SITE}">
<script>
  try {{ var t = localStorage.getItem('Summa.theme'); if (t === 'light' || t === 'dark') document.documentElement.setAttribute('data-theme', t); }} catch (e) {{}}
</script>
<style>
{css}
</style>
</head>
<body id="top">
<a class="skip" href="#main">Skip to the content</a>
{body}
<p class="sr-only" id="copy-status" aria-live="polite"></p>
<script>
(function () {{
  var root = document.documentElement, key = 'Summa.theme', button = document.getElementById('theme');
  var system = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : null;
  function dark() {{ var t = root.getAttribute('data-theme'); return t ? t === 'dark' : !!(system && system.matches); }}
  function label() {{ var text = dark() ? 'Switch to the light theme' : 'Switch to the dark theme'; button.setAttribute('aria-label', text); button.title = text; }}
  button.addEventListener('click', function () {{ var next = dark() ? 'light' : 'dark'; root.setAttribute('data-theme', next);
    try {{ localStorage.setItem(key, next); }} catch (e) {{}} label(); }});
  if (system && system.addEventListener) system.addEventListener('change', label);
  label();
  var demo = document.getElementById('demo');   // the video plays by itself, muted, unless the reader asks for reduced motion
  if (demo && !(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches)) {{
    var playing = demo.play();
    if (playing && playing.catch) playing.catch(function () {{}});
  }}
  var status = document.getElementById('copy-status');
  document.querySelectorAll('.copy').forEach(function (btn) {{
    btn.addEventListener('click', function () {{
      var text = document.getElementById(btn.getAttribute('data-copy')).textContent, l = btn.querySelector('.label');
      function done(ok) {{ btn.classList.toggle('done', ok); l.textContent = ok ? 'Copied' : 'Select and copy';
        status.textContent = ok ? 'Copied to the clipboard' : 'Could not copy: select the text and copy it';
        clearTimeout(btn.timer); btn.timer = setTimeout(function () {{ btn.classList.remove('done'); l.textContent = 'Copy'; status.textContent = ''; }}, 1800); }}
      if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(function () {{ done(true); }}, function () {{ done(false); }});
      else done(false);
    }});
  }});
}})();
</script>
</body>
</html>
'''
    return page


def main():
    page = build()
    target = os.path.join(ROOT, "index.html")
    if "--check" in sys.argv:
        current = open(target, encoding="utf-8").read() if os.path.exists(target) else ""
        if current != page:
            sys.exit("index.html is not up to date: run python3 Development/make_site.py")
        print("index.html is up to date")
        return
    with open(target, "w", encoding="utf-8") as f:
        f.write(page)
    print("written index.html (%d kB)" % (len(page.encode()) // 1024))


if __name__ == "__main__":
    main()
