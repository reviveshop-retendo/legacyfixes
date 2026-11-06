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
| **YouTube** (App Store) | **Working** | Old API endpoints shut down; TLS changes | Fixed by the vendored TubeReplacer backend (see below). |
| **YouTube Kids** | Web fallback + engine | Same family of API/version problems | No public native backend replacement exists; fallback documented below. |
| **Facebook** | **Working on iOS 6–8** (v11) | Login/2FA flow, unsupported-client wall, broken system integration | Info.plist spoof + system integration fix (see below). |
| **Messenger** | Version-spoofed; server still strict | Server enforces a minimum client version / E2E encryption | Works for some versions/accounts; not guaranteed. |
| **App Store** | Not included | Expired/broken trust, UI layout | `iTunesStoreX` (GPL-3) is the known fix. |
| **Instagram / Twitter / Reddit / Spotify** | Not included | API changes, minimum version | Good candidates for new packages. |
| **WhatsApp / Snapchat** | Not included | Aggressive server-side version enforcement | Do not expect these to work. |

“Engine only” means the package installs and can suppress update walls / spoof
OS + User-Agent, but it does **not** restore the service by itself.

## YouTube

`com.legacyfixes.youtube` **works** because it depends on
**TubeReplacer** (`dev.preloading.tubereplacer` 2.0.2), which replaces the
dead backend locally instead of relying on a proxy server. The source is
vendored under `vendor/TubeReplacer` (GPL-3.0) and built by this repo's
toolchain, so users only need one Cydia source. It supports the App Store
YouTube app versions 1.0.0–2.0.0 on iOS 5–10 (armv7 here), including sign-in.

The shared engine still handles the surrounding glue (forced-update alerts,
OS/User-Agent spoofing, logging). The alternative **TubeRepair** approach uses
a self-hosted/community server; its client source currently has no license, so
it is linked rather than bundled: <https://github.com/ObscureMosquito/TubeRepair-Client>.

## YouTube Kids

There is no public backend replacement for the old YouTube Kids client (unlike
TubeReplacer for YouTube), and its native protocol is gone. The package
therefore uses a **web fallback**: a couple of seconds after launch it presents
`https://www.youtubekids.com/` in an in-app browser, so the kid-safe catalogue
is still reachable from the same icon. Tune it with `WebFallback`,
`WebFallbackURL` and `WebFallbackDelay`, or set `WebFallback=false` to keep the
native UI.

The fallback depends on WebKit being able to load Google's modern site. That
works on iOS 8/9; on iOS 6/7 install a TLS 1.2 backport (e.g. TLSFix) first.

## Facebook / Messenger

Facebook 11.x is the last build that runs on iOS 6. Two things broke:

1. **The system Facebook-account integration** (the account stored in
   Settings) makes three requests that modern servers reject:
   `graph.facebook.com//me/privacy_options`, `graph.facebook.com/me/links`
   and `api.facebook.com/method/auth.login` with an old app token. This causes
   crashes/hangs and failed logins. The package's `FacebookSystemFix` component
   registers an `NSURLProtocol` in `accountsd`, `sociald`, `SocialUIService`
   and `SpringBoard` and rewrites exactly those requests.
2. **The client version wall.** The app reports itself as an old Facebook build
   and refuses to continue. `LegacyFixes` overrides `CFBundleShortVersionString`,
   `FBAppVersion` and `FBPlatformVersion` *inside the process* (no edits to the
   signed `.app`). Defaults come from the 2026 community fix: 544.0.0 /
   544.0.0.57.70.

Login flow: enable 2FA on the account, sign in with email + password, and
approve the “Confirm Identity” prompt from a newer device if it appears. The
[bag-xml Facebook guide](https://developer.bag-xml.com/guides/facebook/) has
step-by-step screenshots.

Messenger only checks `FBAppVersion` / `FBPlatformVersion`, so the package
spoofs those to 447.0.0.43.106 / 447.0.0. That gets past the client-side
“wrong credentials” wall. Messenger also enforces server-side rules (and has
moved to end-to-end encryption), so an account may still be refused; there is
no client-side fix for that.

The request/token rewrite is the same technique as the community
`FBIntegrationFix` project, reimplemented here because that project has no
license. The tokens involved are public client tokens embedded in old
Facebook/iOS builds, not user credentials.


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
