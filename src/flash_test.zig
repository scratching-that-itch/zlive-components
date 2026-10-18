// Flash tests — the component itself is generated from flash.html.

const std = @import("std");
const zlive = @import("zlive");
const Flash = zlive.Component(@import("flash.zig"));

const Segment = zlive.Segment;
const diff = zlive.diff;
const flattenHtml = zlive.flattenHtml;

test "flash render snapshot" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const tree = try Flash.render(a, .{ .message = "Saved!", .level = .success });
    const html = try flattenHtml(a, tree);
    try std.testing.expectEqualStrings(
        "<div class=\"flash flash-success\" data-lv-hook=\"flash\">Saved!</div>",
        html,
    );
}

test "flash diff: only the message changes -> one patch" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const base = try Flash.render(a, .{ .message = "Saved!" });
    const updated = try Flash.render(a, .{ .message = "Deleted!" });

    var patches = try diff(a, base, updated);
    defer patches.deinit();

    try std.testing.expectEqual(@as(usize, 1), patches.count());
    try std.testing.expectEqualStrings("3", patches.at(0).path);
    try std.testing.expectEqualStrings("Deleted!", patches.at(0).node.dynamic.string);
}

test "removing a node emits an empty-subtree patch" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const with_flash = [_]Segment{
        .text("header"),
        .{ .children = try Flash.render(a, .{ .message = "hi" }) },
    };
    const without = [_]Segment{
        .text("header"),
        .{ .children = &.{} },
    };

    var patches = try diff(a, &with_flash, &without);
    defer patches.deinit();

    try std.testing.expectEqual(@as(usize, 1), patches.count());
    try std.testing.expectEqualStrings("1", patches.at(0).path);

    const json = try patches.toJson(a);
    try std.testing.expectEqualStrings("{\"1\":[]}", json);
}
