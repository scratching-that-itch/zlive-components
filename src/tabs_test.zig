// Tabs / Accordion tests — the components are generated from tabs.html and
// accordion.html. Zero hooks: no data-lv-hook anywhere.

const std = @import("std");
const zlive = @import("zlive");
const Tabs = zlive.Component(@import("tabs.zig"));
const Accordion = zlive.Component(@import("accordion.zig"));

const Segment = zlive.Segment;
const diff = zlive.diff;
const flattenHtml = zlive.flattenHtml;

const demo_tab_a = [_]Segment{ .text("<p>content A</p>") };
const demo_tab_b = [_]Segment{ .text("<p>content B</p>") };
const demo_tab_c = [_]Segment{ .text("<p>content C</p>") };

fn demoTabs(a: std.mem.Allocator, active: []const u8) ![]Segment {
    return Tabs.render(a, .{
        .id = "demo",
        .active = active,
        .tabs = &.{
            .{ .key = "a", .label = "A", .content = &demo_tab_a },
            .{ .key = "b", .label = "B", .content = &demo_tab_b },
            .{ .key = "c", .label = "C", .content = &demo_tab_c },
        },
    });
}

test "tabs: switching tabs is exactly three patches via stable ids" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const before = try demoTabs(a, "a");
    const after = try demoTabs(a, "b");

    var patches = try diff(a, before, after);
    defer patches.deinit();

    // old + new tab active slots (index 7 inside each tab's node in the
    // header children at slot 3) + the panel content (slot 7)
    try std.testing.expectEqual(@as(usize, 3), patches.count());
    var paths: [3][]const u8 = undefined;
    for (patches.patches.items, 0..) |p, i| paths[i] = p.path;
    std.mem.sort([]const u8, &paths, {}, struct {
        fn lt(_: void, x: []const u8, y: []const u8) bool {
            return std.mem.lessThan(u8, x, y);
        }
    }.lt);
    try std.testing.expectEqualStrings("3.0.7", paths[0]);
    try std.testing.expectEqualStrings("3.1.7", paths[1]);
    try std.testing.expectEqualStrings("7.0", paths[2]);

    // the panel patch carries the new tab's content
    for (patches.patches.items) |p| {
        if (std.mem.eql(u8, p.path, "7.0")) {
            try std.testing.expectEqualStrings("<p>content B</p>", p.node.static);
        }
    }
}

test "tabs: zero hooks - markup relies on ids and click events only" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const tree = try demoTabs(a, "a");
    const html = try flattenHtml(a, tree);

    try std.testing.expect(std.mem.indexOf(u8, html, "data-lv-hook") == null);
    try std.testing.expect(std.mem.indexOf(u8, html, "data-lv-click=\"switch_tab\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "id=\"demo-tab-a\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "id=\"demo-panel\"") != null);
    // only the active tab's content is present
    try std.testing.expect(std.mem.indexOf(u8, html, "content A") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "content B") == null);
}

const demo_section = [_]Segment{ .text("<p>section body</p>") };

fn demoAccordion(a: std.mem.Allocator, open: []const []const u8) ![]Segment {
    return Accordion.render(a, .{
        .id = "faq",
        .open = open,
        .sections = &.{
            .{ .key = "one", .title = "One", .content = &demo_section },
            .{ .key = "two", .title = "Two", .content = &demo_section },
        },
    });
}

test "accordion: toggling a section is exactly two patches" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const closed = try demoAccordion(a, &.{});
    const opened = try demoAccordion(a, &.{"two"});

    var patches = try diff(a, closed, opened);
    defer patches.deinit();

    // section 2 (index 1 under the sections children at slot 3):
    // aria-expanded at offset 11, body children at offset 19
    try std.testing.expectEqual(@as(usize, 2), patches.count());
    var paths: [2][]const u8 = undefined;
    for (patches.patches.items, 0..) |p, i| paths[i] = p.path;
    std.mem.sort([]const u8, &paths, {}, struct {
        fn lt(_: void, x: []const u8, y: []const u8) bool {
            return std.mem.lessThan(u8, x, y);
        }
    }.lt);
    try std.testing.expectEqualStrings("3.1.11", paths[0]);
    try std.testing.expectEqualStrings("3.1.19", paths[1]);
    try std.testing.expectEqualStrings("true", patches.at(0).node.dynamic.html);
}

test "accordion: zero hooks and closed bodies render empty" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const tree = try demoAccordion(a, &.{});
    const html = try flattenHtml(a, tree);

    try std.testing.expect(std.mem.indexOf(u8, html, "data-lv-hook") == null);
    try std.testing.expect(std.mem.indexOf(u8, html, "data-lv-click=\"toggle_section\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "aria-expanded=\"false\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "section body") == null); // closed = empty
}
