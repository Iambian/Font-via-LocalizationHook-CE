''' Part of the ttf2calc project. This file contains most of the UI elements
    and their associated functions. The main application window is initialized
    here and is where the main loop lives.
    The font canvas, notably, is *not* in this file. It is, rather, in
    its own dedicated file and must be imported and used here.
'''
import json
from pathlib import Path
import re
import tkinter as tk
from tkinter import ttk
from PIL import Image, ImageTk
from .canvas import FontCanvas
from .core import AppState

class MainApplication(tk.Frame):
    def __init__(self, master=None, app_state: AppState = None):
        super().__init__(master)
        self.master = master
        self.app_state = app_state or AppState()

        self.folder_path_var = tk.StringVar(value=self.app_state.font_path)
        self.font_var = tk.StringVar(value=self.app_state.font_name)
        self.use_system_fonts_var = tk.BooleanVar(value=self.app_state.use_system_fonts)
        self.small_font_var = tk.BooleanVar(value=self.app_state.small_font)
        self.encoding_var = tk.StringVar(value=self.app_state.encoding)
        self.self_install_var = tk.BooleanVar(value=self.app_state.self_installing)
        self.filename_var = tk.StringVar(value=self.app_state.calculator_filename)
        self.font_size_var = tk.IntVar(value=self.app_state.font_size)
        self._preview_tk_image = None

        self.pack(fill="both", expand=True)
        self.app_state.subscribe(self.on_state_change)
        self.bind("<Destroy>", self._on_destroy)
        self.create_widgets()

    def _get_encoding_names(self):
        encodings_path = Path(__file__).with_name("encodings.json")
        fallback = [
            "Alphanumeric characters only",
            "All ASCII characters",
            "TI-84 Plus CE character set",
            "Custom",
        ]

        try:
            with encodings_path.open("r", encoding="utf-8") as file_handle:
                data = json.load(file_handle)
            if isinstance(data, dict) and data:
                names = [name for name in data.keys() if isinstance(name, str)]
                if names:
                    return names
        except (FileNotFoundError, json.JSONDecodeError, OSError):
            pass

        return fallback

    def create_widgets(self):
        encoding_names = self._get_encoding_names()
        if self.app_state.encoding not in encoding_names:
            self.app_state.set("encoding", encoding_names[0])

        # Top Bar (Folder and Font Selection)
        top_frame = tk.Frame(self)
        top_frame.pack(side="top", fill="x", padx=5, pady=5)
        
        self.btn_folder = tk.Button(top_frame, text="📁")
        self.btn_folder.pack(side="left")
        
        self.lbl_folder_path = tk.Label(top_frame, textvariable=self.folder_path_var, relief="sunken", anchor="w")
        self.lbl_folder_path.pack(side="left", fill="x", expand=True, padx=5)
        
        self.combo_font = ttk.Combobox(top_frame, textvariable=self.font_var, values=[self.app_state.font_name])
        self.combo_font.pack(side="left", padx=5)
        self.combo_font.bind("<<ComboboxSelected>>", self._on_font_changed)
        self.combo_font.bind("<FocusOut>", self._on_font_changed)
        
        # System Fonts Checkbox Row
        sys_font_frame = tk.Frame(self)
        sys_font_frame.pack(side="top", fill="x", padx=5)
        self.check_sys_fonts = tk.Checkbutton(
            sys_font_frame,
            text="Use system fonts",
            variable=self.use_system_fonts_var,
            command=self._on_use_system_fonts_changed,
        )
        self.check_sys_fonts.pack(side="left")

        # Main Content Area
        content_frame = tk.Frame(self)
        content_frame.pack(side="top", fill="both", expand=True, padx=5, pady=5)

        # Right: Preview and Controls
        right_frame = tk.Frame(content_frame)
        right_frame.pack(side="right", fill="y", padx=5)

        # (3) Zoomed View
        #NOTE: This code needs to be before the font canvas
        self.preview_canvas = tk.Canvas(right_frame, width=112, height=128, bg="white", highlightthickness=1, highlightbackground="black")
        self.preview_canvas.pack(side="top", pady=5)

        # Left: Font Canvas
        self.canvas = FontCanvas(
            content_frame,
            app_state=self.app_state,
            on_selection_change=self._on_canvas_selection_changed,
            bg="white",
            width=400,
            height=400,
        )
        self.canvas.pack(side="left", fill="both", expand=True)

        # (5) Controls
        controls_frame = tk.Frame(right_frame)
        controls_frame.pack(side="top", fill="x", pady=10)

        self.check_small_font = tk.Checkbutton(
            controls_frame,
            text="Small font",
            variable=self.small_font_var,
            command=self._on_small_font_changed,
        )
        self.check_small_font.pack(anchor="w")

        tk.Label(controls_frame, text="Font size:").pack(anchor="w")
        self.spin_font_size = tk.Spinbox(
            controls_frame,
            from_=1,
            to=255,
            textvariable=self.font_size_var,
            width=8,
            command=self._on_font_size_changed,
        )
        self.spin_font_size.pack(anchor="w", pady=(0, 5))
        self.spin_font_size.bind("<Return>", self._on_font_size_changed)
        self.spin_font_size.bind("<FocusOut>", self._on_font_size_changed)

        tk.Label(controls_frame, text="Encoding:").pack(anchor="w")
        self.combo_encoding = ttk.Combobox(
            controls_frame,
            values=encoding_names,
            state="readonly",
            textvariable=self.encoding_var,
        )
        self.combo_encoding.pack(fill="x", pady=(0, 5))
        self.combo_encoding.bind("<<ComboboxSelected>>", self._on_encoding_changed)

        self.check_self_install = tk.Checkbutton(
            controls_frame,
            text="Self-installing",
            variable=self.self_install_var,
            command=self._on_self_install_changed,
        )
        self.check_self_install.pack(anchor="w")

        tk.Label(controls_frame, text="Calculator filename:").pack(anchor="w")
        self.entry_filename = tk.Entry(controls_frame, textvariable=self.filename_var)
        self.entry_filename.pack(fill="x")
        self.entry_filename.bind("<KeyRelease>", self._on_filename_input)
        self.entry_filename.bind("<FocusOut>", self._on_filename_changed)
        self.entry_filename.bind("<Return>", self._on_filename_changed)

        self.btn_export = tk.Button(
            controls_frame,
            text="Export",
            state="disabled",
            command=self._on_export_clicked,
        )
        self.btn_export.pack(fill="x", pady=(6, 0))

        # (4) Instructions
        instructions_frame = tk.Frame(right_frame)
        instructions_frame.pack(side="bottom", fill="both", expand=True, pady=10)
        
        instructions_text = (
            "Left click to select a glyph.\n"
            "Right click and drag to pan.\n"
            "Mouse wheel to zoom.\n"
            "Arrow keys to nudge selected glyph."
        )
        self.lbl_instructions = tk.Label(instructions_frame, text=instructions_text, justify="left", anchor="nw")
        self.lbl_instructions.pack(fill="both", expand=True)
        self._update_export_button_state()

    def _on_canvas_selection_changed(self, _codepoint, glyph_img, cell_width, cell_height):
        self.preview_canvas.delete("all")

        preview_width = int(self.preview_canvas.cget("width"))
        preview_height = int(self.preview_canvas.cget("height"))
        self.preview_canvas.create_rectangle(0, 0, preview_width, preview_height, fill="white", outline="")

        if glyph_img is None:
            self._preview_tk_image = None
            self.preview_canvas.create_rectangle(
                4,
                4,
                preview_width - 4,
                preview_height - 4,
                outline="#b0b0b0",
                width=1,
            )
            return

        zoom_factor = 8
        display_img = glyph_img.convert("L").point(lambda value: 0 if value > 0 else 255).convert("1")
        scaled_img = display_img.resize(
            (
                max(1, int(cell_width * zoom_factor)),
                max(1, int(cell_height * zoom_factor)),
            ),
            Image.Resampling.NEAREST,
        )

        self._preview_tk_image = ImageTk.PhotoImage(scaled_img)
        x = max(0, (preview_width - scaled_img.width) // 2)
        y = max(0, (preview_height - scaled_img.height) // 2)
        self.preview_canvas.create_image(x, y, anchor="nw", image=self._preview_tk_image)
        self.preview_canvas.create_rectangle(
            x,
            y,
            x + scaled_img.width,
            y + scaled_img.height,
            outline="#8a8a8a",
            width=1,
        )

    def _on_destroy(self, event):
        if event.widget is self:
            self.app_state.unsubscribe(self.on_state_change)

    def on_state_change(self, field_name, old_value, new_value, _state):
        if field_name == "font_path":
            self.folder_path_var.set(new_value)
        elif field_name == "font_name":
            self.font_var.set(new_value)
        elif field_name == "font_size":
            self.font_size_var.set(new_value)
        elif field_name == "encoding":
            self.encoding_var.set(new_value)
        elif field_name == "small_font":
            self.small_font_var.set(new_value)
        elif field_name == "self_installing":
            self.self_install_var.set(new_value)
            self._update_export_button_state()
        elif field_name == "use_system_fonts":
            self.use_system_fonts_var.set(new_value)
        elif field_name == "calculator_filename":
            self.filename_var.set(new_value)
            self._update_export_button_state()

    def _on_use_system_fonts_changed(self):
        self.app_state.set("use_system_fonts", self.use_system_fonts_var.get())

    def _on_small_font_changed(self):
        self.app_state.set("small_font", self.small_font_var.get())

    def _on_font_size_changed(self, _event=None):
        try:
            self.app_state.set_font_size(self.font_size_var.get())
        except (tk.TclError, ValueError):
            self.font_size_var.set(self.app_state.font_size)

    def _on_encoding_changed(self, _event=None):
        self.app_state.set("encoding", self.encoding_var.get())

    def _on_self_install_changed(self):
        self.app_state.set("self_installing", self.self_install_var.get())
        self._update_export_button_state()

    def _on_filename_changed(self, _event=None):
        self.app_state.set("calculator_filename", self.filename_var.get())
        self._update_export_button_state()

    def _on_filename_input(self, _event=None):
        self._update_export_button_state()

    def _on_export_clicked(self):
        pass

    def _is_valid_calculator_filename(self, name):
        if not isinstance(name, str):
            return False
        if "." in name:
            return False

        if self.self_install_var.get():
            pattern = r"^[A-Z][A-Z0-9]{0,7}$"
        else:
            pattern = r"^[A-Z][A-Za-z0-9]{0,7}$"

        return re.fullmatch(pattern, name) is not None

    def _update_export_button_state(self):
        if not hasattr(self, "btn_export"):
            return
        is_valid = self._is_valid_calculator_filename(self.filename_var.get())
        self.btn_export.configure(state="normal" if is_valid else "disabled")

    def _on_font_changed(self, _event=None):
        self.app_state.set("font_name", self.font_var.get())




