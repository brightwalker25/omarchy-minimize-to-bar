# omarchy-minimize-to-bar

Minimise windows to the Omarchy bar. Each minimised window sits there as **its app
icon alone**; hover one and its title slides out beside it.

![collapsed](docs/collapsed.png)

![hovered](docs/hovered.png)

There is no "minimise" in Hyprland, so this is a move to a `special:minimized`
workspace that nothing ever toggles visible. The window keeps running with its
surface off screen — the compositor equivalent of a taskbar minimise — until you
bring it back.

## Behaviour

| Action | Result |
|---|---|
| `SUPER + M` | Minimise the focused window |
| `SUPER + M` again | Restore it — Hyprland leaves focus on a window it just stashed, so a second press is an undo |
| `SUPER + M` with nothing focused | Restore the most recently minimised window to the current workspace |
| Left-click an icon | Restore to the *current* workspace and focus it |
| Middle-click an icon | Close that window |
| Hover an icon | Slide its title out |

The widget hides itself entirely when nothing is minimised, leaving no gap in the bar.
Restore always targets the workspace you are on now, not the one the window was
stashed from. "Most recent" is read from Hyprland's `focusHistoryID`, so there is no
state file to fall out of sync.

## Requirements

- Omarchy 4.x (Quickshell-based `omarchy-shell`)
- `jq`, for the keybinding script

## Install

```bash
omarchy plugin add https://github.com/brightwalker25/omarchy-minimize-to-bar.git
omarchy plugin enable brightwalker25.minimize --section left
```

The installer only clones files — it never runs plugin code or hooks — so the two
things that live outside the plugin directory are yours to add.

**1. Put the keybinding script on `PATH`:**

```bash
ln -s ~/.config/omarchy/plugins/brightwalker25.minimize/bin/minimize-toggle ~/.local/bin/minimize-toggle
```

**2. Add the keybinding** to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + M", "Minimize / restore window", "minimize-toggle")
```

`SUPER + M` is unbound in stock Omarchy (`SUPER + SHIFT + M` is Music), so nothing is
displaced. Hyprland picks the binding up on save.

## Settings

Set these on the widget's entry in `~/.config/omarchy/shell.json`:

```json
{ "id": "brightwalker25.minimize", "maxLabelWidth": 180, "alwaysShowLabels": false }
```

| Key | Default | What it does |
|---|---|---|
| `maxLabelWidth` | `180` | Widest a title may get before it elides |
| `alwaysShowLabels` | `false` | Show every title permanently instead of on hover |
| `iconSize` | bar icon size | Override the icon size in px |

## Notes

- **Vertical bars** have no room to expand sideways, so there the widget stays
  icon-only and shows the title in the shared tooltip instead.
- A chip that appears *underneath* a stationary pointer — which happens if your mouse
  is resting over the bar when you press `SUPER + M` — arrives already "hovered". Such
  a chip stays collapsed until the pointer leaves it once, so a new icon never shows
  its title unasked.
- Hover is driven by a `HoverHandler`, matching how Omarchy's own tray widget reveals
  its drawer.

## Credits

The idea came from [gardnmi/omarchy-minimize](https://github.com/gardnmi/omarchy-minimize)
by Mike Gardner, MIT licensed. That plugin is what showed me minimising to the Omarchy
bar was possible at all, and I ran it — latterly with a local patch that stripped its
chips back to bare icons — before writing this one.

This is an independent implementation rather than a fork. The two share no code beyond
unavoidable Quickshell boilerplate, they stash to different workspaces, and gardnmi's
live hover previews and interactive Peek have no equivalent here. If you want those,
use theirs; it does considerably more than this does.

## Licence

MIT
