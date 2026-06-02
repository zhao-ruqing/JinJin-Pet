from __future__ import annotations

import json
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parent
OUT = ROOT / "pet-build"
FRAMES = OUT / "frames"
QA = OUT / "qa"
FINAL = OUT / "final"

CELL_W = 192
CELL_H = 208
COLS = 8
ROWS = 9

ROW_SPECS = [
    ("idle", 6),
    ("running-right", 8),
    ("running-left", 8),
    ("waving", 4),
    ("jumping", 5),
    ("failed", 8),
    ("waiting", 6),
    ("running", 6),
    ("review", 6),
]

STATE_SOURCES = {
    "idle": "idle.png",
    "running-right": "avatar.png",
    "running-left": "avatar.png",
    "waving": "happy-wave.png",
    "jumping": "surprised.png",
    "failed": "sleepy.png",
    "waiting": "surprised.png",
    "running": "coding.png",
    "review": "thinking.png",
}

SOURCE_ALIASES = {
    "happy-wave": "waving",
    "coding": "running",
    "thinking": "review",
}

CUTOUT_PREVIEW_DIR = OUT / "cutouts"

OFFSETS = {
    "idle": [(0, 2), (0, 1), (0, 0), (0, 1), (0, 2), (0, 1)],
    "running-right": [(-10, 2), (-6, 0), (-2, 2), (2, 0), (6, 2), (10, 0), (6, 2), (2, 1)],
    "running-left": [(10, 2), (6, 0), (2, 2), (-2, 0), (-6, 2), (-10, 0), (-6, 2), (-2, 1)],
    "waving": [(0, 1), (0, -2), (0, 0), (0, -2)],
    "jumping": [(0, 10), (0, -10), (0, -18), (0, -8), (0, 8)],
    "failed": [(0, 5), (0, 6), (0, 5), (0, 7), (0, 5), (0, 6), (0, 5), (0, 6)],
    "waiting": [(-2, 1), (0, 0), (2, 1), (2, 0), (0, 1), (-2, 0)],
    "running": [(0, 1), (1, 0), (0, 1), (-1, 0), (0, 1), (1, 0)],
    "review": [(-1, 1), (0, 0), (1, 1), (0, 0), (-1, 1), (0, 0)],
}


def ensure_dirs() -> None:
    for path in (OUT, FRAMES, QA, FINAL, CUTOUT_PREVIEW_DIR):
        path.mkdir(parents=True, exist_ok=True)
    for state, _ in ROW_SPECS:
        (FRAMES / state).mkdir(parents=True, exist_ok=True)
        for old in (FRAMES / state).glob("*.png"):
            old.unlink()
    for old in CUTOUT_PREVIEW_DIR.glob("*.png"):
        old.unlink()


def border_key_alpha(rgb: Image.Image, solid_threshold: float | None = None, fade_threshold: float | None = None) -> Image.Image:
    width, height = rgb.size
    px = rgb.load()
    border_samples = []
    step = max(1, min(width, height) // 80)
    for x in range(0, width, step):
        border_samples.extend([px[x, 0], px[x, height - 1]])
    for y in range(0, height, step):
        border_samples.extend([px[0, y], px[width - 1, y]])
    key = tuple(int(sum(c[i] for c in border_samples) / len(border_samples)) for i in range(3))
    key_luma = sum(key) / 3
    if solid_threshold is None:
        solid_threshold = 18.0 if key_luma < 32 else 26.0
    if fade_threshold is None:
        fade_threshold = 58.0 if key_luma < 32 else 92.0

    arr = np.asarray(rgb, dtype=np.float32)
    dist = np.sqrt(np.sum((arr - np.array(key, dtype=np.float32)) ** 2, axis=2))
    visited = bytearray(width * height)
    connected = np.zeros((height, width), dtype=bool)
    queue: deque[tuple[int, int]] = deque()

    def push(x: int, y: int) -> None:
        idx = y * width + x
        if visited[idx]:
            return
        visited[idx] = 1
        if dist[y, x] <= fade_threshold:
            queue.append((x, y))

    for x in range(width):
        push(x, 0)
        push(x, height - 1)
    for y in range(height):
        push(0, y)
        push(width - 1, y)

    while queue:
        x, y = queue.popleft()
        connected[y, x] = True
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < width and 0 <= ny < height:
                push(nx, ny)

    alpha = np.full((height, width), 255, dtype=np.float32)
    edge = connected & (dist > solid_threshold)
    alpha[connected & (dist <= solid_threshold)] = 0
    alpha[edge] = np.clip(
        ((dist[edge] - solid_threshold) / (fade_threshold - solid_threshold)) * 255,
        0,
        255,
    )
    alpha_img = Image.fromarray(alpha.astype(np.uint8), "L")
    alpha_img = alpha_img.filter(ImageFilter.MinFilter(3))
    alpha_img = alpha_img.filter(ImageFilter.GaussianBlur(0.7))
    return alpha_img.point(lambda value: 0 if value < 10 else (255 if value > 244 else value))


def cutout(path: Path, mirror: bool = False, save_preview: bool = True) -> Image.Image:
    opened = Image.open(path)
    if "A" in opened.getbands():
        rgba = opened.convert("RGBA")
        mask = rgba.getchannel("A")
    else:
        src = opened.convert("RGB")
        mask = border_key_alpha(src)
        rgba = src.convert("RGBA")
        rgba.putalpha(mask)
        rgba = despill_background(rgba, src)
    bbox = mask.getbbox()
    if bbox:
        pad = 4
        bbox = (
            max(0, bbox[0] - pad),
            max(0, bbox[1] - pad),
            min(rgba.width, bbox[2] + pad),
            min(rgba.height, bbox[3] + pad),
        )
        rgba = rgba.crop(bbox)
    if mirror:
        rgba = rgba.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    if save_preview:
        preview_name = path.stem + ("-left" if mirror else "") + ".png"
        rgba.save(CUTOUT_PREVIEW_DIR / preview_name)
    return rgba


def despill_background(rgba: Image.Image, rgb: Image.Image) -> Image.Image:
    arr = np.asarray(rgba, dtype=np.float32).copy()
    bg = np.asarray(rgb, dtype=np.float32)
    alpha = arr[:, :, 3] / 255.0
    border = np.concatenate([bg[0, :, :], bg[-1, :, :], bg[:, 0, :], bg[:, -1, :]], axis=0)
    key = np.mean(border, axis=0)
    fringe = (alpha > 0) & (alpha < 0.92)
    if np.any(fringe):
        strength = ((0.92 - alpha[fringe]) / 0.92)[:, None] * 0.62
        arr[:, :, :3][fringe] = np.clip((arr[:, :, :3][fringe] - key * strength) / (1 - strength), 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def fit_cell(sprite: Image.Image, dx: int = 0, dy: int = 0, scale: float = 1.0) -> Image.Image:
    canvas = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
    fitted = sprite.copy()
    max_w, max_h = 142, 186
    ratio = min(max_w / fitted.width, max_h / fitted.height) * scale
    fitted = fitted.resize((max(1, int(fitted.width * ratio)), max(1, int(fitted.height * ratio))), Image.Resampling.LANCZOS)
    left = (CELL_W - fitted.width) // 2 + dx
    top = CELL_H - fitted.height - 9 + dy
    canvas.alpha_composite(fitted, (left, top))
    return canvas


def save_frames() -> None:
    for state, count in ROW_SPECS:
        source = ROOT / STATE_SOURCES[state]
        sprite = cutout(source, mirror=state == "running-left")
        offsets = OFFSETS[state]
        for index in range(count):
            dx, dy = offsets[index]
            scale = 1.0
            if state in {"running-right", "running-left"} and index % 2:
                scale = 0.985
            frame = fit_cell(sprite, dx, dy, scale)
            frame.save(FRAMES / state / f"{index:02d}.png")
    for alias, target in SOURCE_ALIASES.items():
        alias_dir = FRAMES / alias
        alias_dir.mkdir(parents=True, exist_ok=True)
        for old in alias_dir.glob("*.png"):
            old.unlink()
        for source_frame in sorted((FRAMES / target).glob("*.png")):
            Image.open(source_frame).save(alias_dir / source_frame.name)


def compose_atlas() -> Image.Image:
    atlas = Image.new("RGBA", (CELL_W * COLS, CELL_H * ROWS), (0, 0, 0, 0))
    for row, (state, count) in enumerate(ROW_SPECS):
        for col in range(count):
            frame = Image.open(FRAMES / state / f"{col:02d}.png").convert("RGBA")
            atlas.alpha_composite(frame, (col * CELL_W, row * CELL_H))
    return normalize_transparent_rgb(atlas)


def normalize_transparent_rgb(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            if pixels[x, y][3] == 0:
                pixels[x, y] = (0, 0, 0, 0)
    return rgba


def make_contact_sheet(atlas: Image.Image) -> None:
    scale = 0.5
    cell_w = int(CELL_W * scale)
    cell_h = int(CELL_H * scale)
    label_w = 132
    sheet = Image.new("RGBA", (label_w + cell_w * COLS, cell_h * ROWS), (255, 255, 255, 255))
    draw = ImageDraw.Draw(sheet)
    for row, (state, count) in enumerate(ROW_SPECS):
        draw.text((8, row * cell_h + 8), state, fill=(0, 0, 0, 255))
        for col in range(COLS):
            tile = atlas.crop((col * CELL_W, row * CELL_H, (col + 1) * CELL_W, (row + 1) * CELL_H))
            tile = tile.resize((cell_w, cell_h), Image.Resampling.LANCZOS)
            x = label_w + col * cell_w
            y = row * cell_h
            bg = Image.new("RGBA", (cell_w, cell_h), (244, 244, 244, 255) if (row + col) % 2 else (255, 255, 255, 255))
            bg.alpha_composite(tile)
            sheet.alpha_composite(bg, (x, y))
            draw.rectangle((x, y, x + cell_w - 1, y + cell_h - 1), outline=(210, 210, 210, 255))
            if col >= count:
                draw.line((x, y, x + cell_w, y + cell_h), fill=(230, 230, 230, 255))
    sheet.convert("RGB").save(QA / "contact-sheet.png")


def validate(atlas: Image.Image) -> dict:
    errors: list[str] = []
    if atlas.size != (1536, 1872):
        errors.append(f"atlas size is {atlas.size}, expected (1536, 1872)")
    alpha = atlas.getchannel("A")
    for row, (state, count) in enumerate(ROW_SPECS):
        for col in range(COLS):
            tile_alpha = alpha.crop((col * CELL_W, row * CELL_H, (col + 1) * CELL_W, (row + 1) * CELL_H))
            occupied = tile_alpha.getbbox() is not None
            if col < count and not occupied:
                errors.append(f"{state} frame {col} is empty")
            if col >= count and occupied:
                errors.append(f"{state} unused frame {col} is not transparent")
    return {"ok": not errors, "errors": errors, "size": list(atlas.size)}


def write_manifest(validation: dict) -> None:
    pet_json = {
        "id": "custom-codex-pet",
        "displayName": "Custom Codex Pet",
        "description": "A chibi coding companion built from the supplied avatar images.",
        "spritesheetPath": "spritesheet.png",
    }
    (ROOT / "pet.json").write_text(json.dumps(pet_json, indent=2), encoding="utf-8")
    (FINAL / "validation.json").write_text(json.dumps(validation, indent=2), encoding="utf-8")
    summary = {
        "ok": validation["ok"],
        "package": str(ROOT),
        "spritesheet": str(ROOT / "spritesheet.png"),
        "contact_sheet": str(QA / "contact-sheet.png"),
        "validation": str(FINAL / "validation.json"),
    }
    (QA / "run-summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")


def main() -> None:
    ensure_dirs()
    save_frames()
    atlas = compose_atlas()
    atlas.save(FINAL / "spritesheet.png")
    atlas.save(FINAL / "spritesheet.webp", lossless=True, method=6)
    atlas.save(ROOT / "spritesheet.png")
    atlas.save(ROOT / "spritesheet.webp", lossless=True, method=6)
    make_contact_sheet(atlas)
    validation = validate(atlas)
    write_manifest(validation)
    if not validation["ok"]:
        raise SystemExit(json.dumps(validation, indent=2))


if __name__ == "__main__":
    main()
