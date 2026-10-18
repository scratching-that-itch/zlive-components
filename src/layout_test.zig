// Layout primitives: Card, Stack, Cluster, Grid, Container, Separator.
//
// These are structure and spacing only — no hooks, no server state, no
// events — so the tests are render snapshots plus the two properties that
// matter for them: the same props produce no patches, and a single changed
// prop produces exactly one.

const std = @import("std");
const zlive = @import("zlive");

const Card = zlive.Component(@import("card.zig"));
const Stack = zlive.Component(@import("stack.zig"));
const Cluster = zlive.Component(@import("cluster.zig"));
const Grid = zlive.Component(@import("grid.zig"));
const Container = zlive.Component(@import("container.zig"));
const Separator = zlive.Component(@import("separator.zig"));

const Segment = zlive.Segment;
const diff = zlive.diff;
const flattenHtml = zlive.flattenHtml;

fn body(comptime html: []const u8) [1]Segment {
    return .{Segment.text(html)};
}

test "card render: title, description, body and footer" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const children = body("<p>body</p>");
    const footer = body("<span>updated just now</span>");
    const tree = try Card.render(a, .{
        .title = "Revenue",
        .description = "Last 30 days",
        .children = &children,
        .footer = &footer,
    });
    try std.testing.expectEqualStrings(
        "<div class=\"zc-card\" data-slot=\"card\" data-size=\"default\"><div class=\"zc-card-header\" data-slot=\"card-header\">" ++
            "<div class=\"zc-card-title\" data-slot=\"card-title\">Revenue</div>" ++
            "<div class=\"zc-card-desc\" data-slot=\"card-description\">Last 30 days</div></div>" ++
            "<div class=\"zc-card-content\" data-slot=\"card-content\"><p>body</p></div>" ++
            "<div class=\"zc-card-footer\" data-slot=\"card-footer\"><span>updated just now</span></div></div>",
        try flattenHtml(a, tree),
    );
}

test "card render: no header and no footer collapses to a bare surface" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const children = body("<p>only</p>");
    const tree = try Card.render(a, .{ .children = &children });
    try std.testing.expectEqualStrings(
        "<div class=\"zc-card\" data-slot=\"card\" data-size=\"default\"><div class=\"zc-card-content\" data-slot=\"card-content\"><p>only</p></div></div>",
        try flattenHtml(a, tree),
    );
}

test "card: a title-only card still wraps it in a header" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const children = body("");
    const tree = try Card.render(a, .{ .title = "Only", .children = &children });
    try std.testing.expectEqualStrings(
        "<div class=\"zc-card\" data-slot=\"card\" data-size=\"default\"><div class=\"zc-card-header\" data-slot=\"card-header\">" ++
            "<div class=\"zc-card-title\" data-slot=\"card-title\">Only</div></div>" ++
            "<div class=\"zc-card-content\" data-slot=\"card-content\"></div></div>",
        try flattenHtml(a, tree),
    );
}

test "card render: id and live region are optional attributes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const children = body("<p>x</p>");
    const tree = try Card.render(a, .{
        .title = "Algeria",
        .id = "detail",
        .live = true,
        .children = &children,
    });
    try std.testing.expectEqualStrings(
        "<div class=\"zc-card\" data-slot=\"card\" data-size=\"default\" id=\"detail\" aria-live=\"polite\">" ++
            "<div class=\"zc-card-header\" data-slot=\"card-header\"><div class=\"zc-card-title\" data-slot=\"card-title\">Algeria</div></div>" ++
            "<div class=\"zc-card-content\" data-slot=\"card-content\"><p>x</p></div></div>",
        try flattenHtml(a, tree),
    );
}

test "stack render: gap and align become classes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const children = body("<p>x</p>");
    const tree = try Stack.render(a, .{ .gap = .lg, .alignment = .center, .children = &children });
    try std.testing.expectEqualStrings(
        "<div class=\"zc-stack zc-gap-lg zc-align-center\"><p>x</p></div>",
        try flattenHtml(a, tree),
    );
}

test "stack diff: only the gap changes -> one patch" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const children = body("");
    const before = try Stack.render(a, .{ .gap = .md, .children = &children });
    const after = try Stack.render(a, .{ .gap = .sm, .children = &children });

    var patches = try diff(a, before, after);
    defer patches.deinit();
    // One patch, carrying the new gap class — the spacing scale is a
    // single dynamic slot, not an inline style.
    try std.testing.expectEqual(@as(usize, 1), patches.count());
    try std.testing.expectEqualStrings("1", patches.at(0).path);
    try std.testing.expectEqualStrings("sm", patches.at(0).node.dynamic.string);
}

test "cluster and grid render their variants as classes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const children = body("");
    try std.testing.expectEqualStrings(
        "<div class=\"zc-cluster zc-gap-sm zc-justify-between\"></div>",
        try flattenHtml(a, try Cluster.render(a, .{ .justify = .between, .children = &children })),
    );
    try std.testing.expectEqualStrings(
        "<div class=\"zc-grid zc-cols-three zc-gap-md\"></div>",
        try flattenHtml(a, try Grid.render(a, .{ .cols = .three, .children = &children })),
    );
    try std.testing.expectEqualStrings(
        "<div class=\"zc-grid zc-cols-auto zc-gap-lg\"></div>",
        try flattenHtml(a, try Grid.render(a, .{ .gap = .lg, .children = &children })),
    );
}

test "container renders the width variant" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const children = body("<p>hi</p>");
    try std.testing.expectEqualStrings(
        "<div class=\"zc-container zc-container-prose\"><p>hi</p></div>",
        try flattenHtml(a, try Container.render(a, .{ .width = .prose, .children = &children })),
    );
    try std.testing.expectEqualStrings(
        "<div class=\"zc-container zc-container-page\"></div>",
        try flattenHtml(a, try Container.render(a, .{ .children = &.{} })),
    );
}

test "separator render: plain, labelled, and vertical" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    try std.testing.expectEqualStrings(
        "<div class=\"zc-sep\" role=\"separator\" aria-orientation=\"horizontal\"></div>",
        try flattenHtml(a, try Separator.render(a, .{})),
    );
    try std.testing.expectEqualStrings(
        "<div class=\"zc-sep\" role=\"separator\" aria-orientation=\"horizontal\">" ++
            "<span>or</span></div>",
        try flattenHtml(a, try Separator.render(a, .{ .label = "or" })),
    );
    try std.testing.expectEqualStrings(
        "<div class=\"zc-sep zc-sep-vertical\" role=\"separator\" " ++
            "aria-orientation=\"vertical\"></div>",
        try flattenHtml(a, try Separator.render(a, .{ .orientation = .vertical })),
    );
}

test "static layout produces no patches when re-rendered unchanged" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const children = body("<p>stable</p>");
    const card = struct {
        fn make(al: std.mem.Allocator, kids: []const Segment) ![]Segment {
            return Card.render(al, .{ .title = "T", .children = kids });
        }
    };
    const before = try card.make(a, &children);
    const after = try card.make(a, &children);

    var patches = try diff(a, before, after);
    defer patches.deinit();
    try std.testing.expectEqual(@as(usize, 0), patches.count());
}

test "nested layout composes: card holding a grid of stacks" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const item = body("<p>item</p>");
    const stack = try Stack.render(a, .{ .children = &item });
    const stack_seg = [_]Segment{.{ .children = stack }};
    const grid = try Grid.render(a, .{ .cols = .two, .children = &stack_seg });
    const grid_seg = [_]Segment{.{ .children = grid }};
    const card = try Card.render(a, .{ .title = "Board", .children = &grid_seg });

    try std.testing.expectEqualStrings(
        "<div class=\"zc-card\" data-slot=\"card\" data-size=\"default\"><div class=\"zc-card-header\" data-slot=\"card-header\">" ++
            "<div class=\"zc-card-title\" data-slot=\"card-title\">Board</div></div>" ++
            "<div class=\"zc-card-content\" data-slot=\"card-content\">" ++
            "<div class=\"zc-grid zc-cols-two zc-gap-md\">" ++
            "<div class=\"zc-stack zc-gap-md zc-align-stretch\"><p>item</p></div>" ++
            "</div></div></div>",
        try flattenHtml(a, card),
    );
}

test "card: the header action renders in the action column" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const children = body("<p>body</p>");
    // The action is the usual case: an icon Button. It is just a segment
    // list, so the Card does not know or care what it holds.
    const action_segs = [_]Segment{Segment.text("<button class=\"btn\">&#8942;</button>")};
    const tree = try Card.render(a, .{
        .title = "Deployments",
        .description = "Last 24 hours",
        .action = &action_segs,
        .children = &children,
    });
    try std.testing.expectEqualStrings(
        "<div class=\"zc-card\" data-slot=\"card\" data-size=\"default\">" ++
            "<div class=\"zc-card-header\" data-slot=\"card-header\">" ++
            "<div class=\"zc-card-title\" data-slot=\"card-title\">Deployments</div>" ++
            "<div class=\"zc-card-desc\" data-slot=\"card-description\">Last 24 hours</div>" ++
            "<div class=\"zc-card-action\" data-slot=\"card-action\">" ++
            "<button class=\"btn\">&#8942;</button></div></div>" ++
            "<div class=\"zc-card-content\" data-slot=\"card-content\"><p>body</p></div></div>",
        try flattenHtml(a, tree),
    );
}

test "card: an action alone still opens a header" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const children = body("");
    const action_segs = [_]Segment{Segment.text("<span>x</span>")};
    const tree = try Card.render(a, .{ .action = &action_segs, .children = &children });
    try std.testing.expectEqualStrings(
        "<div class=\"zc-card\" data-slot=\"card\" data-size=\"default\">" ++
            "<div class=\"zc-card-header\" data-slot=\"card-header\">" ++
            "<div class=\"zc-card-action\" data-slot=\"card-action\"><span>x</span></div></div>" ++
            "<div class=\"zc-card-content\" data-slot=\"card-content\"></div></div>",
        try flattenHtml(a, tree),
    );
}

test "card: size is a single patch on the card element" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const children = body("<p>x</p>");
    const normal = try Card.render(a, .{ .title = "T", .children = &children });
    const compact = try Card.render(a, .{ .title = "T", .children = &children, .size = .sm });

    var patches = try diff(a, normal, compact);
    defer patches.deinit();
    // One patch: the size is rendered once, as data-size, and the styling
    // hangs off that attribute.
    try std.testing.expectEqual(@as(usize, 1), patches.count());
    try std.testing.expectEqualStrings("1", patches.at(0).path);
    try std.testing.expectEqualStrings("sm", patches.at(0).node.dynamic.string);
}
