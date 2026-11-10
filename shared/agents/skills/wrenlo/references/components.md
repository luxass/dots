# HTML artifact components

Wrenlo injects a theme stylesheet and a small component script into every HTML artifact before your own code. They work offline inside the sandbox. Your own CSS overrides them.

Write a full document or just body content. A fragment without `<html>` is wrapped automatically.

A multi-file artifact can split its page into files. `<link rel="stylesheet">`, `<script src>`, `<script type="module">` with relative imports, `<img src>` to `.svg` files, CSS `url()` to `.svg` files, and links to sibling `.html` pages are inlined from the same revision. `fetch()` stays blocked, so keep data in a JavaScript module. See `examples/dashboard/`.

## Theme tokens

Use these CSS variables instead of hard-coded colors. They switch with light and dark mode.

| Token                                                      | Meaning                     |
| ---------------------------------------------------------- | --------------------------- |
| `--wr-bg`, `--wr-surface`                                  | Page and card backgrounds   |
| `--wr-text`, `--wr-muted`                                  | Main and secondary text     |
| `--wr-border`                                              | Borders and grid lines      |
| `--wr-accent`, `--wr-accent-text`                          | Accent color and text on it |
| `--wr-success`, `--wr-warning`, `--wr-danger`, `--wr-info` | Status colors               |
| `--wr-chart-1` … `--wr-chart-6`                            | Chart series colors         |
| `--wr-font`, `--wr-mono`, `--wr-radius`                    | Fonts and corner radius     |

## Layout classes

| Class                                 | Effect                                           |
| ------------------------------------- | ------------------------------------------------ |
| `wr-page`                             | Centered page with comfortable padding           |
| `wr-stack`                            | Vertical stack with 16px gaps                    |
| `wr-row`                              | Wrapping horizontal row                          |
| `wr-grid`                             | Responsive grid of equal columns (14rem minimum) |
| `wr-card`                             | Bordered surface                                 |
| `wr-table`                            | Styled `<table>`                                 |
| `wr-badge`                            | Small pill label                                 |
| `wr-button`, `data-variant="primary"` | Button styles                                    |
| `wr-muted`                            | Secondary text color                             |

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

`tone` is `info` (default), `success`, `warning`, or `danger`.

### `<wr-progress>`

```html
<wr-progress label="Checklist" value="3" max="7"></wr-progress>
```

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
