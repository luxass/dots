-- Managed by dots. Check with 'rex config check'; apply with 'rex config reload'.
-- Keep the Herdr prefix (Ctrl+B) and shared pane/session/tab shortcuts.
local P = "ctrl+b>"

rex.bind(P .. "ctrl+b", "pane.send_key", { key = "ctrl+b" })
rex.bind(P .. "shift+/", "client.palette.toggle")
rex.bind(P .. "shift+s", "client.settings")
rex.bind(P .. "r", "client.config.reload")
rex.bind(P .. "d", "client.window.close")
rex.bind(P .. "q", "client.window.close")

-- Rex sessions correspond to Herdr workspaces.
rex.bind(P .. "shift+n", "session.new")
rex.bind(P .. "shift+w", "session.rename")
rex.bind(P .. "shift+d", "session.close")
rex.bind(P .. "s", "session.switch")
rex.bind(P .. "w", "session.switch")
rex.bind(P .. "g", "session.switch")
rex.bind(P .. "shift+9", "session.previous")
rex.bind(P .. "shift+0", "session.next")
rex.bind(P .. "b", "client.sidebar.toggle")

rex.bind(P .. "c", "client.tab.new")
rex.bind(P .. ",", "client.tab.rename")
rex.bind(P .. "p", "client.tab.previous")
rex.bind(P .. "n", "client.tab.next")
rex.bind(P .. "shift+x", "client.tab.close")
for i = 1, 9 do
  rex.bind(P .. i, "client.tab.goto", { index = i })
end

rex.bind(P .. "\\", "pane.split", { direction = "right" })
rex.bind(P .. "enter", "pane.split", { direction = "down" })
rex.bind(P .. "x", "pane.close")
rex.bind(P .. "m", "pane.zoom")
rex.bind(P .. "tab", "pane.focus_next")
rex.bind(P .. "shift+tab", "pane.focus_previous")
for key, direction in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  rex.bind(P .. key, "pane.focus", { direction = direction })
  -- Rex moves a pane next to its neighbor, not an exact Herdr swap.
  rex.bind(P .. "shift+" .. key, "pane.move", { direction = direction })
end

rex.mode("resize", { exclusive = true })
rex.bind(P .. "shift+r", "client.mode.enter", { name = "resize" })
for key, direction in pairs({
  h = "left", j = "down", k = "up", l = "right",
  left = "left", down = "down", up = "up", right = "right",
}) do
  rex.bind("resize/" .. key, "pane.resize", { direction = direction })
  rex.bind("resize/shift+" .. key, "pane.resize", { direction = direction, amount = 15 })
end
rex.bind("resize/=", "pane.balance")
rex.bind("resize/enter", "client.mode.exit")

-- Rex has no keyboard copy mode. Use find on the same shortcut instead.
rex.bind(P .. "v", "client.find.open")
-- Herdr Annotate, notifications, agent/worktree navigation, pane renaming,
-- and scrollback editing are not mapped. Do not claim feature parity.
-- Leave Ctrl+H/J/K/L and Shift+Enter to terminal applications.

-- Appearance follows macOS. The theme pair is managed by macos-defaults.conf,
-- not by a shortcut or a Lua action.
