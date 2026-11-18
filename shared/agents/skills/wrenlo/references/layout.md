# Layout and report patterns

Every HTML artifact gets these styles. No import, framework, or build step is needed. Use semantic HTML and kit classes for common layouts. Custom CSS can define a subject-specific composition, drawing area, category color mapping, or print layout.

## Layout

| Class                                                         | Effect                                                                        |
| ------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| `wr-page`                                                     | Centered page, up to 64rem wide, with responsive padding                      |
| `wr-stack`                                                    | Column with 16 px gaps                                                        |
| `wr-row`                                                      | Wrapping row, centered vertically, with 12 px gaps                            |
| `wr-grid`                                                     | Automatic equal columns, each at least 14rem unless the container is narrower |
| `wr-grid-2`, `wr-grid-3`, `wr-grid-4`                         | Column count modifiers for `wr-grid`                                          |
| `wr-between`, `wr-center`                                     | Horizontal distribution modifiers for rows, toolbars, and action rows         |
| `wr-gap-4`, `wr-gap-8`, `wr-gap-12`, `wr-gap-16`, `wr-gap-24` | Gap modifiers for any kit layout                                              |
| `wr-grow`                                                     | Fill the remaining space in a row                                             |
| `wr-sr-only`                                                  | Hide text visually but keep it available to assistive technology              |

At viewport widths of 800 px or less, three- and four-column grids become two columns. At 600 px or less, every fixed-column grid becomes one column. The plain `wr-grid` fits its columns to the container instead.

`wr-between` and `wr-center` set `justify-content`. On a stack, they distribute content vertically, not horizontally. They do not replace the layout class.

`wr-grow` allows a child to shrink below its content width. Wrap long text when your content needs it. For unusual layouts, write CSS rather than adding many unrelated classes.

## Report patterns

A tone is a shared status color. Set `data-tone` to `accent`, `neutral`, `info`, `success`, `warning`, or `danger`. All tones follow light and dark mode.

- `wr-card` keeps a neutral border. A `data-tone` passes its color to progress bars inside.
- `wr-badge` with `data-tone` adds colored text and a soft background.
- `wr-filter` turns a button into a multiline filter card.
- `wr-toolbar` aligns fields and buttons at their bottom edges and wraps them on narrow screens.
- `wr-actions` makes a wrapping row of actions with 8 px gaps.
- `wr-empty` centers an empty-state heading, explanation, and optional action.

A progress bar inherits the nearest tone. Badges need their own `data-tone` to opt into tone styling. Card borders stay neutral. Always name the status in text. Color alone does not describe it.

Use the CSS property `--wr-tone` with a theme token for a category-specific color, for example `data-tone="accent" style="--wr-tone: var(--wr-chart-5)"`.

### Cards, badges, and filters

Use existing components inside the patterns. Do not redraw a metric or a progress bar with custom CSS.

`wr-filter` supplies appearance only. Your script must update `aria-pressed` and filter the results. Use a real `button` with `type="button"`. For form choices, use radios or checkboxes with `wr-choices` instead.

`aria-pressed="true"` styles selected buttons, including filter cards. Selected filters use the accent border, not their status color. A disabled button keeps its disabled appearance and does not gain a hover background.

```html
<div class="wr-grid wr-grid-4">
  <section class="wr-card" data-tone="warning">
    <wr-stat label="Needs review" value="12"></wr-stat>
  </section>
</div>
<div class="wr-grid wr-grid-3" role="group" aria-label="Categories">
  <button type="button" class="wr-filter" data-tone="warning" aria-pressed="true">
    <span class="wr-row wr-between"><span>Needs review</span><strong>12</strong></span>
    <wr-progress label="Share of results" value="12" max="40"></wr-progress>
  </button>
</div>
```

### Toolbars and actions

A direct `wr-grow` child in a toolbar starts at 200 px and takes the remaining space. When it does not fit beside the actions, it moves to another line. Labels around checkboxes already align the control with the text.

```html
<div class="wr-toolbar" aria-label="Result filters">
  <label class="wr-grow">Search <input type="search" /></label>
  <label><input type="checkbox" /> Compact view</label>
  <button type="button">Export</button>
</div>
<nav class="wr-actions wr-center" aria-label="Pages">
  <button type="button">Previous</button>
  <span>Page 1 of 3</span>
  <button type="button">Next</button>
</nav>
<section class="wr-card wr-empty" hidden>
  <h2>No matching results</h2>
  <p>Try another category or clear the search.</p>
  <button type="button">Clear filters</button>
</section>
```

## Native elements

Plain `<details>` gets a panel border, a padded summary, and padded body content. Wrap the body in one element to keep its spacing together. The browser handles toggling and keyboard input.

Add `wr-disclosure` for a summary row with a rotating chevron. Use a badge in the summary to show status. Keep links and buttons outside the summary so they do not compete with its toggle action.

```html
<details class="wr-card wr-disclosure" data-tone="warning">
  <summary>
    <span class="wr-grow">Review build failures</span>
    <span class="wr-badge" data-tone="warning">3 failures</span>
  </summary>
  <div class="wr-stack wr-gap-8">
    <p>Three builds need attention.</p>
    <div class="wr-actions"><button type="button">Open report</button></div>
  </div>
</details>
```

A plain `<dialog>` gets a centered surface with a shadow and a backdrop. Call `showModal()` to open it. The browser handles focus, the modal state, and Escape. A `method="dialog"` form closes it without a network request.

Name every dialog with `aria-labelledby` or `aria-label`. Put layout classes on its content, not on the dialog itself. Do not set `open` directly for a modal dialog. Clicking the backdrop does not close it automatically.

```html
<button type="button" id="open-help">About this report</button>
<dialog id="report-help" aria-labelledby="report-help-title">
  <form method="dialog">
    <h2 id="report-help-title">About this report</h2>
    <p>These numbers describe the last seven days.</p>
    <div class="wr-actions"><button autofocus>Close</button></div>
  </form>
</dialog>
<script>
  document.getElementById("open-help").addEventListener("click", () => {
    document.getElementById("report-help").showModal();
  });
</script>
```

## Dashboard starter

Use [templates/dashboard.html](../templates/dashboard.html) when its structure fits. Replace its sample data, labels, and filter logic. The example combines responsive grids, metric cards, tones, filter cards, search, disclosures, an empty state, and a dialog without custom CSS.

Do not force an interactive explanation into a dashboard. Give the drawing and its controls the space they need. Use kit controls and tokens, with custom composition where the subject needs it. See [interactivity.md](interactivity.md) for controls that update diagrams and calculations.
