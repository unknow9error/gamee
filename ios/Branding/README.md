# Native Fini branding

Run from the repository root with Python 3 and Pillow:

```sh
python3 ios/Branding/generate_icons.py
```

The script performs native asset packaging only. It never invokes Flutter,
Xcode, Gradle or device tools. The approved ImageGen masters remain unchanged:

- `assets/branding/fini-launcher-master.png`: opaque square launcher portrait.
- `assets/images/fini.png`: existing transparent full-body Fini for launch screens.

The existing `AppIcon` asset name and all 19 iOS catalog entries are preserved
(15 unique PNG filenames; some phone/tablet sizes share a file).
Each slot receives an exact-size, opaque RGB/sRGB PNG. Corners remain square;
iOS applies its own mask. There are no invented dark/tinted images or references
to missing appearance assets.

Android legacy mipmaps use the full square master. Android 26+ follows
`mipmap-anydpi-v26/ic_launcher.xml` → `drawable/fox_foreground.xml` →
`drawable-nodpi/fini_launcher_foreground.png`. The old geometric vector is gone.
The 108 dp adaptive canvas contains a 62 dp portrait, centered horizontally and
shifted 5 dp downward so its already-cropped bust ends at the masked viewport
bottom. Existing edge pixels extend into the padding; the character is not
redrawn, recolored or cut out. The approved portrait's ear-tip anchors fit within
the 66 dp safe circle.
Review the masks again if the approved master/framing changes.

Android 31+ splash uses that same bitmap alias. Earlier Android launch screens
use `fox_mark.xml` → `fini_splash_mark.png`; iOS uses the three `LaunchImage`
scales. Both full-body splash exports preserve the original transparency.

Previews and public export metadata are written to `output/qa/launcher-preview`.
The circle/rounded masks are inspection approximations, not replacement icon
assets. Inspect both ear tips and the gradient boundary before a native build.
The export report records master hashes and geometry; it contains no signing
or provider configuration.

Native builds and installation are separate steps. Update/install the normal
application with a new build number; changing Flutter's mascot alone does not
replace a native launcher icon. Do not change bundle identifiers or erase app
data to refresh branding.

Format references: [Android adaptive icon layers](https://developer.android.com/reference/android/graphics/drawable/AdaptiveIconDrawable),
[Android icon design](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive),
[Apple app icon configuration](https://developer.apple.com/documentation/xcode/configuring-your-app-icon).
