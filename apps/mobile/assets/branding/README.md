# Flutter branding assets

The creator / business identity is a folded crimson V. The administrator
identity is a cobalt architectural gateway. Their editable SVG artwork lives
in `apps/web/public/branding/`; the older `public/brand/` paths point to the
same identity for compatibility.

Flutter draws both in-app marks as vectors in `lib/widgets/aevra_logo.dart`,
using the same 64-unit paths and gradient stops as the SVGs. Native launch
screens and app icons use the rendered PNGs in this directory.

- `vae_creator_icon_256.png` and `vae_admin_icon_256.png` are raster exports.
- `aevra_app_icon_1024.png` is the opaque iPhone home-screen icon. Its generated
  sizes are already in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- `aevra_splash_600.png` is the transparent creator mark on the iPhone launch
  screen. It is rendered from the shared creator SVG.
  The native launch background is `#F8F3F4` in light mode and `#171014` in
  dark mode, matching the app theme.

The generated iOS and macOS icons and iOS launch artwork are included. You do
not need to regenerate them to run the app. For future brand changes,
`scripts/refresh_brand_assets.py` renders the SVG, PNG, icon catalog and launch
artwork together; it requires Pillow and `rsvg-convert`. Keep the Flutter
painter geometry in sync when changing a mark.
