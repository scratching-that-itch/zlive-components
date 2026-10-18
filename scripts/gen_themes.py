#!/usr/bin/env python3
"""Regenerate the theme blocks in zc.css from shadcn's theme registry.

shadcn keeps its themes in the shadcn-ui/ui repo, `apps/v4/registry/themes.ts`:
seven *base colors* (neutral, stone, zinc, mauve, olive, mist, taupe) each
carrying the full token set, and seventeen *accent themes* (amber, blue, cyan,
…) that only override `--primary`, `--secondary`, the five chart colors and
`--sidebar-primary`, and therefore layer on top of whichever base is active.
That file is the source of truth for this script; it is vendored next to this
script so regeneration works offline and the audit is reproducible.

    python3 scripts/gen_themes.py            # rewrite the generated files
    python3 scripts/gen_themes.py --check    # fail if they are out of date
    python3 scripts/gen_themes.py --fetch    # refresh the vendored source

It rewrites exactly two things:

  * the region of `src/zc.css` between the `@themes:begin` / `@themes:end`
    markers — the `:root` default, the seven base blocks and the seventeen
    accent blocks, each in its light and dark form;
  * `src/themes.zig` — the list the demo's theme picker and `/themes` page
    render from.

Everything else in zc.css (radii/shadows, the demo's own colours, the
component rules) is hand-written and left alone.
"""

from __future__ import annotations

import argparse
import hashlib
import pathlib
import re
import sys
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent
CSS = HERE.parent / "src" / "zc.css"
ZIG = HERE.parent / "src" / "themes.zig"
VENDORED = HERE / "shadcn-themes.ts"

SOURCE_URL = "https://raw.githubusercontent.com/shadcn-ui/ui/main/apps/v4/registry/themes.ts"
BEGIN = "/* @themes:begin */"
END = "/* @themes:end */"
# Everything a previous run wrote *before* the begin marker: the generated
# header comment and the provenance line. Stripping it keeps regenerating an
# unchanged registry byte-identical, which is what --check relies on.
GENERATED_HEAD_RE = re.compile(
    r"/\* shadcn's themes, generated from the registry.*?\*/\s*\n"
    r"(?:/\* source: shadcn-ui/ui .*?\*/\s*\n)?\Z",
    re.S,
)

# shadcn's own base-color list (apps/v4/registry/base-colors.ts): the themes
# that carry a complete token set. Everything else is an accent.
BASE_NAMES = ["neutral", "stone", "zinc", "mauve", "olive", "mist", "taupe"]


# --------------------------------------------------------------------------
# parsing the registry
# --------------------------------------------------------------------------

def match_brace(text: str, open_index: int) -> str:
    """The `{...}` block starting at `open_index`, braces balanced."""
    assert text[open_index] == "{", text[open_index : open_index + 20]
    depth = 0
    for i in range(open_index, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[open_index : i + 1]
    raise SystemExit("unbalanced braces in the registry source")


def parse_pairs(block: str) -> list[tuple[str, str]]:
    """`key: "value"` / `"key": "value"` pairs, in source order."""
    pairs = []
    for line in block.splitlines():
        m = re.match(r'\s*"?([A-Za-z0-9-]+)"?:\s*"([^"]*)",?\s*$', line)
        if m:
            pairs.append((m.group(1), m.group(2)))
    return pairs


def parse_themes(text: str) -> list[dict]:
    """Every `registry:theme` item, with its light/dark cssVars."""
    themes = []
    for m in re.finditer(r"\n  \{\n", text):
        item = match_brace(text, m.start() + 3)
        name = re.search(r'name:\s*"([^"]+)"', item)
        title = re.search(r'title:\s*"([^"]+)"', item)
        kind = re.search(r'type:\s*"([^"]+)"', item)
        if not (name and title and kind):
            continue
        if kind.group(1) != "registry:theme":
            continue
        cvars_at = item.index("cssVars:")
        cvars = match_brace(item, item.index("{", cvars_at))
        modes = {}
        for mode in ("light", "dark"):
            at = cvars.index(mode + ":")
            modes[mode] = parse_pairs(match_brace(cvars, cvars.index("{", at)))
        themes.append(
            {"name": name.group(1), "title": title.group(1), **modes}
        )
    if not themes:
        raise SystemExit("no themes parsed — did shadcn's file change shape?")
    return themes


# --------------------------------------------------------------------------
# emitting the CSS
# --------------------------------------------------------------------------

def block(selectors: list[str], pairs: list[tuple[str, str]]) -> str:
    head = ",\n".join(selectors)
    body = "\n".join(f"  --{k}: {v};" for k, v in pairs)
    return f"{head} {{\n{body}\n}}\n"


def css_for(themes: list[dict], provenance: str) -> str:
    by_name = {t["name"]: t for t in themes}
    bases = [by_name[n] for n in BASE_NAMES]
    accents = [t for t in themes if t["name"] not in BASE_NAMES]

    out = [
        "/* shadcn's themes, generated from the registry (see scripts/gen_themes.py).",
        " *",
        " * Composition, mirroring shadcn's own model:",
        " *   [data-base=\"<base>\"]     one of the seven base colors; it carries the",
        " *                           whole token set. `neutral` is also the :root",
        " *                           default, so an unthemed page looks like shadcn.",
        " *   [data-accent=\"<accent>\"] an accent theme; it overrides only primary,",
        " *                           secondary, the chart ramp and sidebar-primary,",
        " *                           layering on whatever base is active.",
        " *   [data-theme=\"dark\"]      the mode, on <html> (see pages/theme.js).",
        " *",
        " * Both attributes work on any element, not just <html>, which is how the",
        " * /themes page previews every palette at once: a wrapper gets the base",
        " * tokens, and under a dark root the descendant selectors swap in the dark",
        " * values. Accent blocks come last so that, at equal specificity, an accent",
        " * wins over the base it layers on.",
        " */",
        provenance.rstrip(),
        BEGIN,
        "",
    ]

    # 1. the light half: the default, then each base, then the accents.
    out.append("/* --- light ------------------------------------------------------- */")
    out.append("")
    out.append("/* the default (neutral) also sits on :root */")
    out.append(block([":root", '[data-base="neutral"]'], bases[0]["light"]))
    for theme in bases[1:]:
        out.append(block([f'[data-base="{theme["name"]}"]'], theme["light"]))
    for theme in accents:
        out.append(block([f'[data-accent="{theme["name"]}"]'], theme["light"]))

    # 2. the dark half, in the same order.
    out.append("/* --- dark -------------------------------------------------------- */")
    out.append("")
    out.append("/* the default (neutral) also sits on :root[data-theme=dark] */")
    out.append(
        block(
            [
                ':root[data-theme="dark"]',
                '[data-theme="dark"][data-base="neutral"]',
                '[data-theme="dark"] [data-base="neutral"]',
            ],
            bases[0]["dark"],
        )
    )
    for theme in bases[1:]:
        name = theme["name"]
        out.append(
            block(
                [
                    f'[data-theme="dark"][data-base="{name}"]',
                    f'[data-theme="dark"] [data-base="{name}"]',
                ],
                theme["dark"],
            )
        )
    for theme in accents:
        name = theme["name"]
        out.append(
            block(
                [
                    f'[data-theme="dark"][data-accent="{name}"]',
                    f'[data-theme="dark"] [data-accent="{name}"]',
                ],
                theme["dark"],
            )
        )
    out.append(END)
    return "\n".join(out) + "\n"


def zig_for(themes: list[dict]) -> str:
    by_name = {t["name"]: t for t in themes}
    bases = [by_name[n] for n in BASE_NAMES]
    accents = [t for t in themes if t["name"] not in BASE_NAMES]

    def entry(theme: dict, kind: str) -> str:
        overrides = ", ".join(f'"{k}"' for k, _ in theme["light"])
        return (
            f'    .{{ .name = "{theme["name"]}", .title = "{theme["title"]}", '
            f'.kind = .{kind},\n'
            f'       .overrides = &.{{ {overrides} }} }},'
        )

    lines = [
        "//! shadcn's theme registry, generated from the shadcn-ui/ui source by",
        "//! `scripts/gen_themes.py` — do not edit by hand; re-run the script.",
        "//!",
        "//! A **base** theme carries the whole token set (`data-base`); an **accent**",
        "//! theme overrides only the tokens listed in `overrides` (`data-accent`) and",
        "//! layers on top of whichever base is active. `neutral` is also the default",
        "//! on `:root`, and every theme has a light and a dark form — see zc.css.",
        "",
        "pub const Kind = enum { base, accent };",
        "",
        "pub const Theme = struct {",
        "    /// The `data-base` / `data-accent` attribute value.",
        "    name: []const u8,",
        "    /// shadcn's display title.",
        "    title: []const u8,",
        "    kind: Kind,",
        "    /// The custom properties the theme sets (`--` omitted).",
        "    overrides: []const []const u8,",
        "};",
        "",
        "/// The seven base colors (shadcn's `BASE_COLORS`).",
        "pub const bases = [_]Theme{",
    ]
    lines += [entry(t, "base") for t in bases]
    lines += [
        "};",
        "",
        "/// The accent themes, which layer on a base.",
        "pub const accents = [_]Theme{",
    ]
    lines += [entry(t, "accent") for t in accents]
    lines += [
        "};",
        "",
        "/// Every theme, bases first.",
        "pub const all = bases ++ accents;",
        "",
        "/// The number of tokens a base theme carries, and the number an accent",
        "/// overrides — the two shapes the stylesheet has to reproduce.",
        "pub const base_token_count = bases[0].overrides.len;",
        "pub const accent_token_count = accents[0].overrides.len;",
        "",
        "/// Look a base theme up by its attribute value.",
        "pub fn base(name: []const u8) ?Theme {",
        "    for (bases) |t| if (std.mem.eql(u8, t.name, name)) return t;",
        "    return null;",
        "}",
        "",
        "/// Look an accent theme up by its attribute value.",
        "pub fn accent(name: []const u8) ?Theme {",
        "    for (accents) |t| if (std.mem.eql(u8, t.name, name)) return t;",
        "    return null;",
        "}",
        "",
        "const std = @import(\"std\");",
        "",
    ]
    return "\n".join(lines)


# --------------------------------------------------------------------------
# verifying the generated CSS
# --------------------------------------------------------------------------
#
# There is no browser in this environment, so the parts that would normally be
# checked by looking at the page are checked here instead, against a small
# simulator of exactly the selector shapes this script emits:
#
#   1. values: each theme's CSS block must declare exactly the tokens its
#      registry item does, with exactly those values, in the same order.
#   2. composition: for a matrix of (root mode, subtree base, subtree accent)
#      contexts the cascade must resolve to the value shadcn's model implies —
#      the base's token, the accent's override, or the dark form, depending on
#      which attribute is on which element.

RULE_RE = re.compile(r"(?P<sels>[^{}]+)\{(?P<body>[^{}]*)\}")
COMPOUND_RE = re.compile(r":root|\[[a-z-]+=\"[^\"]+\"\]")


def parse_css_rules(css: str) -> list[tuple[list[str], list[tuple[str, str]]]]:
    """(selectors, declarations) for every rule in the generated region."""
    start, end = css.index(BEGIN), css.index(END)
    # comments first: they sit between rules and would otherwise be read as
    # part of the next rule's selector list
    region = re.sub(r"/\*.*?\*/", "", css[start:end], flags=re.S)
    rules = []
    for m in RULE_RE.finditer(region):
        sels = [s.strip() for s in m.group("sels").split(",") if s.strip()]
        if not sels or sels[0].startswith("---") or sels[0].startswith("*"):
            continue
        decls = re.findall(r"--([A-Za-z0-9-]+):\s*([^;]+);", m.group("body"))
        rules.append((sels, decls))
    if not rules:
        raise SystemExit("no rules found in the generated region")
    return rules


def compound_parts(compound: str) -> tuple[bool, list[tuple[str, str]]]:
    is_root = ":root" in compound
    attrs = re.findall(r'\[([a-z-]+)="([^"]+)"\]', compound)
    return is_root, attrs


def compound_matches(compound: str, el: dict) -> bool:
    is_root, attrs = compound_parts(compound)
    if is_root and not el["root"]:
        return False
    return all(k in el["attrs"] and el["attrs"][k] == v for k, v in attrs)


def selector_matches(selector: str, el: dict, ancestors: list[dict]) -> bool:
    compounds = selector.split()
    if not compound_matches(compounds[-1], el):
        return False
    for compound in reversed(compounds[:-1]):
        if not any(compound_matches(compound, a) for a in ancestors):
            return False
    return True


def specificity(selector: str) -> tuple[int, int, int]:
    classes = len(re.findall(r'\[[a-z-]+="[^"]+"\]', selector)) + selector.count(":root")
    return (0, classes, 0)


def resolve(rules, chain: list[dict]) -> dict[str, str]:
    """The custom property values on chain[-1], inheritance included."""
    props: dict[str, str] = {}
    for i, el in enumerate(chain):
        ancestors = chain[:i]
        best: dict[str, tuple] = {}
        local: dict[str, str] = {}
        for order, (sels, decls) in enumerate(rules):
            for sel in sels:
                if not selector_matches(sel, el, ancestors):
                    continue
                key = (specificity(sel), order)
                for name, value in decls:
                    if name not in best or key >= best[name]:
                        best[name] = key
                        local[name] = value
        props.update(local)
    return props


def verify(themes: list[dict], css: str) -> list[str]:
    """Every way the generated CSS could be wrong, as a list of problems."""
    by_name = {t["name"]: t for t in themes}
    bases = [by_name[n] for n in BASE_NAMES]
    accents = [t for t in themes if t["name"] not in BASE_NAMES]
    rules = parse_css_rules(css)
    problems: list[str] = []

    blocks: list[tuple[list[str], list[tuple[str, str]]]] = []
    for sels, decls in rules:
        # keep only theme blocks: they all declare the base token set
        if any(s.startswith((":root", "[")) for s in sels) and decls:
            blocks.append((sels, decls))

    # 1. values: one light and one dark block per theme, declaring exactly the
    #    registry's tokens and values.
    for theme in themes:
        kind = "base" if theme["name"] in BASE_NAMES else "accent"
        attr = "data-base" if kind == "base" else "data-accent"
        for mode in ("light", "dark"):
            want = theme[mode]
            found = [
                decls
                for sels, decls in blocks
                if any(f'{attr}="{theme["name"]}"' in s for s in sels)
                and any('data-theme="dark"' in s for s in sels) == (mode == "dark")
            ]
            if len(found) != 1:
                problems.append(
                    f'{theme["name"]} {mode}: expected one block, found {len(found)}'
                )
                continue
            if found[0] != want:
                got = dict(found[0])
                for name, value in want:
                    if got.get(name) != value:
                        problems.append(
                            f'{theme["name"]} {mode}: --{name} is '
                            f'{got.get(name)!r}, registry says {value!r}'
                        )
                for name, _ in found[0]:
                    if name not in dict(want):
                        problems.append(
                            f'{theme["name"]} {mode}: --{name} is not in the registry'
                        )

    def el(root: bool, **attrs: str) -> dict:
        return {"root": root, "attrs": attrs}

    def expect(context: str, chain: list[dict], name: str, value: str) -> None:
        prop = name.lstrip("-")
        got = resolve(rules, chain).get(prop)
        if got != value:
            problems.append(f"{context}: --{prop} resolved to {got!r}, want {value!r}")

    dark = {"data-theme": "dark"}
    # 2. composition, each expectation read out of the registry rather than
    #    hard-coded, so the check follows shadcn if a value changes.
    neutral, zinc, stone = by_name["neutral"], by_name["zinc"], by_name["stone"]
    blue = by_name["blue"]

    root_light = [el(True)]
    root_dark = [el(True, **dark)]
    expect("unthemed page", root_light, "--primary", dict(neutral["light"])["primary"])
    expect("unthemed page", root_light, "--background",
           dict(neutral["light"])["background"])
    expect("dark page", root_dark, "--background", dict(neutral["dark"])["background"])
    expect("dark page", root_dark, "--primary", dict(neutral["dark"])["primary"])

    subtree_light = [el(True), el(False, **{"data-base": "zinc"})]
    subtree_dark = [el(True, **dark), el(False, **{"data-base": "zinc"})]
    expect("zinc subtree, light page", subtree_light, "--background",
           dict(zinc["light"])["background"])
    expect("zinc subtree, light page", subtree_light, "--primary",
           dict(zinc["light"])["primary"])
    expect("zinc subtree, dark page", subtree_dark, "--background",
           dict(zinc["dark"])["background"])
    expect("zinc subtree, dark page", subtree_dark, "--primary",
           dict(zinc["dark"])["primary"])
    # a subtree that only carries an accent inherits the page's base
    expect("accent-only subtree, light page", [el(True), el(False, **{"data-accent": "blue"})],
           "--background", dict(neutral["light"])["background"])
    expect("accent-only subtree, light page", [el(True), el(False, **{"data-accent": "blue"})],
           "--primary", dict(blue["light"])["primary"])

    # base + accent together: the accent wins for the tokens it overrides, the
    # base supplies the rest, and the mode picks the right half of both.
    for mode, root in (("light", el(True)), ("dark", el(True, **dark))):
        chain = [root, el(False, **{"data-base": "stone", "data-accent": "blue"})]
        where = f"stone+blue subtree, {mode} page"
        expect(where, chain, "--primary", dict(blue[mode])["primary"])
        expect(where, chain, "--secondary", dict(blue[mode])["secondary"])
        expect(where, chain, "--chart-3", dict(blue[mode])["chart-3"])
        expect(where, chain, "--background", dict(stone[mode])["background"])
        expect(where, chain, "--foreground", dict(stone[mode])["foreground"])
        expect(where, chain, "--sidebar", dict(stone[mode])["sidebar"])
        # shadcn declares --radius in the light half only (the dark block does
        # not repeat it), so a dark subtree inherits it from :root.
        expect(where, chain, "--radius", dict(stone["light"])["radius"])

    # an accent on the root behaves the same way
    expect("blue accent on the root", [el(True, **{"data-accent": "blue"})],
           "--primary", dict(blue["light"])["primary"])
    expect("blue accent on a dark root", [el(True, **{"data-accent": "blue", **dark})],
           "--primary", dict(blue["dark"])["primary"])

    return problems


# --------------------------------------------------------------------------
# file surgery
# --------------------------------------------------------------------------

def splice(css: str, generated: str) -> str:
    start = css.find(BEGIN)
    end = css.find(END)
    if start < 0 or end < 0:
        raise SystemExit(f"zc.css has no {BEGIN} / {END} markers")
    head = GENERATED_HEAD_RE.sub("", css[:start])
    return head + generated.strip() + css[end + len(END):]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true", help="fail if out of date")
    ap.add_argument("--fetch", action="store_true", help="refresh the vendored source")
    args = ap.parse_args()

    if args.fetch or not VENDORED.exists():
        print(f"fetching {SOURCE_URL}")
        with urllib.request.urlopen(SOURCE_URL, timeout=30) as response:
            source = response.read().decode()
        VENDORED.write_text(source)
    source = VENDORED.read_text()

    blob = hashlib.sha1(b"blob %d\0" % len(source.encode()) + source.encode()).hexdigest()
    themes = parse_themes(source)
    names = [t["name"] for t in themes]
    if len(set(names)) != len(names):
        raise SystemExit(f"duplicate theme names: {names}")
    if sorted(BASE_NAMES) != sorted(n for n in names if n in BASE_NAMES):
        raise SystemExit("a base color is missing from the registry source")

    # where the data came from, recorded in the generated files themselves
    provenance = (
        f"/* source: shadcn-ui/ui apps/v4/registry/themes.ts, git blob {blob}\n"
        f" * {len(names)} themes: {len(BASE_NAMES)} base colors, "
        f"{len(names) - len(BASE_NAMES)} accents */"
    )
    generated_css = css_for(themes, provenance)
    generated_zig = zig_for(themes)
    current_css = CSS.read_text()
    spliced = splice(current_css, generated_css)

    if args.check:
        stale = []
        if spliced != current_css:
            stale.append(str(CSS.relative_to(HERE.parent.parent)))
        if generated_zig != ZIG.read_text():
            stale.append(str(ZIG.relative_to(HERE.parent.parent)))
        if stale:
            print("out of date, re-run scripts/gen_themes.py: " + ", ".join(stale))
            return 1

    problems = verify(themes, spliced)
    if problems:
        for problem in problems:
            print("theme check failed: " + problem)
        return 1

    if args.check:
        print(f"up to date: {len(names)} themes "
              f"({len(BASE_NAMES)} base, {len(names) - len(BASE_NAMES)} accent); "
              f"values and cascade verified")
        return 0

    CSS.write_text(spliced)
    ZIG.write_text(generated_zig)
    print(
        f"wrote {CSS.name} and {ZIG.name}: {len(names)} themes "
        f"({len(BASE_NAMES)} base colors, {len(names) - len(BASE_NAMES)} accents), "
        f"source blob {blob[:12]}; values and cascade verified"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
