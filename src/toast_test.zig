// Toast / ToastRegion tests.
//
// A toast is a notification with a corner presentation: the timing and the
// lifetime of the messages live in zlive's notification queue
// (zlive/src/notify.zig, `Queue(App, Props, cap)`), and these two
// components own the visual half — one message, and the fixed corner
// region the stack pops over.
//
// The stack semantics are what the tests below pin down: items arrive in
// age order (oldest first), the region's children slot is the list, so
// appending a toast patches only the new index while dismissing the oldest
// re-renders the survivor in place and clears the vacated slot.

const std = @import("std");
const zlive = @import("zlive");
const Toast = zlive.Component(@import("toast.zig"));
const ToastRegion = zlive.Component(@import("toast_region.zig"));

const Segment = zlive.Segment;
const diff = zlive.diff;
const flattenHtml = zlive.flattenHtml;

/// One rendered toast, as the region's child. Slots are borrowed by
/// reference, so the tests keep every tree in the test's own arena.
fn toast(a: std.mem.Allocator, props: Toast.Props) ![]const Segment {
    return Toast.render(a, props);
}

test "toast render: message, level, id and close button" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const tree = try Toast.render(a, .{ .id = "7", .message = "Saved!" });
    try std.testing.expectEqualStrings(
        "<div class=\"zc-toast\" id=\"zc-toast-7\" data-slot=\"toast\" data-level=\"info\" " ++
            "role=\"status\" aria-live=\"polite\">" ++
            "<div class=\"zc-toast-desc\" data-slot=\"toast-description\">Saved!</div>" ++
            "<button type=\"button\" data-slot=\"button\" data-variant=\"ghost\" " ++
            "data-size=\"icon-xs\" class=\"btn zc-toast-close\" " ++
            "data-lv-click=\"zc:toast:dismiss\" data-lv-value=\"7\" " ++
            "aria-label=\"Dismiss\">&times;</button></div>",
        try flattenHtml(a, tree),
    );
}

test "toast render: no id means no element id and no dismiss value" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const html = try flattenHtml(a, try Toast.render(a, .{ .message = "Plain" }));
    try std.testing.expect(std.mem.indexOf(u8, html, " id=") == null);
    try std.testing.expect(std.mem.indexOf(u8, html, "data-lv-value") == null);
    try std.testing.expect(std.mem.indexOf(u8, html, "data-lv-click=\"zc:toast:dismiss\"") != null);
}

test "toast render: err is an alert, success and info are status" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const err_tree = try Toast.render(a, .{ .message = "Nope", .level = .err });
    const err_html = try flattenHtml(a, err_tree);
    try std.testing.expect(std.mem.indexOf(u8, err_html, "data-level=\"err\" role=\"alert\"") != null);

    const ok_tree = try Toast.render(a, .{ .message = "Done", .level = .success });
    const ok_html = try flattenHtml(a, ok_tree);
    try std.testing.expect(std.mem.indexOf(u8, ok_html, "data-level=\"success\" role=\"status\"") != null);
}

test "toast render: an optional title, and dismissible = false" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const tree = try Toast.render(a, .{
        .message = "3 files uploaded",
        .title = "Upload complete",
        .dismissible = false,
    });
    const html = try flattenHtml(a, tree);
    try std.testing.expect(std.mem.indexOf(u8, html,
        "<div class=\"zc-toast-title\" data-slot=\"toast-title\">Upload complete</div>") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "zc:toast:dismiss") == null);
}

test "toast diff: a new message is one patch" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const first = try Toast.render(a, .{ .message = "Saving…" });
    const second = try Toast.render(a, .{ .message = "Saved!" });

    var patches = try diff(a, first, second);
    defer patches.deinit();
    try std.testing.expectEqual(@as(usize, 1), patches.count());
    try std.testing.expectEqualStrings("Saved!", patches.at(0).node.dynamic.string);
}

test "region: every corner renders as a data-corner value" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const corners = [_]ToastRegion.Corner{ .top_left, .top_right, .bottom_left, .bottom_right };
    const tags = [_][]const u8{ "top-left", "top-right", "bottom-left", "bottom-right" };
    var buf: [48]u8 = undefined;
    inline for (corners, tags) |corner, tag| {
        const tree = try ToastRegion.render(a, .{ .corner = corner, .children = &.{} });
        const needle = try std.fmt.bufPrint(&buf, "data-corner=\"{s}\"", .{tag});
        try std.testing.expect(std.mem.indexOf(u8, try flattenHtml(a, tree), needle) != null);
    }
}

test "region: fromTag round-trips every corner and rejects junk" {
    const corners = [_]ToastRegion.Corner{ .top_left, .top_right, .bottom_left, .bottom_right };
    inline for (corners) |corner| {
        try std.testing.expectEqual(corner, ToastRegion.Corner.fromTag(corner.tag()).?);
    }
    try std.testing.expect(ToastRegion.Corner.fromTag("middle") == null);
    try std.testing.expect(ToastRegion.Corner.fromTag("") == null);
}

test "region diff: switching corner is one patch, and the toasts inside are untouched" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const one = try toast(a, .{ .id = "1", .message = "Saved!" });
    const child = [_]Segment{.{ .children = one }};

    const bottom = try ToastRegion.render(a, .{ .corner = .bottom_right, .children = &child });
    const top = try ToastRegion.render(a, .{ .corner = .top_right, .children = &child });

    var patches = try diff(a, bottom, top);
    defer patches.deinit();
    // Only the region's data-corner: the toast inside is unchanged, which is
    // the point of putting the corner on the region rather than the toast.
    try std.testing.expectEqual(@as(usize, 1), patches.count());
    try std.testing.expectEqualStrings("1", patches.at(0).path);
    try std.testing.expectEqualStrings("top-right", patches.at(0).node.dynamic.string);
}

test "region diff: the first toast replaces the empty children slot" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const empty = try ToastRegion.render(a, .{ .corner = .top_right, .children = &.{} });
    const one = try toast(a, .{ .id = "1", .message = "Saved!" });
    const child = [_]Segment{.{ .children = one }};
    const shown = try ToastRegion.render(a, .{ .corner = .top_right, .children = &child });

    var appear = try diff(a, empty, shown);
    defer appear.deinit();
    try std.testing.expectEqual(@as(usize, 1), appear.count());
    // slot 3 of the region: [markup, corner, close-tag, children, </div>]
    try std.testing.expectEqualStrings("3", appear.at(0).path);
    try std.testing.expect(appear.at(0).node == .children);

    // Dismissing the last toast is the same slot going back to empty: the
    // patch shape a close button and a TTL both produce.
    var vanish = try diff(a, shown, empty);
    defer vanish.deinit();
    const json = try vanish.toJson(a);
    try std.testing.expectEqualStrings("{\"3\":[]}", json);
}

test "region diff: a second toast appends one slot and leaves the first alone" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const one = try toast(a, .{ .id = "1", .message = "first" });
    const two = try toast(a, .{ .id = "2", .message = "second" });

    const one_only = [_]Segment{.{ .children = one }};
    const both = [_]Segment{ .{ .children = one }, .{ .children = two } };

    const before = try ToastRegion.render(a, .{ .corner = .bottom_right, .children = &one_only });
    const after = try ToastRegion.render(a, .{ .corner = .bottom_right, .children = &both });

    var patches = try diff(a, before, after);
    defer patches.deinit();
    // One patch, at the appended index: the first toast is untouched, which
    // is what keeps a stack from re-animating everything on every show.
    try std.testing.expectEqual(@as(usize, 1), patches.count());
    try std.testing.expectEqualStrings("3.1", patches.at(0).path);
    try std.testing.expect(patches.at(0).node == .children);
    const html = try flattenHtml(a, patches.at(0).node.children);
    try std.testing.expect(std.mem.indexOf(u8, html, "id=\"zc-toast-2\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "second") != null);
}

test "region diff: dismissing the oldest re-renders the survivor and clears its slot" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const one = try toast(a, .{ .id = "1", .message = "first" });
    const two = try toast(a, .{ .id = "2", .message = "second" });
    const three = try toast(a, .{ .id = "3", .message = "third" });

    const all = [_]Segment{
        .{ .children = one },
        .{ .children = two },
        .{ .children = three },
    };
    // The oldest expired: the list compacts, so the survivors shift down.
    const after = [_]Segment{
        .{ .children = two },
        .{ .children = three },
    };

    const before = try ToastRegion.render(a, .{ .corner = .top_left, .children = &all });
    const now = try ToastRegion.render(a, .{ .corner = .top_left, .children = &after });

    var patches = try diff(a, before, now);
    defer patches.deinit();
    // The list compacts, so the diff re-patches index 0 and 1 in place (the
    // framework patches changed *slots*; it has no notion of item identity,
    // so a shifted survivor arrives as the slots that differ — its id, its
    // message, its close button's value) and clears the vacated tail. What
    // matters for the stack is that every patch is confined to a surviving
    // index or is that tail clear.
    var cleared_tail = false;
    for (patches.patches.items) |p| {
        if (std.mem.eql(u8, p.path, "3.2")) {
            try std.testing.expect(p.node == .children);
            try std.testing.expectEqual(@as(usize, 0), p.node.children.len);
            cleared_tail = true;
            continue;
        }
        try std.testing.expect(std.mem.startsWith(u8, p.path, "3.0") or
            std.mem.startsWith(u8, p.path, "3.1"));
    }
    try std.testing.expect(cleared_tail);
    // The survivors keep their identity in the payload, which is what lets
    // morphdom reuse their elements instead of re-animating the stack.
    const values = try patchStrings(a, &patches);
    for ([_][]const u8{ "2", "3", "second", "third" }) |needle| {
        try std.testing.expect(contains(values, needle));
    }
}

/// Every `.dynamic` string a patch set carries, flattened — the values the
/// client will write into its tree.
fn patchStrings(a: std.mem.Allocator, patches: *const zlive.PatchSet) ![]const []const u8 {
    var out: std.ArrayListUnmanaged([]const u8) = .empty;
    for (patches.patches.items) |p| try collectStrings(a, p.node, &out);
    return out.toOwnedSlice(a);
}

fn collectStrings(a: std.mem.Allocator, seg: Segment, out: *std.ArrayListUnmanaged([]const u8)) !void {
    switch (seg) {
        .dynamic => |d| switch (d) {
            .string => |s| try out.append(a, s),
            else => {},
        },
        .children => |kids| for (kids) |k| try collectStrings(a, k, out),
        .static => {},
    }
}

fn contains(haystack: []const []const u8, needle: []const u8) bool {
    for (haystack) |h| {
        if (std.mem.eql(u8, h, needle)) return true;
    }
    return false;
}
