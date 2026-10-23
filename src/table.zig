// Table — typed columns, rows as child segment-trees, empty state, sortable headers.

const std = @import("std");
const zlive = @import("zlive");

const Component = zlive.Component;
const Scalar = zlive.Scalar;
const Segment = zlive.Segment;
const diff = zlive.diff;
const treeToValue = zlive.treeToValue;
const freeValue = zlive.freeValue;

fn flattenForTest(tree: []const Segment, out: *std.ArrayListUnmanaged(u8), allocator: std.mem.Allocator) !void {
    const s = try zlive.flattenHtml(allocator, tree);
    defer allocator.free(s);
    try out.appendSlice(allocator, s);
}

/// A data table: typed columns, one child segment-tree per row (the loop
/// case), and an empty state. Layout for C columns:
///
///   [0]                 `<table ...><thead><tr>`
///   [1 .. 1 + 3C)       per column: `<th>`, label, `</th>`
///   [1 + 3C]            `</tr></thead><tbody>`
///   [2 + 3C]            children: one child tree per row (or the empty row)
///   [3 + 3C]            `</tbody></table>`
///
/// A row's child tree is `[<tr>, (<td>, value, </td>)*, </tr>]`, so the
/// value of cell c sits at index 2 + 3c within the row, and row r sits at
/// index (2 + 3C).r relative to the rows node. Trees (including every
/// per-row array) are allocated from the passed allocator.
pub const Table = Component(struct {
    pub const Column = struct {
        key: []const u8,
        label: []const u8,
    };

    /// Server-side sort state; when set, every header becomes clickable
    /// (`data-lv-click="sort"` + the column index) and the sorted column
    /// carries a direction marker (asc "▲" / desc "▼", none otherwise) -
    /// no page-level JavaScript required.
    pub const Sort = struct { col: usize, asc: bool };

    pub const Props = struct {
        columns: []const Column,
        /// rows[r][c] is the cell value for row r, column c. String cells
        /// render as escaped text; a cell that is markup by construction
        /// uses the explicit opt-in `Scalar.html`.
        rows: []const []const Scalar,
        empty: []const u8 = "No rows.",
        /// optional stable ids for the <tr> elements: morphdom matches by
        /// id, so a re-sorted table reorders rows as element moves instead
        /// of rewriting every cell (and stays well-formed doing it)
        row_ids: ?[]const []const u8 = null,
        /// when set, headers are sortable and show the direction marker
        sort: ?Sort = null,
    };

    pub fn render(allocator: std.mem.Allocator, props: Props) ![]Segment {
        var segs: std.ArrayListUnmanaged(Segment) = .empty;
        errdefer segs.deinit(allocator);

        try segs.append(allocator, .text("<table class=\"tbl\"><thead><tr>"));
        for (props.columns, 0..) |col, i| {
            if (props.sort) |s| {
                const sorted = s.col == i;
                const open = try std.fmt.allocPrint(allocator,
                    "<th class=\"sortable{s}\" data-lv-click=\"sort\" data-lv-value=\"{d}\">",
                    .{
                        if (sorted) (if (s.asc) " sorted-asc" else " sorted-desc") else "",
                        i,
                    });
                try segs.append(allocator, .text(open));
                try segs.append(allocator, .{ .dynamic = .{ .string = col.label } });
                try segs.append(allocator, .text(
                    if (sorted) (if (s.asc) " ▲" else " ▼") else "",
                ));
            } else {
                try segs.append(allocator, .text("<th>"));
                try segs.append(allocator, .{ .dynamic = .{ .string = col.label } });
            }
            try segs.append(allocator, .text("</th>"));
        }
        try segs.append(allocator, .text("</tr></thead><tbody>"));

        const row_trees = try allocator.alloc(Segment, @max(props.rows.len, 1));
        if (props.rows.len == 0) {
            // empty state: a single row spanning all columns
            const open = try std.fmt.allocPrint(allocator, "<tr><td colspan=\"{d}\">", .{props.columns.len});
            const cells = try allocator.alloc(Segment, 3);
            cells[0] = .text(open);
            cells[1] = .{ .dynamic = .{ .string = props.empty } };
            cells[2] = .text("</td></tr>");
            row_trees[0] = .{ .children = cells };
        } else {
            for (props.rows, 0..) |row, r| {
                const cells = try allocator.alloc(Segment, 2 + row.len * 3);
                cells[0] = if (props.row_ids) |ids|
                    .text(try std.fmt.allocPrint(allocator, "<tr id=\"{s}\">", .{ids[r]}))
                else
                    .text("<tr>");
                for (row, 0..) |cell, c| {
                    cells[1 + c * 3] = .text("<td>");
                    cells[2 + c * 3] = .{ .dynamic = cell };
                    cells[3 + c * 3] = .text("</td>");
                }
                cells[cells.len - 1] = .text("</tr>");
                row_trees[r] = .{ .children = cells };
            }
        }
        try segs.append(allocator, .{ .children = row_trees });
        try segs.append(allocator, .text("</tbody></table>"));
        return segs.toOwnedSlice(allocator);
    }
});

// --- Table tests ------------------------------------------------------

const test_columns = [_]Table.Column{
    .{ .key = "name", .label = "Name" },
    .{ .key = "score", .label = "Score" },
};

// tree indices for a 2-column table (see Table's layout docs)
const tbl_rows_node = 8; // 2 + 3 * ncols
fn tblCellPath(buf: []u8, row: usize, col: usize) []const u8 {
    return std.fmt.bufPrint(buf, "{d}.{d}.{d}", .{ tbl_rows_node, row, 2 + 3 * col }) catch unreachable;
}

fn nameRows(arena: std.mem.Allocator, names: []const []const u8) ![]const []const Scalar {
    const rows = try arena.alloc([]const Scalar, names.len);
    for (names, 0..) |name, i| {
        const cells = try arena.alloc(Scalar, 2);
        cells[0] = .{ .string = name };
        cells[1] = .{ .int = @intCast(i * 10) };
        rows[i] = cells;
    }
    return rows;
}

test "table: sorting by a column produces minimal nested diffs" {
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const columns = try arena.allocator().dupe(Table.Column, &test_columns);
    const unsorted = try Table.render(arena.allocator(), .{
        .columns = columns,
        .rows = try nameRows(arena.allocator(), &.{ "bob", "al", "cy" }),
    });
    const sorted = try Table.render(arena.allocator(), .{
        .columns = columns,
        .rows = try nameRows(arena.allocator(), &.{ "al", "bob", "cy" }),
    });

    var patches = try diff(allocator, unsorted, sorted);
    defer patches.deinit();

    // only the two swapped rows are touched; the untouched row and
    // everything outside the rows node produce no patches
    var touched0 = false;
    var touched1 = false;
    for (patches.patches.items) |p| {
        try std.testing.expect(!std.mem.startsWith(u8, p.path, "8.2"));
        try std.testing.expect(std.mem.startsWith(u8, p.path, "8.0.") or
            std.mem.startsWith(u8, p.path, "8.1."));
        if (std.mem.startsWith(u8, p.path, "8.0.")) touched0 = true;
        if (std.mem.startsWith(u8, p.path, "8.1.")) touched1 = true;
    }
    try std.testing.expect(touched0 and touched1);
    // each touched row only reorders (same position-scores), so only the
    // name cell of each row changes -> exactly 1 patch per row
    try std.testing.expectEqual(@as(usize, 2), patches.count());
}

test "table: one cell edit patches exactly that cell's path" {
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const columns = try arena.allocator().dupe(Table.Column, &test_columns);
    const before = try Table.render(arena.allocator(), .{
        .columns = columns,
        .rows = try nameRows(arena.allocator(), &.{ "al", "bob", "cy" }),
    });

    const edited = [_][]const Scalar{
    &.{ .{ .string = "al" }, .{ .int = 0 } },
    &.{ .{ .string = "bob" }, .{ .int = 99 } },
    &.{ .{ .string = "cy" }, .{ .int = 20 } },
    };
    const after = try Table.render(arena.allocator(), .{ .columns = columns, .rows = &edited });

    var patches = try diff(allocator, before, after);
    defer patches.deinit();

    try std.testing.expectEqual(@as(usize, 1), patches.count());
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings(tblCellPath(&buf, 1, 1), patches.at(0).path);
    try std.testing.expect(patches.at(0).node.dynamic.int == 99);
}

test "table: deleting the last row patches only the removed index" {
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const columns = try arena.allocator().dupe(Table.Column, &test_columns);
    const before = try Table.render(arena.allocator(), .{
        .columns = columns,
        .rows = try nameRows(arena.allocator(), &.{ "al", "bob", "cy" }),
    });
    const after = try Table.render(arena.allocator(), .{
        .columns = columns,
        .rows = try nameRows(arena.allocator(), &.{ "al", "bob" }),
    });

    var patches = try diff(allocator, before, after);
    defer patches.deinit();

    try std.testing.expectEqual(@as(usize, 1), patches.count());
    try std.testing.expectEqualStrings("8.2", patches.at(0).path);

    const json = try patches.toJson(allocator);
    defer allocator.free(json);
    try std.testing.expectEqualStrings("{\"8.2\":[]}", json);
}

test "table: empty state renders when there are no rows" {
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const columns = try arena.allocator().dupe(Table.Column, &test_columns);
    const tree = try Table.render(arena.allocator(), .{
        .columns = columns,
        .rows = &.{},
        .empty = "Nothing here.",
    });
    const value = try treeToValue(allocator, tree);
    defer freeValue(allocator, value);
    const json = try std.json.Stringify.valueAlloc(allocator, value, .{});
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "colspan=\\\"2\\\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "Nothing here.") != null);
}

test "table: sortable headers with direction markers" {
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const tree = try Table.render(a, .{
        .columns = &test_columns,
        .rows = &.{},
        .empty = "none",
        .sort = .{ .col = 1, .asc = false }, // sorted desc by second column
    });

    var html: std.ArrayListUnmanaged(u8) = .empty;
    defer html.deinit(allocator);
    try flattenForTest(tree, &html, allocator);

    // both headers are clickable with their column index
    try std.testing.expect(std.mem.indexOf(u8, html.items, "data-lv-click=\"sort\" data-lv-value=\"0\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html.items, "data-lv-click=\"sort\" data-lv-value=\"1\"") != null);
    // sorted column carries the desc marker + class, the other none
    try std.testing.expect(std.mem.indexOf(u8, html.items, "sorted-desc") != null);
    try std.testing.expect(std.mem.indexOf(u8, html.items, "Score ▼") != null);
    try std.testing.expect(std.mem.indexOf(u8, html.items, "Name ▲") == null);
    try std.testing.expect(std.mem.indexOf(u8, html.items, "Name ▼") == null);
}

test "table: no sort prop renders plain headers" {
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const tree = try Table.render(arena.allocator(), .{
        .columns = &test_columns,
        .rows = &.{},
    });
    var html: std.ArrayListUnmanaged(u8) = .empty;
    defer html.deinit(allocator);
    try flattenForTest(tree, &html, allocator);
    try std.testing.expect(std.mem.indexOf(u8, html.items, "data-lv-click") == null);
    try std.testing.expect(std.mem.indexOf(u8, html.items, "▲") == null);
}
