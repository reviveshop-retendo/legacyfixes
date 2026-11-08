# Adding a fix

This repo gives you two ways to change an app's behaviour:

1. **Config-only** — flip a boolean/number/string gate with the patch table.
   No rebuild of the tweak needed if you edit the on-device override plist.
2. **Code** — add a Logos hook to `packages/<app>/Tweak.xm` when the fix needs
   logic, arguments, or method replacement.

Start with the first. Only write code when the app's behaviour cannot be
described as “this zero-argument method should return X”.

---

## 0. Before you start

- Use a **test device** you can restore. A boot loop on your daily driver is
  not fun.
- Install OpenSSH on the device and set up key auth.
- Keep the app's original `.app` bundle somewhere safe.
- `firmware (<< 10.0)` and armv7 only: this project targets 32-bit iOS 6–9.

---

## 1. Find the app binary

On the device (over SSH):

```sh
# iOS 8/9
find /var/mobile/Containers/Bundle/Application -maxdepth 2 -name '*.app'

# iOS 6/7
find /var/mobile/Applications -maxdepth 2 -name '*.app'
```

Copy the executable to your computer:

```sh
scp root@DEVICE:'/var/mobile/Containers/Bundle/Application/…/YouTube.app/YouTube' .
```

Useful inspection tools:

| Tool | What it gives you |
| --- | --- |
| `class-dump -H Binary` | Objective-C headers (best on macOS) |
| `llvm-objdump --macho --objc-meta-data Binary` | class/method metadata on Linux |
| `strings -a Binary \| grep -i update` | user-facing strings and selector names |
| `nm -m Binary \| grep -i version` | symbols |
| `radare2` / Hopper / IDA | disassembly when you need to understand logic |
| Cycript (on device) | live object inspection on iOS 6–9 |

> **Shortcut:** the engine can dump classes and methods for you at runtime.
> Set `DumpClasses`/`DumpMethodsForClasses` in the override plist (see below),
> restart the app, then read the log. This is often faster than static tools.

---

## 2. Observe the app

Install the relevant package first, then edit the override plist on-device:

```
/var/mobile/Library/Preferences/com.legacyfixes.<bundle-id>.plist
```

Example for YouTube:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Enabled</key><true/>
    <key>DumpClasses</key><true/>
    <key>DumpClassesFilter</key><string>Update</string>
    <key>DumpMethodsForClasses</key>
    <array>
        <string>YTAppDelegate</string>
    </array>
</dict>
</plist>
```

Then:

```sh
killall -9 YouTube
tail -f /var/mobile/Library/Logs/LegacyFixes/com.google.ios.youtube.log
```

You will get lines like:

```
class YTUpdateChecker
  -[YTUpdateChecker isUpdateRequired] c16@0:8
  -[YTUpdateChecker minimumVersion] @16@0:8
```

That tells you exactly what to patch.

### Common things to look for

- an “update required” flag (`isUpdateRequired`, `shouldBlock`, `isSupported`)
- a minimum-version string (`minimumVersion`, `requiredVersion`)
- a client/API version constant (`apiVersion`, `clientVersion`)
- an eligibility check (`isEligible`, `canPlay`, `isEnabled`)
- a hard-coded API host (`apiHost`, `baseURL`, `endpoint`)

---

## 3a. Fix it with the patch table (no code)

Add a rule to the **override** plist:

```xml
<key>Patches</key>
<array>
    <dict>
        <key>Class</key>    <string>YTUpdateChecker</string>
        <key>Selector</key> <string>isUpdateRequired</string>
        <key>Return</key>   <false/>
        <key>Log</key>      <true/>
    </dict>
    <dict>
        <key>Class</key>    <string>YTUpdateChecker</string>
        <key>Selector</key> <string>minimumVersion</string>
        <key>Return</key>   <string>1.0.0</string>
        <key>Log</key>      <true/>
    </dict>
</array>
```

Supported return types: `void`, booleans, integers, floats/doubles, and
Objective-C objects (strings/numbers). Only **zero-argument** methods can be
patched this way; use a code hook for anything else.

Set `Original` to `true` and omit `Return` to log calls without changing the
result:

```xml
<dict>
    <key>Class</key>    <string>SomeClass</string>
    <key>Selector</key> <string>someMethod</string>
    <key>Original</key> <true/>
    <key>Log</key>      <true/>
</dict>
```

Restart the app. If the rule's class/method does not exist, the engine logs a
“skipping patch” line instead of crashing.

---

## 3b. Spoof the version the app reports (no code)

Many legacy clients gate themselves on their own Info.plist version fields
(Facebook's `FBAppVersion`, Messenger's `FBAppVersion` / `FBPlatformVersion`).
Editing the signed `.app` is fragile and breaks code signing, so the engine
overrides the values in-process instead, through both `NSBundle` and
CoreFoundation:

```xml
<key>InfoPlistOverrides</key>
<dict>
    <key>CFBundleShortVersionString</key> <string>544.0.0</string>
    <key>FBAppVersion</key>               <string>544.0.0.57.70</string>
    <key>FBPlatformVersion</key>          <string>544.0.0</string>
</dict>
```

Only the main app bundle is affected. The launch log prints the effective
values (`effective Info.plist[...] = ...`) so you can confirm the override
before blaming the server. This is how the Facebook and Messenger packages
work; use the values that are known to work for the specific app build.

---

## 3c. Fix it with code

Open `packages/<app>/Tweak.xm` and add Logos hooks below the constructor:

```objc
#import <Foundation/Foundation.h>
#import "LFEngine.h"

%ctor {
    LFStart(@"com.google.ios.youtube");
}

%hook YTUpdateChecker

- (BOOL)isUpdateRequired {
    LFLog(@"[YouTubeFix] blocked update wall");
    return NO;
}

- (NSString *)minimumVersion {
    return @"1.0.0";
}

%end
```

Rules of thumb:

- Always guard with `%orig` when you are unsure; log first, change second.
- Do not hook private methods on frameworks (SpringBoard, UIKit) unless you
  have to; keep the blast radius inside the app.
- Return early instead of throwing exceptions. On iOS 6 an uncaught exception
  is usually a crash.
- Log generously with `LFLog` while developing, then turn it down.
- If a class does not exist in some app version, the hook simply never fires;
  `%hook` is safe in that respect. Do not assume a method's signature though.

Build and install just that package.

With this repo's toolchain, the simplest path is to build everything and copy
the one deb you need to the device:

```bash
./scripts/docker-build.sh
scp build/debs/com.legacyfixes.youtube_*.deb root@DEVICE_IP:/tmp/
ssh root@DEVICE_IP 'dpkg -i /tmp/com.legacyfixes.youtube_*.deb && killall -9 YouTube'
```

If you already have Theos installed on your computer, you can build/install
directly from the package directory instead:

```bash
export THEOS=$HOME/theos
export PATH="$THEOS/bin:$PATH"
cd packages/youtube
make package install THEOS_DEVICE_IP=DEVICE_IP THEOS_DEVICE_PORT=22
```

`make install` uses SSH; set up keys and make sure `OpenSSH` is installed.

---

## 4. Add a whole new app package

1. Copy an existing package:

   ```bash
   cp -R packages/facebook packages/instagram
   ```

2. Rename the tweak in `Makefile` (`FacebookFix` → `InstagramFix`).
3. Rename the filter plist to match the tweak name and update the bundle ID.
4. Update `control` (package id, name, description).
5. Update the patch defaults path under `layout/…/Patches/`.
6. Update the constructor in `Tweak.xm` and the filter plist.
7. Add the directory name to `APP_PACKAGES` in `scripts/build.sh`.
8. Add it to `packages/allinone/control`'s `Depends` and to `repo/index.html`.
9. Build:

   ```bash
   ./scripts/docker-build.sh
   ```

Common bundle IDs:

| App | Bundle ID |
| --- | --- |
| YouTube | `com.google.ios.youtube` |
| YouTube Kids | `com.google.ios.youtubekids` |
| Facebook | `com.facebook.Facebook` |
| Messenger | `com.facebook.Messenger` |
| Instagram | `com.burbn.instagram` |
| Twitter / X | `com.atebits.Tweetie2` |
| Reddit | `com.reddit.Reddit` |
| Spotify | `com.spotify.client` |
| WhatsApp | `net.whatsapp.WhatsApp` |
| Snapchat | `com.toyopagroup.picaboo` |

Verify the ID on-device instead of trusting the table:

```sh
plutil -p /path/to/App.app/Info.plist | grep CFBundleIdentifier
```

---

## 5. Debugging checklist

- **Safe mode after respring?** The tweak crashed on load. Check
  `/var/mobile/Library/Logs/CrashReporter/` and remove the package.
- **Package installed but no log file?** The filter bundle ID is wrong, or the
  app was not fully restarted (`killall -9 <App>`).
- **“class not found” in the log?** The class name is wrong or was stripped;
  dump classes without a filter and search.
- **“unsupported return type”?** Use a code hook for structs, pointers, or
  methods with arguments.
- **Everything loads but nothing changes?** Add `Log`/`Original` to confirm
  your hook is actually called before changing its return value.
- **Cydia says “wrong architecture”?** You are on an arm64 device; this repo
  is armv7 only.

---

## 6. Before you ship

- Remove noisy per-call logging, or leave it behind an explicit config key.
- Make the fix work on a clean install **and** with a user override file.
- Test on the oldest iOS you claim to support (6.0/6.1 if possible).
- Keep the license of any code you port. If you copy GPL-3 code into a
  package, that package becomes GPL-3; note it in the package description and
  README.
