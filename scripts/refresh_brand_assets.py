"""Render the shared VAE vector identity for the web and native launch surfaces.

Run with Python + Pillow and librsvg's rsvg-convert. The in-app Flutter painter
uses the same 64-unit geometry, so marks remain sharp at every interface size.
"""

from pathlib import Path
import io
import json
import subprocess

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "apps/web/public"
MOBILE = ROOT / "apps/mobile/assets/branding"

CREATOR = """<defs>
  <linearGradient id="left" x1="8" y1="10" x2="34" y2="55" gradientUnits="userSpaceOnUse">
    <stop stop-color="#ff9caa"/><stop offset=".38" stop-color="#e5485d"/><stop offset="1" stop-color="#8b1838"/>
  </linearGradient>
  <linearGradient id="right" x1="52" y1="10" x2="27" y2="55" gradientUnits="userSpaceOnUse">
    <stop stop-color="#ffb5bf"/><stop offset=".36" stop-color="#ed6175"/><stop offset="1" stop-color="#c72f47"/>
  </linearGradient>
</defs>
<path d="M7 10H19L36 43L29 55C27 54 26 52 25 50L5 15Q3 10 7 10Z" fill="url(#left)"/>
<path d="M45 10H57Q61 10 59 15L38 51Q35 57 29 55L24 44L45 10Z" fill="url(#right)"/>
<path d="M9 12H18L31 37M46 12H56L37 48" fill="none" stroke="#fff" stroke-opacity=".5" stroke-width="1" stroke-linecap="round" stroke-linejoin="round"/>
"""

ADMIN = """<defs>
  <linearGradient id="arch" x1="13" y1="7" x2="51" y2="54" gradientUnits="userSpaceOnUse">
    <stop stop-color="#b1d6ff"/><stop offset=".35" stop-color="#599bff"/><stop offset="1" stop-color="#2865d6"/>
  </linearGradient>
  <linearGradient id="fold" x1="25" y1="39" x2="39" y2="60" gradientUnits="userSpaceOnUse">
    <stop stop-color="#91bfff"/><stop offset="1" stop-color="#3578ea"/>
  </linearGradient>
</defs>
<path d="M9 53V26C9 13 19 6 32 6C45 6 55 13 55 26V53H44V26C44 20 39 17 32 17C25 17 20 20 20 26V53Z" fill="url(#arch)"/>
<path d="M24 39L32 47L40 39V51L32 59L24 51Z" fill="url(#fold)"/>
<path d="M11 51V26C11 15 20 8 32 8C44 8 53 15 53 26M26 42L32 48L38 42" fill="none" stroke="#fff" stroke-opacity=".5" stroke-width="1" stroke-linecap="round" stroke-linejoin="round"/>
"""


def svg(mark: str, label: str, background: str | None = None) -> str:
    ground = f'<rect width="64" height="64" rx="15" fill="{background}"/>' if background else ""
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" role="img" aria-label="{label}">{ground}{mark}</svg>\n'


def raster(source: str, size: int) -> Image.Image:
    data = subprocess.run(
        ["rsvg-convert", "-w", str(size), "-h", str(size)],
        input=source.encode(), capture_output=True, check=True,
    ).stdout
    return Image.open(io.BytesIO(data)).convert("RGBA")


def padded_mark(source: str, size: int, fraction: float) -> Image.Image:
    mark = raster(source, round(size * fraction))
    image = Image.new("RGBA", (size, size))
    image.alpha_composite(mark, ((size - mark.width) // 2, (size - mark.height) // 2))
    return image


def main() -> None:
    (WEB / "branding").mkdir(exist_ok=True)
    marks = {"creator": svg(CREATOR, "VAE Creator and Business"), "admin": svg(ADMIN, "VAE Administration")}
    font = ImageFont.truetype(str(ROOT / "apps/mobile/assets/fonts/Manrope-SemiBold.ttf"), 128)
    for audience, source in marks.items():
        (WEB / "branding" / f"vae_{audience}_mark.svg").write_text(source)
        (WEB / "brand" / f"vae-{audience}-icon.svg").write_text(source)
        raster(source, 256).save(MOBILE / f"vae_{audience}_icon_256.png")
        horizontal = Image.new("RGBA", (512, 200))
        horizontal.alpha_composite(raster(source, 152), (0, 24))
        ImageDraw.Draw(horizontal).text((176, 6), "VAE", font=font, fill="#e5485d" if audience == "creator" else "#4f8cff")
        horizontal.save(MOBILE / f"vae_{audience}_horizontal_512.png")
        lockup = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 200" role="img" aria-label="VAE {audience}"><svg x="0" y="24" width="152" height="152" viewBox="0 0 64 64">{CREATOR if audience == "creator" else ADMIN}</svg><text x="176" y="147" font-family="Manrope, Arial, sans-serif" font-size="128" font-weight="600" letter-spacing="-7" fill="{("#e5485d" if audience == "creator" else "#4f8cff")}">VAE</text></svg>\n'
        (WEB / "brand" / f"vae-{audience}-horizontal.svg").write_text(lockup)

    (WEB / "brand/aevra-mark.svg").write_text(marks["creator"])
    (WEB / "brand/vae-primary-horizontal.svg").write_text((WEB / "brand/vae-creator-horizontal.svg").read_text())
    (WEB / "favicon.svg").write_text(svg(CREATOR, "VAE", "#121016"))
    icon = Image.new("RGBA", (1024, 1024), "#121016")
    icon.alpha_composite(padded_mark(marks["creator"], 1024, .64))
    icon.convert("RGB").save(MOBILE / "aevra_app_icon_1024.png")
    padded_mark(marks["creator"], 1024, .58).save(MOBILE / "aevra_icon_foreground_1024.png")
    padded_mark(marks["creator"], 600, .55).save(MOBILE / "aevra_splash_600.png")
    padded_mark(marks["creator"], 960, .4).save(MOBILE / "aevra_splash_android12_960.png")

    catalog = ROOT / "apps/mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset"
    entries = json.loads((catalog / "Contents.json").read_text())["images"]
    for entry in entries:
        pixels = round(float(entry["size"].split("x")[0]) * float(entry["scale"].removesuffix("x")))
        icon.convert("RGB").resize((pixels, pixels), Image.Resampling.LANCZOS).save(catalog / entry["filename"])
    for platform in ("ios", "macos"):
        launch = ROOT / f"apps/mobile/{platform}/Runner/Assets.xcassets/LaunchImage.imageset"
        if launch.exists():
            for image in launch.glob("*.png"):
                with Image.open(image) as old:
                    size = old.width
                padded_mark(marks["creator"], size, .55).save(image)
    mac_icon = ROOT / "apps/mobile/macos/Runner/Assets.xcassets/AppIcon.appiconset"
    if mac_icon.exists():
        for entry in json.loads((mac_icon / "Contents.json").read_text())["images"]:
            pixels = round(float(entry["size"].split("x")[0]) * float(entry["scale"].removesuffix("x")))
            icon.convert("RGB").resize((pixels, pixels), Image.Resampling.LANCZOS).save(mac_icon / entry["filename"])


if __name__ == "__main__":
    main()
