# Interactive explanations

Use an interactive explanation when changing an input reveals a relationship. A slider can show how altitude changes orbital speed. A timeline can show the events in a selected period. Keep a reading-only report static when controls add no useful exploration.

## Choose the interaction

Before writing, identify what the person can change, what you calculate, and what the drawing explains. Use a few meaningful controls rather than a control for every value.

- Give each control a label, units, bounds, and a useful initial value.
- Update calculations, drawings, and text from the same state. Listen to `input` for continuous slider updates.
- Show the current values beside the controls. Include assumptions and label illustrative data.
- Provide Reset. Add presets when named examples help the person compare results.
- Keep the explanation visible before any interaction. Do not hide the initial drawing behind a click or animation.
- Make every button work. Do not imitate saving, exporting, calling an agent, or loading live data.

## Choose the drawing

Use `<wr-chart>` for its supported chart types. Set its `data` attribute from JavaScript to redraw it. Wait for `customElements.whenDefined("wr-chart")` before calling a component method or reading a property that its class defines.

Use Canvas for custom simulations and configurable drawings. Recalculate geometry from the inputs and redraw the canvas. Give the canvas a text alternative, with the same key values in ordinary HTML. Keep SVG files as `<img>` sources rather than inserting SVG markup into the page.

Mermaid diagrams are drawn at save time. Use them for static relationships, not diagrams that need to change with a slider. Do not load Mermaid or a chart library from a CDN.

Use kit controls and theme tokens. Custom CSS can give the drawing and controls a composition suited to the subject. Keep controls usable with a keyboard, drawings within the pane, and labels readable in both themes. If motion helps, provide Pause and respect `prefers-reduced-motion`.

## State and platform features

Plain JavaScript handles sliders, filtering, calculations, and drawing without a host API. Keep their state in memory. Reopening the page starts from its saved defaults.

For the current host API, see [JavaScript API](components.md#javascript-api). Do not assume that methods exist because another artifact platform provides them. For answers that a person explicitly sends to an agent, use the documented submission forms, not an automatic call from a slider.

## Example: orbital altitude

This page uses a circular-orbit model around Earth. Altitude changes the orbit drawing, speed, and period together. The controls use kit styles. Canvas uses the kit's theme colors. It needs no dependency, network request, or host API.

```html
<!doctype html>
<html lang="en">
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Orbital altitude</title>
  <style>
    #orbit {
      display: block;
      width: 100%;
      max-width: var(--wr-size-reading);
      height: auto;
      background: var(--wr-color-panel);
      border-radius: var(--wr-radius-panel);
    }
  </style>
  <main class="wr-page wr-stack">
    <h1>How altitude changes an orbit</h1>
    <p>Higher circular orbits take longer to complete and need less orbital speed.</p>
    <label for="altitude">
      Altitude: <output id="altitude-value" for="altitude">2,000 km</output>
      <input id="altitude" type="range" min="200" max="36000" step="100" value="2000" />
    </label>
    <div class="wr-row">
      <p>Speed: <output id="speed" for="altitude"></output> km/s</p>
      <p>Period: <output id="period" for="altitude"></output> minutes</p>
      <button type="button" id="reset">Reset altitude</button>
    </div>
    <canvas
      id="orbit"
      width="640"
      height="480"
      role="img"
      aria-label="Earth and a circular orbit at the selected altitude"
    >
      The orbit radius grows as altitude increases. Speed and period appear above.
    </canvas>
    <p class="wr-muted">
      Earth radius: 6,371 km. Circular orbit, no atmosphere or other bodies. Earth and orbit radii
      share a scale. The satellite marker is enlarged.
    </p>
  </main>
  <script>
    const altitude = document.getElementById("altitude");
    const canvas = document.getElementById("orbit");
    const context = canvas.getContext("2d");

    function renderOrbit() {
      const height = Number(altitude.value);
      const radius = 6371 + height;
      const speed = Math.sqrt(398600.4418 / radius);
      const minutes = (2 * Math.PI * radius) / speed / 60;
      document.getElementById("altitude-value").textContent = `${height.toLocaleString()} km`;
      document.getElementById("speed").textContent = speed.toFixed(2);
      document.getElementById("period").textContent = minutes.toFixed(1);

      const colors = getComputedStyle(canvas);
      const earthRadius = 32;
      const orbitRadius = (radius / 6371) * earthRadius;
      context.clearRect(0, 0, canvas.width, canvas.height);
      context.beginPath();
      context.arc(320, 240, earthRadius, 0, 2 * Math.PI);
      context.fillStyle = colors.getPropertyValue("--wr-color-accent").trim();
      context.fill();
      context.beginPath();
      context.arc(320, 240, orbitRadius, 0, 2 * Math.PI);
      context.strokeStyle = colors.getPropertyValue("--wr-color-secondary").trim();
      context.lineWidth = 2;
      context.stroke();
      context.beginPath();
      context.arc(320 + orbitRadius, 240, 6, 0, 2 * Math.PI);
      context.fillStyle = colors.getPropertyValue("--wr-color-text").trim();
      context.fill();
    }

    altitude.addEventListener("input", renderOrbit);
    document.getElementById("reset").addEventListener("click", () => {
      altitude.value = "2000";
      renderOrbit();
    });
    matchMedia("(prefers-color-scheme: dark)").addEventListener("change", renderOrbit);
    renderOrbit();
  </script>
</html>
```

Before saving, make sure that the minimum, maximum, initial value, and Reset give consistent results. If browser tools are available, try the controls at a narrow width and in both themes. Report anything you could not inspect. Save the working page and return its receipt URL, not a screenshot in place of the artifact.
