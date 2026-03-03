''' Contains the core business logic, including PIL image generation, font
    rendering, and packing the data into a format suitable for the TI-84 CE.
    This file does not import any other file in this project to prevent
    circular dependencies. It is imported by both the UI modules and the
    core module.
'''

import json
from pathlib import Path
from typing import Optional, List, Callable, Dict, Tuple

from PIL import Image, ImageFont, ImageDraw


ALIASING_MODES = [
    "Direct 1-Bit",
    "Hinted 1-Bit",
    "Downsampling",
    "Thresholding",
]

OUTPUT_TARGETS = [
    "Standalone (8xp)",
    "Viewer Only (8xv)",
    "Standalone (C)",
    "Viewer Only (C)",
]

VARIANT_LIMITS = {
    "large": (12, 14),
    "small": (16, 12),
}


class FontData(object):
    def __init__(
        self,
        encoding_name: str,
        encoding_map: Dict[str, str],
        large_path: str,
        large_name: str,
        large_size: int,
        large_aliasing: str,
        small_path: str,
        small_name: str,
        small_size: int,
        small_aliasing: str,
    ):
        self.encoding_name = encoding_name
        self.encoding_map = encoding_map
        self.variant_settings = {
            "large": {
                "font_path": large_path,
                "font_name": large_name,
                "size": int(large_size),
                "aliasing": large_aliasing,
            },
            "small": {
                "font_path": small_path,
                "font_name": small_name,
                "size": int(small_size),
                "aliasing": small_aliasing,
            },
        }

        self.base_images: Dict[str, Dict[int, Image.Image]] = {
            "large": {},
            "small": {},
        }
        self._grid_cache: Dict[Tuple[str, Tuple[Tuple[int, Tuple[int, int]], ...]], Image.Image] = {}
        self._generate_base_images()

    @staticmethod
    def identity_key(
        encoding_name: str,
        large_path: str,
        large_name: str,
        large_size: int,
        large_aliasing: str,
        small_path: str,
        small_name: str,
        small_size: int,
        small_aliasing: str,
    ) -> Tuple:
        return (
            encoding_name,
            str(Path(large_path)),
            large_name,
            int(large_size),
            large_aliasing,
            str(Path(small_path)),
            small_name,
            int(small_size),
            small_aliasing,
        )

    def get_variant_metrics(self, variant: str) -> Dict[str, int]:
        glyph_w, glyph_h = VARIANT_LIMITS[variant]
        stride_x = glyph_w + 1
        stride_y = glyph_h + 1
        return {
            "glyph_w": glyph_w,
            "glyph_h": glyph_h,
            "stride_x": stride_x,
            "stride_y": stride_y,
            "grid_w": 16 * stride_x + 1,
            "grid_h": 16 * stride_y + 1,
        }

    def get_glyph_rect_in_grid(self, codepoint: int, variant: str) -> Tuple[int, int, int, int]:
        metrics = self.get_variant_metrics(variant)
        row = max(0, min(15, codepoint // 16))
        col = max(0, min(15, codepoint % 16))
        x = col * metrics["stride_x"] + 1
        y = row * metrics["stride_y"] + 1
        return (x, y, metrics["glyph_w"], metrics["glyph_h"])

    def get_nudged_glyph_image(
        self,
        variant: str,
        codepoint: int,
        nudge: Tuple[int, int] = (0, 0),
    ) -> Image.Image:
        glyph_w, glyph_h = VARIANT_LIMITS[variant]
        out = Image.new("1", (glyph_w, glyph_h), 0)
        base = self.base_images[variant].get(codepoint)
        if base is None:
            return out

        dx, dy = int(nudge[0]), int(nudge[1])
        out.paste(base, (dx, dy))
        return out

    def get_grid_image(self, variant: str, nudging: Dict[int, Tuple[int, int]]) -> Image.Image:
        cache_key = (variant, tuple(sorted((int(k), (int(v[0]), int(v[1]))) for k, v in nudging.items())))
        if cache_key in self._grid_cache:
            return self._grid_cache[cache_key]

        metrics = self.get_variant_metrics(variant)
        grid = Image.new("L", (metrics["grid_w"], metrics["grid_h"]), 130)

        for codepoint in range(256):
            x, y, w, h = self.get_glyph_rect_in_grid(codepoint, variant)
            cell = Image.new("L", (w, h), 0)
            base = self.base_images[variant].get(codepoint)
            if base is not None:
                dx, dy = nudging.get(codepoint, (0, 0))
                cell.paste(base.convert("L"), (int(dx), int(dy)))
            grid.paste(cell, (x, y))

        self._grid_cache[cache_key] = grid
        return grid

    def clear_grid_cache(self):
        self._grid_cache.clear()

    def _generate_base_images(self):
        for variant in ("large", "small"):
            glyph_w, glyph_h = VARIANT_LIMITS[variant]
            settings = self.variant_settings[variant]
            font_path = Path(settings["font_path"]) / settings["font_name"]

            for codepoint in range(256):
                code_key = f"0x{codepoint:02X}"
                char = self.encoding_map.get(code_key)
                if char is None:
                    continue
                self.base_images[variant][codepoint] = self._render_glyph(
                    char=char,
                    font_file=font_path,
                    font_size=int(settings["size"]),
                    glyph_w=glyph_w,
                    glyph_h=glyph_h,
                    aliasing=str(settings["aliasing"]),
                )

    def _load_font(self, font_file: Path, size: int) -> ImageFont.ImageFont:
        if font_file.exists():
            try:
                return ImageFont.truetype(str(font_file), size=max(1, int(size)))
            except OSError:
                pass
        return ImageFont.load_default()

    def _render_mask(
        self,
        char: str,
        font: ImageFont.ImageFont,
        render_w: int,
        render_h: int,
    ) -> Image.Image:
        temp = Image.new("L", (render_w, render_h), 0)
        draw = ImageDraw.Draw(temp)
        draw.text((2, 2), char, font=font, fill=255)
        bbox = temp.getbbox()
        if bbox is None:
            return Image.new("L", (1, 1), 0)
        return temp.crop(bbox)

    def _render_glyph(
        self,
        char: str,
        font_file: Path,
        font_size: int,
        glyph_w: int,
        glyph_h: int,
        aliasing: str,
    ) -> Image.Image:
        if aliasing == "Downsampling":
            scale = 4
            hi_font = self._load_font(font_file, max(1, font_size * scale))
            hi_mask = self._render_mask(char, hi_font, glyph_w * 8 * scale, glyph_h * 8 * scale)
            mask = hi_mask.resize((max(1, hi_mask.width // scale), max(1, hi_mask.height // scale)), Image.Resampling.LANCZOS)
        else:
            base_font = self._load_font(font_file, font_size)
            mask = self._render_mask(char, base_font, glyph_w * 8, glyph_h * 8)

        out_l = Image.new("L", (glyph_w, glyph_h), 0)

        src_w = min(mask.width, glyph_w)
        src_h = min(mask.height, glyph_h)
        if src_w > 0 and src_h > 0:
            y = max(0, (glyph_h - src_h) // 2)
            cropped = mask.crop((0, 0, src_w, src_h))
            out_l.paste(cropped, (0, y))

        threshold = 128
        if aliasing == "Thresholding":
            threshold = 170
        out_1 = out_l.point(lambda v: 255 if v >= threshold else 0, mode="1")
        return out_1


class AppState(object):
    def __init__(self, notify_on_change: Optional[List[Callable]] = None):
        self._callbacks: List[Callable] = list(notify_on_change or [])
        self.root_dir = Path(__file__).resolve().parents[1]
        self.projects_dir = self.root_dir / "projects"
        self.projects_dir.mkdir(parents=True, exist_ok=True)

        self.encodings = self._load_encodings()
        self.encoding_name = next(iter(self.encodings.keys()))

        self.project_name = "UNTITLED"
        self.project_path = self.projects_dir / f"{self.project_name}.cefont"

        self.view_variant = "large"
        self.variants = {
            "large": {
                "font_path": str((self.root_dir / ".." / "fonts").resolve()),
                "font_name": "OpenSans.ttf",
                "size": 12,
                "aliasing": "Direct 1-Bit",
                "nudging": {},
            },
            "small": {
                "font_path": str((self.root_dir / ".." / "fonts").resolve()),
                "font_name": "OpenSans.ttf",
                "size": 11,
                "aliasing": "Direct 1-Bit",
                "nudging": {},
            },
        }

        self.selected_glyph = 0
        self.output_target = OUTPUT_TARGETS[0]
        self.output_basename = "UNTITLED"
        self.canvas_transform = {
            "scale": 1,
            "pan_x": 0,
            "pan_y": 0,
        }

        self.current_font_data: Optional[FontData] = None
        self.current_font_data_key: Optional[Tuple] = None
        self.cached_font_data: Dict[Tuple, FontData] = {}
        self.font_data_refresh_source = "new"
        self.font_data_generation = 0
        self.refresh_font_data(force=True)

    def add_callback(self, callback: Callable):
        self._callbacks.append(callback)

    def _notify(self):
        for callback in self._callbacks:
            callback(self)

    def _load_encodings(self) -> Dict[str, Dict[str, str]]:
        encodings_path = Path(__file__).with_name("encodings.json")
        with encodings_path.open("r", encoding="utf-8") as handle:
            return json.load(handle)

    def get_encoding_names(self) -> List[str]:
        return list(self.encodings.keys())

    def _font_data_key(self) -> Tuple:
        large = self.variants["large"]
        small = self.variants["small"]
        return FontData.identity_key(
            self.encoding_name,
            large["font_path"],
            large["font_name"],
            int(large["size"]),
            large["aliasing"],
            small["font_path"],
            small["font_name"],
            int(small["size"]),
            small["aliasing"],
        )

    def refresh_font_data(self, force: bool = False):
        key = self._font_data_key()

        if self.current_font_data is not None and self.current_font_data_key is not None:
            self.cached_font_data[self.current_font_data_key] = self.current_font_data

        if (not force) and key in self.cached_font_data:
            self.current_font_data = self.cached_font_data[key]
            self.font_data_refresh_source = "cache-hit"
        else:
            large = self.variants["large"]
            small = self.variants["small"]
            self.current_font_data = FontData(
                encoding_name=self.encoding_name,
                encoding_map=self.encodings[self.encoding_name],
                large_path=large["font_path"],
                large_name=large["font_name"],
                large_size=int(large["size"]),
                large_aliasing=large["aliasing"],
                small_path=small["font_path"],
                small_name=small["font_name"],
                small_size=int(small["size"]),
                small_aliasing=small["aliasing"],
            )
            self.cached_font_data[key] = self.current_font_data
            self.font_data_refresh_source = "new"
            self.font_data_generation += 1

        self.current_font_data_key = key

    def get_font_data_debug_text(self) -> str:
        key = self.current_font_data_key
        if key is None:
            return "FontData: none"

        short_key = (
            f"\nenc={key[0]}\n "
            f"L={key[2]}:{key[3]}:{key[4]}\n"
            f"S={key[6]}:{key[7]}:{key[8]}\n"
        )
        return (
            f"FontData [{self.font_data_refresh_source}]\n"
            f"gen={self.font_data_generation} {short_key}"
        )

    def set_encoding(self, encoding_name: str):
        if encoding_name not in self.encodings or encoding_name == self.encoding_name:
            return
        self.encoding_name = encoding_name
        self.refresh_font_data()
        self._notify()

    def set_view_variant(self, variant: str):
        if variant not in ("large", "small"):
            return
        if self.view_variant == variant:
            return
        self.view_variant = variant
        self._notify()

    def set_variant_font_path(self, variant: str, font_path: str):
        if self.variants[variant]["font_path"] == font_path:
            return
        self.variants[variant]["font_path"] = font_path
        self.refresh_font_data()
        self._notify()

    def set_variant_font_name(self, variant: str, font_name: str):
        if self.variants[variant]["font_name"] == font_name:
            return
        self.variants[variant]["font_name"] = font_name
        self.refresh_font_data()
        self._notify()

    def set_variant_font_size(self, variant: str, size: int):
        size = max(1, int(size))
        if int(self.variants[variant]["size"]) == size:
            return
        self.variants[variant]["size"] = size
        self.refresh_font_data()
        self._notify()

    def set_variant_aliasing(self, variant: str, aliasing: str):
        if aliasing not in ALIASING_MODES:
            return
        if self.variants[variant]["aliasing"] == aliasing:
            return
        self.variants[variant]["aliasing"] = aliasing
        self.refresh_font_data()
        self._notify()

    def get_variant_nudging(self, variant: str) -> Dict[int, Tuple[int, int]]:
        return self.variants[variant]["nudging"]

    def set_nudge(self, variant: str, codepoint: int, dx: int, dy: int):
        codepoint = int(codepoint)
        dx = int(dx)
        dy = int(dy)
        if dx == 0 and dy == 0:
            self.variants[variant]["nudging"].pop(codepoint, None)
        else:
            self.variants[variant]["nudging"][codepoint] = (dx, dy)
        if self.current_font_data is not None:
            self.current_font_data.clear_grid_cache()
        self._notify()

    def nudge_selected_glyph(self, dx: int, dy: int):
        variant = self.view_variant
        codepoint = int(self.selected_glyph)
        current_dx, current_dy = self.variants[variant]["nudging"].get(codepoint, (0, 0))
        self.set_nudge(variant, codepoint, current_dx + int(dx), current_dy + int(dy))

    def reset_variant_nudging(self, variant: str):
        if variant not in ("large", "small"):
            return
        self.variants[variant]["nudging"] = {}
        if self.current_font_data is not None:
            self.current_font_data.clear_grid_cache()
        self._notify()

    def set_selected_glyph(self, codepoint: int):
        codepoint = max(0, min(255, int(codepoint)))
        if self.selected_glyph == codepoint:
            return
        self.selected_glyph = codepoint
        self._notify()

    def set_output_target(self, output_target: str):
        if output_target not in OUTPUT_TARGETS or output_target == self.output_target:
            return
        self.output_target = output_target
        self._notify()

    def set_output_basename(self, basename: str):
        sanitized = "".join(ch for ch in basename if ch.isalnum() or ch == "_")[:8]
        if not sanitized:
            sanitized = "UNTITLED"
        if sanitized == self.output_basename:
            return
        self.output_basename = sanitized
        self._notify()

    def set_canvas_transform(self, scale: Optional[int] = None, pan_x: Optional[int] = None, pan_y: Optional[int] = None):
        if scale is not None:
            self.canvas_transform["scale"] = max(1, min(8, int(scale)))
        if pan_x is not None:
            self.canvas_transform["pan_x"] = int(pan_x)
        if pan_y is not None:
            self.canvas_transform["pan_y"] = int(pan_y)
        self._notify()

    def set_project_path(self, project_path: str):
        path = Path(project_path)
        if path.suffix.lower() != ".cefont":
            path = path.with_suffix(".cefont")
        self.project_path = path
        self.project_name = path.stem or "UNTITLED"
        self._notify()

    def to_project_data(self) -> Dict:
        return {
            "project_path": str(self.project_path),
            "project_name": self.project_name,
            "encoding_name": self.encoding_name,
            "view_variant": self.view_variant,
            "selected_glyph": self.selected_glyph,
            "output_target": self.output_target,
            "output_basename": self.output_basename,
            "canvas_transform": dict(self.canvas_transform),
            "variants": {
                "large": {
                    "font_path": self.variants["large"]["font_path"],
                    "font_name": self.variants["large"]["font_name"],
                    "size": int(self.variants["large"]["size"]),
                    "aliasing": self.variants["large"]["aliasing"],
                    "nudging": {
                        f"0x{codepoint:02X}": [int(delta[0]), int(delta[1])]
                        for codepoint, delta in self.variants["large"]["nudging"].items()
                    },
                },
                "small": {
                    "font_path": self.variants["small"]["font_path"],
                    "font_name": self.variants["small"]["font_name"],
                    "size": int(self.variants["small"]["size"]),
                    "aliasing": self.variants["small"]["aliasing"],
                    "nudging": {
                        f"0x{codepoint:02X}": [int(delta[0]), int(delta[1])]
                        for codepoint, delta in self.variants["small"]["nudging"].items()
                    },
                },
            },
        }

    def load_project_data(self, project_data: Dict):
        project_path = project_data.get("project_path") or str(self.project_path)
        self.set_project_path(project_path)

        encoding_name = project_data.get("encoding_name", self.encoding_name)
        if encoding_name in self.encodings:
            self.encoding_name = encoding_name

        self.view_variant = project_data.get("view_variant", self.view_variant)
        self.selected_glyph = max(0, min(255, int(project_data.get("selected_glyph", 0))))
        self.output_target = project_data.get("output_target", self.output_target)
        self.output_basename = project_data.get("output_basename", self.output_basename)

        transform = project_data.get("canvas_transform", {})
        self.canvas_transform["scale"] = max(1, min(8, int(transform.get("scale", 1))))
        self.canvas_transform["pan_x"] = int(transform.get("pan_x", 0))
        self.canvas_transform["pan_y"] = int(transform.get("pan_y", 0))

        variants = project_data.get("variants", {})
        for variant_name in ("large", "small"):
            variant_data = variants.get(variant_name, {})
            target = self.variants[variant_name]
            target["font_path"] = variant_data.get("font_path", target["font_path"])
            target["font_name"] = variant_data.get("font_name", target["font_name"])
            target["size"] = int(variant_data.get("size", target["size"]))
            alias = variant_data.get("aliasing", target["aliasing"])
            target["aliasing"] = alias if alias in ALIASING_MODES else target["aliasing"]

            nudging = {}
            for key, value in variant_data.get("nudging", {}).items():
                if isinstance(key, str) and key.startswith("0x"):
                    try:
                        codepoint = int(key, 16)
                    except ValueError:
                        continue
                else:
                    try:
                        codepoint = int(key)
                    except (TypeError, ValueError):
                        continue
                if isinstance(value, list) and len(value) == 2:
                    nudging[codepoint] = (int(value[0]), int(value[1]))
            target["nudging"] = nudging

        self.refresh_font_data(force=True)
        self._notify()

    def save_project_file(self, project_path: Optional[str] = None):
        if project_path is not None:
            self.set_project_path(project_path)

        self.project_path.parent.mkdir(parents=True, exist_ok=True)
        with self.project_path.open("w", encoding="utf-8") as handle:
            json.dump(self.to_project_data(), handle, indent=4, ensure_ascii=False)
            handle.write("\n")

    def load_project_file(self, project_path: str):
        path = Path(project_path)
        with path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
        self.load_project_data(data)
