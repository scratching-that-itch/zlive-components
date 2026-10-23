// Floating overlay tests — the components are generated from
// dropdown/dropdown_panel/popover/tooltip.html.

const std = @import("std");
const zlive = @import("zlive");
const Dropdown = zlive.Component(@import("dropdown.zig"));
const Popover = zlive.Component(@import("popover.zig"));
const Tooltip = zlive.Component(@import("tooltip.zig"));

const Segment = zlive.Segment;
const diff = zlive.diff;
const flattenHtml = zlive.flattenHtml;

fn demoDropdown(a: std.mem.Allocator, open: bool) ![]Segment {
    return Dropdown.render(a, .{
        .id = "row-menu-3",
        .label = "⋯",
        .open = open,
        .items = &.{
            .{ .label = "Set score to 100", .event = "menu_boost", .value = "3" },
            .{ .label = "Reset score", .event = "menu_clear", .value = "3" },
        },
    });
}

test "dropdown: trigger + open panel markup" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const tree = try demoDropdown(a, true);
    const html = try flattenHtml(a, tree);

    try std.testing.expect(std.mem.indexOf(u8, html, "data-lv-click=\"zc:dropdown:toggle\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "data-lv-hook=\"zc-dropdown\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "data-zc-anchor=\"row-menu-3\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "role=\"menu\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "data-lv-click=\"menu_boost\" data-lv-value=\"3\"") != null);
}

test "dropdown: opening patches the trigger state and the panel" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const closed = try demoDropdown(a, false);
    const open = try demoDropdown(a, true);

    // Opening is two slots, both meaningful: the trigger's aria-expanded
    // (the trigger is a Button call, so its slots sit under the child node
    // at root 0 — aria-expanded is slot 23) and the panel node at root 1.
    // shadcn marks the trigger up the same way; the alternative (no
    // aria-expanded) would be one patch and an inaccessible disclosure.
    var patches = try diff(a, closed, open);
    defer patches.deinit();
    try std.testing.expectEqual(@as(usize, 2), patches.count());
    try std.testing.expectEqualStrings("0.23", patches.at(0).path);
    try std.testing.expectEqualStrings(" aria-expanded=\"true\"", patches.at(0).node.dynamic.html);
    try std.testing.expectEqualStrings("1", patches.at(1).path);
    try std.testing.expect(patches.at(1).node == .children);

    var patches2 = try diff(a, open, closed);
    defer patches2.deinit();
    const json = try patches2.toJson(a);
    try std.testing.expectEqualStrings(
        "{\"0.23\":{\"html\":\" aria-expanded=\\\"false\\\"\"},\"1\":[]}",
        json,
    );
}

test "popover: toggle diff and aria-expanded on the trigger" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const body = [_]Segment{ .text("<p>info</p>") };
    const closed = try Popover.render(a, .{ .id = "cols", .label = "?", .open = false, .children = &body });
    const open = try Popover.render(a, .{ .id = "cols", .label = "?", .open = true, .children = &body });

    var patches = try diff(a, closed, open);
    defer patches.deinit();
    // trigger aria-expanded flips AND the panel is added
    try std.testing.expectEqual(@as(usize, 2), patches.count());

    const html = try flattenHtml(a, open);
    try std.testing.expect(std.mem.indexOf(u8, html, "aria-expanded=\"true\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "data-lv-hook=\"zc-popover\"") != null);
}

test "tooltip: no events at all - pure client presentation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const tree = try Tooltip.render(a, .{ .anchor = "help-sort", .text = "Pick a column" });
    const html = try flattenHtml(a, tree);

    try std.testing.expect(std.mem.indexOf(u8, html, "role=\"tooltip\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "hidden") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "data-lv-click") == null);
    try std.testing.expect(std.mem.indexOf(u8, html, "data-lv-hook=\"zc-tooltip\"") != null);
}

// ---------------------------------------------------------------------
// The shadcn row taxonomy: label / item / shortcut / inset / disabled /
// destructive / checkbox / radio / separator / submenu.
// ---------------------------------------------------------------------

const DropdownPanel = zlive.Component(@import("dropdown_panel.zig"));

const share_items = [_]DropdownPanel.Item{
    .{ .label = "Email", .event = "share", .value = "email" },
    .{ .label = "Copy link", .event = "share", .value = "link", .shortcut = "⌘C" },
    .{ .kind = .separator },
    .{ .label = "Expand", .event = "share", .value = "expand", .disabled = true },
    .{ .label = "Delete…", .event = "share", .value = "delete", .variant = .destructive },
};

fn menuWithKinds(a: std.mem.Allocator, details: bool, sort: usize, open_sub: ?[]const u8) ![]Segment {
    return DropdownPanel.render(a, .{
        .id = "ks-dd-trigger",
        .open_sub = open_sub,
        .items = &.{
            .{ .kind = .label, .label = "Actions" },
            .{ .label = "Bump count by 10", .event = "ks_action", .value = "bump", .shortcut = "⌘B" },
            .{ .kind = .separator },
            .{ .kind = .checkbox, .label = "Show details", .event = "ks_dd_details", .value = "details", .checked = details },
            .{ .kind = .radio, .label = "Name", .event = "ks_dd_sort", .value = "0", .checked = sort == 0 },
            .{ .kind = .radio, .label = "Size", .event = "ks_dd_sort", .value = "1", .checked = sort == 1 },
            .{ .kind = .sub, .label = "Share", .value = "share", .sub = &share_items },
            .{ .kind = .item, .label = "Delete…", .event = "ks_action", .value = "delete", .variant = .destructive, .inset = true },
        },
    });
}

test "dropdown: every row kind renders shadcn's role and data-slot" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const html = try flattenHtml(a, try menuWithKinds(a, true, 0, null));

    try std.testing.expect(std.mem.indexOf(u8, html, "data-slot=\"dropdown-menu-content\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "data-slot=\"dropdown-menu-label\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "data-slot=\"dropdown-menu-separator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "data-slot=\"dropdown-menu-sub-trigger\"") != null);
    // the shortcut hint rides inside the row
    try std.testing.expect(std.mem.indexOf(u8, html, "data-slot=\"dropdown-menu-shortcut\">⌘B</span>") != null);
    // checked checkbox row: aria-checked is the single carrier of the state,
    // and an unchecked radio row is the same element with false
    try std.testing.expect(std.mem.indexOf(u8, html,
        "role=\"menuitemcheckbox\" aria-checked=\"true\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html,
        "role=\"menuitemradio\" aria-checked=\"true\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html,
        "role=\"menuitemradio\" aria-checked=\"false\"") != null);
    // inset + destructive row
    try std.testing.expect(std.mem.indexOf(u8, html,
        "data-variant=\"destructive\" class=\"zc-dropdown-item zc-dropdown-item-inset\"") != null);
    // the submenu trigger points at its own panel and starts closed
    try std.testing.expect(std.mem.indexOf(u8, html,
        "id=\"ks-dd-trigger-sub-share\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "aria-expanded=\"false\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "ks-dd-trigger-sub-share-panel") == null);
}

test "dropdown: an open submenu renders its nested panel" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const html = try flattenHtml(a, try menuWithKinds(a, false, 1, "share"));

    try std.testing.expect(std.mem.indexOf(u8, html, "aria-expanded=\"true\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html,
        "data-slot=\"dropdown-menu-sub-content\"") != null);
    // the panel anchors to the sub-trigger, to the right of it
    try std.testing.expect(std.mem.indexOf(u8, html,
        "data-zc-anchor=\"ks-dd-trigger-sub-share\" data-zc-placement=\"right-start\"") != null);
    // and renders its own rows, including a disabled one
    try std.testing.expect(std.mem.indexOf(u8, html, "disabled data-disabled=\"true\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, ">Email</button>") != null);
}

test "dropdown: a checkbox row toggle is one patch" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const off = try menuWithKinds(a, false, 0, null);
    const on = try menuWithKinds(a, true, 0, null);

    var patches = try diff(a, off, on);
    defer patches.deinit();
    // aria-checked is the only slot carrying the state (shadcn/Radix also
    // emit data-state; keeping one carrier is what makes this a single
    // patch) plus the indicator span appearing.
    try std.testing.expectEqual(@as(usize, 2), patches.count());
    try std.testing.expectEqualStrings("true", patches.at(0).node.dynamic.html);
}

test "dropdown: selecting a radio row is two patches per changed row" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const name_selected = try menuWithKinds(a, false, 0, null);
    const size_selected = try menuWithKinds(a, false, 1, null);

    var patches = try diff(a, name_selected, size_selected);
    defer patches.deinit();
    // Exactly the two rows that changed, and in each row exactly the two
    // things that really did change: aria-checked, and the indicator span
    // shadcn's ItemIndicator renders only while checked. Nothing about the
    // other rows is in the patch set.
    try std.testing.expectEqual(@as(usize, 4), patches.count());
}

test "popover: returns trigger segments and the panel node, in that order" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const body = try a.dupe(Segment, &[_]Segment{.text("<p>hi</p>")});
    const closed = try Popover.render(a, .{ .id = "p1", .label = "About", .open = false, .children = body });
    const open = try Popover.render(a, .{ .id = "p1", .label = "About", .open = true, .children = body });

    // The shape callers depend on: a flat run of trigger segments, then one
    // `children` node that holds the panel (or nothing while closed). Views
    // splice `[0 .. len-1]` as the trigger and append `[len-1]` as the panel
    // — taking a fixed index instead (as the kitchen sink used to) appends a
    // stray dynamic segment and never renders the panel.
    try std.testing.expect(open.len > 1);
    try std.testing.expect(open[open.len - 1] == .children);
    try std.testing.expect(closed[closed.len - 1] == .children);
    try std.testing.expectEqual(@as(usize, 0), closed[closed.len - 1].children.len);

    const trigger = try flattenHtml(a, open[0 .. open.len - 1]);
    try std.testing.expect(std.mem.indexOf(u8, trigger, "class=\"zc-popover-trigger\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, trigger, "aria-expanded=\"true\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, trigger, "About") != null);

    const panel = try flattenHtml(a, open[open.len - 1].children);
    try std.testing.expect(std.mem.indexOf(u8, panel, "data-zc-anchor=\"p1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, panel, "<p>hi</p>") != null);

    // ...and the closed list is exactly one node shorter: the trigger run is
    // a stable prefix across the toggle, so a view's own indices (a header
    // slot, a toolbar) do not move.
    try std.testing.expectEqual(closed.len, open.len);
}
