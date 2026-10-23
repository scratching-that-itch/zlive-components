// Button tests — the component itself is generated from button.html.
//
// The API surface is shadcn/ui's: six variants, eight sizes, data-variant /
// data-size for styling, and a `class` prop that *merges* (shadcn's
// className) instead of replacing the variant styling.

const std = @import("std");
const zlive = @import("zlive");
const Button = zlive.Component(@import("button.zig"));

const diff = zlive.diff;
const flattenHtml = zlive.flattenHtml;

test "button render snapshot (default, clickable)" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const tree = try Button.render(a, .{ .label = "Save", .on_click = "save" });
    const html = try flattenHtml(a, tree);
    try std.testing.expectEqualStrings(
        "<button type=\"button\" data-slot=\"button\" data-variant=\"default\"" ++
            " data-size=\"default\" class=\"btn\" data-lv-click=\"save\">Save</button>",
        html,
    );
}

test "button render snapshot (destructive, disabled, no click)" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const tree = try Button.render(a, .{ .label = "Delete", .variant = .destructive, .disabled = true });
    const html = try flattenHtml(a, tree);
    try std.testing.expectEqualStrings(
        "<button type=\"button\" data-slot=\"button\" data-variant=\"destructive\"" ++
            " data-size=\"default\" class=\"btn\" disabled>Delete</button>",
        html,
    );
}

test "button: every shadcn variant and size renders its data attribute" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    // The names are the contract: they are what shadcn's CSS and any
    // consumer's overrides key off, so pin all of them.
    const variants = [_]Button.Variant{
        .@"default", .outline, .secondary, .ghost, .destructive, .link,
    };
    const variant_names = [_][]const u8{ "default", "outline", "secondary", "ghost", "destructive", "link" };
    var buf: [64]u8 = undefined;
    inline for (variants, variant_names) |variant, name| {
        const tree = try Button.render(a, .{ .label = "x", .variant = variant });
        const needle = try std.fmt.bufPrint(&buf, "data-variant=\"{s}\"", .{name});
        try std.testing.expect(std.mem.indexOf(u8, try flattenHtml(a, tree), needle) != null);
    }

    const sizes = [_]Button.Size{
        .@"default", .xs, .sm, .lg, .icon, .@"icon-xs", .@"icon-sm", .@"icon-lg",
    };
    const size_names = [_][]const u8{ "default", "xs", "sm", "lg", "icon", "icon-xs", "icon-sm", "icon-lg" };
    var size_buf: [64]u8 = undefined;
    inline for (sizes, size_names) |size, name| {
        const tree = try Button.render(a, .{ .label = "x", .size = size });
        const needle = try std.fmt.bufPrint(&size_buf, "data-size=\"{s}\"", .{name});
        try std.testing.expect(std.mem.indexOf(u8, try flattenHtml(a, tree), needle) != null);
    }
}

test "button diff: only the label changes -> one patch" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const base = try Button.render(a, .{ .label = "Save", .on_click = "save" });
    const renamed = try Button.render(a, .{ .label = "Saved", .on_click = "save" });

    var patches = try diff(a, base, renamed);
    defer patches.deinit();

    try std.testing.expectEqual(@as(usize, 1), patches.count());
    // The label is the last dynamic slot. Slot indices track the open tag's
    // attribute segments, so they move when the template grows an attribute
    // — what this test is about is that a label change is exactly one
    // patch, of the label.
    try std.testing.expectEqualStrings("28", patches.at(0).path);
    try std.testing.expectEqualStrings("Saved", patches.at(0).node.dynamic.string);
}

test "button diff: only disabled toggles -> one patch" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const enabled = try Button.render(a, .{ .label = "Save", .on_click = "save" });
    const disabled = try Button.render(a, .{ .label = "Save", .on_click = "save", .disabled = true });

    var patches = try diff(a, enabled, disabled);
    defer patches.deinit();

    try std.testing.expectEqual(@as(usize, 1), patches.count());
    try std.testing.expectEqualStrings("13", patches.at(0).path);
    try std.testing.expectEqualStrings(" disabled", patches.at(0).node.dynamic.html);
}

test "button diff: only the variant changes -> one patch" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const base = try Button.render(a, .{ .label = "Save" });
    const danger = try Button.render(a, .{ .label = "Save", .variant = .destructive });

    var patches = try diff(a, base, danger);
    defer patches.deinit();

    // One patch, not two: the variant is rendered once (data-variant) and
    // styling hangs off that attribute, so there is no second class slot.
    try std.testing.expectEqual(@as(usize, 1), patches.count());
    try std.testing.expectEqualStrings("3", patches.at(0).path);
    try std.testing.expectEqualStrings("destructive", patches.at(0).node.dynamic.string);
}

test "button diff: only the size changes -> one patch" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const base = try Button.render(a, .{ .label = "Save" });
    const small = try Button.render(a, .{ .label = "Save", .size = .sm });

    var patches = try diff(a, base, small);
    defer patches.deinit();

    try std.testing.expectEqual(@as(usize, 1), patches.count());
    try std.testing.expectEqualStrings("5", patches.at(0).path);
    try std.testing.expectEqualStrings("sm", patches.at(0).node.dynamic.string);
}

// ---------------------------------------------------------------------
// The trigger surface: id / value / payload / aria / class / submit.
// ---------------------------------------------------------------------

// The kitchen sink's "Show flash": a payload-carrying click.
test "button render: payload trigger (show flash)" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const tree = try Button.render(a, .{
        .label = "Show flash",
        .variant = .secondary,
        .on_click = "flash",
        .payload = "{\"message\":\"Saved!\",\"ttl_ms\":3000}",
    });
    const html = try flattenHtml(a, tree);
    try std.testing.expectEqualStrings(
        "<button type=\"button\" data-slot=\"button\" data-variant=\"secondary\"" ++
            " data-size=\"default\" class=\"btn\" data-lv-click=\"flash\"" ++
            " data-lv-payload='{\"message\":\"Saved!\",\"ttl_ms\":3000}'>Show flash</button>",
        html,
    );
}

// The kitchen sink's dropdown trigger: an id anchor plus a value, with
// aria-expanded reflecting server state.
test "button render: anchored disclosure trigger, expanded" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const tree = try Button.render(a, .{
        .label = "Actions ▾",
        .variant = .outline,
        .id = "ks-dd-trigger",
        .on_click = "zc:dropdown:toggle",
        .value = "ks-dd",
        .aria_expanded = true,
    });
    const html = try flattenHtml(a, tree);
    try std.testing.expectEqualStrings(
        "<button type=\"button\" data-slot=\"button\" data-variant=\"outline\"" ++
            " data-size=\"default\" class=\"btn\" id=\"ks-dd-trigger\"" ++
            " data-lv-click=\"zc:dropdown:toggle\" data-lv-value=\"ks-dd\"" ++
            " aria-expanded=\"true\">Actions ▾</button>",
        html,
    );

    // The same button collapsed: one patch, and only the aria slot.
    const collapsed = try Button.render(a, .{
        .label = "Actions ▾",
        .variant = .outline,
        .id = "ks-dd-trigger",
        .on_click = "zc:dropdown:toggle",
        .value = "ks-dd",
        .aria_expanded = false,
    });
    var patches = try diff(a, tree, collapsed);
    defer patches.deinit();
    try std.testing.expectEqual(@as(usize, 1), patches.count());
    try std.testing.expectEqualStrings(
        " aria-expanded=\"false\"",
        patches.at(0).node.dynamic.html,
    );
}

// `class` merges (shadcn's className), it does not replace the variant: the
// markup still says data-variant="ghost" and the extra class rides along.
test "button render: extra class merges with the variant classes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const tree = try Button.render(a, .{
        .label = "&#8942;",
        .variant = .ghost,
        .size = .@"icon-sm",
        .class = "row-menu-btn",
        .id = "row-menu-7",
        .on_click = "zc:dropdown:toggle",
        .value = "7",
    });
    const html = try flattenHtml(a, tree);
    try std.testing.expectEqualStrings(
        "<button type=\"button\" data-slot=\"button\" data-variant=\"ghost\"" ++
            " data-size=\"icon-sm\" class=\"btn row-menu-btn\" id=\"row-menu-7\"" ++
            " data-lv-click=\"zc:dropdown:toggle\" data-lv-value=\"7\">&#8942;</button>",
        html,
    );
}

test "button render: submit renders type=submit" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const tree = try Button.render(a, .{ .label = "Send", .submit = true });
    const html = try flattenHtml(a, tree);
    try std.testing.expect(std.mem.startsWith(u8, html, "<button type=\"submit\""));
}

test "button render: value beats payload and both can coexist" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    // The client sends {id, value} when data-lv-value is present, else the
    // parsed data-lv-payload. Both attributes render; the ordering is
    // stable so the diff stays minimal.
    const tree = try Button.render(a, .{
        .label = "Both",
        .on_click = "evt",
        .value = "v",
        .payload = "{\"k\":1}",
        .aria_label = "do the thing",
    });
    const html = try flattenHtml(a, tree);
    try std.testing.expectEqualStrings(
        "<button type=\"button\" data-slot=\"button\" data-variant=\"default\"" ++
            " data-size=\"default\" class=\"btn\" data-lv-click=\"evt\"" ++
            " data-lv-value=\"v\" data-lv-payload='{\"k\":1}'" ++
            " aria-label=\"do the thing\">Both</button>",
        html,
    );
}
