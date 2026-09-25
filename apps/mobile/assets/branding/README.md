# Flutter branding assets

The creator and administrator marks come from the same vector artwork used by
the web app in `apps/web/public/brand/`. Flutter uses the matching PNGs here
because native launch screens and app icons do not load SVGs.

- `vae_creator_icon_256.png` and `vae_admin_icon_256.png` are the in-app marks.
- `aevra_app_icon_1024.png` is the opaque iPhone home-screen icon. Its generated
  sizes are already in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- `aevra_splash_600.png` is the transparent creator mark on the iPhone launch
  screen. It is rendered from `apps/web/public/brand/vae-creator-icon.svg`.
  The native launch background is `#F8F3F4` in light mode and `#171014` in
  dark mode, matching the app theme.

The generated iOS icon and launch screen are included in the repository. You do
not need to regenerate them to run the app. If the vector or palette changes,
update these source assets and run `dart run flutter_launcher_icons` and
`dart run flutter_native_splash:create` from `apps/mobile`.
