const std = @import("std");
const zlive_build = @import("zlive");

/// The component templates, compiled to .zig next to the .html sources.
pub const template_files = [_][]const u8{
    "src/button.html",
    "src/flash.html",
    "src/text_input.html",
    "src/select.html",
    "src/checkbox.html",
    "src/form.html",
    "src/toast.html",
    "src/toast_region.html",
    "src/submit_button.html",
    "src/dialog.html",
    "src/tabs.html",
    "src/accordion.html",
    "src/dropdown.html",
    "src/dropdown_panel.html",
    "src/dropdown_sub.html",
    "src/popover.html",
    "src/tooltip.html",
    // Icons, the sidebar primitive set, avatar, breadcrumb, collapsible.
    "src/avatar.html",
    "src/breadcrumb.html",
    "src/collapsible.html",
    "src/icon.html",
    "src/sidebar.html",
    "src/sidebar_content.html",
    "src/sidebar_footer.html",
    "src/sidebar_group.html",
    "src/sidebar_group_action.html",
    "src/sidebar_group_content.html",
    "src/sidebar_group_label.html",
    "src/sidebar_header.html",
    "src/sidebar_input.html",
    "src/sidebar_inset.html",
    "src/sidebar_menu.html",
    "src/sidebar_menu_action.html",
    "src/sidebar_menu_badge.html",
    "src/sidebar_menu_button.html",
    "src/sidebar_menu_item.html",
    "src/sidebar_menu_sub.html",
    "src/sidebar_menu_sub_button.html",
    "src/sidebar_menu_sub_item.html",
    "src/sidebar_provider.html",
    "src/sidebar_rail.html",
    "src/sidebar_separator.html",
    "src/sidebar_trigger.html",
    // The composed page frame: the header bar and the sidebar layout.
    "src/site_header.html",
    "src/sidebar_layout.html",
    // Layout primitives: structure only, no hooks, no server state.
    "src/card.html",
    "src/stack.html",
    "src/cluster.html",
    "src/grid.html",
    "src/container.html",
    "src/separator.html",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zlive_dep = b.dependency("zlive", .{
        .target = target,
        .optimize = optimize,
    });

    const templates = templatesStep(b, zlive_dep, null, "");

    const zlive_components = b.addModule("zlive_components", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    zlive_components.addImport("zlive", zlive_dep.module("zlive"));

    const tests = b.addTest(.{
        .root_module = zlive_components,
    });
    tests.step.dependOn(templates);
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run zlive-components unit tests");
    test_step.dependOn(&run_tests.step);

    const templates_step = b.step("templates", "Regenerate .zig files from .html templates");
    templates_step.dependOn(templates);

    // The theme blocks in zc.css and the theme list in src/themes.zig are
    // generated from shadcn's registry by scripts/gen_themes.py (which also
    // verifies the values and the cascade). These two steps are the manual
    // path; `zig build test` does not need Python, since css_test.zig checks
    // the shipped shape on its own.
    const themes_gen = b.addSystemCommand(&.{ "python3", "scripts/gen_themes.py" });
    const themes_step = b.step("themes", "Regenerate the theme blocks from shadcn's registry");
    themes_step.dependOn(&themes_gen.step);
    const themes_check = b.addSystemCommand(&.{ "python3", "scripts/gen_themes.py", "--check" });
    const themes_check_step = b.step("themes-check", "Fail if the generated themes are stale");
    themes_check_step.dependOn(&themes_check.step);
}

/// Step that compiles the component templates. From this package's own
/// build pass `self_dep = null` and `out_prefix = ""`; from a sibling root
/// build (e.g. the examples app) pass the components dependency and the
/// package path relative to that build root, since UpdateSourceFiles
/// writes relative to the ROOT build root.
pub fn templatesStep(
    b: *std.Build,
    zlive_dep: *std.Build.Dependency,
    self_dep: ?*std.Build.Dependency,
    out_prefix: []const u8,
) *std.Build.Step {
    var paths: [template_files.len]std.Build.LazyPath = undefined;
    inline for (template_files, 0..) |f, i| {
        paths[i] = if (self_dep) |d| d.path(f) else b.path(f);
    }
    return zlive_build.addTemplates(b, zlive_dep, out_prefix, &paths);
}
