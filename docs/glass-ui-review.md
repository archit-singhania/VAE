# VAE glass UI review

The Creator / Business and Admin experiences now share a glass navigation
system, synchronized color tokens, new vector identities, and the same film
artwork on web and Flutter. Content panels use denser fills so their text and
data remain readable. The effects are custom cross-platform implementations
inspired by Apple's Liquid Glass design; Flutter and CSS do not reproduce the
operating system's native optical rendering exactly.

## What changed

- Creator / Business: a folded crimson V with satin highlights.
- Administration: a cobalt architectural gateway with a folded inner V.
- Both marks have matching web SVGs, Flutter vector geometry, and native icon
  exports. The wordmark uses Manrope.
- Desktop workspaces have an inset floating sidebar that collapses to icons.
  Search, theme, profile, and the primary action sit in a floating top toolbar.
- Phones have a floating capsule dock with a moving selected-tab highlight.
  The web drawer holds additional tools; Flutter's Commands control opens them.
- Landing pages keep the video at full opacity in both themes. A natural
  portrait edit appears on phones and the landscape film on wider layouts.
  Local text scrims preserve readability without covering the whole film.
- Sheets, navigation highlights and dialogs use fluid transitions. Flutter
  routes use Cupertino transitions. Reduce Motion pauses the film or shows its
  actual poster and suppresses movement; high contrast makes chrome denser.
- Colors for both portals and both themes come from
  `packages/shared/design-tokens.json`. Run `python3 scripts/design_tokens.py`
  after updating that file; `--check` detects stale generated output.

## Manual review

1. Open the web app at `http://127.0.0.1:3000`. Start on Creator / Business,
   switch between Light and Dark, and confirm the film remains visible. Open
   Admin sign in and confirm the cobalt gateway appears and your theme persists.
2. On a phone, scroll the landing page. The film should have a clear viewing
   area above the main copy. Get started opens registration; Sign in opens the
   existing-account form. Email, password reveal, and the submit action should
   remain reachable when the keyboard is open.
3. Sign in. On desktop, use Compact navigation / Collapse sidebar and confirm
   every icon still has a label on hover. Expand the sidebar again. On a phone,
   switch tabs in the bottom dock and check that the selected capsule follows.
4. Open Search / Commands, open Profile, and dismiss each. Their controls should
   remain readable against the blurred background. Do not save profile changes
   unless you intend to change the account.
5. Switch themes from the toolbar or profile sheet. Check Home, Create / AI
   usage, Publishing, Analytics, and payment review. Their main actions should
   remain visible and the content should scroll above the dock.
6. On iPhone, turn on Settings → Accessibility → Motion → Reduce Motion.
   Relaunch the app: the landing artwork should show a real still frame and
   navigation should avoid animated movement. Check larger text sizes too.
7. Reinstall a rebuilt native app to check its new home-screen icon and launch
   artwork. Hot reload alone does not replace these native assets.

## Run on this Mac and iPhone

The detailed API/model setup, Simulator instructions, and beginner functionality
tour remain in [`mobile-ios-manual-test.md`](mobile-ios-manual-test.md). Use the
visual expectations in this review for the current makeover.

### Web preview

For this Mac's bundled Node runtime, the web preview can be started with:

```sh
cd /Users/architsinghania/Documents/VAE/apps/web
/Users/architsinghania/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node node_modules/next/dist/bin/next dev --hostname 127.0.0.1 --port 3000
```

The installed global pnpm requires a newer Node runtime than the default
Node 20 on this Mac. The bundled Node 24 runtime avoids that mismatch.

### Install the current app on your real iPhone

A signed iOS Debug build exists at
`apps/mobile/build/ios/iphoneos/Runner.app`. The wireless installation attempt
timed out while connecting to the device, so this version has not been visually
verified on the physical iPhone. The command below builds with the correct
phone API address and installs by USB.

1. Connect your iPhone to this Mac with a USB cable. Unlock it and keep it
   unlocked during installation. If the phone asks **Trust This Computer?**,
   tap **Trust** and enter its passcode. Confirm a trust prompt on the Mac too,
   if one appears.
2. Keep the Mac and iPhone on the same Wi-Fi network. USB is used to install
   the app; the phone reaches the local API through Wi-Fi. On the iPhone,
   open Safari and visit `http://192.168.1.8:8000/health`. Expect a short JSON
   response containing `"status":"ok"`. Leave the API's Terminal window open.
3. Open **Terminal** on the Mac and paste:

   ```sh
   cd "/Users/architsinghania/Documents/VAE/apps/mobile"
   /opt/homebrew/share/flutter/bin/flutter run -d 00008101-000D44113480001E --dart-define=API_BASE_URL=http://192.168.1.8:8000/api/v1
   ```

   Wait for the Xcode build and installation to finish. The first run can take
   several minutes. VAE should open automatically on the iPhone. Keep Terminal
   open while testing.
4. If prompted, enable **Settings → Privacy & Security → Developer Mode** on
   the iPhone, restart it, unlock it, and confirm Developer Mode. Then run the
   command again. If iOS shows an untrusted developer message, open
   **Settings → General → VPN & Device Management** and trust the developer
   account shown for this app. Only do this for your own development account.
5. If VAE asks for access to your local network, tap **Allow**. If access was
   previously denied, enable VAE under **Settings → Privacy & Security → Local
   Network**. If macOS prompts to allow Python incoming connections, allow it
   for this local development session.

Expected first screen: the crimson folded V for Creator / Business, Manrope
text, rounded glass controls, and a portrait film with a clear viewing area
above the copy. Open Administrator sign in to see the cobalt gateway mark.
Switch Light and Dark in each portal: the film should stay visible and controls
should remain readable. With **Reduce Motion** enabled, a still frame is
expected instead of moving video. After sign-in, the floating dock highlights
the selected tab. Reinstallation applies the new app icon and launch artwork;
hot reload alone cannot update those native assets.

While `flutter run` is running, click its Terminal window and press:

- `r`: hot reload Dart UI edits, usually preserving the current screen.
- `R`: restart the app from its initial Dart state.
- `q`: stop this Flutter run session.

Changes to `API_BASE_URL` require stopping the run and rerunning the command
with the new address.

### If the Mac address or iPhone ID changes

Find the current Mac Wi-Fi IP address:

```sh
ipconfig getifaddr en0
```

If it prints nothing, open **System Settings → Wi-Fi → Details** for the
connected network and use its IP address. Replace `192.168.1.8` in both the
Safari URL and Flutter command. A server bound to `127.0.0.1` can only be reached
from the Mac; a physical phone must use the Mac's Wi-Fi address.

The local API was made available on `192.168.1.8:8000` after your explicit
approval. If that server has stopped, start it from a separate Terminal with:

```sh
cd "/Users/architsinghania/Documents/VAE"
AEVRA_DATABASE_URL=sqlite:///./aevra.db AEVRA_ENABLE_REDIS_RATE_LIMIT=0 AEVRA_EMBEDDING_PROVIDER=hashing AEVRA_IMAGE_PROVIDER=deterministic AEVRA_OLLAMA_MODEL=qwen3:1.7b ./.venv/bin/python -m uvicorn aevra_api.main:app --app-dir apps/api --host 192.168.1.8 --port 8000
```

This uses the existing local database; no reseeding is necessary. If your Wi-Fi
address changed, replace the `--host` value too. Keep the separate loopback API
on `127.0.0.1:8000` running when using the web preview. If the command reports
that the address is already in use, check `/health` before starting another
copy. Text generation also needs the Ollama server described in the setup guide.

To find a changed device ID, keep the iPhone connected and unlocked, then run:

```sh
cd "/Users/architsinghania/Documents/VAE/apps/mobile"
/opt/homebrew/share/flutter/bin/flutter devices
```

Copy the ID beside the physical **iPhone** entry into the `-d` argument. If it
does not appear, open Xcode's **Window → Devices and Simulators**, select the
phone, and finish any pairing or trust steps. Existing signing uses bundle ID
`com.archit.vae`; if Xcode reports a signing problem, open
`ios/Runner.xcworkspace`, select **Runner → Signing & Capabilities**, and select
your Apple development team with automatic signing enabled.

## Verification completed

- The loopback API and authorized Wi-Fi API both returned `"status":"ok"`.
  Ollama was restarted on loopback; the installed `qwen3:1.7b` model completed
  a short generation request successfully. No additional model download was
  needed.
- Web TypeScript, lint, and production build passed.
- The production web app was checked at a 393-pixel phone width in Creator /
  Business and Admin, Light and Dark. The portrait video loaded and played at
  full opacity, there was no horizontal overflow, and the saved theme remained
  selected when switching portals.
- Flutter's 65 responsive layout checks passed, covering phone and desktop
  sizes, larger text, both portals/themes, and sidebar collapse. The other 12
  existing tests passed in the earlier suite run.
- Flutter analysis of `lib` and `test` reported no issues. The Mac's Wi-Fi API
  health check at `http://192.168.1.8:8000/health` returned `"status":"ok"`.
- The signed iOS Debug build completed successfully. Rendered Flutter previews
  and browser screenshots were reviewed; native physical-device installation
  and visual checks remain for the USB steps above.
- These checks cover the makeover and build. Social-provider connections still
  require their own credentials, and empty metrics/review queues are expected
  until local data is created. They do not establish that every external
  integration works on the real iPhone.

## Saved previews

- [Creator / Business and Admin brand identities](ui-previews/brand-identities.png)
- [Flutter Creator / Business workspace in Light](ui-previews/flutter-creator-light-workspace.png)
- [Web Creator / Business desktop in Light](ui-previews/web-creator-light-desktop.jpg)
