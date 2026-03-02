''' Contains the core business logic, including PIL image generation, font
    rendering, and packing the data into a format suitable for the TI-84 CE.
    This file does not import any other file in this project to prevent
    circular dependencies. It is imported by both the UI modules and the 
    core module.
'''

import json
from pathlib import Path
from typing import Optional, List, Callable, Any, Dict

from PIL import Image, ImageFont, ImageDraw, ImageOps

class AppState(object):
    def __init__(self, notify_on_change: Optional[List[Callable]] = None):
        self.font_path = "../fonts/"
        self.font_name = "OpenSans.ttf"
        self.font_size_large = 12
        self.font_size_small = 12
        self.font_size = self.font_size_large
        self.encoding = "Alphanumeric characters only"
        self.small_font = False
        self.self_installing = True
        self.use_system_fonts = False
        self.calculator_filename = "FONT.8XP"
        self.debug_mode = True

        self._notify_on_change = list(notify_on_change or [])

    def _notify_change(self, field_name: str, old_value: Any, new_value: Any):
        if self.debug_mode:
            print(f"AppState change: {field_name} changed from {old_value} to {new_value}")
        if self._notify_on_change:
            for callback in self._notify_on_change:
                try:
                    callback(field_name, old_value, new_value, self)
                except TypeError:
                    callback()

    def subscribe(self, callback: Callable):
        if callback not in self._notify_on_change:
            self._notify_on_change.append(callback)

    def unsubscribe(self, callback: Callable):
        if callback in self._notify_on_change:
            self._notify_on_change.remove(callback)

    def set(self, field_name: str, value: Any) -> bool:
        if field_name == "font_size":
            return self.set_font_size(value)

        if field_name == "small_font":
            target_small_font = bool(value)
            if self.small_font == target_small_font:
                return False

            old_small_font = self.small_font
            self.small_font = target_small_font
            self._notify_change("small_font", old_small_font, target_small_font)

            target_size = self.font_size_small if self.small_font else self.font_size_large
            if self.font_size != target_size:
                old_font_size = self.font_size
                self.font_size = target_size
                self._notify_change("font_size", old_font_size, target_size)

            return True

        if not hasattr(self, field_name):
            raise AttributeError(f"Unknown AppState field: {field_name}")

        old_value = getattr(self, field_name)
        if old_value == value:
            return False

        setattr(self, field_name, value)
        self._notify_change(field_name, old_value, value)
        return True

    def set_font_size(self, value: Any) -> bool:
        size = int(value)
        if size < 1:
            size = 1

        if self.small_font:
            old_size = self.font_size_small
            if old_size == size:
                return False
            self.font_size_small = size
        else:
            old_size = self.font_size_large
            if old_size == size:
                return False
            self.font_size_large = size

        old_font_size = self.font_size
        self.font_size = size
        self._notify_change("font_size", old_font_size, size)
        return True

    def update(self, **kwargs: Any) -> bool:
        changed = False
        for key, value in kwargs.items():
            changed = self.set(key, value) or changed
        return changed

    def snapshot(self) -> Dict[str, Any]:
        return {
            "font_path": self.font_path,
            "font_name": self.font_name,
            "font_size": self.font_size,
            "font_size_large": self.font_size_large,
            "font_size_small": self.font_size_small,
            "encoding": self.encoding,
            "small_font": self.small_font,
            "self_installing": self.self_installing,
            "use_system_fonts": self.use_system_fonts,
            "calculator_filename": self.calculator_filename,
        }
    


class FontData(object):
    def __init__(
        self,
        font_path: str,
        font_name: str,
        font_size: int,
        encoding_name: str,
        small_font: bool,
        encodings_path: Optional[str] = None,
        nudge_settings: Optional[Dict[Any, Any]] = None,
    ):
        self.font_path = font_path  #Path to the folder containing the font file.
        self.font_name = font_name  #Filename of the font file.
        self.font_size = font_size  #Size of the input font. This is adjustable because there is no guarantee that any particular input will actually fill the space needed.
        self.encoding_name = encoding_name
        #"small_font" is boolean referring to target on-calculator font size.
        #Large font area is 12x16, small font area is 14x12.
        self.small_font = small_font
        self.images: Dict[int, Image.Image] = {}    #Stores per-cell monochrome images for this font.
        self.encodings_path = Path(encodings_path) if encodings_path else Path(__file__).with_name("encodings.json")
        self.encoding = self._load_encoding_map(self.encoding_name)
        self.cell_width, self.cell_height = self._get_cell_dimensions()
        self.nudge_settings: Dict[int, List[int]] = self._normalize_nudge_settings(nudge_settings)
        self._font = self._load_font()
        self.collect_images()  #Collect images for each character in the encoding.

    def __repr__(self) -> str:
        return f"FontData(font_path={self.font_path}, font_name={self.font_name}, font_size={self.font_size}, encoding_name={self.encoding_name}, small_font={self.small_font})"

    def _get_cell_dimensions(self) -> tuple[int, int]:
        if self.small_font:
            return (14, 12)
        return (12, 16)

    def _load_encoding_map(self, encoding_name: str) -> Dict[int, str]:
        try:
            with self.encodings_path.open("r", encoding="utf-8") as file_handle:
                encodings_data = json.load(file_handle)
        except (FileNotFoundError, OSError, json.JSONDecodeError):
            return {}

        if not isinstance(encodings_data, dict):
            return {}

        selected = encodings_data.get(encoding_name, {})
        if not isinstance(selected, dict):
            return {}

        mapping: Dict[int, str] = {}
        for raw_key, raw_value in selected.items():
            if not isinstance(raw_key, str) or not isinstance(raw_value, str) or not raw_value:
                continue

            try:
                codepoint = int(raw_key, 16)
            except ValueError:
                continue

            if 0 <= codepoint <= 0xFF:
                mapping[codepoint] = raw_value[0]

        return mapping

    def _build_font_file_path(self) -> Path:
        return Path(self.font_path) / self.font_name

    def _normalize_nudge_settings(self, raw_settings: Optional[Dict[Any, Any]]) -> Dict[int, List[int]]:
        normalized: Dict[int, List[int]] = {}
        if not isinstance(raw_settings, dict):
            return normalized

        for raw_key, raw_value in raw_settings.items():
            if isinstance(raw_key, str):
                try:
                    codepoint = int(raw_key, 0)
                except ValueError:
                    continue
            elif isinstance(raw_key, int):
                codepoint = raw_key
            else:
                continue

            if not (0 <= codepoint <= 0xFF):
                continue

            if not isinstance(raw_value, (list, tuple)) or len(raw_value) != 2:
                continue

            try:
                dx = int(raw_value[0])
                dy = int(raw_value[1])
            except (TypeError, ValueError):
                continue

            if dx != 0 or dy != 0:
                normalized[codepoint] = [dx, dy]

        return normalized

    def _load_font(self) -> Optional[ImageFont.FreeTypeFont]:
        try:
            return ImageFont.truetype(str(self._build_font_file_path()), self.font_size)
        except OSError:
            return None
    
    def _render_character_to_cell(self, font: Optional[ImageFont.FreeTypeFont], char: str, codepoint: int) -> Image.Image:
        """Render a single character into a fixed-size monochrome cell image.

        Rendering is deterministic, left aligned, vertically centered, and clipped to the cell.
        """
        cell_image = Image.new("1", (self.cell_width, self.cell_height), 0)
        if font is None or not char:
            return cell_image

        work_width = max(self.font_size * 4, self.cell_width * 4, 64)
        work_height = max(self.font_size * 4, self.cell_height * 4, 64)
        work_image = Image.new("L", (work_width, work_height), 0)
        draw = ImageDraw.Draw(work_image)

        origin_x = 8
        origin_y = 8
        draw.text((origin_x, origin_y), char, font=font, fill=255)

        bbox = work_image.getbbox()
        if not bbox:
            return cell_image

        glyph = work_image.crop(bbox)
        glyph = glyph.point(lambda value: 255 if value >= 128 else 0, mode="1")

        glyph_w, glyph_h = glyph.size
        if glyph_w > self.cell_width:
            glyph = glyph.crop((0, 0, self.cell_width, glyph_h))
            glyph_w = self.cell_width
        if glyph_h > self.cell_height:
            glyph = glyph.crop((0, 0, glyph_w, self.cell_height))
            glyph_h = self.cell_height

        nudge_dx, nudge_dy = self.nudge_settings.get(codepoint, [0, 0])
        paste_x = nudge_dx
        paste_y = max(0, (self.cell_height - glyph_h) // 2) + nudge_dy
        cell_image.paste(glyph, (paste_x, paste_y))
        return cell_image

    def collect_images(self) -> None:
        """Collects fixed-size images for all calculator codepoints 0x00-0xFF."""
        self.images.clear()
        for codepoint in range(0x100):
            char = self.encoding.get(codepoint, "")
            image = self._render_character_to_cell(self._font, char, codepoint)
            self.images[codepoint] = image

    def rerender_codepoint(self, codepoint: int) -> None:
        if not (0 <= codepoint <= 0xFF):
            return
        char = self.encoding.get(codepoint, "")
        self.images[codepoint] = self._render_character_to_cell(self._font, char, codepoint)

    def nudge_codepoint(self, codepoint: int, dx: int, dy: int, relative: bool = True) -> bool:
        if not (0 <= codepoint <= 0xFF):
            return False

        current_dx, current_dy = self.nudge_settings.get(codepoint, [0, 0])
        if relative:
            next_dx = current_dx + int(dx)
            next_dy = current_dy + int(dy)
        else:
            next_dx = int(dx)
            next_dy = int(dy)

        if next_dx == current_dx and next_dy == current_dy:
            return False

        if next_dx == 0 and next_dy == 0:
            self.nudge_settings.pop(codepoint, None)
        else:
            self.nudge_settings[codepoint] = [next_dx, next_dy]

        self.rerender_codepoint(codepoint)
        return True

    def export_nudge_settings(self) -> Dict[str, List[int]]:
        return {f"0x{codepoint:02X}": [offsets[0], offsets[1]] for codepoint, offsets in sorted(self.nudge_settings.items())}

    def get_image(self, codepoint: int) -> Optional[Image.Image]:
        """Returns the image for a given codepoint, or None if not found."""
        return self.images.get(codepoint)



