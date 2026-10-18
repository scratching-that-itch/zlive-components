// Dialog tests — the component itself is generated from dialog.html.
//
// Portal rule: the render output is spliced into the view tree at root
// level as a `.children` node (a sibling of everything else), never nested
// inside other containers — so no ancestor's overflow/transform can clip
// it, and opening/closing is exactly one root-level patch.

const std = @import("std");
const zlive = @import("zlive");
const Dialog = zlive.Component(@import("dialog.zig"));
const TextInput = zlive.Component(@import("text_input.zig"));

const Segment = zlive.Segment;
const diff = zlive.diff;
const flattenHtml = zlive.flattenHtml;

test "dialog: snapshot carries role, aria, hook and close event" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const dialog = try Dialog.render(a, .{
        .id = "feedback",
        .title = "Send feedback",
        .children = &.{},
    });
    const html = try flattenHtml(a, dialog);
    try std.testing.expect(std.mem.indexOf(u8, html, "role=\"dialog\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "aria-modal=\"true\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "data-lv-hook=\"zc-dialog\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "data-lv-click=\"zc:dialog:close\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "aria-labelledby=\"feedback-title\"") != null);
}

test "dialog: closing is one root-level empty-slot patch (portal)" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const base = [_]Segment{ .text("<main>"), .text("</main>") };
    const with_dialog = [_]Segment{
        .text("<main>"),
        .text("</main>"),
        .{ .children = try Dialog.render(a, .{ .id = "fb", .title = "T", .children = &.{} }) },
    };

    var patches = try diff(a, &with_dialog, &base);
    defer patches.deinit();

    try std.testing.expectEqual(@as(usize, 1), patches.count());
    const p = patches.at(0);
    try std.testing.expect(std.mem.indexOfScalar(u8, p.path, '.') == null); // root-level
    try std.testing.expect(p.node == .children);
    try std.testing.expectEqual(@as(usize, 0), p.node.children.len);

    const json = try patches.toJson(a);
    try std.testing.expect(std.mem.eql(u8, json[0..2], "{\"") and std.mem.endsWith(u8, json, ":[]}"));
}

test "dialog: a title change is one nested patch" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const before = try Dialog.render(a, .{ .id = "fb", .title = "Old", .children = &.{} });
    const after = try Dialog.render(a, .{ .id = "fb", .title = "New", .children = &.{} });

    var patches = try diff(a, before, after);
    defer patches.deinit();

    try std.testing.expectEqual(@as(usize, 1), patches.count());
    try std.testing.expectEqualStrings("7", patches.at(0).path);
    try std.testing.expectEqualStrings("New", patches.at(0).node.dynamic.string);
}

test "dialog: form validation inside the dialog diffs to the error span only" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const body_a = try TextInput.render(a, .{ .id = "d-email", .value = "bad" });
    const body_b = try TextInput.render(a, .{ .id = "d-email", .value = "bad", .error_msg = "must contain @" });

    const before = try Dialog.render(a, .{ .id = "fb", .title = "T", .children = body_a });
    const after = try Dialog.render(a, .{ .id = "fb", .title = "T", .children = body_b });

    var patches = try diff(a, before, after);
    defer patches.deinit();

    // dialog body children (slot 9) -> TextInput error slot (slot 11)
    try std.testing.expectEqual(@as(usize, 1), patches.count());
    try std.testing.expectEqualStrings("9.11", patches.at(0).path);
    try std.testing.expectEqualStrings("must contain @", patches.at(0).node.dynamic.string);
}
