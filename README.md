# zlive-components

Component library for [zlive](../zlive). Requires **Zig 0.17.0**; depends
on the sibling `../zlive` package (path dependency), std-only otherwise.

- Module name: `zlive_components`
- `zig build test` runs every component's unit tests (render snapshots and
  diff-minimality checks).

## Components

Interactive: Button, TextInput, Select, Checkbox, Form, SubmitButton,
Dialog, Tabs, Accordion, Dropdown, Popover, Tooltip, Table, Flash, Toast +
ToastRegion, and the sidebar primitive set (SidebarProvider, Sidebar,
SidebarTrigger, SidebarRail, SidebarInset, SidebarHeader/Content/Footer,
SidebarGroup*, SidebarMenu*).

Button, Card and Dropdown follow shadcn/ui's current API: Button has
shadcn's six variants and eight sizes, Card has a `size` prop and a header
action slot, and Dropdown has shadcn's row kinds (label, item, checkbox,
radio, separator, shortcut, inset, destructive, submenu).

Toast is a notification with a corner presentation: a `ToastRegion` fixed to
one of four corners, holding a stack of `Toast` messages (each with its own
server-side deadline and its own close button). Flash is the same thing
inline, i.e. a queue of capacity 1.

The sidebar follows shadcn's `sidebar` API, and its open state is a single
server-owned attribute on the provider, so collapsing the whole layout —
gap, width, labels, sub-menus, rail — is one patched slot and CSS does the
rest. `SidebarLayout` composes the frame and exposes the options as props
(`open`, `side`, `variant`, `mini`, `sticky_header`); `SiteHeader` is the
header above the content, with `sticky` as its option. `zlive-examples`
serves shadcn's `sidebar-07` block at `/sidebar`.

Layout primitives: Card, Stack, Cluster, Grid, Container, Separator —
structure and spacing only, no hooks and no state. Plus the small pieces a
sidebar block needs: Icon (lucide shapes, inlined), Avatar, Breadcrumb,
Collapsible.

See [COMPONENTS.md](COMPONENTS.md) for per-component Props, events, hook
names, and the server-vs-hook split.

## Embedded assets

- `zlive_components.hooks_js` — the `zc-*` client hooks (dialog focus
  trap, floating positioning, tooltip), registered with the zlive
  `LiveHooks` registry.
- `zlive_components.css` — the component stylesheet. Its tokens are
  shadcn/ui's (v4, oklch: `--primary`, `--card`, `--accent`, `--ring`,
  `--radius`, the `--chart-*` ramp, ...) and it implements **all 24 themes in
  shadcn's registry**: seven base colors on `data-base`, seventeen accents on
  `data-accent`, and the mode on `data-theme="dark"` — on any element, so a
  subtree can carry its own palette. The blocks are generated from shadcn's
  own `themes.ts` by `scripts/gen_themes.py` (`zig build themes` /
  `themes-check`); see the Theming section of [COMPONENTS.md](COMPONENTS.md)
  and [SHADCN-DIFF.md](SHADCN-DIFF.md) for how this CSS compares to shadcn's.
- `zlive_components.themes` — the generated theme list (names, titles, kind,
  the tokens each one overrides), for a picker or gallery.

A runnable demo consuming this library lives in `../zlive-examples`.

## License

BSD 3-Clause License — see [LICENSE](LICENSE).
