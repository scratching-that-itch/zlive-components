// The stylesheet's own invariants.
//
// zc.css is hand-written from shadcn's Tailwind classes, and one class of
// mistake is invisible to every other test in this package: a rule that
// copies shadcn's *browser default* cursor — `cursor-default`, which is what
// Tailwind v4's preflight left buttons with — onto something the user clicks.
// A component's markup, slots and patches can all be perfect while its rows
// still show an arrow cursor. These checks read the same bytes the server
// serves (`root.css` embeds this file), so they cover the shipped CSS.

const std = @import("std");

const css: []const u8 = @embedFile("zc.css");

/// The stylesheet without its comments, so a rule quoted in prose does not
/// count as a rule.
fn code(a: std.mem.Allocator) ![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(a);
    var i: usize = 0;
    while (i < css.len) {
        if (i + 1 < css.len and css[i] == '/' and css[i + 1] == '*') {
            const end = std.mem.indexOf(u8, css[i + 2 ..], "*/") orelse
                return error.UnterminatedComment;
            i += 2 + end + 2;
            continue;
        }
        try out.append(a, css[i]);
        i += 1;
    }
    return out.toOwnedSlice(a);
}

test "clickables opt into the hand cursor" {
    const body = try code(std.testing.allocator);
    defer std.testing.allocator.free(body);

    // Buttons are where this matters — the sidebar renders every row as a
    // <button> (or an <a href>), and Tailwind's preflight left them on the
    // browser's arrow cursor. `:not(:disabled)` is deliberate: a disabled
    // control should not advertise a click.
    try std.testing.expect(std.mem.indexOf(u8, body, "#lv button:not(:disabled)") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "[role=\"button\"]:not(:disabled)") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "#lv a[href]") != null);
}

test "no rule hands an interactive element the arrow cursor" {
    const body = try code(std.testing.allocator);
    defer std.testing.allocator.free(body);

    // `cursor: default` here means someone ported a shadcn class list
    // literally. Components that are not clickable at all (a badge, a
    // separator) simply do not set a cursor.
    try std.testing.expect(std.mem.indexOf(u8, body, "cursor: default") == null);
    try std.testing.expect(std.mem.indexOf(u8, body, "cursor: auto") == null);
}

test "the sidebar rail keeps its resize cursors" {
    const body = try code(std.testing.allocator);
    defer std.testing.allocator.free(body);

    // The one clickable that must *not* be a hand: it drags the sidebar edge,
    // so it advertises resize instead. It is a <button>, so it overrides the
    // base rule above with its own (more specific) rules.
    try std.testing.expect(std.mem.indexOf(u8, body, "cursor: w-resize") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "cursor: e-resize") != null);
}

// --------------------------------------------------------------------------
// The theme blocks, which scripts/gen_themes.py generates from shadcn's own
// registry. The script checks the values against that file and simulates the
// cascade; these checks run without Python and cover the shape of what
// shipped: every theme present, both modes, and the two token sets complete.
// --------------------------------------------------------------------------

const themes = @import("themes.zig");

/// The tokens an accent theme overrides, mirroring shadcn's registry item.
const accent_tokens = [_][]const u8{
    "primary",       "primary-foreground", "secondary",
    "secondary-foreground", "chart-1",     "chart-2",
    "chart-3",       "chart-4",            "chart-5",
    "sidebar-primary", "sidebar-primary-foreground",
};

/// The tokens a base theme must declare, mirroring shadcn's registry item.
const base_tokens = [_][]const u8{
    "background",         "foreground",           "card",
    "card-foreground",    "popover",              "popover-foreground",
    "primary",            "primary-foreground",   "secondary",
    "secondary-foreground", "muted",              "muted-foreground",
    "accent",             "accent-foreground",    "destructive",
    "border",             "input",                "ring",
    "chart-1",            "chart-2",              "chart-3",
    "chart-4",            "chart-5",              "radius",
    "sidebar",            "sidebar-foreground",   "sidebar-primary",
    "sidebar-primary-foreground", "sidebar-accent", "sidebar-accent-foreground",
    "sidebar-border",     "sidebar-ring",
};

fn count(haystack: []const u8, needle: []const u8) usize {
    var n: usize = 0;
    var i: usize = 0;
    while (std.mem.indexOfPos(u8, haystack, i, needle)) |at| {
        n += 1;
        i = at + needle.len;
    }
    return n;
}

/// The body of the rule whose selector list mentions `selector`.
fn blockFor(body: []const u8, selector: []const u8) ?[]const u8 {
    var i: usize = 0;
    while (std.mem.indexOfPos(u8, body, i, selector)) |at| {
        // the rule has to start at this selector: walk back to the previous
        // `{` or `}` and check nothing but that selector list sits between
        const open = std.mem.indexOfScalarPos(u8, body, at, '{') orelse return null;
        const head_start = if (std.mem.lastIndexOfAny(u8, body[0..at], "}\n")) |p| p + 1 else 0;
        const head = body[head_start..open];
        if (std.mem.indexOf(u8, head, "}") == null) {
            const close = std.mem.indexOfScalarPos(u8, body, open, '}') orelse return null;
            return body[open + 1 .. close];
        }
        i = at + selector.len;
    }
    return null;
}

test "every shadcn theme has a light and a dark block" {
    const body = try code(std.testing.allocator);
    defer std.testing.allocator.free(body);

    try std.testing.expectEqual(@as(usize, 7), themes.bases.len);
    try std.testing.expectEqual(@as(usize, 17), themes.accents.len);
    try std.testing.expectEqual(@as(usize, 24), themes.all.len);

    // the default is neutral on :root, so an unthemed page is a shadcn page
    try std.testing.expect(std.mem.indexOf(u8, body, ":root,\n[data-base=\"neutral\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, ":root[data-theme=\"dark\"]") != null);

    for (themes.bases) |theme| {
        const attr = try std.fmt.allocPrint(std.testing.allocator, "[data-base=\"{s}\"]", .{theme.name});
        defer std.testing.allocator.free(attr);
        const light = try std.fmt.allocPrint(std.testing.allocator, "\n{s} {{", .{attr});
        defer std.testing.allocator.free(light);
        try std.testing.expectEqual(@as(usize, 1), count(body, light));
        const dark = try std.fmt.allocPrint(std.testing.allocator,
            "[data-theme=\"dark\"] [data-base=\"{s}\"]", .{theme.name});
        defer std.testing.allocator.free(dark);
        try std.testing.expect(count(body, dark) == 1);
    }
    for (themes.accents) |theme| {
        const attr = try std.fmt.allocPrint(std.testing.allocator, "[data-accent=\"{s}\"]", .{theme.name});
        defer std.testing.allocator.free(attr);
        const light = try std.fmt.allocPrint(std.testing.allocator, "\n{s} {{", .{attr});
        defer std.testing.allocator.free(light);
        try std.testing.expectEqual(@as(usize, 1), count(body, light));
        const dark = try std.fmt.allocPrint(std.testing.allocator,
            "[data-theme=\"dark\"] [data-accent=\"{s}\"]", .{theme.name});
        defer std.testing.allocator.free(dark);
        try std.testing.expect(count(body, dark) == 1);
    }
}

test "the generated token lists match the stylesheet" {
    const body = try code(std.testing.allocator);
    defer std.testing.allocator.free(body);

    // the generated Zig list claims these shapes; the CSS has to have them
    try std.testing.expectEqual(base_tokens.len, themes.base_token_count);
    try std.testing.expectEqual(accent_tokens.len, themes.accent_token_count);
    try std.testing.expectEqual(base_tokens.len, themes.bases[0].overrides.len);
    for (themes.accents) |theme| {
        try std.testing.expectEqual(accent_tokens.len, theme.overrides.len);
        for (accent_tokens, theme.overrides) |want, got| {
            try std.testing.expectEqualStrings(want, got);
        }
    }

    for (base_tokens) |token| {
        for (themes.bases) |theme| {
            for (theme.overrides) |name| {
                if (std.mem.eql(u8, name, token)) break;
            } else return error.BaseThemeMissingToken;
        }
    }
    // every base block declares all of them (the neutral block sits on :root)
    const neutral = blockFor(body, ":root,\n[data-base=\"neutral\"]") orelse
        return error.NoNeutralBlock;
    for (base_tokens) |token| {
        const decl = try std.fmt.allocPrint(std.testing.allocator, "--{s}:", .{token});
        defer std.testing.allocator.free(decl);
        try std.testing.expect(std.mem.indexOf(u8, neutral, decl) != null);
    }
    // an accent overrides only accent-scoped tokens: no surface tokens
    const accent = blockFor(body, "[data-accent=\"blue\"]") orelse return error.NoAccentBlock;
    try std.testing.expect(std.mem.indexOf(u8, accent, "--background:") == null);
    try std.testing.expect(std.mem.indexOf(u8, accent, "--primary:") != null);
    try std.testing.expect(std.mem.indexOf(u8, accent, "--chart-5:") != null);
    try std.testing.expect(std.mem.indexOf(u8, accent, "--sidebar-primary:") != null);
}

test "radius is shadcn's derivation and destructive has no stray token" {
    const body = try code(std.testing.allocator);
    defer std.testing.allocator.free(body);

    // shadcn: --radius-{sm,md,lg,xl} = calc(var(--radius) ∓ 4px/2px)
    try std.testing.expect(std.mem.indexOf(u8, body, "calc(var(--radius) - 4px)") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "calc(var(--radius) - 2px)") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "calc(var(--radius) + 4px)") != null);
    // shadcn v4 dropped --destructive-foreground (its destructive Button is
    // `text-white`), so ours must not have crept back in
    try std.testing.expect(std.mem.indexOf(u8, body, "--destructive-foreground") == null);
    try std.testing.expect(std.mem.indexOf(u8, body, "color: #fff") != null);
}

test "the box model is Tailwind's" {
    const body = try code(std.testing.allocator);
    defer std.testing.allocator.free(body);

    // shadcn's sizes rely on the preflight reset; without it every bordered
    // control is 2px larger than shadcn's
    try std.testing.expect(std.mem.indexOf(u8, body,
        "*, *::before, *::after { box-sizing: border-box; }") != null);
}

/// The text of the rule whose selector begins with `selector` — `{` through
/// `}`, so a declaration can be checked without pinning its formatting.
fn rule(selector: []const u8, body: []const u8) ![]const u8 {
    const start = std.mem.indexOf(u8, body, selector) orelse return error.MissingRule;
    const open = std.mem.indexOfScalarPos(u8, body, start, '{') orelse
        return error.MissingRule;
    const close = std.mem.indexOfScalarPos(u8, body, open, '}') orelse
        return error.MissingRule;
    return body[open .. close + 1];
}

test "the icon rail centres its rows and keeps the logo/avatar tiles whole" {
    const body = try code(std.testing.allocator);
    defer std.testing.allocator.free(body);

    const row = try rule(
        "#lv .zc-sidebar-wrapper[data-collapsible=\"icon\"][data-state=\"collapsed\"] .zc-sidebar-menu-button {",
        body,
    );
    try std.testing.expect(std.mem.indexOf(u8, row, "width: 2rem") != null);
    // A 2rem tile in a 1rem content box overflows: without centring it is
    // cropped on one side only, which reads as a broken logo rather than a
    // rail. Symmetric cropping is the shadcn look.
    try std.testing.expect(std.mem.indexOf(u8, row, "justify-content: center") != null);

    const tile = try rule(
        "#lv .zc-sidebar-wrapper[data-collapsible=\"icon\"][data-state=\"collapsed\"] .zc-sidebar-menu-button[data-size=\"lg\"] {",
        body,
    );
    // The lg row *is* its 2rem avatar/logo tile, so the padding goes.
    try std.testing.expect(std.mem.indexOf(u8, tile, "padding: 0;") != null);
}

test "the rail hides caller content only while collapsed" {
    const body = try code(std.testing.allocator);
    defer std.testing.allocator.free(body);

    // `zc-hide-collapsed` is the public hook for content with no place in a
    // 3rem rail (the block's two-line name/plan). It must be hidden by the
    // collapsed selector, never by a rule of its own — a standalone rule
    // would take the same content out of the expanded sidebar.
    const at = std.mem.indexOf(u8, body, ".zc-hide-collapsed") orelse
        return error.MissingHook;
    try std.testing.expect(std.mem.indexOf(u8, body[at + 1 ..], ".zc-hide-collapsed") == null);
    const before = body[if (at > 160) at - 160 else 0..at];
    try std.testing.expect(std.mem.indexOf(u8, before,
        "[data-collapsible=\"icon\"][data-state=\"collapsed\"]") != null);
}

/// The brace-matched block that starts at `open` (a `{`), so a rule can be
/// checked against the bracket that encloses it.
fn blockFrom(body: []const u8, open: usize) ![]const u8 {
    var depth: usize = 0;
    var i = open;
    while (i < body.len) : (i += 1) {
        switch (body[i]) {
            '{' => depth += 1,
            '}' => {
                depth -= 1;
                if (depth == 0) return body[open .. i + 1];
            },
            else => {},
        }
    }
    return error.UnbalancedBlock;
}

/// Asserts `needle` sits inside the `@media <query> { … }` block that governs
/// it: the last media query before it, whose braces still enclose it.
fn expectInsideMedia(body: []const u8, needle: []const u8, query: []const u8) !void {
    const at = std.mem.indexOf(u8, body, needle) orelse
        return error.MissingNeedle;
    const media_at = std.mem.lastIndexOf(u8, body[0..at], "@media") orelse
        return error.NoMediaAround;
    const open = std.mem.indexOfScalarPos(u8, body, media_at, '{') orelse
        return error.NoMediaAround;
    const block = try blockFrom(body, open);
    try std.testing.expect(at < open + block.len);
    const prelude = std.mem.trim(u8, body[media_at .. open + 1], " \t\n");
    // `prelude` is the query plus the opening brace.
    try std.testing.expect(prelude.len == query.len + 2 and
        std.mem.eql(u8, prelude[0..query.len], query));
}

test "only the mobile drawer slides the sidebar off-screen" {
    const body = try code(std.testing.allocator);
    defer std.testing.allocator.free(body);

    // The drawer hides itself with a transform, under the small-screen query
    // only. Unscoped, it also applies on desktop, where it takes every
    // collapsed mode — the icon rail included — out of the viewport and
    // leaves an empty strip where the rail should be.
    try expectInsideMedia(body, "translateX(-100%)", "@media (max-width: 767px)");
    try expectInsideMedia(body, "translateX(100%)", "@media (max-width: 767px)");
    // …and there is no second, unscoped copy of either.
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, body, "translateX(-100%)"));
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, body, "translateX(100%)"));

    // Desktop pins the container and resets the transform: collapsing there
    // is a width (icon) or an offset (offcanvas), so the rail stays visible.
    const container = try rule("#lv .zc-sidebar-container { z-index: 10;", body);
    try std.testing.expect(std.mem.indexOf(u8, container, "transform: none") != null);
    try std.testing.expect(std.mem.indexOf(u8, container, "width: var(--sidebar-width)") != null);
    try expectInsideMedia(body, "#lv .zc-sidebar-container { z-index: 10;", "@media (min-width: 768px)");

    // …and the icon rail's collapsed width is the thin strip itself.
    const rail = try rule(
        "#lv .zc-sidebar-wrapper[data-collapsible=\"icon\"][data-state=\"collapsed\"] .zc-sidebar-container {",
        body,
    );
    try std.testing.expect(std.mem.indexOf(u8, rail, "width: var(--sidebar-width-icon)") != null);
}

/// The integer in `decl` (e.g. "z-index: ") inside one rule.
fn declNumber(text: []const u8, decl: []const u8) !i64 {
    const at = std.mem.indexOf(u8, text, decl) orelse return error.MissingDecl;
    const rest = std.mem.trimStart(u8, text[at + decl.len ..], " \n");
    const end = std.mem.indexOfAny(u8, rest, "; \n") orelse rest.len;
    return std.fmt.parseInt(i64, rest[0..end], 10);
}

test "the sticky site header stays under the overlay ladder" {
    const body = try code(std.testing.allocator);
    defer std.testing.allocator.free(body);

    const sticky = try rule("#lv .zc-site-header[data-sticky=\"true\"] {", body);
    try std.testing.expect(std.mem.indexOf(u8, sticky, "position: sticky") != null);
    try std.testing.expect(std.mem.indexOf(u8, sticky, "top: 0") != null);
    // Dropdown panels are z-index 30: a header above them would paint over a
    // menu opened from the header itself.
    try std.testing.expect(try declNumber(sticky, "z-index: ") < 30);

    // A 4rem bar (the frame's --header-height) that shrinks to 3rem while an
    // *inset* sidebar is an icon rail — a full-width bar keeps its height,
    // because the sidebar is pinned below it by exactly that height.
    const wrapper = try rule("#lv .zc-sidebar-wrapper {", body);
    try std.testing.expect(std.mem.indexOf(u8, wrapper, "--header-height: 4rem") != null);
    const bar = try rule("#lv .zc-site-header-bar {", body);
    try std.testing.expect(std.mem.indexOf(u8, bar, "min-height: var(--header-height, 4rem)") != null);
    const shrink = try rule(
        "#lv .zc-sidebar-wrapper:not([data-header=\"full\"])[data-collapsible=\"icon\"][data-state=\"collapsed\"] .zc-site-header-bar {",
        body,
    );
    try std.testing.expect(std.mem.indexOf(u8, shrink, "min-height: 3rem") != null);
}

test "a full-width header offsets the sidebar below it" {
    const body = try code(std.testing.allocator);
    defer std.testing.allocator.free(body);

    // sidebar-16's structure: the frame becomes a column, the bar on top and
    // the sidebar/content row below it.
    const full = try rule("#lv .zc-sidebar-wrapper[data-header=\"full\"] {", body);
    try std.testing.expect(std.mem.indexOf(u8, full, "flex-direction: column") != null);

    // …and the fixed sidebar starts below the bar by the frame's height, the
    // same number the bar uses. If these drift apart, the rail floats or the
    // bar covers the sidebar's first row.
    const offset = try rule(
        "#lv .zc-sidebar-wrapper[data-header=\"full\"] .zc-sidebar-container {",
        body,
    );
    try std.testing.expect(std.mem.indexOf(u8, offset, "top: var(--header-height)") != null);
    try std.testing.expect(std.mem.indexOf(u8, offset, "bottom: auto") != null);
    try std.testing.expect(std.mem.indexOf(u8, offset,
        "height: calc(100svh - var(--header-height))") != null);

    // The right-hand sidebar still reverses its row — now inside the body.
    const right = try rule("#lv .zc-sidebar-wrapper[data-side=\"right\"] .zc-sidebar-body {", body);
    try std.testing.expect(std.mem.indexOf(u8, right, "flex-direction: row-reverse") != null);
}
