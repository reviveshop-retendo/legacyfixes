# App compatibility notes (iOS 6–9, 32-bit)

This table is a starting point, not a promise. Old clients break for three
different reasons, and only the first one is fully fixable by a client tweak:

1. **Client-side gates** — a version check, an unsupported-OS alert, a dead
   endpoint baked into the app. These are what this repo is built for.
2. **Protocol/API changes** — the server expects a newer request format. Fixable
   only by rewriting requests per app (a lot of work, but possible).
3. **Server-side blocks** — the service refuses old client versions or accounts.
   A client tweak usually cannot fix this.

| App | Status with this repo | Main blockers | Notes |
| --- | --- | --- | --- |
| **YouTube** (App Store) | Engine only | Old API endpoints shut down; TLS changes | The real fix is a request-rewriting tweak. See below. |
| **YouTube Kids** | Engine only | Same family of API/version problems | Start by dumping classes for “update”/“support”. |
| **Facebook** | Engine only | Login/2FA flow, unsupported-client wall | Community login workaround exists; see below. |
| **Messenger** | Engine only | Server enforces a minimum client version | Hardest of the four; may not be fixable client-side. |
| **App Store** | Not included | Expired/broken trust, UI layout | `iTunesStoreX` (GPL-3) is the known fix. |
| **Instagram / Twitter / Reddit / Spotify** | Not included | API changes, minimum version | Good candidates for new packages. |
| **WhatsApp / Snapchat** | Not included | Aggressive server-side version enforcement | Do not expect these to work. |

“Engine only” means the package installs and can suppress update walls / spoof
OS + User-Agent, but it does **not** restore the service by itself.

## YouTube

The pre-Google YouTube app and old App Store YouTube builds use long-dead
endpoints. Two open-source approaches exist:

- **TubeReplacer** — a backendless fix for iOS 5–10 (GPL-3.0).
  <https://github.com/Preloading/TubeReplacer>
- **TubeRepair** — a tweak + self-hosted/community server that redirects the old
  app to an Invidious-style backend. The client source currently has no license,
  so link users to it instead of bundling it.
  <https://github.com/ObscureMosquito/TubeRepair-Client>

If you want YouTube to actually play video, porting one of those into this repo
(or depending on the upstream package) is the realistic path. The engine here
is the right place for the surrounding glue: suppress the forced-update alert,
spoof the reported OS/UA, and log the old app's requests.

## Facebook / Messenger

Facebook's old clients hit a mix of login-flow changes and “unsupported client”
walls. The community guide at <https://developer.bag-xml.com/guides/facebook/>
covers the current login workaround (confirming identity from a newer device).
Messenger is stricter: it tends to enforce a minimum version server-side, which
a tweak cannot negotiate around.

`FBIntegrationFix` (system Facebook account integration on iOS 6–8) is useful
context, but it has no license, so do not copy it into this repo:
<https://github.com/Epix512/FBIntegrationFix>

## Trust and TLS on old iOS

A surprising number of “app won't connect” problems on iOS 6–9 are certificate
problems, not app bugs:

- Old devices do not trust newer roots such as **ISRG Root X1** (Let's Encrypt).
  Installing the root certificate as a configuration profile fixes many
  websites and some apps.
- Expired intermediate/root certificates cause failures that look like network
  errors.
- Check **Settings → General → Date & Time** first; a wrong clock breaks TLS.

Installing a root CA is a user action (Settings → General → Profile), not
something a Cydia package should silently do. Put the `.mobileconfig` on your
repo and document it if you want to help users here.

## Adding another app

Copy `packages/facebook`, rename the tweak, change the bundle ID, and follow
[docs/adding-a-fix.md](adding-a-fix.md). Candidate apps with active legacy
communities: Instagram, Twitter/X, Reddit, Spotify, Pinterest, Tumblr, VK.

Before investing time, check whether the failure is actually client-side:

```sh
# Watch what the app is doing
tail -f /var/mobile/Library/Logs/LegacyFixes/<bundle-id>.log
```

If the app never even reaches a decision point (the server closes the
connection or returns “upgrade required” for every request), a client tweak
will not save it.
