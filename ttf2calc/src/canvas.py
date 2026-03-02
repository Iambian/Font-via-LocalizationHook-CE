''' Contains a custom tkinter canvas class with all associated functions.
    This drives the font preview and editing functionality of this application.
'''
import tkinter as tk
from PIL import Image, ImageTk
from .core import AppState, FontData

class FontCanvas(tk.Canvas):
    def __init__(self, master, app_state: AppState = None, on_selection_change=None, **kwargs):
        super().__init__(master, **kwargs)
        self.app_state = app_state
        self.on_selection_change = on_selection_change
        self.grid_size = 16
        self.cell_width = 14 if (self.app_state and self.app_state.small_font) else 12
        self.cell_height = 12 if (self.app_state and self.app_state.small_font) else 16
        self.base_display_scale = 2.0
        self.zoom_level = 1.0
        self.min_zoom = 0.5
        self.max_zoom = 8.0
        self.font_data = None
        self._tk_images = {}
        self._glyph_items = {}
        self.selected_codepoint = None
        self._selection_item_id = None
        
        self.bind("<Button-1>", self.on_click)
        self.bind("<Button-3>", self.start_pan)
        self.bind("<B3-Motion>", self.do_pan)
        self.bind("<MouseWheel>", self.on_zoom)
        self.bind("<Button-4>", self.on_zoom)
        self.bind("<Button-5>", self.on_zoom)
        self.bind("<Key-plus>", self.on_zoom_in_key)
        self.bind("<Key-equal>", self.on_zoom_in_key)
        self.bind("<KP_Add>", self.on_zoom_in_key)
        self.bind("<Key-minus>", self.on_zoom_out_key)
        self.bind("<KP_Subtract>", self.on_zoom_out_key)
        self.bind("<Key-0>", self.on_zoom_reset_key)
        self.bind("<KP_0>", self.on_zoom_reset_key)
        self.bind("<Up>", self.on_nudge_up)
        self.bind("<Down>", self.on_nudge_down)
        self.bind("<Left>", self.on_nudge_left)
        self.bind("<Right>", self.on_nudge_right)
        self.bind("<Destroy>", self._on_destroy)

        if self.app_state:
            self.app_state.subscribe(self.on_state_change)

        self.refresh_font_data()
        
        self.draw_grid()

    def refresh_font_data(self):
        if not self.app_state:
            self.font_data = None
            return

        existing_nudges = None
        if self.font_data is not None:
            existing_nudges = self.font_data.export_nudge_settings()

        self.font_data = FontData(
            font_path=self.app_state.font_path,
            font_name=self.app_state.font_name,
            font_size=self.app_state.font_size,
            encoding_name=self.app_state.encoding,
            small_font=self.app_state.small_font,
            nudge_settings=existing_nudges,
        )

        self.cell_width = self.font_data.cell_width
        self.cell_height = self.font_data.cell_height

    def draw_grid(self):
        self.delete("all")
        self._tk_images = {}
        self._glyph_items.clear()

        grid_width = self.grid_size * self.cell_width * self.base_display_scale
        grid_height = self.grid_size * self.cell_height * self.base_display_scale

        self.create_rectangle(0, 0, grid_width, grid_height, fill="white", outline="")

        if self.font_data:
            for codepoint in range(0x100):
                row = codepoint // self.grid_size
                col = codepoint % self.grid_size
                px = col * self.cell_width * self.base_display_scale
                py = row * self.cell_height * self.base_display_scale

                glyph_img = self.font_data.get_image(codepoint)
                if glyph_img is None:
                    continue

                tk_image = self._build_tk_glyph_image(glyph_img, self.zoom_level)
                self._tk_images[codepoint] = tk_image
                item_id = self.create_image(px, py, anchor="nw", image=tk_image, tags="glyph")
                self._glyph_items[codepoint] = item_id

        for i in range(self.grid_size + 1):
            x = i * self.cell_width * self.base_display_scale
            y = i * self.cell_height * self.base_display_scale
            self.create_line(0, y, grid_width, y, tags="grid", fill="gray")
            self.create_line(x, 0, x, grid_height, tags="grid", fill="gray")

        if self.zoom_level != 1.0:
            self.scale("grid", 0, 0, self.zoom_level, self.zoom_level)
            self.scale("glyph", 0, 0, self.zoom_level, self.zoom_level)
        self._draw_selection_border()
        self._notify_selection_changed()
        self._update_scrollregion()

    def on_click(self, event):
        self.focus_set()
        self._select_cell_at(event.x, event.y)

    def start_pan(self, event):
        self.scan_mark(event.x, event.y)

    def do_pan(self, event):
        self.scan_dragto(event.x, event.y, gain=1)

    def on_zoom(self, event):
        zoom_in = False
        if hasattr(event, "delta") and event.delta:
            zoom_in = event.delta > 0
        elif getattr(event, "num", None) == 4:
            zoom_in = True
        elif getattr(event, "num", None) == 5:
            zoom_in = False
        else:
            return

        step_factor = 2.0
        step_factor = step_factor if zoom_in else (1.0 / step_factor)
        self._zoom_at(self.canvasx(event.x), self.canvasy(event.y), step_factor)

    def on_zoom_in_key(self, _event):
        center_x = self.canvasx(self.winfo_width() / 2)
        center_y = self.canvasy(self.winfo_height() / 2)
        self._zoom_at(center_x, center_y, 1.1)

    def on_zoom_out_key(self, _event):
        center_x = self.canvasx(self.winfo_width() / 2)
        center_y = self.canvasy(self.winfo_height() / 2)
        self._zoom_at(center_x, center_y, 1.0 / 1.1)

    def on_zoom_reset_key(self, _event):
        if self.zoom_level == 1.0:
            return
        center_x = self.canvasx(self.winfo_width() / 2)
        center_y = self.canvasy(self.winfo_height() / 2)
        self._zoom_at(center_x, center_y, 1.0 / self.zoom_level)

    def on_nudge_up(self, _event):
        self._nudge_selected(0, -1)

    def on_nudge_down(self, _event):
        self._nudge_selected(0, 1)

    def on_nudge_left(self, _event):
        self._nudge_selected(-1, 0)

    def on_nudge_right(self, _event):
        self._nudge_selected(1, 0)

    def _zoom_at(self, anchor_x, anchor_y, step_factor):
        target_zoom = self.zoom_level * step_factor
        target_zoom = max(self.min_zoom, min(self.max_zoom, target_zoom))

        if target_zoom == self.zoom_level:
            return

        scale_factor = target_zoom / self.zoom_level
        self.scale("grid", anchor_x, anchor_y, scale_factor, scale_factor)
        self.scale("glyph", anchor_x, anchor_y, scale_factor, scale_factor)
        self.zoom_level = target_zoom
        self._refresh_glyph_images_for_zoom()
        self._draw_selection_border()
        self._update_scrollregion()

    def _select_cell_at(self, view_x, view_y):
        canvas_x = self.canvasx(view_x)
        canvas_y = self.canvasy(view_y)

        zoomed_cell_w = self.cell_width * self.base_display_scale * self.zoom_level
        zoomed_cell_h = self.cell_height * self.base_display_scale * self.zoom_level
        if zoomed_cell_w <= 0 or zoomed_cell_h <= 0:
            return

        col = int(canvas_x // zoomed_cell_w)
        row = int(canvas_y // zoomed_cell_h)

        if 0 <= col < self.grid_size and 0 <= row < self.grid_size:
            self.selected_codepoint = row * self.grid_size + col
        else:
            self.selected_codepoint = None

        self._draw_selection_border()
        self._notify_selection_changed()

    def _draw_selection_border(self):
        if self._selection_item_id is not None:
            self.delete(self._selection_item_id)
            self._selection_item_id = None

        if self.selected_codepoint is None:
            return

        row = self.selected_codepoint // self.grid_size
        col = self.selected_codepoint % self.grid_size

        zoomed_cell_w = self.cell_width * self.base_display_scale * self.zoom_level
        zoomed_cell_h = self.cell_height * self.base_display_scale * self.zoom_level

        x0 = col * zoomed_cell_w
        y0 = row * zoomed_cell_h
        x1 = x0 + zoomed_cell_w
        y1 = y0 + zoomed_cell_h

        self._selection_item_id = self.create_rectangle(
            x0,
            y0,
            x1,
            y1,
            outline="red",
            width=max(1, int(self.zoom_level)),
            tags="selection",
        )

    def _build_tk_glyph_image(self, glyph_img, zoom_factor):
        display_img = glyph_img.convert("L").point(lambda value: 0 if value > 0 else 255).convert("1")
        scaled_img = display_img.resize(
            (
                max(1, int(self.cell_width * self.base_display_scale * zoom_factor)),
                max(1, int(self.cell_height * self.base_display_scale * zoom_factor)),
            ),
            Image.Resampling.NEAREST,
        )
        return ImageTk.PhotoImage(scaled_img)

    def _refresh_glyph_images_for_zoom(self):
        if not self.font_data or not self._glyph_items:
            return

        for codepoint, item_id in self._glyph_items.items():
            glyph_img = self.font_data.get_image(codepoint)
            if glyph_img is None:
                continue

            tk_image = self._build_tk_glyph_image(glyph_img, self.zoom_level)
            self._tk_images[codepoint] = tk_image
            self.itemconfigure(item_id, image=tk_image)


    def _refresh_single_glyph(self, codepoint):
        if not self.font_data:
            return

        item_id = self._glyph_items.get(codepoint)
        if item_id is None:
            return

        glyph_img = self.font_data.get_image(codepoint)
        if glyph_img is None:
            return

        tk_image = self._build_tk_glyph_image(glyph_img, self.zoom_level)
        self._tk_images[codepoint] = tk_image
        self.itemconfigure(item_id, image=tk_image)

    def _nudge_selected(self, dx, dy):
        if self.selected_codepoint is None or not self.font_data:
            return

        changed = self.font_data.nudge_codepoint(self.selected_codepoint, dx, dy, relative=True)
        if not changed:
            return

        self._refresh_single_glyph(self.selected_codepoint)
        self._notify_selection_changed()

    def _notify_selection_changed(self):
        if not callable(self.on_selection_change):
            return

        glyph_img = None
        if self.font_data is not None and self.selected_codepoint is not None:
            glyph_img = self.font_data.get_image(self.selected_codepoint)

        self.on_selection_change(
            self.selected_codepoint,
            glyph_img,
            self.cell_width,
            self.cell_height,
        )

    def on_state_change(self, field_name, _old_value, new_value, _state):
        if field_name in {"small_font", "font_path", "font_name", "font_size", "encoding"}:
            self.refresh_font_data()
            self.draw_grid()

    def _update_scrollregion(self):
        bbox = self.bbox("all")
        if bbox:
            self.configure(scrollregion=bbox)

    def _on_destroy(self, event):
        if event.widget is self and self.app_state:
            self.app_state.unsubscribe(self.on_state_change)
