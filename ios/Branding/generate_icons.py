"""Export native icons from the approved, immutable Fini bitmap masters.

Packaging only: resize, contain, edge-clamp padding and native masks for previews.
This does not draw a substitute character or invoke a platform SDK.
"""

import argparse
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw, ImageOps, PngImagePlugin


ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / "assets/branding/fini-launcher-master.png"
SPLASH_MASTER = ROOT / "assets/images/fini.png"
IOS = ROOT / "ios/Runner/Assets.xcassets"
ANDROID = ROOT / "android/app/src/main/res"
PAPER = "#FFFBF3"
LANCZOS = Image.Resampling.LANCZOS
# Android: 108 dp layers, 72 dp masked viewport, 66 dp safe circle.
# A 62 dp master keeps this portrait's tall ear tips inside the safe circle.
LAYER_DP = 108
ART_DP = 62
ART_Y_SHIFT_DP = 5  # Align the already-cropped bust with the masked viewport bottom.
VIEWPORT_DP = 72
EXPORT_SCALE = 4


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save_png(image, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    clean = image.copy()
    clean.info.clear()
    srgb = PngImagePlugin.PngInfo()
    srgb.add(b"sRGB", b"\x00")
    clean.save(path, format="PNG", pnginfo=srgb, optimize=True)


def load_masters():
    with Image.open(MASTER) as source:
        if source.width != source.height or source.width < 1024:
            raise ValueError("Launcher master must be square and at least 1024 px.")
        if "A" in source.getbands() and source.getchannel("A").getextrema() != (255, 255):
            raise ValueError("Launcher master must be opaque; alpha removal is not inferred.")
        icon = source.convert("RGB")
    with Image.open(SPLASH_MASTER) as source:
        splash = source.convert("RGBA")
    return icon, splash


def padded_adaptive_layer(master):
    """Clamp existing edge pixels into padding, without repainting the master."""
    side = LAYER_DP * EXPORT_SCALE
    art_side = ART_DP * EXPORT_SCALE
    left = (side - art_side) // 2
    top = left + ART_Y_SHIFT_DP * EXPORT_SCALE
    right = side - left - art_side
    bottom = side - top - art_side
    art = master.resize((art_side, art_side), LANCZOS)
    layer = Image.new("RGB", (side, side))
    layer.paste(art, (left, top))
    strips = [
        ((0, 0, art_side, 1), (art_side, top), (left, 0)),
        ((0, art_side - 1, art_side, art_side), (art_side, bottom), (left, top + art_side)),
        ((0, 0, 1, art_side), (left, art_side), (0, top)),
        ((art_side - 1, 0, art_side, art_side), (right, art_side), (left + art_side, top)),
    ]
    for crop, size, origin in strips:
        layer.paste(art.crop(crop).resize(size), origin)
    corners = [((0, 0, left, top), (0, 0)),
               ((left + art_side, 0, side, top), (art_side - 1, 0)),
               ((0, top + art_side, left, side), (0, art_side - 1)),
               ((left + art_side, top + art_side, side, side), (art_side - 1, art_side - 1))]
    for rectangle, sample in corners:
        layer.paste(art.getpixel(sample), rectangle)
    # Ear-tip anchors checked against the approved portrait, not inferred cutouts.
    for x, y in [(0.238, 0.052), (0.674, 0.017)]:
        dx = (x - 0.5) * ART_DP
        dy = (y - 0.5) * ART_DP + ART_Y_SHIFT_DP
        radius = (dx * dx + dy * dy) ** 0.5
        if radius > 33:
            raise ValueError("Fini's ear tip exceeds Android's 66 dp safe circle.")
    return layer


def splash_image(master, scale):
    canvas = Image.new("RGBA", (168 * scale, 185 * scale))
    art = ImageOps.contain(master, (168 * scale, 185 * scale), LANCZOS)
    origin = ((canvas.width - art.width) // 2, (canvas.height - art.height) // 2)
    canvas.alpha_composite(art, origin)
    return canvas


def write_bitmap_alias(name, resource):
    (ANDROID / f"drawable/{name}.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<bitmap xmlns:android="http://schemas.android.com/apk/res/android"\n'
        f'    android:src="@drawable/{resource}" android:gravity="fill" android:filter="true" />\n'
    )


def write_android_wiring(background):
    colors_path = ANDROID / "values/colors.xml"
    tree = ET.parse(colors_path)
    colors = tree.getroot()
    color = colors.find("color[@name='trails_launcher_background']")
    if color is None:
        color = ET.SubElement(colors, "color", {"name": "trails_launcher_background"})
    color.text = background
    ET.indent(tree, space="    ")
    tree.write(colors_path, encoding="utf-8", xml_declaration=True)
    write_bitmap_alias("fox_foreground", "fini_launcher_foreground")
    write_bitmap_alias("fox_mark", "fini_splash_mark")
    (ANDROID / "mipmap-anydpi-v26/ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/trails_launcher_background" />\n'
        '    <foreground android:drawable="@drawable/fox_foreground" />\n'
        '</adaptive-icon>\n'
    )
    for folder in ("drawable", "drawable-v21"):
        (ANDROID / folder / "launch_background.xml").write_text(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <item android:drawable="@color/trails_paper" />\n'
            '    <item android:width="168dp" android:height="185dp" android:gravity="center" '
            'android:drawable="@drawable/fox_mark" />\n'
            '</layer-list>\n'
        )


def masked_preview(image, circle=False):
    image = image.resize((256, 256), LANCZOS).convert("RGBA")
    mask = Image.new("L", image.size)
    draw = ImageDraw.Draw(mask)
    if circle:
        draw.ellipse((0, 0, 255, 255), fill=255)
    else:
        draw.rounded_rectangle((0, 0, 255, 255), radius=58, fill=255)
    image.putalpha(mask)
    paper = Image.new("RGBA", image.size, PAPER)
    paper.alpha_composite(image)
    return paper.convert("RGB")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview-dir", type=Path, default=ROOT / "output/qa/launcher-preview")
    args = parser.parse_args()
    before = {str(path.relative_to(ROOT)): digest(path) for path in (MASTER, SPLASH_MASTER)}
    icon, splash = load_masters()
    adaptive = padded_adaptive_layer(icon)
    catalog = IOS / "AppIcon.appiconset"
    manifest = json.loads((catalog / "Contents.json").read_text())
    for item in manifest["images"]:
        if item.get("appearances"):
            raise ValueError("Appearance-specific slots require separately approved masters.")
        width, height = (float(value) for value in item["size"].split("x"))
        if width != height:
            raise ValueError("AppIcon slots must be square.")
        pixels = round(width * float(item["scale"].removesuffix("x")))
        save_png(icon.resize((pixels, pixels), LANCZOS), catalog / item["filename"])
    for density, side in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        save_png(icon.resize((side, side), LANCZOS), ANDROID / f"mipmap-{density}/ic_launcher.png")
    save_png(adaptive, ANDROID / "drawable-nodpi/fini_launcher_foreground.png")
    save_png(splash_image(splash, 3), ANDROID / "drawable-nodpi/fini_splash_mark.png")
    corners = [icon.getpixel(point) for point in [(0, 0), (icon.width - 1, 0),
                                               (0, icon.height - 1), (icon.width - 1, icon.height - 1)]]
    background = "#" + "".join(f"{round(sum(c[i] for c in corners) / 4):02X}" for i in range(3))
    write_android_wiring(background)
    for scale in (1, 2, 3):
        suffix = "" if scale == 1 else f"@{scale}x"
        save_png(splash_image(splash, scale), IOS / f"LaunchImage.imageset/LaunchImage{suffix}.png")
    preview = args.preview_dir
    save_png(masked_preview(icon), preview / "ios-rounded-preview.png")
    inset = (LAYER_DP - VIEWPORT_DP) * EXPORT_SCALE // 2
    viewport = adaptive.crop((inset, inset, adaptive.width - inset, adaptive.height - inset))
    save_png(masked_preview(viewport, circle=True), preview / "android-circle-preview.png")
    save_png(masked_preview(viewport), preview / "android-rounded-preview.png")
    paper = Image.new("RGBA", (336, 370), PAPER)
    paper.alpha_composite(splash_image(splash, 2))
    save_png(paper, preview / "splash-preview.png")
    after = {str(path.relative_to(ROOT)): digest(path) for path in (MASTER, SPLASH_MASTER)}
    if after != before:
        raise RuntimeError("A bitmap master changed during export.")
    report = {"mastersSha256": after, "iosSlots": len(manifest["images"]),
              "androidLayerDp": LAYER_DP, "androidArtworkDp": ART_DP,
              "androidArtworkYShiftDp": ART_Y_SHIFT_DP,
              "androidMaskedViewportDp": VIEWPORT_DP, "androidCriticalSafeCircleDp": 66,
              "maskPreviewsAreApproximations": True, "masterPixelsCreativelyEdited": False}
    (preview / "export.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"Exported {len(manifest['images'])} iOS slots, Android bitmap launcher/splashes; previews: {preview}")


if __name__ == "__main__":
    main()
