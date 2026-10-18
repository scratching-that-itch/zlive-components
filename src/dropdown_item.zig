// Row types shared by the dropdown menu templates.
//
// Hand-written (not generated): dropdown_panel.html renders the top-level
// menu and dropdown_sub.html renders a nested one, and both need the same
// Item definition. Keeping it here means the two templates share one type
// and neither has to import the other.
//
// shadcn/ui's DropdownMenu is a set of row kinds (item, checkbox item,
// radio item, label, separator, shortcut, sub trigger/content). zlive keeps
// the same taxonomy, with one structural difference: the *checked* state of
// checkbox/radio rows and which submenu is open are server state, not
// client state, so they are fields the caller passes in and events the
// server handles.

const std = @import("std");

/// Item emphasis. shadcn: `variant?: "default" | "destructive"`.
pub const Variant = enum {
    @"default",
    destructive,

    pub fn tag(self: Variant) []const u8 {
        return @tagName(self);
    }
};

/// The row kinds. `kind` decides which Item fields apply:
///
///   .item      label, event, value, shortcut, variant, inset, disabled
///   .checkbox  + checked
///   .radio     + checked
///   .sub       + sub (the nested menu's rows), inset
///   .label     label, inset
///   .separator —
pub const Kind = enum { item, checkbox, radio, label, separator, sub };

pub const Item = struct {
    kind: Kind = .item,
    label: []const u8 = "",
    /// Event sent on select. Null renders a row with no click behavior.
    event: ?[]const u8 = null,
    /// data-lv-value. For kind = .sub it doubles as the submenu's key: the
    /// sub-trigger's element id is "<menu id>-sub-<value>", which is what
    /// the nested panel anchors to, so it must be unique within the menu.
    value: ?[]const u8 = null,
    /// Right-aligned hint, e.g. "⌘B" (shadcn: DropdownMenuShortcut).
    shortcut: ?[]const u8 = null,
    variant: Variant = .@"default",
    /// Indents the row into the indicator column (shadcn: `inset`).
    inset: bool = false,
    disabled: bool = false,
    /// .checkbox / .radio: the current selected state. The caller owns it —
    /// the row sends its event and the server re-renders with the new value,
    /// which is why there is no client-side check state here.
    checked: bool = false,
    /// .sub: the nested menu's rows. One level only: a submenu's rows may
    /// not themselves be kind = .sub.
    sub: []const Item = &.{},
};

/// True when `key` is the open submenu. The server owns `open_sub`, so
/// opening a submenu is a patch like any other state change.
pub fn subOpen(open: ?[]const u8, key: []const u8) bool {
    const o = open orelse return false;
    return std.mem.eql(u8, o, key);
}

test "subOpen compares by value, and null means closed" {
    try std.testing.expect(!subOpen(null, "share"));
    try std.testing.expect(subOpen("share", "share"));
    try std.testing.expect(!subOpen("share", "export"));
}
