#!/usr/bin/env python3

from pathlib import Path
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/site/public/images/homepage_social.png"
LOGO = ROOT / "docs/site/public/images/whatchord_logo.webp"
FONT = ROOT / "assets/fonts/InterVariable.ttf"
SCREENSHOT = ROOT / "docs/site/public/images/theme_modes.webp"

WIDTH = 1200
HEIGHT = 630


def font(size: int, weight: int) -> ImageFont.FreeTypeFont:
    output = Path(tempfile.gettempdir()) / f"Inter-{weight}.ttf"
    if not output.exists():
        subprocess.run(
            [
                str(ROOT / ".venv/bin/fonttools"),
                "varLib.instancer",
                str(FONT),
                f"wght={weight}",
                f"--output={output}",
            ],
            check=True,
            capture_output=True,
        )
    return ImageFont.truetype(output, size=size)


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *size), radius=radius, fill=255)
    return mask


def main() -> None:
    image = Image.new("RGB", (WIDTH, HEIGHT), "#0d0d13")
    pixels = image.load()

    # Subtle blue light behind the product image.
    for y in range(HEIGHT):
        for x in range(WIDTH):
            dx = (x - 930) / 570
            dy = (y - 300) / 430
            strength = max(0, 1 - (dx * dx + dy * dy)) ** 2
            pixels[x, y] = (
                int(13 + 10 * strength),
                int(13 + 27 * strength),
                int(19 + 58 * strength),
            )

    draw = ImageDraw.Draw(image)

    logo = Image.open(LOGO).convert("RGBA").resize((90, 90), Image.Resampling.LANCZOS)
    image.paste(logo, (70, 44), logo)

    word_y = 64
    what_font = font(49, 350)
    chord_font = font(49, 600)
    draw.text((176, word_y), "What", font=what_font, fill="#eaeaf2")
    what_width = draw.textlength("What", font=what_font)
    draw.text((176 + what_width, word_y), "Chord", font=chord_font, fill="#eaeaf2")

    headline = font(55, 400)
    draw.text((70, 205), "Identify chords.", font=headline, fill="#ffffff")
    draw.text((70, 271), "Understand harmony.", font=headline, fill="#ffffff")

    body = font(24, 400)
    draw.text((72, 375), "Live MIDI and manual note entry.", font=body, fill="#9494ae")
    draw.text(
        (72, 411), "Explore voicings, scales, and context.", font=body, fill="#9494ae"
    )

    screenshot = Image.open(SCREENSHOT).convert("RGB")
    crop = screenshot.crop((0, 0, 2868, 1320))
    card_size = (720, 331)
    crop = crop.resize(card_size, Image.Resampling.LANCZOS)
    mask = rounded_mask(card_size, 23)
    card = Image.new("RGBA", (744, 355))
    card_draw = ImageDraw.Draw(card)
    card_draw.rounded_rectangle(
        (0, 0, 743, 354), radius=29, fill="#181822", outline="#49699f", width=3
    )
    card.paste(crop, (12, 12), mask)
    rotated = card.rotate(-10, resample=Image.Resampling.BICUBIC, expand=True)

    shadow = Image.new("RGBA", rotated.size)
    shadow_alpha = rotated.getchannel("A").filter(ImageFilter.GaussianBlur(30))
    shadow.putalpha(shadow_alpha.point(lambda value: int(value * 0.7)))
    image.paste(shadow, (600, 210), shadow)
    image.paste(rotated, (600, 180), rotated)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUTPUT, "PNG", optimize=True)


if __name__ == "__main__":
    main()
