''' Contains a custom tkinter canvas class with all associated functions.
    This drives the font preview and editing functionality of this application.
'''
import tkinter as tk
from PIL import Image, ImageTk
from .core import AppState, FontData


class FontCanvas(tk.Canvas):
    def __init__(self, master, app_state: AppState = None, on_selection_change=None, **kwargs):
        super().__init__(master, **kwargs)
        self.app_state = app_state or AppState()
        self.on_selection_change = on_selection_change

        self._image_item = None
        self._photo = None
        self._selection_item = None

        self._press_xy = None
        self._start_pan = None
        self._is_panning = False

        self.bind("<Configure>", self._on_resize)
        self.bind("<MouseWheel>", self._on_mousewheel)
        self.bind("<ButtonPress-1>", self._on_left_press)
        self.bind("<B1-Motion>", self._on_left_drag)
        self.bind("<ButtonRelease-1>", self._on_left_release)
        self.bind("<KeyPress-Up>", self._on_arrow_nudge)
        self.bind("<KeyPress-Down>", self._on_arrow_nudge)
        self.bind("<KeyPress-Left>", self._on_arrow_nudge)
        self.bind("<KeyPress-Right>", self._on_arrow_nudge)

        self.redraw()

    def _on_resize(self, _event):
        self.redraw()

    def _on_mousewheel(self, event):
        delta = 1 if event.delta > 0 else -1
        current_scale = int(self.app_state.canvas_transform["scale"])
        next_scale = max(1, min(8, current_scale + delta))
        if next_scale == current_scale:
            return

        pan_x = int(self.app_state.canvas_transform["pan_x"])
        pan_y = int(self.app_state.canvas_transform["pan_y"])

        image_x = (event.x - pan_x) / current_scale
        image_y = (event.y - pan_y) / current_scale

        next_pan_x = int(event.x - image_x * next_scale)
        next_pan_y = int(event.y - image_y * next_scale)
        self.app_state.set_canvas_transform(scale=next_scale, pan_x=next_pan_x, pan_y=next_pan_y)

    def _on_left_press(self, event):
        self.focus_set()
        self._press_xy = (event.x, event.y)
        self._start_pan = (
            int(self.app_state.canvas_transform["pan_x"]),
            int(self.app_state.canvas_transform["pan_y"]),
        )
        self._is_panning = False

    def _on_left_drag(self, event):
        if self._press_xy is None or self._start_pan is None:
            return

        dx = event.x - self._press_xy[0]
        dy = event.y - self._press_xy[1]
        if not self._is_panning and (abs(dx) >= 3 or abs(dy) >= 3):
            self._is_panning = True

        if self._is_panning:
            self.app_state.set_canvas_transform(
                pan_x=self._start_pan[0] + dx,
                pan_y=self._start_pan[1] + dy,
            )

    def _on_left_release(self, event):
        try:
            if not self._is_panning:
                self._select_from_canvas_xy(event.x, event.y)
        finally:
            self._press_xy = None
            self._start_pan = None
            self._is_panning = False

    def _on_arrow_nudge(self, event):
        delta = {
            "Up": (0, -1),
            "Down": (0, 1),
            "Left": (-1, 0),
            "Right": (1, 0),
        }
        dx_dy = delta.get(event.keysym)
        if dx_dy is None:
            return

        self.app_state.nudge_selected_glyph(dx_dy[0], dx_dy[1])
        return "break"

    def _select_from_canvas_xy(self, canvas_x: int, canvas_y: int):
        font_data = self.app_state.current_font_data
        if font_data is None:
            return

        variant = self.app_state.view_variant
        metrics = font_data.get_variant_metrics(variant)
        scale = int(self.app_state.canvas_transform["scale"])
        pan_x = int(self.app_state.canvas_transform["pan_x"])
        pan_y = int(self.app_state.canvas_transform["pan_y"])

        img_x = (canvas_x - pan_x) / scale
        img_y = (canvas_y - pan_y) / scale

        if img_x < 0 or img_y < 0 or img_x >= metrics["grid_w"] or img_y >= metrics["grid_h"]:
            return

        col = int(img_x // metrics["stride_x"])
        row = int(img_y // metrics["stride_y"])

        if not (0 <= col <= 15 and 0 <= row <= 15):
            return

        codepoint = row * 16 + col
        self.app_state.set_selected_glyph(codepoint)
        if self.on_selection_change is not None:
            self.on_selection_change(codepoint)

    def redraw(self):
        self.delete("all")

        font_data = self.app_state.current_font_data
        if font_data is None:
            return

        variant = self.app_state.view_variant
        nudging = self.app_state.get_variant_nudging(variant)
        base_img = font_data.get_grid_image(variant, nudging)

        scale = int(self.app_state.canvas_transform["scale"])
        pan_x = int(self.app_state.canvas_transform["pan_x"])
        pan_y = int(self.app_state.canvas_transform["pan_y"])

        scaled_w = base_img.width * scale
        scaled_h = base_img.height * scale
        scaled = base_img.resize((scaled_w, scaled_h), Image.Resampling.NEAREST)

        self._photo = ImageTk.PhotoImage(scaled)
        self._image_item = self.create_image(pan_x, pan_y, image=self._photo, anchor="nw")

        self._draw_selection_overlay(font_data, variant, scale, pan_x, pan_y)

    def _draw_selection_overlay(self, font_data: FontData, variant: str, scale: int, pan_x: int, pan_y: int):
        codepoint = int(self.app_state.selected_glyph)
        x, y, w, h = font_data.get_glyph_rect_in_grid(codepoint, variant)

        x0 = pan_x + x * scale
        y0 = pan_y + y * scale
        x1 = x0 + w * scale
        y1 = y0 + h * scale

        self._selection_item = self.create_rectangle(
            x0,
            y0,
            x1,
            y1,
            outline="#ff0000",
            width=2,
        )