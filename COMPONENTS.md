# zlive-components

Reference for the component library in `src/` (module name
`zlive_components`): interactive components (Button, Table, Dialog, Tabs,
forms, overlays, Flash, the Sidebar primitive set) plus the composed frame
(`SidebarLayout`, `SiteHeader`), layout primitives
(Card, Stack, Cluster, Grid, Container, Separator) and the small pieces a
sidebar block needs (Icon, Avatar, Breadcrumb, Collapsible). Every
component follows the same contract: a typed
`Props`, a `render` returning the recursive segment tree assembled from
comptime statics (only prop values are dynamic slots, so diffs touch
exactly what changed), and — where needed — a client hook from
`src/hooks.js`.

Event legend:

- `data-lv-click="<event>" [data-lv-value="<v>"] [data-lv-payload='<json>']`
  — click sends `{event, payload}`; `data-lv-value` wraps as `{id, value}`,
  `data-lv-payload` (JSON) carries arbitrary arguments
- `data-lv-change="input"` — input/change sends `{event: "input", payload:
  {id, value}}` (checkboxes send their boolean)
- `zc:<component>:<action>` — component-protocol events (toggle/close)

Server-vs-hook split: **state lives on the server** (a re-render + diff is
the only update mechanism); **hooks only do what the server cannot**:
positioning against the layout, focus management, and gesture detection
that translates into `zc:*` events.

Slot slices are **borrowed, not copied**. A generated `render` stores the
`children` / `footer` / `content` slices it is handed directly in the tree
(`.{ .children = props.children }`), so whatever backs them must stay alive
as long as the tree does — in the demo, the render arena. A stack array
compiles fine and then segfaults on the first encode, because Debug fills
the frame with `0xaa` once the function returns:

```zig
const footer = [1]Segment{Segment.text("<p>hi</p>")};  // dangles
try view.Card.render(a, .{ .children = &.{}, .footer = &footer });

const footer = try a.dupe(Segment, &.{Segment.text("<p>hi</p>")});  // ok
```

## Theming: shadcn's whole registry

`zc.css` carries shadcn/ui's v4 token set, in oklch, under the same names:
`--background`, `--foreground`, `--card`, `--popover`, `--primary`,
`--secondary`, `--muted`, `--muted-foreground`, `--accent`, `--destructive`
(+ their `-foreground` pairs), `--border`, `--input`, `--ring`, `--radius`,
the `--chart-1…5` ramp, the sidebar's `--sidebar`, `--sidebar-foreground`,
`--sidebar-primary`, `--sidebar-primary-foreground`, `--sidebar-accent`,
`--sidebar-accent-foreground`, `--sidebar-border`, `--sidebar-ring`, and the
derived `--radius-sm|md|lg|xl` and `--shadow-xs|sm|md|lg`.

All **24 themes in shadcn's registry** are implemented, generated from
shadcn's own `apps/v4/registry/themes.ts`:

| kind | attribute | themes | what it sets |
| --- | --- | --- | --- |
| base color | `data-base="…"` | `neutral`, `stone`, `zinc`, `mauve`, `olive`, `mist`, `taupe` | the complete token set |
| accent | `data-accent="…"` | `amber`, `blue`, `cyan`, `emerald`, `fuchsia`, `green`, `indigo`, `lime`, `orange`, `pink`, `purple`, `red`, `rose`, `sky`, `teal`, `violet`, `yellow` | `--primary`, `--secondary`, the chart ramp and `--sidebar-primary` (11 tokens), layered on whichever base is active |
| mode | `data-theme="dark"` | — | the dark half of every theme |

`neutral` is also the `:root` default, so an unthemed page *is* shadcn's
default palette. An accent alone is valid (`data-accent` on top of neutral),
and the attributes work on **any element**, not just `<html>`:

```html
<html data-theme="dark" data-base="zinc" data-accent="blue">   <!-- the page -->
<div data-base="stone">…</div>                                  <!-- just this card -->
```

That is how the demo's `/themes` page previews every palette at once: each
card is a wrapper carrying one theme, and the components inside it are coloured
by the wrapper's tokens. The switcher is client state
(`zlive-examples/src/pages/theme.js`: `zcTheme.setBase/setAccent/setMode/reset`,
persisted in `localStorage`), so a theme change is never a server roundtrip and
morphdom can never reset it.

**Regenerating.** The theme blocks are generated — do not hand-edit them:

```sh
cd zlive-components
python3 scripts/gen_themes.py            # rewrite src/zc.css + src/themes.zig
python3 scripts/gen_themes.py --check    # fail if stale; verifies values + cascade
```

The script parses the vendored copy of shadcn's `themes.ts`
(`scripts/shadcn-themes.ts`, kept next to the script so this works offline and
the audit is reproducible; `--fetch` refreshes it and prints the git blob it
got). It:

- rewrites the region of `zc.css` between the `@themes:begin`/`@themes:end`
  markers, with the source's git blob in a header comment;
- writes `src/themes.zig`, the list the demo's picker and `/themes` page render
  from — so the list cannot drift from the stylesheet;
- verifies, without a browser, that every theme's block declares exactly the
  tokens and values the registry does, and *simulates the cascade* for a matrix
  of modes/bases/accents (root and subtree) to prove the composition resolves as
  intended.

`src/css_test.zig` re-checks the shipped shape without Python: all 24 themes
present in both modes, the 32-token base set and 11-token accent set complete,
shadcn's `--radius` derivation, no `--destructive-foreground`, and the
`box-sizing` reset.

Three differences from a stock shadcn install, all deliberate:

- dark mode is the `data-theme="dark"` attribute (not shadcn's `.dark` class)
  and palettes are scoped with `data-base`/`data-accent`, which also work on a
  subtree — the theme lives outside the patched container, so morphdom can
  never reset it;
- the styles are hand-written CSS rather than Tailwind v4's `@theme` plus
  `cn-*` utilities, so `color-mix(in oklab, …)` stands in for Tailwind's
  `/90` and `/50` opacity modifiers, and the shadows are literal values;
- there is no `cn()` merge: a component's `class` prop appends, and the
  variant/size styling comes from `data-*` attributes, which is what keeps
  a variant change a single patch.

`--ok` and `--hook` are demo-only semantic colours (the protocol log), not
shadcn tokens. The pre-shadcn aliases (`--bg`, `--fg`, `--surface`,
`--surface2`, `--border2`, `--accent-soft`, `--chart-track`, `--err`) are gone
— an alias on `:root` cannot follow a palette scoped to a subtree.

Two more things came out of the shadcn recheck and are documented in
[SHADCN-DIFF.md](SHADCN-DIFF.md), which lists every difference found and what
was done about it:

- the `box-sizing: border-box` reset Tailwind's preflight provides, without
  which every bordered control rendered 2px larger than shadcn's;
- the cursor rule: `#lv button:not(:disabled)`, `#lv [role="button"]:not(:disabled)`
  and `#lv a[href]` are `cursor: pointer`, because Tailwind v4's preflight
  dropped the browser's pointer cursor for buttons. It is scoped to `#lv`, so a
  host page's own buttons keep the browser default; `SidebarRail` (resize) and a
  tooltip anchor (help) override it on purpose, and `src/css_test.zig` fails the
  build if a rule reintroduces `cursor: default`.

## Button — no hook

shadcn/ui's Button, same variant and size vocabulary.

- **Variants**: `default`, `outline`, `secondary`, `ghost`, `destructive`,
  `link` — spelled `.@"default"` in Zig, because `default` is a keyword.
- **Sizes**: `default`, `xs`, `sm`, `lg`, `icon`, `@"icon-xs"`,
  `@"icon-sm"`, `@"icon-lg"` (the `icon-*` sizes are square).
- **Props**: `label`, `variant`, `size`, `disabled`, `submit: bool`
  (renders `type="submit"`), `class: ?[]const u8`, `id: ?[]const u8`
  (required when the button is a Floating UI anchor),
  `on_click: ?[]const u8`, `value: ?[]const u8` (`data-lv-value`),
  `payload: ?[]const u8` (raw JSON `data-lv-payload`),
  `aria_expanded: ?bool` (omitted when null), `aria_label: ?[]const u8`
- **Markup**: `data-slot="button"`, `data-variant`, `data-size`, and
  `class="btn"` — the variant and size live in the data attributes and the
  stylesheet selects on them (`#lv .btn[data-variant="destructive"]`). That
  is deliberate: rendering the variant into a class *and* a data attribute
  would make a variant change two patches instead of one, and
  `button_test.zig` pins both the markup and the one-patch diff.
- **`class` merges** (like shadcn's `className`): it is appended after
  `btn`, so an extra class positions the button without discarding its
  variant. The countries close button is `variant = .ghost`,
  `size = .@"icon-sm"` plus `class = "detail-close"` for placement.
- **Events**: `on_click` via `data-lv-click` (absent when null). When both
  `value` and `payload` are set, the client's rule applies: `data-lv-value`
  wins and is sent as `{id, value}`.
- **Split**: 100% server. A prop change is one patch per changed slot, so a
  disclosure trigger toggling open/closed is a single patch (the
  `aria-expanded` slot) and a variant change is a single patch
  (`data-variant`).
- **Still hand-written in the demo** (all expressible with the props above,
  just not yet migrated): the countries page's ⓘ / pagination buttons, the
  table's per-row `row-menu-btn`, and the counter view's inline `+`. The
  counter is the one that needs view surgery rather than a swap: its
  trigger is baked into a single static text segment
  (`"<p>count: <button …>+</button> <span …>"`), so composing a child there
  means splitting that segment into sibling slots.

## Layout primitives — no hooks, no state

Structure and spacing only: no hooks, no events, no server state. They
compose around the interactive components, and the same props always render
the same tree, so a re-render with unchanged props emits no patch. Spacing
lives in the stylesheet (`zc-gap-*`, `zc-cols-*`), never inline, so the
scale stays themeable.

- **Card** — shadcn's Card: `title`, `description`,
  `action: ?[]const Segment` (shadcn's CardAction — the header's second
  column, top-right; usually an icon Button), `children`,
  `footer: ?[]const Segment`, `size: default|sm`, `id`, `live: bool`.
  Renders `data-slot="card"`, `data-size`, and header / title /
  description / action / content / footer slots carrying shadcn's
  `data-slot` names. The header renders when any of title, description or
  action is present. There are no rules between the parts: shadcn separates
  them with spacing, so the stylesheet uses `gap` plus per-part padding.
  `live` marks it an ARIA live region, for a card the server replaces in
  place (the countries detail panel). Card title/description are `div`s,
  matching shadcn v4 (`<h3>`/`<p>` in v3).
  The kitchen sink renders two cards in a Grid: the full anatomy with an
  action and a footer, and the compact `size = sm` one.
- **Stack** — vertical flex. `gap: none|sm|md|lg = .md`,
  `alignment: start|center|end|stretch = .stretch`, `children`.
- **Cluster** — horizontal, wrapping (toolbars, button rows).
  `gap = .sm`, `justify: start|between|end = .start`, `children`.
- **Grid** — `cols: one|two|three|auto = .auto`, `gap = .md`, `children`.
  `auto` is `repeat(auto-fit, minmax(14rem, 1fr))`; the fixed counts
  collapse to one column under 34rem.
- **Container** — `width: prose|page|full = .page`, `children`. Centred
  max-width wrapper (34rem / 60rem / unbounded).
- **Separator** — `orientation: horizontal|vertical = .horizontal`,
  `label: ?[]const u8`. A rule, optionally with a centred label
  (`—— or ——`), or a vertical spacer inside a flex row.

Nesting is the point — a Card holding a Grid of Stacks is one tree:

```zig
const card = try view.Card.render(a, .{
    .title = "Board",
    .children = try view.Grid.render(a, .{ .cols = .two, .children = &stacks }),
});
```

`Alignment` is spelled `alignment` because `align` is a Zig keyword.

The kitchen sink's **Card** section is the live composition
(`zlive-examples/src/views/kitchen_sink.zig`): a Card with all four slots
populated — header, a Stack body (paragraph → labelled Separator → Cluster),
and a text footer — whose buttons carry the page's existing `inc` and
`flash` events. It reads no server state, so after mount it never appears in
a patch. `Grid` and `Container` are the two primitives with no call site
there: the page shell already constrains width, and the table spreads its
own columns.

## Flash — no hook

- **Props**: `message`, `level: .info|.success|.err`
- **Events**: none from the client; shown and dismissed by server push
- **Split**: server owns the TTL. The message lives in a `zlive.http.Queue`
  of capacity 1 (the inline banner), whose reaper re-renders the view when
  it expires — so the dismiss patch is an ordinary diff
  (`{"<slot>": []}`), not a patch the timer writes around the view.

## Toast / ToastRegion — no hooks

A Toast is a notification with a corner presentation. The messages, their
deadlines and their identity live in a `zlive.http.Queue` (capacity 3 in the
demo); `ToastRegion` is the fixed viewport and the stack, `Toast` is one
message inside it.

- **Props (ToastRegion)**: `corner: top_left|top_right|bottom_left|bottom_right
  = .bottom_right`, `children`. Renders `data-slot="toast-region"` and
  `data-corner="top-right"`; `Corner.tag()` gives the rendered value and
  `Corner.fromTag()` parses it back (server-side click values).
- **Props (Toast)**: `id: ?[]const u8`, `message`,
  `level: .info|.success|.err`, `title: ?[]const u8`,
  `dismissible: bool = true`. Renders `data-slot="toast"`, `data-level`,
  `role="status"` (`alert` for `.err`) and, when dismissible, a Button whose
  event is `zc:toast:dismiss`.
- **`id`** is the item's identity: the element's DOM id (`zc-toast-<id>`, so
  morphdom matches a toast by identity and reuses its element when a
  neighbour leaves) and the value the close button reports. A view fills it
  in from the queue item (`item.id` as decimal text); without one, neither
  the id nor the dismiss value is rendered.
- **The stack**: render the queue's `items()` — oldest first, one child node
  per toast — as the region's `children`. Then showing a toast patches only
  the appended index, dismissing one compacts the list (the survivors shift
  down, their elements matched by id), and the region's own slot never
  changes. The order in the DOM is age order; CSS does the corner work:
  `column` for the bottom corners and `column-reverse` for the top ones, so
  the newest toast is always nearest the edge.
- **Dismissal is per toast**: `zc:toast:dismiss` carries the id, the app
  calls `queue.dismiss(id)`, and the next diff drops exactly that item. A
  close and a TTL produce the same patch shape, because both are just "the
  item is gone" — the TTL case re-renders through the queue's reaper.
- **Why the region is always mounted**: the region is a fixed node from
  mount, so the region's own position is never re-sent and CSS can animate
  each toast as it is inserted. The corner lives on the region, not the
  toast: switching corners is one patch on `data-corner` and leaves the
  stack untouched.
- **Capacity**: the queue drops the oldest item when it is full, so the
  newest message is never the one lost.
- **Divergence from shadcn/Sonner**: no swipe-to-dismiss, no
  hover-to-pause, no per-toast progress bar, and no "stacked peek" (Sonner
  collapses a taller stack behind the front card).

## Icon — no hook

- **Props**: `name: Name` (23 lucide shapes: `panel_left`, `chevrons_up_down`,
  `plus`, `square_terminal`, `bot`, `book_open`, `settings_2`,
  `chevron_right`, `frame`, `pie_chart`, `map`, `more_horizontal`, `folder`,
  `forward`, `trash_2`, `sparkles`, `badge_check`, `credit_card`, `bell`,
  `log_out`, `gallery_vertical_end`, `audio_waveform`, `command`), `class`
- **Renders**: an inline 24×24 `<svg>` with lucide's shape data, stroked with
  `currentColor`, plus `data-icon="<name>"` for styling hooks and tests. The
  shapes are in the template — nothing is fetched at runtime, and an icon
  change is an ordinary segment patch.
- **Attribution**: shapes are [lucide](https://lucide.dev)'s (ISC licence).
- **Sizing**: the context sets it (a sidebar row's icon is 1rem, the team
  logo square 0.75rem); `.zc-icon` is the 1rem default.

## Avatar — no hook

- **Props**: `src: ?[]const u8` (an `<img>` when set), `fallback`
  (initials — always rendered underneath), `class`
- **Renders**: `data-slot="avatar"` + `data-slot="avatar-image"` /
  `data-slot="avatar-fallback"`. `class = "zc-avatar-square"` is the
  rounded-square variant shadcn's sidebar uses.
- **Divergence**: there is no client-side image-error handling, so a demo
  without avatar files passes `src = null` and shows the fallback; shadcn's
  Radix Avatar hides a broken image at runtime.

## Breadcrumb — no hook

- **Props**: `trail: []Item` (`Item{label, href}` — the ancestors, in
  order), `page` (the current page: no link, `aria-current="page"`), `class`
- **Renders**: `nav[aria-label=breadcrumb] > ol` with `data-slot="breadcrumb-*"`
  per part and a chevron separator between items.
- **Divergence**: one component with a trail instead of shadcn's
  Breadcrumb/BreadcrumbList/Item/Link/Page/Separator composition — the same
  markup for the one case a page header needs.

## Collapsible — no hook

- **Props**: `id`, `open`, `trigger: []const Segment`, `children`, `class`
- **Renders**: `data-slot="collapsible"` with `data-state="open|closed"`,
  the trigger in its own wrapper, and the content in a
  `.zc-collapsible-content > .zc-collapsible-inner` pair.
- **The content stays mounted** and is collapsed with
  `grid-template-rows: 1fr → 0fr` (plus `visibility: hidden`, so a closed
  panel is out of the tab order), which makes opening and closing a single
  `data-state` patch and lets CSS animate the height.
- **Divergence**: shadcn's `asChild` has no equivalent in a template
  language, so the trigger is a slot rather than the component's own element
  — and inside the sidebar the nav rows carry the state themselves
  (`SidebarMenuItem.open`), which is what shadcn's `Collapsible asChild`
  around `SidebarMenuItem` compiles to.

## Sidebar — hook `zc-sidebar`

shadcn's `Sidebar` primitive set, which is what the `sidebar-07` block is
built from: `SidebarProvider`, `Sidebar`, `SidebarTrigger`, `SidebarRail`,
`SidebarInset`, `SidebarHeader`, `SidebarContent`, `SidebarFooter`,
`SidebarSeparator`, `SidebarInput`, `SidebarGroup`, `SidebarGroupLabel`,
`SidebarGroupAction`, `SidebarGroupContent`, `SidebarMenu`,
`SidebarMenuItem`, `SidebarMenuButton`, `SidebarMenuAction`,
`SidebarMenuBadge`, `SidebarMenuSub`, `SidebarMenuSubItem`,
`SidebarMenuSubButton`. A live page is `/sidebar` in the demo app (shadcn's
`sidebar-07`: a team switcher, the Platform nav with collapsible sub-menus,
a Projects group and a user menu — and, in the icon rail, popup menus for
the nav rows).

- **Props (SidebarProvider)**: `open: bool = true`, `side`
  (`left|right`), `variant` (`sidebar|floating|inset`), `collapsible`
  (`offcanvas|icon|none`), `class`, `children`. Each enum has `tag()` (the
  rendered value) and `fromTag()` (parsing a click value back).
- **Props (Sidebar)**: `class`, `children` — renders the gap + container +
  inner.
- **Props (SidebarMenuButton)**: `id`, `label`, `icon: ?Icon.Name`,
  `size` (`sm|default|lg`), `variant` (`default|outline`), `active`,
  `chevron`, `href` (an `<a>` instead of a `<button>`), `event`, `value`,
  `expanded`, `title`, `children: ?[]const Segment`, `class`. Custom
  `children` is what shadcn gets from `asChild` (the team switcher's logo
  box, the user row's two lines) and it replaces the icon + label + chevron
  shape.
- **Props (SidebarMenuSubButton)**: the same minus `variant`/`chevron`, with
  `size` (`sm|md`).
- **Props (SidebarMenuItem)**: `open: ?bool` — `null` renders no
  `data-state` (a plain row); a nav row keeps the attribute for its whole
  life, so opening its sub-list is one patched value.
- **Props (SidebarMenuAction)**: `id`, `name: Icon.Name`, `event`
  (`zc:dropdown:toggle` by default), `value`, `label`, `show_on_hover`.
- **Events**: whatever the view passes (`zc:sidebar:toggle` for the trigger
  and rail in the demo, `zc:sidebar:nav` for a nav row, `zc:dropdown:toggle`
  for the menus). The library owns no event names of its own here.
- **The whole layout is one attribute.** The provider renders `data-state`
  (`expanded|collapsed`), `data-side`, `data-variant` and `data-collapsible`
  (the configured *mode*, always present), and every descendant is styled
  from those — gap width, container width/offset, labels, sub-menus, badges
  and actions in the icon rail, group labels fading, the header height in
  the block. Collapsing is therefore **one patched slot**, and the animation
  is entirely CSS: no client state, no hook, nothing to re-render per
  descendant.
- **Divergences from shadcn**, all deliberate:
  - the state attributes live on the **provider** (the wrapper), where
    shadcn puts them on the Sidebar root and reaches the siblings with
    Tailwind's group/peer variants. One provider-level attribute is the same
    styling with one patch instead of one per element;
  - `data-collapsible` carries the mode rather than being blanked when
    expanded, for the same reason (a collapse changes one attribute);
  - **mobile is CSS-only**: the same `data-state` slides the sidebar over
    the content below 768px, with a scrim button that sends the toggle
    event. shadcn mounts a Sheet (portal + viewport hook + a second
    `openMobile` state); this has no portal, no hook and one state, at the
    cost of sharing the collapsed/expanded meaning across breakpoints;
  - `SidebarMenuButton.title` is a native tooltip. shadcn renders a floating
    Tooltip per row while collapsed, which would be one Tooltip component
    (and one client hook) per row — and would put N slots in the collapse
    patch;
  - the icon rail's 3rem squares, the rail's hairline and the collapse
    selectors are hand-written CSS off `data-state`/`data-collapsible`
    instead of Tailwind's `group-data-[collapsible=icon]:…` utilities;
  - `zc-hide-collapsed` is the caller-side class for a whole group that
    should disappear in the icon rail (shadcn spells it
    `group-data-[collapsible=icon]:hidden` on the group);
  - in the icon rail a row cannot show its sub-list, so the demo view turns
    the same `zc:sidebar:nav` click into a **popup menu** beside the rail
    (`DropdownPanel` anchored to the row, `side=right`, the current sub-item
    marked as a radio row). shadcn's icon mode leaves the sub-items
    unreachable; because the view branches on server state, the row's markup
    is identical expanded and collapsed — the popup costs one appended slot,
    never a re-render of the rail;
  - the rail's `lg` rows are avatar/logo *tiles*, so in the icon rail they
    keep their full 2rem and drop the 0.5rem padding (shadcn's `p-2!` would
    crop them to a 1rem window).
- **Hook (`zc-sidebar`, on the provider)**: only what CSS cannot do — the
  **Cmd/Ctrl+B** shortcut (sends the toggle event) and mirroring
  `data-state` into the `sidebar_state` cookie on every update, which is the
  cookie shadcn writes. The demo's page reads it back and passes it in the
  join payload, so a reload returns to the same state.
- **Icons in collapsed mode**: an icon-only row keeps its label in the DOM
  and the CSS hides it, so widening the sidebar restores the text with no
  round trip.

## SiteHeader — no hook

The page header shadcn's blocks put above the content (sidebar-16's
`SiteHeader`): a 4rem bar with the page background and a bottom rule, whose
frame — not its contents — is the component.

- **Props**: `sticky: bool = false`, `class`, `children` (the bar's
  contents: trigger, separator, breadcrumb, actions — the page composes
  them).
- **Sizing**: 4rem, shrinking to 3rem while an enclosing sidebar is collapsed
  to the icon rail (shadcn's `group-has-data-[collapsible=icon]:h-12`).
- **Sticky**: `data-sticky="true"` is `position: sticky; top: 0; z-index: 10`
  — under the overlay ladder (dropdown 30, tooltip 40, toast 50), so a menu
  opened from the header still paints over it. The page needs content taller
  than the viewport for the effect to be visible, which the demo has.
- **Composition**: `SidebarLayout` renders it; use it directly when the
  header is not next to a sidebar.

## SidebarLayout — hook `zc-sidebar`

The dashboard frame as one component: the provider's attributes and scrim,
the `Sidebar` column, and a `SidebarInset` holding a `SiteHeader` and the
page content. It exists so a page configures the frame instead of
re-assembling `SidebarProvider` + `Sidebar` + `SidebarInset` by hand — every
option is a prop.

- **Props**: `open: bool = true`, `side` (`left|right`), `variant`
  (`sidebar|floating|inset`), `mini: bool = true`, `header_placement`
  (`inset|full`), `sticky_header: bool = false`, `header`, `sidebar` and
  `content` (segment slots), `class`.
- **`mini`**: what a collapse leaves behind — `true` maps to
  `data-collapsible="icon"` (the 3rem rail), `false` to `"offcanvas"` (the
  sidebar slides away). It is the block's "collapse to icons" switch.
- **`header_placement`**: `inset` puts the bar inside the content column
  (sidebar-07). `full` makes the frame a column — the bar across the top,
  the sidebar and content in a row below it — and pins the fixed sidebar
  below the bar by `--header-height` (sidebar-16's structure). A full-width
  header is always sticky: it is the offset the sidebar hangs from, so
  `sticky_header` only applies to the inset placement.
- **`sticky_header`**: forwarded to `SiteHeader.sticky` in the inset
  placement.
- **One attribute per option**: `open`, `side`, `variant`, `mini` and
  `sticky_header` each render exactly one attribute, so flipping one is one
  patched slot; the slots below are untouched.
- **Primitives stay available**: `SidebarProvider` / `Sidebar` /
  `SidebarInset` still exist for layouts this component does not cover; its
  markup is the same by design (the composed frame is not a second dialect).

## Table — no hook

- **Props**: `columns: []Column{key,label}`, `rows: [][]Scalar`,
  `empty`, `row_ids: ?[][]const u8`
- **Events**: none built in — callers embed triggers in string cells
  (string scalars flatten as raw HTML; **escape user input**)
- **Split**: 100% server. `row_ids` give `<tr>`s stable ids so re-sorts
  reorder keyed elements instead of rewriting every cell.

## TextInput / Select / Checkbox / Form / SubmitButton — no hooks

- **Props**: see `render` doc comments in the per-component source files (`src/button.zig`, `src/form.zig`, ...). Form fields carry an
  `error_msg: ?[]const u8` rendered into a per-field error span.
- **Events**: `input` via `data-lv-change` on every keystroke
  (`{id, value}`); forms submit via a plain button's `data-lv-click`.
- **Split**: 100% server, including the SubmitButton loading state
  (`disabled` + `Saving…` as patches) and validation errors appearing and
  clearing as single-slot diffs. Value preservation across patches is a
  consequence of slot isolation: an unchanged value emits no patch, and
  morphdom updates attributes in place.

## Dialog — hook `zc-dialog`

- **Props**: `id`, `title`, `children`
- **Events**: close button + backdrop carry
  `data-lv-click="zc:dialog:close"`; Escape also sends it (hook)
- **Hook**: focus trap (Tab wrap), Escape, body scroll-lock (refcounted),
  initial focus + restore. `updated()` is deliberately empty — never steal
  focus from a form being typed into.
- **Split**: server renders semantics (`role="dialog"`, `aria-modal`,
  `aria-labelledby`) and owns open/close state; the hook owns focus and
  keyboard. Portal rule: rendered as a single node at view root.

## Tabs / Accordion — no hooks

- **Props (Tabs)**: `id`, `tabs: []Tab{key,label,content}`, `active`
- **Props (Accordion)**: `id`, `sections: []Section{key,title,content}`,
  `open: [][]const u8`
- **Events**: header buttons send `switch_tab` / `toggle_section` with
  `data-lv-value="<key>"`
- **Split**: 100% server state; switching patches the active-indicator
  statics + region (Tabs: 3 patches; Accordion: 2 — aria value + body).

## Dropdown / Popover — hooks `zc-dropdown` / `zc-popover`

Dropdown is shadcn's DropdownMenu: a Button trigger plus a menu panel whose
rows are typed by `kind`.

- **Props (Dropdown)**: `id`, `label`, `open`, `items: []Item`, `placement`,
  `variant` / `size` (the trigger Button's, `outline` by default),
  `open_sub: ?[]const u8`
- **Props (DropdownPanel)**: `id`, `items`, `placement`, `open_sub`
- **Item kinds** (`Item{kind, label, event, value, shortcut, variant,
  inset, disabled, checked, sub}`):
  - `.item` — `role="menuitem"`, plus `variant = destructive`, `inset`,
    `disabled`, and a right-aligned `shortcut` hint
  - `.checkbox` — `role="menuitemcheckbox"`, `aria-checked`, and an
    indicator span rendered only while checked (shadcn's ItemIndicator)
  - `.radio` — `role="menuitemradio"`, same indicator treatment; the caller
    renders one checked row per group
  - `.label` / `.separator` — `role="separator"` and a plain heading
  - `.sub` — a sub-trigger (`aria-haspopup="menu"`, `aria-expanded`) plus
    `sub: []Item`; the nested panel renders inside the menu and anchors to
    the trigger's id (`<menu id>-sub-<value>`)
- **Events**: `zc:dropdown:toggle` / `zc:popover:toggle` from the trigger;
  rows send their own `data-lv-click` events; `zc:dropdown:sub` carries the
  submenu key; outside-click and Escape (hook) send
  `zc:dropdown:close` / `zc:popover:close`
- **Hook**: positions the panel with Floating UI (`strategy: "fixed"`,
  offset/flip/shift) relative to `data-zc-anchor`, repositions on
  `updated`, detects dismissal. First menu item takes focus; an opening
  submenu focuses its own first row.
- **Shape of `Popover.render`** (a contract callers depend on, and one
  `overlays_test.zig` pins): a flat run of trigger segments followed by
  **one `children` node** holding the panel — or nothing while `open` is
  false. A view therefore splices `[0 .. len-1]` where the trigger belongs
  and appends `[len-1]` as the overlay. Taking a fixed index instead (the
  kitchen sink used `popover[1]`, one dynamic segment of the trigger)
  renders the anchor id as loose text and never shows the panel.
- **Split**: server owns *everything stateful* — which menu is open, which
  rows are checked, which submenu is open — and renders/removes panels (via
  `DropdownPanel`, spliced at view root — never inside a table row); the
  hook owns positioning and gesture detection. The fixed strategy is what
  escapes clipping ancestors. A checkbox row does not close the menu
  (shadcn's behaviour); a plain row does.
- **Divergences from shadcn**, all deliberate:
  - rows are `<button>`s, not `div[role=menuitem]`, so the hook can focus
    them and the keyboard/AT story works without a roving-tabindex
    implementation;
  - `checked` is carried by `aria-checked` alone. Radix also mirrors it into
    `data-state`; a single carrier is what keeps a checkbox toggle at one
    patch for the attribute plus one for the indicator;
  - a submenu opens on **click**, not hover, and there is no arrow-key
    submenu navigation yet — hover-open would mean a server round trip per
    pointer move, and the hook has no roving-focus model;
  - one level of nesting: a submenu's rows may not themselves be `.sub`.

## Tooltip — hook `zc-tooltip`

- **Props**: `anchor` (element id), `text`, `placement`
- **Events**: **none** — the only state-free component. Hover/focus
  toggles visibility client-side; no server roundtrip, no state.
- **Hook**: positions with Floating UI on show.

## Chart — hook `zc-chart`

- **Props**: `id`, `spec` (the Apache ECharts option, serialized to JSON by
  the view), `height` (default `320px`)
- **Events**: **none** — the chart is output-only.
- **Hook**: `echarts.init` on mount, `setOption(spec)` on `updated`,
  `dispose` on `destroyed`; a window-resize listener calls `chart.resize()`.
- **Client-owned subtree**: the element carries `data-lv-ignore`, so
  morphdom morphs its attributes (a spec change is exactly the
  `data-lv-chart` slot — one patch) but never touches the canvas ECharts
  drew inside. ECharts is loaded by the page via CDN (`window.echarts`),
  like Floating UI; the server owns the spec, the hook owns the canvas.

## JavaScript model & multiple instances

**Two files, two responsibilities** (`client.js` in zlive, `src/hooks.js` here):

- `client.js` owns everything *protocol and DOM-agnostic*: the socket
  (join, per-message JSON envelopes, ref pairing, reconnect with backoff),
  the tree model (apply patches, flatten, morphdom), and the two delegated
  event contracts — `data-lv-click`/`data-lv-value`/`data-lv-payload` and
  `data-lv-change`. It never knows about components.
- `hooks.js` owns everything that needs *the rendered DOM*: the `LiveHooks`
  registry plus the `zc-*` hooks. It never touches the socket or the tree
  directly — it reaches the protocol only through `Live.send`.

**How a component gets its JS**: a component's markup includes
`data-lv-hook="<name>"`. The registry (`LiveHooks.register(name, {mounted,
updated, destroyed})`) is name-based; **instances are element-based** — the
internal `attached` map and every hook's state WeakMap are keyed by the
element, not the name. Lifecycle is driven by rendering: elements inserted
by a render/patch morph fire `mounted`, in-place morph updates fire
`updated`, removals fire `destroyed` (see the dialog hook's contract: never
steal focus in `updated`).

**Multiple instances of the same component work, with these rules:**

1. *Element-keyed state*: each instance's listeners, focus memory and
   positioning state live in its own WeakMap entry — N tooltips, N dialogs,
   N dropdowns don't collide. Verified live: two `zc-tooltip` instances on
   the kitchen sink position independently (placement top vs bottom).
2. *Unique ids are the caller's contract*: anchors are resolved with
   `getElementById`, so two floating panels anchored to the same id would
   both follow the first match. Every instance gets `{id}-panel` /
   `{anchor}-tip` ids from the components; pass distinct `Props.id`s.
3. *Shared resources are refcounted*: the dialog's body scroll-lock counts
   open dialogs; each dialog still restores its own `prevFocus`, so stacked
   dialogs unwind focus correctly.
4. *Dismissal semantics are per-instance but cooperative*: each open
   dropdown/popover listens on document click/Escape (capture). Clicking
   one component's trigger is "outside" the other, so opening one closes
   the other — that is intentional, not a limitation of the registry.
5. *Single-instance exceptions are deliberate*: Flash keeps one
   `FlashState` per connection — a new flash supersedes the old one (older
   timers exit via a generation counter and their own refcount).

Server-side, instances are just tree slots: two dialogs render as two root
nodes with distinct ids, morphdom's keyed matching inserts/removes each
independently, and patches address each slot separately.
