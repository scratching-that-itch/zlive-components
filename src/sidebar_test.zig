// Sidebar / Icon / Avatar / Breadcrumb / Collapsible tests.
//
// The sidebar's contract is that the *layout* is CSS and the *state* is one
// server-owned attribute on the provider: gap width, container offset,
// labels, sub-menus, the rail and the icon-rail squares all hang off
// `data-state` / `data-side` / `data-variant` / `data-collapsible`. The tests
// below pin that down where it matters — a collapse is one patched slot, a
// mode change is one slot, and nothing inside the sidebar is in the patch
// set — plus the shapes (`asChild` replacements, conditional attributes) that
// are easy to get subtly wrong.

const std = @import("std");
const zlive = @import("zlive");

const Icon = zlive.Component(@import("icon.zig"));
const Avatar = zlive.Component(@import("avatar.zig"));
const Breadcrumb = zlive.Component(@import("breadcrumb.zig"));
const Collapsible = zlive.Component(@import("collapsible.zig"));
const Provider = zlive.Component(@import("sidebar_provider.zig"));
const Sidebar = zlive.Component(@import("sidebar.zig"));
const Trigger = zlive.Component(@import("sidebar_trigger.zig"));
const Rail = zlive.Component(@import("sidebar_rail.zig"));
const Inset = zlive.Component(@import("sidebar_inset.zig"));
const Header = zlive.Component(@import("sidebar_header.zig"));
const Content = zlive.Component(@import("sidebar_content.zig"));
const Footer = zlive.Component(@import("sidebar_footer.zig"));
const Separator = zlive.Component(@import("sidebar_separator.zig"));
const Input = zlive.Component(@import("sidebar_input.zig"));
const Group = zlive.Component(@import("sidebar_group.zig"));
const GroupLabel = zlive.Component(@import("sidebar_group_label.zig"));
const GroupAction = zlive.Component(@import("sidebar_group_action.zig"));
const GroupContent = zlive.Component(@import("sidebar_group_content.zig"));
const Menu = zlive.Component(@import("sidebar_menu.zig"));
const MenuItem = zlive.Component(@import("sidebar_menu_item.zig"));
const MenuButton = zlive.Component(@import("sidebar_menu_button.zig"));
const MenuAction = zlive.Component(@import("sidebar_menu_action.zig"));
const MenuBadge = zlive.Component(@import("sidebar_menu_badge.zig"));
const MenuSub = zlive.Component(@import("sidebar_menu_sub.zig"));
const MenuSubItem = zlive.Component(@import("sidebar_menu_sub_item.zig"));
const MenuSubButton = zlive.Component(@import("sidebar_menu_sub_button.zig"));
const SiteHeader = zlive.Component(@import("site_header.zig"));
const Layout = zlive.Component(@import("sidebar_layout.zig"));

const Segment = zlive.Segment;
const diff = zlive.diff;
const flattenHtml = zlive.flattenHtml;

fn arena() std.heap.ArenaAllocator {
    return std.heap.ArenaAllocator.init(std.testing.allocator);
}

test "collapsing the sidebar is one patched slot" {
    var a_ = arena();
    defer a_.deinit();
    const a = a_.allocator();

    const open = try Provider.render(a, .{ .open = true, .children = &.{} });
    const closed = try Provider.render(a, .{ .open = false, .children = &.{} });

    var patches = try diff(a, open, closed);
    defer patches.deinit();
    // The headline property: the whole layout is one attribute, so a collapse
    // costs exactly one patch however much CSS hangs off it.
    try std.testing.expectEqual(@as(usize, 1), patches.count());
    try std.testing.expectEqualStrings("collapsed", patches.at(0).node.dynamic.string);
}

test "side, variant and collapse mode are one patched slot each" {
    var a_ = arena();
    defer a_.deinit();
    const a = a_.allocator();

    const left = try Provider.render(a, .{ .side = .left, .children = &.{} });
    const right = try Provider.render(a, .{ .side = .right, .children = &.{} });
    var side = try diff(a, left, right);
    defer side.deinit();
    try std.testing.expectEqual(@as(usize, 1), side.count());
    try std.testing.expectEqualStrings("right", side.at(0).node.dynamic.string);

    const plain = try Provider.render(a, .{ .variant = .sidebar, .children = &.{} });
    const inset = try Provider.render(a, .{ .variant = .inset, .children = &.{} });
    var variant = try diff(a, plain, inset);
    defer variant.deinit();
    // The mode is the exception by design: switching to `none` also has to
    // open the sidebar, and that is the view's job (its event handler), not
    // the component's — so the patch here is still just the attribute.
    try std.testing.expectEqual(@as(usize, 1), variant.count());
    try std.testing.expectEqualStrings("inset", variant.at(0).node.dynamic.string);
}

test "the provider renders the state, the mode and the hook" {
    var a_ = arena();
    defer a_.deinit();
    const a = a_.allocator();

    // `data-collapsible` carries the configured mode even while expanded, so
    // a collapse changes one attribute instead of two (shadcn blanks it).
    const open = try flattenHtml(a, try Provider.render(a, .{
        .open = true,
        .side = .right,
        .variant = .floating,
        .collapsible = .icon,
        .children = &.{},
    }));
    try std.testing.expect(std.mem.indexOf(u8, open, "data-state=\"expanded\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, open, "data-side=\"right\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, open, "data-variant=\"floating\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, open, "data-collapsible=\"icon\"") != null);
    // the keyboard shortcut + state cookie live on this hook
    try std.testing.expect(std.mem.indexOf(u8, open, "data-lv-hook=\"zc-sidebar\"") != null);
    // the mobile drawer's click-away target
    try std.testing.expect(std.mem.indexOf(u8, open, "data-slot=\"sidebar-scrim\"") != null);
}

test "the provider's enums parse the values a click sends" {
    const sides = [_]Provider.Side{ .left, .right };
    for (sides) |value| try std.testing.expectEqual(value, Provider.Side.fromTag(value.tag()).?);
    const variants = [_]Provider.Variant{ .sidebar, .floating, .inset };
    for (variants) |value| try std.testing.expectEqual(value, Provider.Variant.fromTag(value.tag()).?);
    const modes = [_]Provider.Collapsible{ .offcanvas, .icon, .none };
    for (modes) |value| try std.testing.expectEqual(value, Provider.Collapsible.fromTag(value.tag()).?);
    try std.testing.expect(Provider.Side.fromTag("middle") == null);
    try std.testing.expect(Provider.Variant.fromTag("") == null);
    try std.testing.expect(Provider.Collapsible.fromTag("icons") == null);
}

test "a nav row's disclosure is one patched value; a plain row has none" {
    var a_ = arena();
    defer a_.deinit();
    const a = a_.allocator();

    const closed = try MenuItem.render(a, .{ .open = false, .children = &.{} });
    const open = try MenuItem.render(a, .{ .open = true, .children = &.{} });
    var patches = try diff(a, closed, open);
    defer patches.deinit();
    // The attribute is present for the row's whole life, so only its value
    // changes — which is what keeps a nav click to a handful of slots.
    try std.testing.expectEqual(@as(usize, 1), patches.count());
    try std.testing.expectEqualStrings("open", patches.at(0).node.dynamic.string);

    // No state at all is a plain row: shadcn only puts data-state on a
    // Collapsible, and an empty attribute would be one more slot to patch.
    const plain = try flattenHtml(a, try MenuItem.render(a, .{ .children = &.{} }));
    try std.testing.expect(std.mem.indexOf(u8, plain, "data-state") == null);
}

test "a menu row is an anchor or a button, and only renders what it has" {
    var a_ = arena();
    defer a_.deinit();
    const a = a_.allocator();

    // asChild: an <a> for a link (shadcn's nav rows), a <button> for an event.
    const link = try flattenHtml(a, try MenuButton.render(a, .{
        .label = "Playground",
        .href = "#",
        .active = true,
    }));
    try std.testing.expect(std.mem.startsWith(u8, link, "<a href=\"#\""));
    try std.testing.expect(std.mem.indexOf(u8, link, "data-active=\"true\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, link, "aria-expanded") == null);
    try std.testing.expect(std.mem.endsWith(u8, link, "</a>"));

    const button = try flattenHtml(a, try MenuButton.render(a, .{
        .label = "Models",
        .event = "zc:sidebar:nav",
        .value = "models",
        .expanded = false,
    }));
    try std.testing.expect(std.mem.startsWith(u8, button, "<button type=\"button\""));
    try std.testing.expect(std.mem.indexOf(u8, button, "data-lv-click=\"zc:sidebar:nav\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, button, "data-lv-value=\"models\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, button, "aria-expanded=\"false\"") != null);
    // a conditional attribute must be *absent*, not empty — the regression
    // that rendered `… data-sidebar=\"menu-button\"false>`
    try std.testing.expect(std.mem.indexOf(u8, button, "\"false>") == null);
    try std.testing.expect(std.mem.indexOf(u8, button, "title=") == null);

    const sub = try flattenHtml(a, try MenuSubButton.render(a, .{ .label = "History", .href = "#" }));
    try std.testing.expect(std.mem.indexOf(u8, sub, "data-size=\"md\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, sub, "aria-expanded") == null);
    try std.testing.expect(std.mem.endsWith(u8, sub, "</a>"));
}

test "custom content replaces the icon + label shape (asChild)" {
    var a_ = arena();
    defer a_.deinit();
    const a = a_.allocator();

    const content = try a.dupe(Segment, &[_]Segment{
        .text("<span class=\"logo\">x</span>"),
    });
    const html = try flattenHtml(a, try MenuButton.render(a, .{
        .id = "sb-team",
        .size = .lg,
        .children = content,
        .value = "sb-team",
        .event = "zc:dropdown:toggle",
    }));
    try std.testing.expect(std.mem.indexOf(u8, html, "<span class=\"logo\">x</span>") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "id=\"sb-team\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "data-size=\"lg\"") != null);
    // the default shape (and its label span) is not rendered
    try std.testing.expect(std.mem.indexOf(u8, html, "zc-sidebar-menu-label") == null);
}

test "every sidebar part renders its slot, including the ones the block skips" {
    var a_ = arena();
    defer a_.deinit();
    const a = a_.allocator();

    // One row per part: the demo block only uses a subset, so this is what
    // keeps the rest (Input, GroupAction, GroupContent, MenuBadge) honest.
    const parts = [_]struct { slot: []const u8, tree: []const Segment }{
        .{ .slot = "sidebar", .tree = try Sidebar.render(a, .{ .children = &.{} }) },
        .{ .slot = "sidebar-trigger", .tree = try Trigger.render(a, .{}) },
        .{ .slot = "sidebar-rail", .tree = try Rail.render(a, .{}) },
        .{ .slot = "sidebar-inset", .tree = try Inset.render(a, .{ .children = &.{} }) },
        .{ .slot = "sidebar-header", .tree = try Header.render(a, .{ .children = &.{} }) },
        .{ .slot = "sidebar-content", .tree = try Content.render(a, .{ .children = &.{} }) },
        .{ .slot = "sidebar-footer", .tree = try Footer.render(a, .{ .children = &.{} }) },
        .{ .slot = "sidebar-separator", .tree = try Separator.render(a, .{}) },
        .{ .slot = "sidebar-input", .tree = try Input.render(a, .{ .id = "q" }) },
        .{ .slot = "sidebar-group", .tree = try Group.render(a, .{ .children = &.{} }) },
        .{ .slot = "sidebar-group-label", .tree = try GroupLabel.render(a, .{ .children = &.{} }) },
        .{ .slot = "sidebar-group-action", .tree = try GroupAction.render(a, .{ .event = "x" }) },
        .{ .slot = "sidebar-group-content", .tree = try GroupContent.render(a, .{ .children = &.{} }) },
        .{ .slot = "sidebar-menu", .tree = try Menu.render(a, .{ .children = &.{} }) },
        .{ .slot = "sidebar-menu-item", .tree = try MenuItem.render(a, .{ .children = &.{} }) },
        .{ .slot = "sidebar-menu-button", .tree = try MenuButton.render(a, .{ .label = "x" }) },
        .{ .slot = "sidebar-menu-action", .tree = try MenuAction.render(a, .{}) },
        .{ .slot = "sidebar-menu-badge", .tree = try MenuBadge.render(a, .{ .children = &.{} }) },
        .{ .slot = "sidebar-menu-sub", .tree = try MenuSub.render(a, .{ .children = &.{} }) },
        .{ .slot = "sidebar-menu-sub-item", .tree = try MenuSubItem.render(a, .{ .children = &.{} }) },
        .{ .slot = "sidebar-menu-sub-button", .tree = try MenuSubButton.render(a, .{ .label = "x" }) },
        .{ .slot = "avatar", .tree = try Avatar.render(a, .{ .fallback = "CN" }) },
        .{ .slot = "breadcrumb", .tree = try Breadcrumb.render(a, .{
            .trail = &.{},
            .page = "Data Fetching",
        }) },
        .{ .slot = "collapsible", .tree = try Collapsible.render(a, .{
            .id = "c1",
            .open = true,
            .trigger = &.{},
            .children = &.{},
        }) },
    };
    var buf: [48]u8 = undefined;
    for (parts) |part| {
        const html = try flattenHtml(a, part.tree);
        const needle = try std.fmt.bufPrint(&buf, "data-slot=\"{s}\"", .{part.slot});
        try std.testing.expect(std.mem.indexOf(u8, html, needle) != null);
    }
}

test "the collapse selectors have the attributes they need" {
    var a_ = arena();
    defer a_.deinit();
    const a = a_.allocator();

    // The stylesheet reaches these from the provider: a group hidden in the
    // icon rail, a row action shown on hover, and a rail per side.
    const group = try flattenHtml(a, try Group.render(a, .{ .class = "zc-hide-collapsed", .children = &.{} }));
    try std.testing.expect(std.mem.indexOf(u8, group, "zc-hide-collapsed") != null);

    const action = try flattenHtml(a, try MenuAction.render(a, .{
        .id = "sb-project-0",
        .show_on_hover = true,
    }));
    try std.testing.expect(std.mem.indexOf(u8, action, "zc-show-on-hover") != null);
    try std.testing.expect(std.mem.indexOf(u8, action, "id=\"sb-project-0\"") != null);

    const badge = try flattenHtml(a, try MenuBadge.render(a, .{ .children = &.{} }));
    try std.testing.expect(std.mem.indexOf(u8, badge, "data-slot=\"sidebar-menu-badge\"") != null);
}

test "the icons are inline paths, not fetched assets" {
    var a_ = arena();
    defer a_.deinit();
    const a = a_.allocator();

    const html = try flattenHtml(a, try Icon.render(a, .{ .name = .square_terminal, .class = "big" }));
    try std.testing.expect(std.mem.startsWith(u8, html, "<svg class=\"zc-icon big\" data-icon=\"square_terminal\""));
    try std.testing.expect(std.mem.indexOf(u8, html, "<path d=") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "stroke=\"currentColor\"") != null);
    try std.testing.expect(std.mem.endsWith(u8, html, "</svg>"));
    // an icon change is a segment patch, and both names are distinct shapes
    const other = try Icon.render(a, .{ .name = .bot });
    var patches = try diff(a, try Icon.render(a, .{ .name = .square_terminal }), other);
    defer patches.deinit();
    try std.testing.expect(patches.count() > 0);
}

test "a collapsible keeps its content mounted so a toggle is one patch" {
    var a_ = arena();
    defer a_.deinit();
    const a = a_.allocator();

    const body = try a.dupe(Segment, &[_]Segment{.text("<p>panel</p>")});
    const closed = try Collapsible.render(a, .{
        .id = "c1",
        .open = false,
        .trigger = &.{},
        .children = body,
    });
    const open = try Collapsible.render(a, .{
        .id = "c1",
        .open = true,
        .trigger = &.{},
        .children = body,
    });
    var patches = try diff(a, closed, open);
    defer patches.deinit();
    try std.testing.expectEqual(@as(usize, 1), patches.count());
    // ...and the content is in the tree either way (CSS collapses it)
    try std.testing.expect(std.mem.indexOf(u8, try flattenHtml(a, closed), "<p>panel</p>") != null);
    try std.testing.expect(std.mem.indexOf(u8, try flattenHtml(a, closed), "data-state=\"closed\"") != null);
}

test "a breadcrumb links its trail and marks the current page" {
    var a_ = arena();
    defer a_.deinit();
    const a = a_.allocator();

    const trail = try a.dupe(Breadcrumb.Item, &.{
        .{ .label = "Build Your Application", .href = "#" },
    });
    const html = try flattenHtml(a, try Breadcrumb.render(a, .{
        .trail = trail,
        .page = "Data Fetching",
    }));
    try std.testing.expect(std.mem.indexOf(u8, html,
        "<a class=\"zc-breadcrumb-link\" data-slot=\"breadcrumb-link\" href=\"#\">Build Your Application</a>") != null);
    try std.testing.expect(std.mem.indexOf(u8, html,
        "<span class=\"zc-breadcrumb-page\" data-slot=\"breadcrumb-page\" aria-current=\"page\">Data Fetching</span>") != null);
}

test "an avatar shows the fallback, and the image only when there is one" {
    var a_ = arena();
    defer a_.deinit();
    const a = a_.allocator();

    const fallback = try flattenHtml(a, try Avatar.render(a, .{ .fallback = "CN" }));
    try std.testing.expect(std.mem.indexOf(u8, fallback, "zc-avatar-image") == null);
    try std.testing.expect(std.mem.indexOf(u8, fallback, ">CN</span>") != null);

    const image = try flattenHtml(a, try Avatar.render(a, .{
        .src = "/a.png",
        .fallback = "CN",
        .class = "zc-avatar-square",
    }));
    try std.testing.expect(std.mem.indexOf(u8, image, "src=\"/a.png\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, image, "zc-avatar-square") != null);
}

test "the site header owns its frame and its sticky option" {
    var a_ = arena();
    defer a_.deinit();
    const a = a_.allocator();

    const body = try a.dupe(Segment, &[_]Segment{.text("<p>crumb</p>")});
    const sticky = try flattenHtml(a, try SiteHeader.render(a, .{ .sticky = true, .children = body }));
    try std.testing.expect(std.mem.startsWith(u8, sticky, "<header class=\"zc-site-header\""));
    try std.testing.expect(std.mem.indexOf(u8, sticky, "data-sticky=\"true\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, sticky, "data-slot=\"site-header-bar\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, sticky, "<p>crumb</p>") != null);
    try std.testing.expect(std.mem.endsWith(u8, sticky, "</div></header>"));

    // The option is one attribute, so flipping it is one patched slot.
    const still = try SiteHeader.render(a, .{ .children = body });
    const moving = try SiteHeader.render(a, .{ .sticky = true, .children = body });
    var patches = try diff(a, still, moving);
    defer patches.deinit();
    try std.testing.expectEqual(@as(usize, 1), patches.count());
    try std.testing.expectEqualStrings("true", patches.at(0).node.dynamic.string);
}

test "the layout composes the frame and puts the header in the inset" {
    var a_ = arena();
    defer a_.deinit();
    const a = a_.allocator();

    const sidebar = try a.dupe(Segment, &[_]Segment{.text("<p>nav</p>")});
    const header = try a.dupe(Segment, &[_]Segment{.text("<p>bar</p>")});
    const content = try a.dupe(Segment, &[_]Segment{.text("<p>body</p>")});
    const html = try flattenHtml(a, try Layout.render(a, .{
        .header = header,
        .sidebar = sidebar,
        .content = content,
    }));

    // The frame is the provider's markup plus the header: one hook, the
    // state attributes, the scrim and the two columns.
    try std.testing.expect(std.mem.startsWith(u8, html, "<div class=\"zc-sidebar-wrapper\""));
    try std.testing.expect(std.mem.indexOf(u8, html, "data-lv-hook=\"zc-sidebar\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "data-slot=\"sidebar-scrim\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "data-slot=\"sidebar-inset\"") != null);
    // Slots land where they belong: the sidebar inside the sidebar, the bar
    // inside the header, the content below the header, all inside the inset.
    const nav = std.mem.indexOf(u8, html, "<p>nav</p>").?;
    const bar = std.mem.indexOf(u8, html, "<p>bar</p>").?;
    const body = std.mem.indexOf(u8, html, "<p>body</p>").?;
    try std.testing.expect(nav < std.mem.indexOf(u8, html, "zc-sidebar-inset").?);
    try std.testing.expect(bar > std.mem.indexOf(u8, html, "zc-site-header-bar").?);
    try std.testing.expect(body > std.mem.indexOf(u8, html, "</header>").?);
    try std.testing.expect(std.mem.indexOf(u8, html, "</header>").? < std.mem.indexOf(u8, html, "</main>").?);
}

test "each layout option is one patched attribute" {
    var a_ = arena();
    defer a_.deinit();
    const a = a_.allocator();

    // `mini` picks what a collapse leaves behind: the 3rem rail (icon) or
    // nothing at all (offcanvas).
    const rail = try Layout.render(a, .{ .mini = true, .header = &.{}, .sidebar = &.{}, .content = &.{} });
    const hidden = try Layout.render(a, .{ .mini = false, .header = &.{}, .sidebar = &.{}, .content = &.{} });
    var mini = try diff(a, rail, hidden);
    defer mini.deinit();
    try std.testing.expectEqual(@as(usize, 1), mini.count());
    try std.testing.expectEqualStrings("offcanvas", mini.at(0).node.dynamic.string);

    const still = try Layout.render(a, .{ .sticky_header = false, .header = &.{}, .sidebar = &.{}, .content = &.{} });
    const sticky = try Layout.render(a, .{ .sticky_header = true, .header = &.{}, .sidebar = &.{}, .content = &.{} });
    var header = try diff(a, still, sticky);
    defer header.deinit();
    try std.testing.expectEqual(@as(usize, 1), header.count());
    try std.testing.expectEqualStrings("true", header.at(0).node.dynamic.string);
}

test "a full-width header sits above the sidebar and is always sticky" {
    var a_ = arena();
    defer a_.deinit();
    const a = a_.allocator();

    const header = try a.dupe(Segment, &[_]Segment{.text("<p>bar</p>")});
    const full = try flattenHtml(a, try Layout.render(a, .{
        .header_placement = .full,
        .sticky_header = false, // ignored: the bar is the sidebar's offset
        .header = header,
        .sidebar = &.{},
        .content = &.{},
    }));
    try std.testing.expect(std.mem.indexOf(u8, full, "data-header=\"full\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, full, "data-sticky=\"true\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, full, "data-sticky=\"false\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, full, "zc-site-header").? <
        std.mem.indexOf(u8, full, "zc-sidebar-body").?);

    // The default placement keeps the bar inside the content column, where
    // `sticky_header` is the live switch.
    const inset = try flattenHtml(a, try Layout.render(a, .{
        .header = header,
        .sidebar = &.{},
        .content = &.{},
    }));
    try std.testing.expect(std.mem.indexOf(u8, inset, "data-header=\"inset\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, inset, "data-sticky=\"false\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, inset, "zc-sidebar-body").? <
        std.mem.indexOf(u8, inset, "zc-site-header").?);
}
