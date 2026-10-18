//! shadcn's theme registry, generated from the shadcn-ui/ui source by
//! `scripts/gen_themes.py` — do not edit by hand; re-run the script.
//!
//! A **base** theme carries the whole token set (`data-base`); an **accent**
//! theme overrides only the tokens listed in `overrides` (`data-accent`) and
//! layers on top of whichever base is active. `neutral` is also the default
//! on `:root`, and every theme has a light and a dark form — see zc.css.

pub const Kind = enum { base, accent };

pub const Theme = struct {
    /// The `data-base` / `data-accent` attribute value.
    name: []const u8,
    /// shadcn's display title.
    title: []const u8,
    kind: Kind,
    /// The custom properties the theme sets (`--` omitted).
    overrides: []const []const u8,
};

/// The seven base colors (shadcn's `BASE_COLORS`).
pub const bases = [_]Theme{
    .{ .name = "neutral", .title = "Neutral", .kind = .base,
       .overrides = &.{ "background", "foreground", "card", "card-foreground", "popover", "popover-foreground", "primary", "primary-foreground", "secondary", "secondary-foreground", "muted", "muted-foreground", "accent", "accent-foreground", "destructive", "border", "input", "ring", "chart-1", "chart-2", "chart-3", "chart-4", "chart-5", "radius", "sidebar", "sidebar-foreground", "sidebar-primary", "sidebar-primary-foreground", "sidebar-accent", "sidebar-accent-foreground", "sidebar-border", "sidebar-ring" } },
    .{ .name = "stone", .title = "Stone", .kind = .base,
       .overrides = &.{ "background", "foreground", "card", "card-foreground", "popover", "popover-foreground", "primary", "primary-foreground", "secondary", "secondary-foreground", "muted", "muted-foreground", "accent", "accent-foreground", "destructive", "border", "input", "ring", "chart-1", "chart-2", "chart-3", "chart-4", "chart-5", "radius", "sidebar", "sidebar-foreground", "sidebar-primary", "sidebar-primary-foreground", "sidebar-accent", "sidebar-accent-foreground", "sidebar-border", "sidebar-ring" } },
    .{ .name = "zinc", .title = "Zinc", .kind = .base,
       .overrides = &.{ "background", "foreground", "card", "card-foreground", "popover", "popover-foreground", "primary", "primary-foreground", "secondary", "secondary-foreground", "muted", "muted-foreground", "accent", "accent-foreground", "destructive", "border", "input", "ring", "chart-1", "chart-2", "chart-3", "chart-4", "chart-5", "radius", "sidebar", "sidebar-foreground", "sidebar-primary", "sidebar-primary-foreground", "sidebar-accent", "sidebar-accent-foreground", "sidebar-border", "sidebar-ring" } },
    .{ .name = "mauve", .title = "Mauve", .kind = .base,
       .overrides = &.{ "background", "foreground", "card", "card-foreground", "popover", "popover-foreground", "primary", "primary-foreground", "secondary", "secondary-foreground", "muted", "muted-foreground", "accent", "accent-foreground", "destructive", "border", "input", "ring", "chart-1", "chart-2", "chart-3", "chart-4", "chart-5", "radius", "sidebar", "sidebar-foreground", "sidebar-primary", "sidebar-primary-foreground", "sidebar-accent", "sidebar-accent-foreground", "sidebar-border", "sidebar-ring" } },
    .{ .name = "olive", .title = "Olive", .kind = .base,
       .overrides = &.{ "background", "foreground", "card", "card-foreground", "popover", "popover-foreground", "primary", "primary-foreground", "secondary", "secondary-foreground", "muted", "muted-foreground", "accent", "accent-foreground", "destructive", "border", "input", "ring", "chart-1", "chart-2", "chart-3", "chart-4", "chart-5", "radius", "sidebar", "sidebar-foreground", "sidebar-primary", "sidebar-primary-foreground", "sidebar-accent", "sidebar-accent-foreground", "sidebar-border", "sidebar-ring" } },
    .{ .name = "mist", .title = "Mist", .kind = .base,
       .overrides = &.{ "background", "foreground", "card", "card-foreground", "popover", "popover-foreground", "primary", "primary-foreground", "secondary", "secondary-foreground", "muted", "muted-foreground", "accent", "accent-foreground", "destructive", "border", "input", "ring", "chart-1", "chart-2", "chart-3", "chart-4", "chart-5", "radius", "sidebar", "sidebar-foreground", "sidebar-primary", "sidebar-primary-foreground", "sidebar-accent", "sidebar-accent-foreground", "sidebar-border", "sidebar-ring" } },
    .{ .name = "taupe", .title = "Taupe", .kind = .base,
       .overrides = &.{ "background", "foreground", "card", "card-foreground", "popover", "popover-foreground", "primary", "primary-foreground", "secondary", "secondary-foreground", "muted", "muted-foreground", "accent", "accent-foreground", "destructive", "border", "input", "ring", "chart-1", "chart-2", "chart-3", "chart-4", "chart-5", "radius", "sidebar", "sidebar-foreground", "sidebar-primary", "sidebar-primary-foreground", "sidebar-accent", "sidebar-accent-foreground", "sidebar-border", "sidebar-ring" } },
};

/// The accent themes, which layer on a base.
pub const accents = [_]Theme{
    .{ .name = "amber", .title = "Amber", .kind = .accent,
       .overrides = &.{ "primary", "primary-foreground", "secondary", "secondary-foreground", "chart-1", "chart-2", "chart-3", "chart-4", "chart-5", "sidebar-primary", "sidebar-primary-foreground" } },
    .{ .name = "blue", .title = "Blue", .kind = .accent,
       .overrides = &.{ "primary", "primary-foreground", "secondary", "secondary-foreground", "chart-1", "chart-2", "chart-3", "chart-4", "chart-5", "sidebar-primary", "sidebar-primary-foreground" } },
    .{ .name = "cyan", .title = "Cyan", .kind = .accent,
       .overrides = &.{ "primary", "primary-foreground", "secondary", "secondary-foreground", "chart-1", "chart-2", "chart-3", "chart-4", "chart-5", "sidebar-primary", "sidebar-primary-foreground" } },
    .{ .name = "emerald", .title = "Emerald", .kind = .accent,
       .overrides = &.{ "primary", "primary-foreground", "secondary", "secondary-foreground", "chart-1", "chart-2", "chart-3", "chart-4", "chart-5", "sidebar-primary", "sidebar-primary-foreground" } },
    .{ .name = "fuchsia", .title = "Fuchsia", .kind = .accent,
       .overrides = &.{ "primary", "primary-foreground", "secondary", "secondary-foreground", "chart-1", "chart-2", "chart-3", "chart-4", "chart-5", "sidebar-primary", "sidebar-primary-foreground" } },
    .{ .name = "green", .title = "Green", .kind = .accent,
       .overrides = &.{ "primary", "primary-foreground", "secondary", "secondary-foreground", "chart-1", "chart-2", "chart-3", "chart-4", "chart-5", "sidebar-primary", "sidebar-primary-foreground" } },
    .{ .name = "indigo", .title = "Indigo", .kind = .accent,
       .overrides = &.{ "primary", "primary-foreground", "secondary", "secondary-foreground", "chart-1", "chart-2", "chart-3", "chart-4", "chart-5", "sidebar-primary", "sidebar-primary-foreground" } },
    .{ .name = "lime", .title = "Lime", .kind = .accent,
       .overrides = &.{ "primary", "primary-foreground", "secondary", "secondary-foreground", "chart-1", "chart-2", "chart-3", "chart-4", "chart-5", "sidebar-primary", "sidebar-primary-foreground" } },
    .{ .name = "orange", .title = "Orange", .kind = .accent,
       .overrides = &.{ "primary", "primary-foreground", "secondary", "secondary-foreground", "chart-1", "chart-2", "chart-3", "chart-4", "chart-5", "sidebar-primary", "sidebar-primary-foreground" } },
    .{ .name = "pink", .title = "Pink", .kind = .accent,
       .overrides = &.{ "primary", "primary-foreground", "secondary", "secondary-foreground", "chart-1", "chart-2", "chart-3", "chart-4", "chart-5", "sidebar-primary", "sidebar-primary-foreground" } },
    .{ .name = "purple", .title = "Purple", .kind = .accent,
       .overrides = &.{ "primary", "primary-foreground", "secondary", "secondary-foreground", "chart-1", "chart-2", "chart-3", "chart-4", "chart-5", "sidebar-primary", "sidebar-primary-foreground" } },
    .{ .name = "red", .title = "Red", .kind = .accent,
       .overrides = &.{ "primary", "primary-foreground", "secondary", "secondary-foreground", "chart-1", "chart-2", "chart-3", "chart-4", "chart-5", "sidebar-primary", "sidebar-primary-foreground" } },
    .{ .name = "rose", .title = "Rose", .kind = .accent,
       .overrides = &.{ "primary", "primary-foreground", "secondary", "secondary-foreground", "chart-1", "chart-2", "chart-3", "chart-4", "chart-5", "sidebar-primary", "sidebar-primary-foreground" } },
    .{ .name = "sky", .title = "Sky", .kind = .accent,
       .overrides = &.{ "primary", "primary-foreground", "secondary", "secondary-foreground", "chart-1", "chart-2", "chart-3", "chart-4", "chart-5", "sidebar-primary", "sidebar-primary-foreground" } },
    .{ .name = "teal", .title = "Teal", .kind = .accent,
       .overrides = &.{ "primary", "primary-foreground", "secondary", "secondary-foreground", "chart-1", "chart-2", "chart-3", "chart-4", "chart-5", "sidebar-primary", "sidebar-primary-foreground" } },
    .{ .name = "violet", .title = "Violet", .kind = .accent,
       .overrides = &.{ "primary", "primary-foreground", "secondary", "secondary-foreground", "chart-1", "chart-2", "chart-3", "chart-4", "chart-5", "sidebar-primary", "sidebar-primary-foreground" } },
    .{ .name = "yellow", .title = "Yellow", .kind = .accent,
       .overrides = &.{ "primary", "primary-foreground", "secondary", "secondary-foreground", "chart-1", "chart-2", "chart-3", "chart-4", "chart-5", "sidebar-primary", "sidebar-primary-foreground" } },
};

/// Every theme, bases first.
pub const all = bases ++ accents;

/// The number of tokens a base theme carries, and the number an accent
/// overrides — the two shapes the stylesheet has to reproduce.
pub const base_token_count = bases[0].overrides.len;
pub const accent_token_count = accents[0].overrides.len;

/// Look a base theme up by its attribute value.
pub fn base(name: []const u8) ?Theme {
    for (bases) |t| if (std.mem.eql(u8, t.name, name)) return t;
    return null;
}

/// Look an accent theme up by its attribute value.
pub fn accent(name: []const u8) ?Theme {
    for (accents) |t| if (std.mem.eql(u8, t.name, name)) return t;
    return null;
}

const std = @import("std");
