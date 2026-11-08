## Install

```bash
omarchy plugin add https://github.com/erbilozum/omarchy-nextdns-ip.git --enable
omarchy restart shell
```

Then click the shield icon in the bar, enter your personal linked IP URL in the
**Settings** section and press **Save**. Get the URL from the NextDNS dashboard:
Setup → Linked IP.

The URL contains a secret token, so it is stored only on your machine in
`~/.config/nextdns-ip/url` (permissions `600`) and never in this repo.
You can also create that file by hand instead of using the panel.