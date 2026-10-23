// Chart tests — the component itself is generated from chart.html.
//
// The contract that matters here is the client-ownership one: the element
// must carry both data-lv-hook="zc-chart" (so the hook drives it) and
// data-lv-ignore (so morphdom never deletes the canvas ECharts drew), and
// a spec change must surface as exactly the one attribute's dynamic slot —
// the hook's `updated` reads it back from the DOM.

const std = @import("std");
const zlive = @import("zlive");
const Chart = zlive.Component(@import("chart.zig"));

const diff = zlive.diff;
const flattenHtml = zlive.flattenHtml;

test "chart: snapshot carries the hook, the ignore marker and the spec" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const chart = try Chart.render(a, .{
        .id = "sales",
        .spec = "{\"series\":[{\"type\":\"line\",\"data\":[1,2,3]}]}",
    });
    const html = try flattenHtml(a, chart);
    try std.testing.expect(std.mem.indexOf(u8, html, "id=\"sales\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "data-lv-hook=\"zc-chart\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "data-lv-ignore") != null);
    // the spec slot is raw here — HTML-escaping happens in the client's
    // flatten, which turns the quotes into &quot; inside the attribute
    try std.testing.expect(std.mem.indexOf(u8, html, "data-lv-chart=\"{\"series\":[{\"type\":\"line\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "height:320px") != null);
}

test "chart: a spec change is exactly one patch, on the spec slot" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const before = try Chart.render(a, .{ .id = "c", .spec = "{\"a\":1}" });
    const after = try Chart.render(a, .{ .id = "c", .spec = "{\"a\":2}" });

    var patches = try diff(a, before, after);
    defer patches.deinit();

    try std.testing.expectEqual(@as(usize, 1), patches.count());
    try std.testing.expectEqualStrings("{\"a\":2}", patches.at(0).node.dynamic.string);
}

test "chart: an unchanged spec diffs empty" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const before = try Chart.render(a, .{ .id = "c", .spec = "{\"a\":1}" });
    const after = try Chart.render(a, .{ .id = "c", .spec = "{\"a\":1}" });

    var patches = try diff(a, before, after);
    defer patches.deinit();

    try std.testing.expectEqual(@as(usize, 0), patches.count());
}
