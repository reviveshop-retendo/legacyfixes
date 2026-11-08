# LegacyFixes

A Cydia / Sileo / Zebra repository that bundles compatibility fixes for apps
that still run on **legacy 32-bit iOS (6 through 9)** — YouTube, YouTube Kids,
Facebook and Messenger today — plus **TextNow Legacy**, a standalone SMS client
for iOS 7+.

It is a working monorepo, not just a list of packages:

- **Per-app packages** (`com.legacyfixes.youtube`, `…youtubekids`,
  `…facebook`, `…messenger`) plus an **All-in-One metapackage**.
- **TextNow Legacy** (`com.legacyfixes.textnow`), an unofficial native client
  for TextNow's web API, installed separately from the fixes (iOS 7+).
- A **shared runtime engine** compiled into each tweak: update-nag
  suppression, iOS-version and User-Agent spoofing, an optional certificate
  pinning bypass, a config-driven hook table, and a class/method dumper.
- A **reproducible Docker toolchain** (Theos + iOS 9.3 SDK + armv7) so builds
  are identical locally and in CI.
- **GitHub Actions → GitHub Pages** publishing, with a ready-to-use source
  page and install buttons.

> **Reality check:** the shared engine fixes common *client-side* problems
> (forced-update walls, OS checks, old user agents, pinned endpoints). It does
> not magically resurrect a service whose APIs were shut down. YouTube is fixed
> by the vendored TubeReplacer backend; the other apps use app-specific
> rewrites where a public, working technique exists.

## What is in this repo

| Package | Bundle ID | What it does |
| --- | --- | --- |
| `com.legacyfixes.allinone` | — | Metapackage that installs everything |
| `com.legacyfixes.youtube` | `com.google.ios.youtube` | **Working fix.** Depends on the vendored TubeReplacer backend (search, playback, sign-in) plus alert suppression and the shared engine |
| `com.legacyfixes.youtubekids` | `com.google.ios.youtubekids` | Same engine, for YouTube Kids |
| `com.legacyfixes.facebook` | `com.facebook.Facebook` | Info.plist version spoofing + system Facebook-integration fix + engine |
| `com.legacyfixes.messenger` | `com.facebook.Messenger` | Info.plist version spoofing + engine |
| `com.legacyfixes.textnow` | `com.legacyfixes.textnow` (standalone app) | **Unofficial TextNow client** for iOS 7+: sign in, conversations, SMS over TextNow's web API |
| `dev.preloading.tubereplacer` | `com.google.ios.youtube*` | Vendored TubeReplacer 2.0.2 (GPL-3.0); pulled in automatically by the YouTube package |

Target: `iphoneos-arm` (armv7), minimum iOS 6.0, maximum iOS 9.x. It will not
run on arm64 devices. TextNow Legacy requires iOS 7.0 and is therefore not part
of the All-in-One package (which still supports iOS 6).

**Live source:** <https://reviveshop-retendo.github.io/legacyfixes>

Add that URL in Cydia, Sileo or Zebra (see the iOS 6 TLS caveat below).

## Quick start (build locally)

Requirements: Docker. Everything else (Theos, toolchain, iOS SDK, dpkg tools)
lives in the build image.

```bash
# Point repo.conf at your Pages URL (already set for this instance)
./scripts/set-repo-url.sh https://reviveshop-retendo.github.io/legacyfixes

# Build every deb and regenerate the repo metadata
./scripts/docker-build.sh
```

Outputs:

```
build/debs/*.deb     # installable packages
repo/                # the exact directory to serve (Packages, Release, debs/, index.html)
```

Serve it locally to test on a device on the same network:

```bash
cd repo && python3 -m http.server 8080
# Add http://<your-computer-ip>:8080/ as a source on the device
```

Install a single package over SSH without a repo at all:

```bash
scp build/debs/com.legacyfixes.youtube_*.deb root@<device-ip>:/tmp/
ssh root@<device-ip> 'dpkg -i /tmp/com.legacyfixes.youtube_*.deb && killall -9 YouTube'
```

## TextNow Legacy

TextNow's current App Store client requires iOS 15 and its web client needs ES
modules, so neither runs on iOS 7. `packages/textnow` is instead a small native
Objective-C app that talks to TextNow's web API directly:

- Login with your own TextNow credentials (session cookies are persisted in the
  iOS Keychain; the password is only stored if you enable **Remember
  password**).
- Conversation list with unread badges, polling, compose, chat history and
  sending SMS.
- Foreground polling only — no WebSocket or background-mode dependency, so it
  stays compatible with iOS 7's networking stack.

Build it like any other package:

```bash
docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$PWD:/work" -w /work legacyfixes-build \
  make -C packages/textnow clean package FINALPACKAGE=1
```

The deb installs `/Applications/TextNowLegacy.app` and refreshes the icon cache
in `postinst`. It is an **unofficial client**: TextNow can change or block its
web API at any time, and accounts using Google/Apple sign-in must set a
password before signing in here. No TextNow account is bundled or required by
the build.

## Publish with GitHub Pages

This instance is published from `reviveshop-retendo/legacyfixes` to
<https://reviveshop-retendo.github.io/legacyfixes>. To publish your own fork:

1. Push the repository to GitHub (the default branch must be `main`).
2. **Settings → Pages → Build and deployment → Source: GitHub Actions.**
3. Push a commit. `.github/workflows/build.yml` builds in Docker and deploys
   `repo/` to Pages.
4. Point `repo.conf` at your Pages URL:

   ```bash
   ./scripts/set-repo-url.sh https://YOURNAME.github.io/YOUR-REPO
   ```

The page at that URL computes the source address from the browser location,
so the Cydia/Sileo/Zebra buttons work without extra configuration.

### Hosting caveat for iOS 6

GitHub Pages only accepts TLS 1.2+. iOS 7–9 handles that; **iOS 6's Cydia/APT
often does not**, so adding the source can fail with “Could not connect”.

Options for iOS 6:

- Install a TLS backport for legacy APT first (for example
  [TLSFix](https://github.com/nfzerox/TLSFix), installed from its own repo or
  `.deb`), then add the HTTPS source.
- Mirror `repo/` on a server/CDN that still negotiates TLS 1.0/1.1, or serve it
  over plain HTTP. If you do, sign the repo (see below) so clients can verify
  the metadata.
- Prefer iOS 7–9 for the devices you support publicly.

Update `REPO_URL` in `repo.conf` if you mirror it elsewhere.


### Signing (optional but recommended)

Replace `YOURNAME` in `repo.conf`, then add a GPG key:

```bash
export REPO_SIGNING_KEY=<key-id>
./scripts/make-repo.sh   # writes Release.gpg + InRelease when the key is set
```

Do not commit the private key. In CI, import it from a secret before the build
step and export `REPO_SIGNING_KEY`.

## Repository layout

```
shared/LFEngine.{h,m}      # the runtime compiled into every tweak
packages/<app>/            # one Theos project per app fix
  Makefile
  Tweak.xm                 # constructor + app-specific %hooks
  control                  # Debian package metadata
  <Tweak>.plist            # MobileSubstrate bundle filter
  layout/…/Patches/<bundle-id>.plist   # default config
packages/textnow/          # standalone TextNow Legacy app (not a tweak)
  Makefile
  TN*.{h,m}                # Objective-C sources
  Resources/Info.plist
  generate-icons.py        # regenerates icons/launch images
  layout/DEBIAN/postinst   # uicache refresh
packages/allinone/control  # metapackage template
repo/                      # published site (index.html + generated metadata)
scripts/build.sh           # build all debs + repo
scripts/docker-build.sh    # same, inside the pinned toolchain
docker/Dockerfile          # Theos + iOS 9.3 SDK + armv7
```

## Configuration on-device

Defaults are installed per app at:

```
/Library/Application Support/LegacyFixes/Patches/<bundle-id>.plist
```

Per-device overrides go in:

```
/var/mobile/Library/Preferences/com.legacyfixes.<bundle-id>.plist
```

The override is deep-merged over the defaults, so you only need to include the
keys you want to change. Restart the app after editing. Logs:

```
/var/mobile/Library/Logs/LegacyFixes/<bundle-id>.log
```

Useful keys:

| Key | Type | Meaning |
| --- | --- | --- |
| `Enabled` | bool | Master switch |
| `SystemVersion` | string | Report this iOS version to the app |
| `UserAgent` | string | Replace outgoing `User-Agent` |
| `SuppressAlerts` | array | Hide alerts containing any string |
| `InfoPlistOverrides` | dict | Values returned for the app's `Info.plist` via `NSBundle` and CoreFoundation (e.g. `FBAppVersion`) |
| `BypassCertPinning` | bool | Accept any TLS trust result (**debug only**) |
| `DumpClasses` | bool | Log every class name at launch |
| `DumpClassesFilter` | string | Only dump classes containing this text |
| `DumpMethodsForClasses` | array | Log instance/class methods for these classes |
| `Patches` | array | Config-driven zero-argument method patches |
| `WebFallback` | bool | YouTube Kids only: use the in-app web client |
| `WebFallbackURL` | string | YouTube Kids only: page to load |
| `WebFallbackDelay` | number | YouTube Kids only: seconds to wait after launch |
| `WebFallbackUserAgent` | string | YouTube Kids only: optional UIWebView User-Agent |

Example patch rule (disable a boolean gate without writing code):

```xml
<key>Patches</key>
<array>
    <dict>
        <key>Class</key>      <string>SomeClass</string>
        <key>Selector</key>   <string>isSupported</string>
        <key>Return</key>     <true/>
        <key>Log</key>        <true/>
    </dict>
</array>
```

Set `Original` to `true` (and omit `Return`) to only log calls and then invoke
the real implementation.

## Adding a fix

See [docs/adding-a-fix.md](docs/adding-a-fix.md). The short version:

1. Add `%hook` blocks to `packages/<app>/Tweak.xm`, or add a rule to the patch
   plist for simple yes/no gates.
2. `./scripts/docker-build.sh`
3. Install the deb and watch `/var/mobile/Library/Logs/LegacyFixes/`.

## Related open-source work

These projects solve specific apps and are worth studying or depending on.
Check each license before redistributing binaries:

- **TubeReplacer** — YouTube fix for iOS 5–10, no backend required. GPL-3.0.
  **Vendored under `vendor/TubeReplacer` and shipped by this repo.**
  <https://github.com/Preloading/TubeReplacer>
- **FBIntegrationFix** — repairs iOS 6–8's system Facebook account integration.
  No license file, so the technique was independently reimplemented here; see
  `packages/facebook/FBSystemFix.xm`.
  <https://github.com/Epixx512/FBIntegrationFix>
- **TubeRepair** — classic YouTube + App Store YouTube client/server fix.
  Client source currently has no license, so link to it rather than vendoring.
  <https://github.com/ObscureMosquito/TubeRepair-Client>
- **YouTubeLegacy** — newer YouTube clients (iOS 11+, arm64). MIT.
  <https://github.com/PoomSmart/YouTubeLegacy>
- **iTunesStoreX** — App Store connectivity/layout on old iOS. GPL-3.0.
  <https://github.com/ObscureMosquito/iTunesStoreX>
- **bag-xml legacy guides** — Facebook login workarounds and more.
  <https://developer.bag-xml.com/guides/facebook/>

## Legal / ethical notes

- Only install on devices you own.
- TextNow Legacy is an unofficial client for your own TextNow account. It is
  not affiliated with or endorsed by TextNow.
- Do not use this project to bypass DRM, paid features, or account bans.
- Respect the licenses of any code you copy into this repo. The MIT license
  here covers only the original code in this repository.
- Apps may still ban or break old clients server-side; that is outside the
  scope of a client tweak.

## License

MIT — see [LICENSE](LICENSE).
