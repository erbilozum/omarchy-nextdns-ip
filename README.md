# omarchy-nextdns-ip

An Omarchy bar plugin that keeps your NextDNS **linked IP** up to date, so NextDNS
always knows your current public IP address.

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

The link is sent to NextDNS first. If NextDNS rejects it, nothing is saved and you
get a warning. The link contains a secret token, so it is stored only on your
machine in `~/.config/nextdns-ip/url` (permissions `600`), never in this repo.

## Features

- Updates your linked IP on boot, when the connection comes back, after resuming
  from suspend, whenever your public IP changes, and at least every N hours.
- Refresh interval is adjustable from 1 to 24 hours (default 6 hours).
- Shows your external IP, last update time and connection state in the panel.
- "Refresh now" button for a manual update.
- When there is no internet connection the button is disabled and a warning is shown.
- Follows your current Omarchy theme.

## Privacy

To detect IP changes the plugin asks a public "what is my IP" service
(`api.ipify.org`, falling back to `icanhazip.com` and `ifconfig.me`) about every
15 minutes. Set `IP_CHECK=0` in `nextdns-ip.sh` to turn this off.
No data is sent anywhere else except to NextDNS.

## Update / remove

```bash
omarchy plugin update io.github.erbilozum.nextdns-ip
omarchy plugin remove io.github.erbilozum.nextdns-ip
```

## Icon states

- Shield: last update succeeded
- Warning: not set up yet, no internet connection, or last attempt failed

## Tuning

Constants at the top of `nextdns-ip.sh`:

- `MIN_GAP`: minimum seconds between update attempts (default 600)
- `IP_CHECK`: seconds between external IP checks (default 900, 0 = off)

## License

MIT