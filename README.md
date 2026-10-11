# OmaDi.sysmon — Hardware Monitor for Omarchy

An Omarchy shell plugin that adds a hardware monitor icon to the top-right
bar. Click it to open a live dashboard: CPU temp/load, memory, disk usage,
fan speed, battery, and network throughput.

![bar widget](https://img.shields.io/badge/bar-widget-right-blue)

## What it shows

- **Hero row** — CPU temperature, CPU %, load average
- **Usage bars** — CPU / MEM / DISK with live progress bars
- **Details grid** — fan RPM, battery temp + voltage, GPU temp, network up/down rates
- **Disk section** — mount point, free space, lifetime network totals

Missing sensors degrade gracefully to `--` instead of breaking the panel.

## Requirements

- [Omarchy](https://omarchy.org/) (Hyprland + Quickshell shell)
- `sensors` (`lm_sensors`), `jq` (optional, for richer temp parsing), standard `/proc` + `df`

## Install

```bash
# 1. Clone into your user plugins
git clone https://github.com/<you>/OmDi-Sysmon.git ~/.config/omarchy/plugins/OmaDi.sysmon

# 2. Put the stats helper on PATH
cp ~/.config/omarchy/plugins/OmaDi.sysmon/bin/omadi-sysmon-stats ~/.local/bin/
chmod +x ~/.local/bin/omadi-sysmon-stats

# 3. Validate + enable in the top-right bar
omarchy plugin validate ~/.config/omarchy/plugins/OmaDi.sysmon
omarchy plugin enable OmaDi.sysmon --section right
omarchy bar move OmaDi.sysmon --after omarchy.audio

# 4. If the icon doesn't appear immediately
omarchy-shell shell rescanPlugins
# or: omarchy restart shell
```

## Usage

- **Left-click** the `󰻠` icon → open/close the live dashboard (refreshes every 2s while open)
- **Right-click** → force an immediate refresh

## Files

| File | Purpose |
|------|---------|
| `manifest.json` | Plugin manifest (`bar-widget`, defaults to right section) |
| `Panel.qml` | Bar icon + dashboard popup (modeled on `omarchy.power`) |
| `Model.js` | Pure parsing/formatting helpers (Node-testable) |
| `bin/omadi-sysmon-stats` | Bash collector: `sensors` + `/proc` + `df` → one JSON object |

## Test the collector

```bash
omadi-sysmon-stats | jq .
node -e 'const M=require("./Model.js"); console.log(M.formatTemp(72), M.formatRpm(3635))'
```

## License

MIT
