// Form component tests — the components are generated from their .html
// templates (text_input/select/checkbox/form/submit_button).

const std = @import("std");
const zlive = @import("zlive");

const TextInput = zlive.Component(@import("text_input.zig"));
const Select = zlive.Component(@import("select.zig"));
const Checkbox = zlive.Component(@import("checkbox.zig"));
const Form = zlive.Component(@import("form.zig"));
const SubmitButton = zlive.Component(@import("submit_button.zig"));

const diff = zlive.diff;
const flattenHtml = zlive.flattenHtml;

test "text input: value preserved across patches unless the server changed it" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const unchanged = try TextInput.render(a, .{ .id = "f-name", .value = "ab" });
    // server-side validation changed only the error -> the input element
    // (slot 0) must not be patched
    const with_error = try TextInput.render(a, .{ .id = "f-name", .value = "ab", .error_msg = "too short" });

    var patches = try diff(a, unchanged, with_error);
    defer patches.deinit();
    try std.testing.expectEqual(@as(usize, 1), patches.count());
    try std.testing.expectEqualStrings("11", patches.at(0).path);
    try std.testing.expectEqualStrings("too short", patches.at(0).node.dynamic.string);

    // server changed the value -> exactly the value slot patches
    const new_value = try TextInput.render(a, .{ .id = "f-name", .value = "abc" });
    var patches2 = try diff(a, unchanged, new_value);
    defer patches2.deinit();
    try std.testing.expectEqual(@as(usize, 1), patches2.count());
    try std.testing.expectEqualStrings("5", patches2.at(0).path);
}

test "text input: emits lv-change and renders id-stable DOM" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const tree = try TextInput.render(a, .{ .id = "f-email", .value = "a@b.c" });
    const html = try flattenHtml(a, tree);
    try std.testing.expect(std.mem.indexOf(u8, html, "data-lv-change=\"input\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "id=\"f-email\"") != null);
}

test "select: changing the selection patches only the selected slots" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const options = [_]Select.Option_{
        .{ .value = "admin", .label = "Admin" },
        .{ .value = "user", .label = "User" },
    };
    const before = try Select.render(a, .{ .id = "f-role", .options = &options, .value = "admin" });
    const after = try Select.render(a, .{ .id = "f-role", .options = &options, .value = "user" });

    var patches = try diff(a, before, after);
    defer patches.deinit();

    // each option is a nested children node under the options slot (5);
    // the selected flag is index 3 within an option
    try std.testing.expectEqual(@as(usize, 2), patches.count());
    try std.testing.expectEqualStrings("5.0.3", patches.at(0).path);
    try std.testing.expectEqualStrings("5.1.3", patches.at(1).path);
}

test "checkbox: toggle patches only the checked slot" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const off = try Checkbox.render(a, .{ .id = "f-sub", .label = "Subscribe" });
    const on = try Checkbox.render(a, .{ .id = "f-sub", .label = "Subscribe", .checked = true });

    var patches = try diff(a, off, on);
    defer patches.deinit();
    try std.testing.expectEqual(@as(usize, 1), patches.count());
    try std.testing.expectEqualStrings("5", patches.at(0).path);
    try std.testing.expectEqualStrings(" checked", patches.at(0).node.dynamic.html);
}

test "form: wraps children and renders the submitting attribute" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const field = try TextInput.render(a, .{ .id = "f-name", .value = "ab" });
    const tree = try Form.render(a, .{ .id = "profile", .submitting = true, .children = field });
    const html = try flattenHtml(a, tree);
    try std.testing.expect(std.mem.startsWith(u8, html, "<form id=\"profile\" data-submitting>"));
    try std.testing.expect(std.mem.endsWith(u8, html, "</form>"));
    try std.testing.expect(std.mem.indexOf(u8, html, "<input type=\"text\" id=\"f-name\"") != null);
}

test "submit button: server-side loading state patches the button" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const idle = try SubmitButton.render(a, .{ .label = "Save" });
    const loading = try SubmitButton.render(a, .{ .label = "Save", .loading = true });

    var patches = try diff(a, idle, loading);
    defer patches.deinit();
    try std.testing.expectEqual(@as(usize, 2), patches.count());
    // The submit button is a Button call, so its slots sit under the child
    // node renderChild allocates at root index 0: disabled is slot 13,
    // the label is slot 28 (see button.html's attribute order).
    try std.testing.expectEqualStrings("0.13", patches.at(0).path);
    try std.testing.expectEqualStrings(" disabled", patches.at(0).node.dynamic.html);
    try std.testing.expectEqualStrings("0.28", patches.at(1).path);
    try std.testing.expectEqualStrings("Saving…", patches.at(1).node.dynamic.string);
}
