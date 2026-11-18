# HTML artifact components

Wrenlo adds its artifact kit to every HTML artifact, before your own code: the app's design tokens, the app's font (Inter), element styles, and a few components. Your artifact looks like Wrenlo without any CSS of its own. The kit loads with the page; your artifact itself cannot load anything from the network. Your CSS can override the kit, except that hidden content and closed dialogs stay hidden.

Write a full document or just body content. A fragment without `<html>` is wrapped automatically. Use kit controls and theme tokens by default. Add custom CSS for the page's composition and subject-specific visuals. Kit components are building blocks, not a required page structure.

## Before writing CSS

| Instead of styling                             | Use                                                                |
| ---------------------------------------------- | ------------------------------------------------------------------ |
| Responsive columns, spacing, and alignment     | `wr-grid`, `wr-row`, `wr-stack`, and [layout modifiers](layout.md) |
| Metric cards and progress tracks               | `wr-card` with `<wr-stat>` or `<wr-progress>`                      |
| Status badges, neutral cards, and filter cards | [Report patterns and tones](layout.md#report-patterns)             |
| Expandable groups and modal windows            | Native `<details>` and `<dialog>`, already styled                  |
| Search bars, action rows, and empty states     | `wr-toolbar`, `wr-actions`, and `wr-empty`                         |
| Visually hidden labels                         | `wr-sr-only`                                                       |

Use [the dashboard template](../templates/dashboard.html) when its structure fits the report. It combines these patterns without custom CSS. Choose a different composition for an explainer, timeline, or simulation. For controls that update drawings and calculations, read [interactivity.md](interactivity.md).

A multi-file artifact can split its page into files. `<link rel="stylesheet">`, `<script src>`, `<script type="module">` with relative imports, `<img src>` to `.svg` files, CSS `url()` to `.svg` files, and links to sibling `.html` pages are inlined from the same revision. `fetch()` stays blocked, so keep data in a JavaScript module. See `examples/dashboard/`. `examples/style-guide.html` shows everything below.

## JavaScript API

Wrenlo defines `window.wrenlo` before the artifact's scripts run, on private and public share pages. The API currently contains only `window.wrenlo.version`, the full Git commit SHA from the build metadata, or `"x.y.z"` when commit metadata is unavailable. It identifies the Wrenlo build, not the artifact's revision or the JSON API version.

This object does not grant storage, network access, or calls to an agent. Keep interactive state in the page's JavaScript. If you open the HTML outside Wrenlo, the object is absent.

## Plain HTML

Plain elements already have the app's look, so write semantic HTML first and add CSS only for what is special about your page.

- **Text:** 14 px Inter. `h1` to `h4` are 24, 20, 16, and 14 px, like Markdown files in Wrenlo. Headings and paragraphs have no margins; space them with `wr-stack`.
- **Links, `code`, `pre`, `kbd`, `blockquote`, `hr`, and lists** look as they do in the app.
- **Tables** have hairline rows, a quiet header, and a hover color, like the app's lists. Wrap one in `<wr-table>` to make it sortable.
- **Buttons** are soft violet, in the app's sizes. `data-variant="primary"` is solid violet; `"ghost"` and `"danger"` are the other styles. Use `class="wr-button"` to make a link look like a button.
- **Fields:** text inputs, `select`, and `textarea` are 32 px tall, with the accent focus ring and a red border once the person entered something invalid. Radios, checkboxes, and sliders use the accent.
- **Labels:** `<label>Name <input></label>` puts the text above a field that fills the line. A label around a radio or checkbox puts the control before its text. `<small>` in a label is a hint.
- **Forms** stack their parts 16 px apart. A `fieldset` is a panel with a semibold `legend`; a disabled one is dimmed.
- **Toggle buttons:** `aria-pressed="true"` shows the selected state. Your script changes the attribute and applies the action.
- **Disclosures and dialogs:** `<details>` has a panel border and padded content. `<dialog>` has the app's surface, shadow, and backdrop. See [native elements](layout.md#native-elements) for markup and behavior.
- **Hidden content:** `hidden` stays hidden even with a layout class. Closed dialogs also stay hidden. `hidden="until-found"` keeps its browser behavior.

## Design tokens

Use these CSS variables instead of hard-coded values. They come from the app's own theme, and colors switch with light and dark mode.

| Token                                                                                                        | Meaning                                         |
| ------------------------------------------------------------------------------------------------------------ | ----------------------------------------------- |
| `--wr-color-bg`, `--wr-color-panel`                                                                          | Page and panel backgrounds                      |
| `--wr-color-hover`, `--wr-color-selected`                                                                    | Hover and selected backgrounds                  |
| `--wr-color-text`, `--wr-color-secondary`, `--wr-color-faint`                                                | Main, secondary, and faint text                 |
| `--wr-color-hairline`, `--wr-color-input`                                                                    | Borders and field borders                       |
| `--wr-color-backdrop`                                                                                        | Modal backdrop                                  |
| `--wr-color-accent`, `--wr-color-accent-soft`                                                                | Accent and its soft background                  |
| `--wr-color-success`, `--wr-color-warning`, `--wr-color-danger`, `--wr-color-danger-soft`, `--wr-color-info` | Status colors                                   |
| `--wr-color-markdown`, `--wr-color-html`, `--wr-color-svg`, `--wr-color-mermaid`                             | Wrenlo's format colors                          |
| `--wr-chart-1` … `--wr-chart-6`                                                                              | Chart series colors                             |
| `--wr-space-2`, `-4`, `-8`, `-12`, `-16`, `-20`, `-24`, `-32`, `-40`, `-48`                                  | Spacing, in pixels                              |
| `--wr-radius-control`, `--wr-radius-panel`, `--wr-radius-pill`                                               | 6 px, 10 px, and round corners                  |
| `--wr-text-xs`, `-sm`, `-md`, `-lg`, `-xl`                                                                   | 12, 13, 14, 16, and 20 px text                  |
| `--wr-weight-regular`, `-medium`, `-semibold`, `--wr-leading-base`                                           | Font weights and line height                    |
| `--wr-font-sans`, `--wr-font-mono`                                                                           | Inter and the monospace font                    |
| `--wr-shadow-popover`, `--wr-shadow-dialog`                                                                  | Shadows                                         |
| `--wr-size-row`, `-control`, `-button`, `-button-small`, `-chip`, `-icon`, `-icon-small`, `-reading`         | 36, 32, 28, 24, 20, 16, 14, and 720 px          |
| `--wr-size-menu`, `--wr-size-dialog`                                                                         | 200 px toolbar field basis, 480 px dialog width |

The first names (`--wr-bg`, `--wr-surface`, `--wr-text`, `--wr-muted`, `--wr-border`, `--wr-accent`, `--wr-radius`, `--wr-font`, `--wr-mono`, and the status colors) still work.

## Classes

| Class        | Effect                                                        |
| ------------ | ------------------------------------------------------------- |
| `wr-page`    | Centered page with comfortable padding                        |
| `wr-stack`   | Vertical stack with 16 px gaps                                |
| `wr-row`     | Wrapping horizontal row with 12 px gaps                       |
| `wr-grid`    | Responsive grid of equal columns (14rem minimum)              |
| `wr-card`    | Panel with a hairline border                                  |
| `wr-choices` | Option cards for a radio or checkbox group (see Send answers) |
| `wr-badge`   | Small pill label                                              |
| `wr-button`  | A link that looks like a button                               |
| `wr-muted`   | Secondary text color                                          |

For column counts, gaps, alignment, tones, filters, disclosures, and empty states, see [layout and report patterns](layout.md).

## Components

### `<wr-chart>`

Bar, line, area, pie, and donut charts as inline SVG.

```html
<wr-chart
  type="bar"
  heading="Deploys per day"
  data='[["Mon", 3], ["Tue", 5], ["Wed", 2]]'
></wr-chart>

<!-- A header row creates several series. -->
<wr-chart type="line" unit="ms">
  [["Day", "api", "web"], ["Mon", 320, 180], ["Tue", 290, 210]]
</wr-chart>
```

| Attribute | Values                                    | Default |
| --------- | ----------------------------------------- | ------- |
| `type`    | `bar`, `line`, `area`, `pie`, `donut`     | `bar`   |
| `data`    | JSON rows (or JSON as the element's text) | —       |
| `heading` | Title shown above the chart               | none    |
| `unit`    | Suffix for axis and tooltip values        | none    |
| `height`  | Height in pixels                          | 240     |
| `series`  | Series name when there is no header row   | `Value` |

Pie and donut charts use the first series. Invalid data shows an error message in place of the chart. Change the `data` attribute from a script to redraw.

### `<wr-tabs>` and `<wr-tab>`

```html
<wr-tabs>
  <wr-tab label="Summary">…</wr-tab>
  <wr-tab label="Details" selected>…</wr-tab>
</wr-tabs>
```

Arrow keys, Home, and End move between tabs.

### `<wr-stat>`

```html
<wr-stat label="Median deploy" value="4m 12s" delta="−8% vs last week" trend="good"></wr-stat>
```

`trend` is `good` (green) or `bad` (red). Omit it for neutral.

### `<wr-callout>`

```html
<wr-callout tone="warning" heading="Slow builds">Builds take longer on Mondays.</wr-callout>
```

A note with a bar and a title row in the tone's color, like GitHub's alerts. `tone` is `info` (default), `success`, `warning`, or `danger`, and picks the icon. Without `heading`, the title is the tone's name: Note, Success, Warning, or Danger.

### `<wr-progress>`

```html
<wr-progress label="Checklist" value="3" max="7"></wr-progress>
```

For progress bar colors, see [report tones](layout.md#report-patterns).

### `<wr-table>`

Wrap a table with a `<thead>` to make its columns sortable. Numbers sort numerically.

```html
<wr-table>
  <table>
    <thead>
      <tr>
        <th>Service</th>
        <th>Deploys</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>api</td>
        <td>12</td>
      </tr>
      <tr>
        <td>web</td>
        <td>7</td>
      </tr>
    </tbody>
  </table>
</wr-table>
```

## Send answers

A form with `data-wrenlo-submit` sends its answers to the agent when the person submits it in Wrenlo. Wrenlo shows them in its own dialog first, and nothing is sent until the person presses Send. Name each form with up to 64 letters, digits, `-`, or `_`, and give each form on a page its own name.

```html
<form data-wrenlo-submit="db-choice">
  <fieldset class="wr-choices">
    <legend>Which database?</legend>
    <label
      ><input type="radio" name="engine" value="d1" required /> D1
      <small>Built in, no setup</small></label
    >
    <label
      ><input type="radio" name="engine" value="postgres" /> Postgres
      <small>Hosted elsewhere</small></label
    >
  </fieldset>
  <label>Replicas <input type="number" name="replicas" min="1" max="5" /></label>
  <label><input type="checkbox" name="backups" /> Daily backups</label>
  <label>Anything else? <textarea name="notes" maxlength="500"></textarea></label>
  <button>Send to agent</button>
</form>
```

The form as saved is the schema. Wrenlo checks the answers against its fields and sends typed values: `{ "engine": "postgres", "replicas": 2, "backups": true }`.

| Field                                | Answer                                                   |
| ------------------------------------ | -------------------------------------------------------- |
| Radio group                          | One of its values, as a string                           |
| One checkbox                         | `true` or `false`                                        |
| Several checkboxes with one name     | A list of the checked values, possibly empty             |
| `<select>`                           | One option value; a list with `multiple`                 |
| `number`, `range`                    | A number, within `min` and `max`                         |
| `email`, `url`                       | A string in that format                                  |
| Other inputs, `<textarea>`, `hidden` | A string, within `minlength`, `maxlength`, and `pattern` |

- An empty field is left out, so an optional question the person skipped has no key. `required` makes a field required.
- Disabled fields, including those in a disabled `<fieldset>`, are never required. To ask a follow-up only sometimes, disable it in the HTML and enable it from a script.
- Only fields inside the form element count. Buttons, file inputs, and fields with a `form` attribute send nothing.
- Scripts may fill fields, including `hidden` ones, before the person submits. A form that a script creates after the page loads cannot send: Wrenlo reads the form from the saved file.
- If your own submit handler calls `preventDefault()`, Wrenlo leaves that submission alone.
- Limits: 50 fields, 2000 characters per answer, and 16 KiB in total.
- **Looks:** the form's submit button is primary unless it sets `data-variant`. `wr-choices` on a `fieldset` turns each `<label>` with a radio or checkbox into a card; a `<small>` in it is the card's second line.

After a send, the form resets to the values in your HTML, like a normal form, and has `data-wrenlo-state="sent"` until the person types again. Its fields fire `input` and `change` after the reset, so your scripts update. Unsent answers survive a reload in the same browser. On share pages and outside Wrenlo, forms cannot send and say so.

## Complete example

```html
<!doctype html>
<title>Deploy times</title>
<main class="wr-page wr-stack">
  <h1>Deploy times this week</h1>
  <div class="wr-grid">
    <div class="wr-card">
      <wr-stat label="Median" value="4m 12s" delta="−8%" trend="good"></wr-stat>
    </div>
    <div class="wr-card"><wr-stat label="Failed" value="2" delta="+1" trend="bad"></wr-stat></div>
  </div>
  <wr-tabs>
    <wr-tab label="Chart">
      <wr-chart
        type="bar"
        unit="m"
        data='[["Day", "api", "web"], ["Mon", 3.8, 2.2], ["Tue", 4.5, 2.6]]'
      ></wr-chart>
    </wr-tab>
    <wr-tab label="Failures">
      <wr-callout tone="danger" heading="Tuesday">The web deploy timed out twice.</wr-callout>
    </wr-tab>
  </wr-tabs>
</main>
```
