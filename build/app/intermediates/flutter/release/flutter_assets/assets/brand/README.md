# FinGenius AI Brand Assets

Master vector: `fingenius_mark.svg` ("Orbit G" — see `docs/logo_concepts.md` for rationale and scoring).

## Files

| File | Use |
|---|---|
| `fingenius_mark.svg` | Gradient mark, transparent background (dark surfaces) |
| `fingenius_mark_dark.svg` | Mark on navy tile (app splash, previews) |
| `fingenius_mark_light.svg` | Navy mark for light surfaces |
| `fingenius_mark_monochrome.svg` | Single-colour (`currentColor`) for notification icon, themed icon, print |
| `fingenius_wordmark.svg` | Wordmark only |
| `fingenius_lockup_horizontal.svg` | Mark + wordmark, horizontal |
| `fingenius_lockup_stacked.svg` | Mark above wordmark + tagline |
| `brand_preview.svg` | All approved colour combinations |

## Usage rules

- Clear space: half the ring diameter on all sides.
- Minimum size: 16 dp (mono), 24 dp (colour), 96 dp (lockups).
- Approved combinations: gradient-on-navy, white-mono-on-navy, navy-on-white, single-colour mono anywhere contrast ≥ 4.5:1.
- Prohibited: rotation, shadows, outlines, recolouring, gradient mark on mid-grey, text inside the app icon, stretching.
- Wordmark uses Manrope (SIL OFL 1.1). For print/final exports, convert text to outlines with Manrope installed.

## Rendering PNG assets

Repeatable pipeline (documented, not manual copies):

```bash
tool/render_brand_assets.sh   # requires ImageMagick or rsvg-convert
```

Outputs: Play Store 512×512 (`dist/play_store_icon_512.png`), legacy launcher mipmaps, splash PNG. Adaptive launcher foreground/background/monochrome are **vector drawables** under `android/app/src/main/res/drawable*/` — no rasterisation required on API 26+. All critical artwork sits inside the adaptive-icon 66 dp safe circle (ring occupies the central 61%).
