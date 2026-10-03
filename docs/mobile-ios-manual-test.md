# Run VAE Mobile on this Mac

This guide runs the Flutter app as a native Mac app, in an iOS Simulator, and
on a real iPhone. The local API uses SQLite, so Docker and Android Studio are
not needed.

For the current glass UI makeover, build status, and a copy-and-paste USB
installation command for your connected iPhone, see
[`glass-ui-review.md`](glass-ui-review.md).

## What is installed on this Mac

- Flutter 3.44.1 and Dart 3.12.1
- Xcode 26.6
- A native macOS Flutter target
- iOS 26.5 Simulator runtime and a VAE iPhone 16 Pro simulator
- CocoaPods 1.16.2 under Ruby 3.2.0
- Ollama and FFmpeg

The app targets iOS 15 and newer. The native macOS target is ready to run.

## 1. Download a local text model

Text and campaign generation use Ollama when no Groq API key is configured. Run
the model server in its own Terminal window and leave that window open:

```sh
ollama serve
```

If Ollama says that port `11434` is already in use, its server is already
running. Open a second Terminal window and download the smaller Qwen model:

```sh
ollama pull qwen3:1.7b
```

The download can take a while. Image generation is deterministic locally and
does not need another model download. Knowledge search uses local hashing
embeddings by default.

## 2. Install and start the API

Open another Terminal window. Copy these commands one at a time or paste the
whole block:

```sh
cd "/Users/architsinghania/Documents/VAE"
python3 -m venv .venv
./.venv/bin/python -m pip install --upgrade pip
./.venv/bin/python -m pip install -e "./apps/api[dev]"
export AEVRA_DATABASE_URL=sqlite:///./aevra.db
export AEVRA_ENABLE_REDIS_RATE_LIMIT=0
export AEVRA_EMBEDDING_PROVIDER=hashing
export AEVRA_IMAGE_PROVIDER=deterministic
export AEVRA_OLLAMA_MODEL=qwen3:1.7b
./.venv/bin/python -m alembic upgrade head
./.venv/bin/python -m aevra_api.seed
./.venv/bin/python -m uvicorn aevra_api.main:app --reload --app-dir apps/api --host 127.0.0.1 --port 8000
```

The first install downloads the Python packages. Keep this Terminal window open
while you use the app. The last command should say that Uvicorn is listening on
port `8000`. Check the API in a browser at [http://localhost:8000/health](http://localhost:8000/health);
the response should include `"status":"ok"`.

This server is for the Mac, web preview, and iOS Simulator. The physical iPhone
uses a second server bound specifically to the Mac's Wi-Fi IP, as described in
section 5. If dependencies and the database are already set up, reuse them:
you only need the environment settings and final server command to restart
the API. Do not recreate or reseed the database for each test session.

The local database is `aevra.db` in the repository root. The seed command
creates this demo administrator and a starter brand:

| Field | Value |
| --- | --- |
| Email | `admin@vae.local` |
| Password | `VaeAdminLocalOnly!2026` |

This account and password are for this local development database only.

## 3. Run as a native Mac app

Open another Terminal window and run:

```sh
cd "/Users/architsinghania/Documents/VAE/apps/mobile"
flutter pub get
cd macos
pod install
cd ..
flutter run -d macos
```

The VAE window should open on the Mac. The local API address defaults to
`http://localhost:8000/api/v1`. The macOS Debug build keeps the access token in
memory because this Mac has no Apple development signing certificate for
Keychain Sharing. You can use the full app after signing in, and will sign in
again after restarting the Debug app. The iOS app continues to use secure
Keychain storage.

Leave the `flutter run` Terminal open. Press `r` there to apply Dart hot reload,
`R` to restart the app, and `q` to stop it.

## 4. Run in the iOS Simulator

Open another Terminal window and start an installed iPhone simulator:

```sh
open -a Simulator
```

In Simulator, choose an iPhone from **File → Open Simulator** if no device is
already shown. Then run:

```sh
cd "/Users/architsinghania/Documents/VAE/apps/mobile"
flutter pub get
cd ios
pod install
cd ..
flutter devices
```

Once `flutter devices` lists the simulator, start the app with its exact name
or device ID:

```sh
flutter run -d "VAE iPhone 16 Pro"
```

The iOS Simulator reaches the Mac API at `http://localhost:8000/api/v1`, which
is the app's default API address. If you selected a different simulator, replace
`VAE iPhone 16 Pro` with the exact name shown by `flutter devices`.

## 5. Run on a physical iPhone

An iPhone needs to be connected to the Mac for Xcode signing and installation.
This checkout has already produced a signed iOS build using bundle ID
`com.archit.vae`. The wireless installation attempt timed out; USB installation
and physical-device visual verification are the next steps.

1. Connect the unlocked iPhone to the Mac with a USB cable. Tap **Trust** on the
   iPhone and confirm the trust prompt on the Mac.
2. The existing signing settings can be reused on this Mac. If installation
   reports a signing problem, open `apps/mobile/ios/Runner.xcworkspace` in
   Xcode. Select the **Runner** project, then the **Runner** target, then
   **Signing & Capabilities**.
3. For a signing problem, turn on **Automatically manage signing** and choose
   your Apple account's team. Keep the existing bundle identifier unless Xcode
   specifically requires a unique one. Xcode can add a free Personal Team from
   **Xcode → Settings → Accounts**.
4. If the iPhone asks, enable **Settings → Privacy & Security → Developer Mode**
   and restart it. Unlock it again after restart.
5. Keep the iPhone and Mac on the same Wi-Fi network. In a Terminal window on
   the Mac, get its Wi-Fi IP address:

   ```sh
   ipconfig getifaddr en0
   ```

   If this prints nothing, open **System Settings → Wi-Fi → Details** for the
   connected network and use the IP address shown there.
6. The current Mac Wi-Fi address is `192.168.1.8`. You approved API access on
   this local Wi-Fi interface. If its API server has stopped, start it in a
   separate Terminal window:

   ```sh
   cd "/Users/architsinghania/Documents/VAE"
   AEVRA_DATABASE_URL=sqlite:///./aevra.db AEVRA_ENABLE_REDIS_RATE_LIMIT=0 AEVRA_EMBEDDING_PROVIDER=hashing AEVRA_IMAGE_PROVIDER=deterministic AEVRA_OLLAMA_MODEL=qwen3:1.7b ./.venv/bin/python -m uvicorn aevra_api.main:app --app-dir apps/api --host 192.168.1.8 --port 8000
   ```

   Replace `192.168.1.8` with the address from step 5 if it has changed. Keep
   this Terminal open. The loopback API from section 2 can stay running for the
   web and Simulator. If the Wi-Fi server reports that its address is already
   in use, check its health before starting another copy. On the iPhone, open
   Safari at `http://192.168.1.8:8000/health` (using the new IP if necessary).
   Expect JSON containing `"status":"ok"` before opening VAE.
7. In the mobile app Terminal, list devices and run on the iPhone. Replace
   `MAC_IP` with the address from the previous step and `PHONE_DEVICE_ID` with
   the iPhone ID shown by `flutter devices`:

   ```sh
   cd "/Users/architsinghania/Documents/VAE/apps/mobile"
   /opt/homebrew/share/flutter/bin/flutter devices
   /opt/homebrew/share/flutter/bin/flutter run -d PHONE_DEVICE_ID --dart-define=API_BASE_URL=http://MAC_IP:8000/api/v1
   ```

   For your currently detected iPhone and Mac address, use:

   ```sh
   /opt/homebrew/share/flutter/bin/flutter run -d 00008101-000D44113480001E --dart-define=API_BASE_URL=http://192.168.1.8:8000/api/v1
   ```

8. When iOS asks whether VAE may access the local network, tap **Allow**. The
   API server must still be running in the other Terminal window. If macOS asks
   whether Python may accept incoming connections, allow it on your private
   network.
9. If iOS reports an untrusted developer, open **Settings → General → VPN &
   Device Management** and trust the developer account shown for VAE, provided
   it is your own development account. Keep Terminal open while testing: press
   `r` for Dart hot reload, `R` for a restart, or `q` to stop the Flutter run.

For example, if the Mac address is `192.168.1.20`, use
`--dart-define=API_BASE_URL=http://192.168.1.20:8000/api/v1`. Do not use
`localhost` for a physical iPhone; that would point back to the phone itself.

## 6. Manual test tour

Start with the demo email and password above.

1. **Sign in and onboarding:** on an iPhone, swipe up on the landing page to
   reach the sign-in fields below the introduction. Enter the credentials and
   submit. On the first successful sign-in, step through the welcome tour and
   tap its final button. The iOS app stays signed in after relaunch. The macOS
   Debug app asks you to
   sign in again after restart. Open **Profile** from the top-right avatar or
   **Commands** from the search icon, then choose **Sign out** to return to the
   login screen.
2. **Home:** check the greeting and the media, channel, schedule, and engagement
   cards. On a fresh local database, most counts start at zero. Tap **Create
   media** and **Publish** to visit those tabs. Tap **Campaigns** to open the
   review queue.
3. **Create an image:** open **Create**, leave **Image** selected, enter a prompt
   such as `A ceramic coffee cup on a sunny kitchen table`, leave the aspect
   ratio at `1:1`, and tap **Generate image**. A progress bar appears; a new
   image asset should show in the library when it finishes. Try `4:5` or `9:16`
   and generate again.
4. **Create a caption:** select **Text**, enter a short post idea, then tap
   **Generate caption**. Qwen writes the result locally. Tap **Use for
   publishing** to open Publish with the caption filled in.
5. **Upload media:** in Publish, tap **Upload an asset** and choose a small image
   or video from Files. It should appear in the asset library. The app rejects
   files over 50 MB.
6. **Brand knowledge and search:** tap the search/command icon in the top bar,
   then **Brand knowledge & sources**. Add a test brand, add a short source with
   a title and body, and search for a phrase from that source. The result should
   show cited text. Go back to the main tabs with the back button.
7. **Campaign review:** open **Campaigns** from Home. Campaign creation is in
   the web/API workspace; this mobile page lists campaigns and lets you inspect
   variants and approve or reject campaigns awaiting review. A new local
   database has no campaigns yet, so an empty queue is expected until one is
   created in the web workspace.
8. **Publish and schedule:** first create an image or upload an asset, then open
   **Publish**. Choose the asset, enter a caption, choose a connected channel,
   and either publish now or select a future date and time. Review the
   confirmation before submitting. The timeline shows scheduled posts and
   offers cancel or retry actions when their status allows it.
9. **Channels:** expand **Connected channels** and choose a provider. Completing
   OAuth requires that provider's own developer app credentials and callback
   configuration in the API environment. Without those credentials, a provider
   setup error is expected. No social-network credentials are included in this
   repository.
10. **Analytics and insights:** open **Analytics**, change the date range and
    channel filters, then tap **Explore ML insights**. On a fresh workspace the
    metrics view is empty until a channel has published posts and metrics have
    been collected.
11. **Theme and commands:** use the sun/moon button to switch themes. Open the
    command palette from the search icon to try **Refresh VAE**, **Replay the
    tour**, **Profile**, and theme/sound actions. The seeded administrator also
    gets an **Admin dashboard** command.

### Visual checks on Mac and iPhone

- The four color sets are shared with the web workspace:

  | Portal / theme | Background | Action accent |
  | --- | --- | --- |
  | Creator / Business, Dark | `#121016` | `#E5485D` |
  | Creator / Business, Light | `#F3F2F6` | `#C72F47` |
  | Admin, Dark | `#0D1420` | `#4F8CFF` |
  | Admin, Light | `#F0F3F9` | `#2865D6` |

  Glass controls blend these colors with the artwork behind them, so a
  screenshot's translucent pixels will vary with their background.
- Creator / Business uses a folded crimson V; Admin uses a cobalt gateway
  with a folded inner V. The wordmark and interface use Manrope. The native
  app icon and launch artwork use the new branding. Reinstall the app to
  refresh them; hot reload does not replace native assets. Controls and
  navigation use the Lucide icon family shared with web.
- On a narrow iPhone screen, the floating glass dock shows **Home**, **Publish**,
  **Create**, **Analytics**, and **Profile** for Creator / Business. Admin shows
  **Home**, **AI usage**, **Publishing**, **Analytics**, and **Review**; **Review**
  opens Payment review. Admin Profile is in the top-right avatar and Commands.
  Tap each item and expect the selected capsule to follow. At desktop widths,
  a floating sidebar replaces the dock; collapse it and expand it again.
- Home opens with a greeting and action buttons, then metric cards, upcoming
  work, recent media, and next actions. A new local database can show zero
  metrics and empty states; these are expected until content exists.
- Switch between dark and light mode and visit Home, Create, Publish, Analytics,
  and Profile. In Admin, also check AI usage, Publishing, and Payment review.
  Text, icons, sheets, and status labels should stay readable in both themes.
- On both landing portals, the film should stay visible in Light and Dark.
  Phones use the natural portrait edit, with a clear viewing area above the
  copy; wider layouts use the landscape film. A real poster appears while
  video initializes. With **Settings → Accessibility → Motion → Reduce Motion**
  enabled, a still frame is expected. The same film artwork is used on web and
  Flutter.

## Common fixes

- **Login says it cannot connect:** confirm the API Terminal is still running
  and that `/health` loads in Safari on the same device. For a real phone, use
  the Mac's Wi-Fi IP in `API_BASE_URL`, keep both devices on the same network,
  and allow VAE under **Settings → Privacy & Security → Local Network**.
- **`flutter run` cannot see the iPhone simulator:** open **Xcode → Settings →
  Components** and check that the iOS 26.5 Simulator runtime is installed. Run
  `open -a Simulator`, select **VAE iPhone 16 Pro** from **File → Open
  Simulator**, then run `flutter devices` again.
- **CocoaPods is not found:** this checkout pins the installed project Ruby in
  `apps/mobile/.ruby-version`. From `apps/mobile`, run `rbenv version` and
  `pod --version`, then try `cd ios && pod install` again.
- **Xcode says “No space left on device”:** the simulator runtime and first
  iOS build need several gigabytes of free disk space. Check with `df -h /`.
  If your npm download cache is large, `npm cache clean --force` safely clears
  downloaded package copies; then retry `flutter run`.
- **Text generation reports Ollama unavailable:** leave `ollama serve` running,
  then check `ollama list` contains `qwen3:1.7b` and that the API Terminal has
  `AEVRA_OLLAMA_MODEL=qwen3:1.7b` set before starting the API.

## Official setup references

- [Flutter iOS development setup](https://docs.flutter.dev/platform-integration/ios)
- [Apple: enable Developer Mode on an iPhone](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)
- [Apple: local network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy)
- [Apple: trust a computer connected to an iPhone](https://support.apple.com/en-gb/109054)
