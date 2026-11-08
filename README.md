# omarchy-nextdns-ip

An Omarchy bar plugin that keeps your NextDNS **linked IP** up to date. It watches
your public IP address and contacts NextDNS only when the address has changed.

## Requirements

- **A NextDNS account with a configuration (profile).** This plugin does nothing
  without a NextDNS service. Create one at <https://my.nextdns.io>.
- Linked IP is meant for setups where your DNS runs through NextDNS's plain IPv4
  DNS servers and your public IP changes from time to time (typical home internet).
- Omarchy 4 or newer (Quickshell-based plugin system), plus `curl`, `jq`, `flock`
  and `ip` (iproute2).

## Install

```bash
omarchy plugin add https://github.com/erbilozum/omarchy-nextdns-ip.git --enable
omarchy restart shell
```

## First-time setup

1. Sign in at <https://my.nextdns.io>.
2. Open your configuration and go to the **Setup** tab.
3. Under **Linked IP**, copy the link. It looks like
   `https://link-ip.nextdns.io/<id>/<token>`.
4. Click the shield icon in the bar, paste the link into **NEXTDNS LINKED IP URL**
   and press **Verify and save**.

The link is sent to NextDNS first. If NextDNS does not accept it, nothing is saved
and you get a warning. The link contains a secret token, so it is stored only on
your machine in `~/.config/nextdns-ip/url` (permissions `600`), never in this repo.

## How it works

- Your public IP is checked at the interval you choose in Settings (1 to 24 hours,
  default 6 hours). It is also checked right after boot, when the connection comes
  back, after resuming from suspend, and when you open the panel.
- If the IP differs from the one NextDNS was last told about, the plugin sends the
  update request by itself. If the IP is unchanged, NextDNS is not contacted.
- A failed update is retried every 10 minutes.
- "Refresh now" sends the request immediately.
- The panel shows your external IP, the time of the last update and the last IP
  check, and the connection state.
- When there is no internet connection the button is disabled and a warning is shown.
- Follows your current Omarchy theme.

## Privacy

To learn your public IP the plugin asks a public "what is my IP" service
(`api.ipify.org`, falling back to `icanhazip.com` and `ifconfig.me`) at the chosen
interval. No data is sent anywhere else except to NextDNS.

## Update / remove

```bash
omarchy plugin update io.github.erbilozum.nextdns-ip
omarchy plugin remove io.github.erbilozum.nextdns-ip
```

## Uninstall

1. Optional: open the panel, go to Settings and press **Remove saved URL**
   (deletes your token from disk).
2. Remove the plugin:

```bash
omarchy plugin remove io.github.erbilozum.nextdns-ip
```

3. Delete the leftover files:

```bash
rm -rf ~/.config/nextdns-ip ~/.local/state/nextdns-ip
```

## What the plugin does on your system

- **Network:** calls your own NextDNS linked IP URL, and asks a public IP lookup
  service (`api.ipify.org`, falling back to `icanhazip.com` and `ifconfig.me`)
  for your address. Until you add your URL, nothing is sent to NextDNS.
- **Files:** `~/.config/nextdns-ip/` (your URL and check interval, permissions
  `600`) and `~/.local/state/nextdns-ip/` (status and lock file).
- **Programs it runs:** `bash`, `curl`, `jq`, `ip`, `flock`, `notify-send` (one
  setup reminder) and `xdg-open` (only when you click "Open my.nextdns.io").
- **Install:** installing runs no scripts; the plugin is only cloned.

## Icon states

- Shield: last update succeeded
- Warning: not set up yet, no internet connection, or last attempt failed

## Tuning

Constant at the top of `nextdns-ip.sh`:

- `MIN_GAP`: minimum seconds between update attempts (default 600)

## License

MIT