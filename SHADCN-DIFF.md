# zc.css vs shadcn/ui — the recheck

What this is: a line-by-line comparison of this library's hand-written
stylesheet against shadcn's actual sources, and the list of what that
comparison changed. It was done by fetching shadcn's files at `main` and
mapping every Tailwind class in a component's `className` onto the
declarations in `zc.css`, part by part (`data-slot` to rule).

Two authorities were read, and they do not agree with each other:

- **`apps/v4/registry/themes.ts`** — the theme registry. This is what
  `shadcn init` installs and what the `/themes` page offers: seven base colors
  with a complete token set, plus seventeen accent themes that layer on top.
  **This is the authority `zc.css` now follows**, because the theme system is
  built from it (see `scripts/gen_themes.py`).
- **`apps/v4/app/globals.css`** — the shadcn *website's own* stylesheet. It
  uses `oklch(0% 0 0)` for `--foreground`/`--primary`, i.e. pure black. Our
  first port copied those values, which is exactly why the default palette
  looked heavier than an installed shadcn: the registry's `neutral` is
  `oklch(0.145 0 0)` / `oklch(0.205 0 0)`.

  The website is not a theme; the registry is. Everything below is against the
  registry.

## 1. Tokens

| token | was | shadcn `neutral` (light) | now |
| --- | --- | --- | --- |
| `--foreground`, `--card-foreground`, `--popover-foreground` | `oklch(0% 0 0)` | `oklch(0.145 0 0)` | registry |
| `--primary` | `oklch(0% 0 0)` | `oklch(0.205 0 0)` | registry |
| `--chart-1…5` | absent | the five-step ramp | added (all 24 themes) |
| `--destructive-foreground` | `oklch(0.97 0.01 17)` / `oklch(0.58 0.22 27)` | **does not exist** (v4 uses `text-white`) | removed |
| `--radius-sm/md/lg/xl` | `0.6× / 0.8× / 1× / 1.4× --radius` | `calc(var(--radius) ∓ 4px/2px)` | shadcn's formula |
| dark `--foreground` … `--sidebar-ring` | already correct | — | unchanged (verified) |
| sidebar tokens | already correct | — | unchanged (verified) |

The `--radius` formulas happen to agree at shadcn's `0.625rem`
(6/8/10/14px) but diverge for any other radius, so they were replaced.

The old pre-shadcn aliases (`--bg`, `--fg`, `--surface`, `--surface2`,
`--border2`, `--accent-soft`, `--chart-track`, `--err`) are gone: twelve rules
still used them, and an alias declared on `:root` cannot follow a palette that
is scoped to a subtree. `--ok` and `--hook` stay — they are demo-only colours
(the protocol log), not shadcn tokens.

## 2. The global find: box-sizing

`zc.css` is the only stylesheet in the repo and had no preflight, so
everything was `content-box`. Tailwind's preflight sets
`box-sizing: border-box`, and every shadcn size assumes it: `h-9` is **2.25rem
including the border**, so each of our bordered controls rendered 2px taller
than shadcn's (buttons 38px instead of 36px, inputs ~34px, dialogs 2px wider
than their `max-width`). Fixed with one scoped-but-global reset:

```css
*, *::before, *::after { box-sizing: border-box; }
```

## 3. Per component

### Button (`button.tsx`)

| part | shadcn | was | now |
| --- | --- | --- | --- |
| base | — | `box-shadow: var(--shadow-xs)` on every variant | shadow only on `outline` |
| `destructive` | `text-white`, `dark:bg-destructive/60` | pink-tinted `--destructive-foreground`, full-strength dark fill | `color: #fff` + dark 60% wash |
| `outline` | `border-border`, `dark:bg-input/30`, `dark:hover:bg-input/50` | `--input` in both modes, opaque | `--border` light, dark wash |
| `ghost` | `dark:hover:bg-accent/50` | solid accent | 50% wash in dark |
| `xs`, `icon-xs` | `rounded-md` | `rounded-sm` | `--radius-md` |
| `xs`, `icon-xs` svg | `size-3` | 1rem | 0.75rem |
| `has-[>svg]` | narrows inline padding (`px-3/2.5/4/1.5`) | absent | `:has(> svg)` rules |
| `link` | keeps the size's height | `height: auto` | keeps it |

### Card (`card.tsx`)

`gap-6` (1.5rem, was 1rem), header `gap-2` (0.5rem, was 0.375rem), title
`leading-none` (was 1.3), footer inherits the card's colour and size (was
forced to 0.875rem `--muted-foreground`). Our `data-size="sm"` is an addition;
shadcn v4's Card has no size prop.

### Input, select, label (`input.tsx`, `select.tsx`, `label.tsx`)

The controls were the biggest visible gap: no height, no radius, `padding:
0.35rem`, no focus ring, no placeholder colour.

- `h-9` (2.25rem), `rounded-md`, `padding: 0 0.75rem`, `text-sm`
  (16px below 768px), transparent background — so a control on a card shows
  the card, not the page — `shadow-xs`, a 3px `--ring` focus ring, a
  `--muted-foreground` placeholder, and `dark:bg-input/30`.
- `Label` is `text-sm leading-none font-medium`; ours was `0.85rem`, weight
  400, with margins shadcn does not have.

### Dialog (`dialog.tsx`)

`max-w-lg` (32rem; was 26rem **plus** padding and border), `p-6` (was
`1.25rem 1.5rem`), `gap-4` between children (was none), `bg-background` (was
`--card`, which is lighter in dark mode), vertically centred (was `10vh`), a
`text-lg/leading-none/font-semibold` title (was the UA's 24px/700 `h2`), and a
close button at `top-4 right-4` with `opacity-70 → 1` (was `×` at 1.3rem at
6.4/9.6px).

### Dropdown, popover, tooltip

- **Dropdown**: `overflow: hidden` with no `max-height` clipped any menu taller
  than the viewport; now `overflow-y: auto` with a 24rem cap. Separator is
  `--border` (was `--muted`, nearly invisible on a popover), label weight 500
  (was 600), sub-menu gets `shadow-lg`.
- **Popover**: `w-72` fixed (was `max-width`), `p-4` (was `0.5rem 0.9rem`), and
  its trigger is an outline Button at default size (`h-9 px-4 font-medium
  shadow-xs`) instead of a 2rem pill.
- **Tooltip**: `px-3 py-1.5 rounded-md text-xs` (was `0.2rem 0.5rem`,
  `rounded-sm`, 0.8rem), and `sideOffset` is now 0 as in shadcn
  (`data-zc-offset` on the panel; dropdown/popover keep shadcn's 4).

### Toast / sonner

Geometry moved to sonner's defaults, which is what shadcn mounts: padding 1rem
(was 0.75/0.9rem), stack gap 0.875rem (was 0.5rem). Our per-level tinting and
in-flow close button remain (see deviations).

### Separator, avatar, breadcrumb

- Separator: `flex-shrink: 0` (a vertical rule could be squeezed to 0 in a flex
  row). The generic `.zc-sep` still adds a 0.75rem vertical margin — shadcn's
  has none, and its call sites space it — which is a deviation we keep.
- Avatar fallback: `text-sm` (was 0.75rem/500).
- Breadcrumb: gap widens to 0.625rem from 640px up; the link transitions.

### Sidebar — four real cascade bugs

These were bugs, not style choices: a rule with lower specificity was being
silently overridden, and nothing failed.

1. **The trigger rendered 36px instead of 28px.** `#lv .btn[data-size="icon"]`
   (specificity 1,2,0) beat `.zc-sidebar-trigger` (1,1,0). Fixed by making the
   component rule `.btn.zc-sidebar-trigger`.
2. **Every sidebar separator got a 12px vertical margin and lost its `mx-2`.**
   `.zc-sep` is declared later at equal specificity, so it won the cascade.
   Fixed with `.zc-sep.zc-sidebar-separator`. The same bug collapsed the
   sidebar-07 header divider to a 0×1px hairline: its page rule was
   `.dash-header .dash-sep` (0,2,0) — now `#lv .dash-header .dash-sep`.
3. **The menu action's hover ink never applied.** A later rule with equal
   specificity re-declared `color: var(--sidebar-foreground)` on the wrapper;
   the hover colour was dead code. The redundant rule is gone, and the row's
   hover now turns the action and badge ink to `--sidebar-accent-foreground`,
   as in shadcn.
4. **Collapsing hid the sidebar on desktop, icon rail and all.** The mobile
   drawer's `transform: translateX(±100%)` was declared outside its
   breakpoint, so *every* collapsed state inherited it: the container slid
   off-screen and the page showed an empty strip where the 3rem rail should
   have been. The transform is now scoped to `max-width: 767px`, desktop pins
   the container and collapses by width (icon) or offset (offcanvas), and
   `css_test.zig` asserts the transform can only live under the small-screen
   query.

Plus: the badge had **no `top`**, so (being absolutely positioned with `auto`)
it rendered at its static position *below* the row; a row with a menu action
now pads its label clear of it (`pr-8`); the action/badge offsets follow the
row size (`sm`/default/`lg`); the right-hand rail was missing its
`translateX(-50%)`; the collapsed-offcanvas rail sat 8px too far out and kept
its hairline at 50% instead of the outer edge; the mobile scrim was `black/30`
(shadcn's Sheet overlay is `black/50`) and the drawer had no edge divider below
768px; sub-menu icons use `--sidebar-accent-foreground`; rows have a pressed
state; and the five sidebar controls got shadcn's 2px `--sidebar-ring` focus
ring. A right-hand sidebar now reverses the flex row (shadcn's
`data-[side=right]:order-last`), so the width-reserving gap and the fixed
container both move to the right instead of leaving a strip on the left.

## 4. Deliberate deviations (kept)

- **Cursors.** shadcn's dropdown rows are `cursor-default`; ours are a hand.
  That is a product decision made earlier in this project: a clickable row
  should look clickable. The rail keeps its resize cursors.
- **Themes are scoped per subtree** (`data-base`/`data-accent` work on any
  element) and the mode is `data-theme="dark"` on `<html>`, not `.dark`.
- **No Tailwind**, so `color-mix()` stands in for `/90`, `/60`, `/30`; there is
  no `cn()` merge, and variants come from `data-*` attributes.
- **Component patterns we chose**: the Table is a bordered grid with monospace
  cells and row striping (shadcn: bottom borders, `p-2`, sans); Tabs are the
  underline pattern (shadcn v4's default is a segmented control); Accordion
  has no chevron; the toast stack tints by level and keeps its close button
  in flow; Select uses the native popup; the mobile sidebar is CSS-only with a
  scrim button instead of a Sheet; dropdown/tooltip glyphs are text, not lucide
  icons.
- **The z-index ladder is ours** (dialog 20 < dropdown/popover 30 < tooltip 40
  < toast 50). shadcn puts nearly everything at `z-50`; a single ladder inverts
  the same relationships more predictably (a dropdown inside a dialog still
  stacks above it).
- `--ok` and `--hook` are demo-only semantic colours, not tokens.

## 5. Still open (recommendation, not done)

| item | shadcn | ours | recommendation |
| --- | --- | --- | --- |
| Table | row bottom borders, `p-2`, `h-10` head, `text-sm` sans, row hover | 1px grid, `0.3rem 0.75rem`, monospace 0.9rem, zebra, cell hover | port it; it reads as a different component. Needs a `table.zig` rework |
| Tabs | `bg-muted h-9 rounded-lg p-[3px]`, active `bg-background shadow-sm` | underline bar | CSS-only change; decide whether the underline is wanted |
| Accordion | `py-4 text-sm font-medium`, chevron, no rule on the last item | tighter padding, weight 600 when open, no chevron | cheap; do it with Tabs |
| Badge | `rounded-full px-2 py-0.5 text-xs` | no component | add |
| Textarea | `min-h-16 px-3 py-2 rounded-md` | no rule at all | add |
| Checkbox | `size-4 rounded-[4px] border-input`, primary fill, focus ring | bare UA input | style it (input + label) |
| Avatar sizes | `data-[size=sm|lg]` → 1.5rem/2.5rem | fixed 2rem | add the prop |
| Sidebar skeleton | `SidebarMenuSkeleton` | absent | add when needed |
| `aria-invalid` | destructive border + 20% ring | absent | add to inputs/buttons |
