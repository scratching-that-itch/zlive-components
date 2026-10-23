// zlive-components: the component library for zlive.
//
// Each component declares a typed Props struct and a render returning the
// recursive segment tree, assembled from comptime statics with only prop
// values as dynamic segments — so diffs touch exactly the slots whose
// props changed. See COMPONENTS.md for per-component Props, events, hook
// names, and the server-vs-hook split.

const std = @import("std");
const zlive = @import("zlive");

// Template-driven components: the .zig files are generated from the .html
// templates by zlive-compile at build time (see build.zig).
pub const Button = zlive.Component(@import("button.zig"));
pub const Flash = zlive.Component(@import("flash.zig"));
pub const Toast = zlive.Component(@import("toast.zig"));
pub const ToastRegion = zlive.Component(@import("toast_region.zig"));
pub const TextInput = zlive.Component(@import("text_input.zig"));
pub const Select = zlive.Component(@import("select.zig"));
pub const Checkbox = zlive.Component(@import("checkbox.zig"));
pub const Form = zlive.Component(@import("form.zig"));
pub const SubmitButton = zlive.Component(@import("submit_button.zig"));
pub const Dialog = zlive.Component(@import("dialog.zig"));
pub const Tabs = zlive.Component(@import("tabs.zig"));
pub const Accordion = zlive.Component(@import("accordion.zig"));
pub const Dropdown = zlive.Component(@import("dropdown.zig"));
pub const DropdownPanel = zlive.Component(@import("dropdown_panel.zig"));
pub const Popover = zlive.Component(@import("popover.zig"));
pub const Tooltip = zlive.Component(@import("tooltip.zig"));
// Chart: an Apache ECharts host. The server owns the option JSON (the
// `spec` prop); the zc-chart hook owns the canvas, which is why the
// element is marked data-lv-ignore.
pub const Chart = zlive.Component(@import("chart.zig"));
pub const Table = @import("table.zig").Table;

// Icons: lucide's shapes, inlined (no runtime fetch, no icon font).
pub const Icon = zlive.Component(@import("icon.zig"));

// Sidebar: the primitive set shadcn's `sidebar` block is built from. The
// open/collapsed state is server state on the provider, and every
// descendant (gap, width, labels, sub-menus, the rail) is styled from that
// one attribute — so toggling the sidebar is one patch.
pub const SidebarProvider = zlive.Component(@import("sidebar_provider.zig"));
pub const Sidebar = zlive.Component(@import("sidebar.zig"));
pub const SidebarTrigger = zlive.Component(@import("sidebar_trigger.zig"));
pub const SidebarRail = zlive.Component(@import("sidebar_rail.zig"));
pub const SidebarInset = zlive.Component(@import("sidebar_inset.zig"));
pub const SidebarHeader = zlive.Component(@import("sidebar_header.zig"));
pub const SidebarContent = zlive.Component(@import("sidebar_content.zig"));
pub const SidebarFooter = zlive.Component(@import("sidebar_footer.zig"));
pub const SidebarSeparator = zlive.Component(@import("sidebar_separator.zig"));
pub const SidebarInput = zlive.Component(@import("sidebar_input.zig"));
pub const SidebarGroup = zlive.Component(@import("sidebar_group.zig"));
pub const SidebarGroupLabel = zlive.Component(@import("sidebar_group_label.zig"));
pub const SidebarGroupAction = zlive.Component(@import("sidebar_group_action.zig"));
pub const SidebarGroupContent = zlive.Component(@import("sidebar_group_content.zig"));
pub const SidebarMenu = zlive.Component(@import("sidebar_menu.zig"));
pub const SidebarMenuItem = zlive.Component(@import("sidebar_menu_item.zig"));
pub const SidebarMenuButton = zlive.Component(@import("sidebar_menu_button.zig"));
pub const SidebarMenuAction = zlive.Component(@import("sidebar_menu_action.zig"));
pub const SidebarMenuBadge = zlive.Component(@import("sidebar_menu_badge.zig"));
pub const SidebarMenuSub = zlive.Component(@import("sidebar_menu_sub.zig"));
pub const SidebarMenuSubItem = zlive.Component(@import("sidebar_menu_sub_item.zig"));
pub const SidebarMenuSubButton = zlive.Component(@import("sidebar_menu_sub_button.zig"));

// The composed frame: a site header with a sticky option, and the sidebar
// layout that puts it beside the sidebar. The options (open, side, variant,
// mini, sticky_header) are props, so a page configures the frame instead of
// re-assembling it.
pub const SiteHeader = zlive.Component(@import("site_header.zig"));
pub const SidebarLayout = zlive.Component(@import("sidebar_layout.zig"));

// Avatar and Breadcrumb: what a sidebar header/footer and an inset page
// header are made of.
pub const Avatar = zlive.Component(@import("avatar.zig"));
pub const Breadcrumb = zlive.Component(@import("breadcrumb.zig"));

// Collapsible: shadcn's Collapsible. A disclosure whose content stays in the
// DOM (CSS collapses it), so opening and closing is one attribute patch.
pub const Collapsible = zlive.Component(@import("collapsible.zig"));

// Layout primitives: structure and spacing only — no hooks, no server
// state, no events. They compose around the interactive components.
pub const Card = zlive.Component(@import("card.zig"));
pub const Stack = zlive.Component(@import("stack.zig"));
pub const Cluster = zlive.Component(@import("cluster.zig"));
pub const Grid = zlive.Component(@import("grid.zig"));
pub const Container = zlive.Component(@import("container.zig"));
pub const Separator = zlive.Component(@import("separator.zig"));

/// The component hooks (zc-dialog, zc-dropdown, zc-popover, zc-tooltip,
/// zc-chart, flash) and the component stylesheet, embedded so consumers can
/// serve them without depending on their working directory.
/// shadcn's theme registry (base colors + accents), generated from the
/// shadcn-ui/ui source by scripts/gen_themes.py — see src/themes.zig.
pub const themes = @import("themes.zig");

pub const hooks_js: []const u8 = @embedFile("hooks.js");
pub const css: []const u8 = @embedFile("zc.css");

test {
    std.testing.refAllDecls(@This());
    _ = @import("button_test.zig");
    _ = @import("flash_test.zig");
    _ = @import("toast_test.zig");
    _ = @import("form_test.zig");
    _ = @import("dialog_test.zig");
    _ = @import("chart_test.zig");
    _ = @import("tabs_test.zig");
    _ = @import("overlays_test.zig");
    _ = @import("layout_test.zig");
    _ = @import("sidebar_test.zig");
    _ = @import("css_test.zig");
}
