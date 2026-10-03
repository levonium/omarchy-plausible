# levonium.plausible

[Plausible Analytics](https://plausible.io) stats for your sites, in the
[Omarchy](https://omarchy.org/) shell bar. Click the bar icon to see a compact
panel with one section per site.

## Features

For each site you configure:

- **Realtime** visitors (right now)
- **Today's** visitors and pageviews
- **Today's** organic search visitors
- **Today's** referral visitors (links from other websites)
- **Today's** AI assistant visitors (ChatGPT, Perplexity and similar channels
  as classified by Plausible)

The panel refreshes on a timer (60 seconds by default) and has a manual refresh
button. It uses your Omarchy theme and fits in with the built-in bar panels.

## Requirements

- Omarchy with the Quickshell-based shell (`omarchy-shell`).
- A Plausible account on **plausible.io** (self-hosted instances are not
  supported yet: the API URL is fixed) and a **Stats API** key (create one in
  your Plausible account settings under API keys).
- `curl`.

## Install

```bash
omarchy plugin add https://github.com/levonium/omarchy-plausible.git --enable
```

Then set up two things:

**1. Your API key.** It's read from a plain-text file inside the plugin folder
and is never committed to git (`secret.conf` is in `.gitignore`):

```bash
cd ~/.config/omarchy/plugins/levonium.plausible
cp secret.conf.example secret.conf
chmod 600 secret.conf
$EDITOR secret.conf       # replace the placeholder with your Stats API key
```

**2. Your sites.** They're read from `sites.json` in the same folder, which is
also never committed to git (it's in `.gitignore`). The `domain` must match the
site ID in Plausible, and `label` is what the panel displays:

```bash
cp sites.example.json sites.json
$EDITOR sites.json
```

```json
[
  { "domain": "example.com", "label": "Example" },
  { "domain": "blog.example.com", "label": "Blog" }
]
```

The panel watches the file, so changes apply as soon as you save.

If the icon doesn't appear, run `omarchy restart shell`. Update later with
`omarchy plugin update levonium.plausible`.

To install by hand, copy the folder to
`~/.config/omarchy/plugins/levonium.plausible/` (the folder name must match the
`id` in `manifest.json`), then run `omarchy-shell shell rescanPlugins` and
`omarchy plugin enable levonium.plausible`.

## Configuration

Your sites and key live in `sites.json` and `secret.conf` (see Install). Optional
settings go in the plugin's entry in `~/.config/omarchy/shell.json`
(hot-reloaded on save), for example `{ "id": "levonium.plausible", "refreshSeconds": 30 }`:

| Setting | Default | Meaning |
|---|---|---|
| `refreshSeconds` | `60` | Refresh interval in seconds (minimum 15) |
| `sites` | not set | Same format as `sites.json`. If present it **overrides** `sites.json` |

## Usage

Click the icon to open the panel, `Esc` to close it. You can also toggle it from
a keybinding or script:

```bash
omarchy-shell levonium.plausible toggle    # also: open, close
```

For example, in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + CTRL + ALT + P", "Toggle Plausible", "omarchy-shell levonium.plausible toggle")
```

## Files

| File | Purpose |
|---|---|
| `manifest.json` | Plugin registration (bar widget) |
| `Panel.qml` | The bar icon and popup UI |
| `Model.js` | Parsing and formatting of Plausible API responses |
| `secret.conf` | **Your API key (local only, git-ignored)** |
| `secret.conf.example` | Template for `secret.conf` |
| `sites.json` | **Your site list (local only, git-ignored)** |
| `sites.example.json` | Template for `sites.json` |

## Troubleshooting

- **"Add your Plausible Stats API key…" message:** `secret.conf` is missing or empty.
- **"No sites configured":** create `sites.json` from `sites.example.json` as shown above.
- **"sites.json is not valid":** it must be a JSON list of `{ "domain", "label" }`
  objects. Check for a missing comma or bracket.
- **Numbers show `—`:** the request failed. Check that the key is a *Stats* API
  key, that `domain` matches the Plausible site ID, and your network.
- **Changes not showing after editing the plugin:** `omarchy restart shell`.
- **Check for QML errors:** `quickshell log -n -p /usr/share/omarchy/shell | grep -i plausible`

## License

[MIT](LICENSE)
