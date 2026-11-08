# omarchy-nextdns-ip

An Omarchy bar plugin that keeps your NextDNS linked IP up to date.

- Updates your NextDNS linked IP on boot, when the internet connection comes back,
  after resuming from suspend, and at least every 6 hours (about 4 times a day)
- Click the bar icon to see the last successful update time
- "Refresh now" button for a manual update
- When there is no internet connection, the button is disabled and a warning is shown
- Follows your current Omarchy theme

## Requirements

Omarchy 4 or newer (Quickshell-based plugin system), plus `curl`, `jq`, `flock` and `ip` (iproute2).

## Install

```bash
omarchy plugin add https://github.com/erbilozum/omarchy-nextdns-ip.git --enable

mkdir -p ~/.config/nextdns-ip
printf '%s\n' 'https://link-ip.nextdns.io/XXXXXX/YYYYYYYYYYYYYYYY' > ~/.config/nextdns-ip/url
chmod 600 ~/.config/nextdns-ip/url

omarchy restart shell
```

Get your personal URL from the NextDNS dashboard: Setup → Linked IP.
The URL contains a secret token, so it is stored locally and never in this repo.

## Update / remove

```bash
omarchy plugin update io.github.erbilozum.nextdns-ip
omarchy plugin remove io.github.erbilozum.nextdns-ip
```

## Icon states

- Shield: last update succeeded
- Warning: no internet connection, last attempt failed, or no URL configured (open the panel for details)

## Tuning

Edit the constants at the top of `nextdns-ip.sh`:

- `INTERVAL`: maximum seconds between successful updates (default 21600 = 6 h)
- `MIN_GAP`: minimum seconds between attempts (default 600)

## License

MIT