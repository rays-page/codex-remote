# Security And Setup

## Desktop Launcher Behavior

`desktop/codex_remote_desktop.py` copies the installed Codex runtime from the Windows app package into:

```text
%LOCALAPPDATA%\CodexRemote\runtime\resources
```

That local staged runtime is what the shortcut launches. This avoids the `Access is denied` problem that can happen when trying to run the packaged executable in place from `C:\Program Files\WindowsApps`.

## Token Handling

The launcher creates a capability token in:

```text
%LOCALAPPDATA%\CodexRemote\capability.token
```

The iPhone client uses that token as:

```text
Authorization: Bearer <token>
```

If you think the token leaked:

1. Stop the relay.
2. Delete `%LOCALAPPDATA%\CodexRemote\capability.token`.
3. Start the relay again to generate a fresh token.

## Recommended Use

- Local network only: `ws://LAN-IP:8765`
- Outside home/work network: put the websocket behind a secure tunnel and use `wss://...`

The launcher accepts a public override:

```powershell
python .\desktop\codex_remote_desktop.py launch --public-ws-url wss://your-host.example/ws
```

That does not create the tunnel for you. It only changes the pairing output so the phone app gets the right endpoint.

## Suggested Tunnel Options

- Tailscale: easiest if both your phone and desktop are on the same tailnet
- Cloudflare Tunnel: good if you already control DNS and want a stable public hostname
- Reverse proxy: good if you already run Nginx, Caddy, or Traefik

## Mobile App Safety

The iPhone app deliberately enables cleartext networking because this is a self-hosted operator tool. If you expose the service outside your LAN, prefer `wss://` and terminate TLS before the websocket reaches the Codex relay.
