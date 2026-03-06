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
from tkinter import ttk, filedialog, messagebox
from PIL import Image, ImageTk
from .canvas import FontCanvas
from .core import AppState, ALIASING_MODES, OUTPUT_TARGETS, export_font_data


class MainApplication(tk.Frame):
    def __init__(self, master=None, app_state: AppState = None):
        super().__init__(master)
        self.master = master
        self.app_state = app_state or AppState()
        self.app_state.add_callback(self._on_state_change)
        self.pack(fill="both", expand=True)

        self.project_path_var = tk.StringVar(value=str(self.app_state.project_path))
        self.encoding_var = tk.StringVar(value=self.app_state.encoding_name)
        self.font_path_var = tk.StringVar()
        self.font_name_var = tk.StringVar()
        self.font_size_var = tk.IntVar()
        self.aliasing_var = tk.StringVar()
        self.output_target_var = tk.StringVar(value=self.app_state.output_target)
        self.output_basename_var = tk.StringVar(value=self.app_state.output_basename)
        self.export_status_var = tk.StringVar(value="")
        self.font_data_debug_var = tk.StringVar(value=self.app_state.get_font_data_debug_text())

        self.preview_photo = None

        self._build_ui()
        self._populate_variant_controls_from_state()
        self._refresh_view_buttons()
        self._refresh_preview()
        self._ensure_path_entries_show_end()

    def _build_ui(self):
        self.columnconfigure(0, weight=1)
        self.columnconfigure(1, weight=0,minsize=300)
        self.rowconfigure(0, weight=1)

        self.canvas = FontCanvas(
            self,
            app_state=self.app_state,
            on_selection_change=self._on_canvas_selection_change,
            bg="#202020",
            highlightthickness=0,
        )
        self.canvas.grid(row=0, column=0, sticky="nsew", padx=8, pady=8)

        panel = ttk.Frame(self)
        panel.grid(row=0, column=1, sticky="nsew", padx=(0, 8), pady=8)
        panel.columnconfigure(0, weight=1)

        self._build_project_row(panel)
        self._build_preview_section(panel)
        self._build_encoding_and_view(panel)
        self._build_variant_section(panel)
        self._build_output_section(panel)
        self._build_instructions_section(panel)

    def _build_project_row(self, parent):
        frame = ttk.Frame(parent)
        frame.grid(row=0, column=0, sticky="ew", pady=(0, 8))
        frame.columnconfigure(2, weight=1)

        ttk.Button(frame, text="📁", width=3, command=self._load_project).grid(row=0, column=0, padx=(0, 4))
        ttk.Button(frame, text="💾", width=3, command=self._save_project).grid(row=0, column=1, padx=(0, 4))

        self.project_entry = ttk.Entry(frame, textvariable=self.project_path_var)
        self.project_entry.grid(row=0, column=2, sticky="ew")
        self.project_entry.bind("<Return>", self._on_project_path_commit)
        self.project_entry.bind("<FocusOut>", self._on_project_path_commit)
        self.project_entry.bind("<FocusOut>", lambda _event: self._show_entry_end(self.project_entry), add="+")

    def _build_preview_section(self, parent):
        cspanpos = 3
        info_frame = ttk.Frame(parent)
        info_frame.grid(row=1, column=0, sticky="ew", pady=(0, 8))
        info_frame.columnconfigure(1, weight=1)

        debug_label =ttk.Label(
            info_frame,
            textvariable=self.font_data_debug_var,
            foreground="#606060",
            justify="right",
            font=("Consolas", 6),
        )
        debug_label.grid(row=0, column=cspanpos, columnspan=4, sticky="e", pady=(4, 0))

        preview_frame = ttk.LabelFrame(info_frame, text="Preview")
        preview_frame.grid(row=0, column=0, sticky="ew", pady=(0, 8))
        self.preview_label = ttk.Label(preview_frame)
        self.preview_label.grid(row=0, column=0, columnspan=cspanpos, padx=8, pady=8)

    def _build_encoding_and_view(self, parent):
        enc_frame = ttk.Frame(parent)
        enc_frame.grid(row=2, column=0, sticky="ew", pady=(0, 8))
        enc_frame.columnconfigure(1, weight=1)

        ttk.Label(enc_frame, text="Encodings:").grid(row=0, column=0, sticky="w")
        self.encoding_combo = ttk.Combobox(
            enc_frame,
            textvariable=self.encoding_var,
            values=self.app_state.get_encoding_names(),
            state="readonly",
        )
        self.encoding_combo.grid(row=0, column=1, sticky="ew")
        self.encoding_combo.bind("<<ComboboxSelected>>", self._on_encoding_selected)

        view_row = ttk.Frame(parent)
        view_row.grid(row=3, column=0, sticky="ew", pady=(0, 8))
        ttk.Label(view_row, text="View:").pack(side="left", padx=(0, 6))
        self.large_btn = ttk.Button(view_row, text="Large", command=lambda: self._set_view_variant("large"))
        self.large_btn.pack(side="left", padx=(0, 4))
        self.small_btn = ttk.Button(view_row, text="Small", command=lambda: self._set_view_variant("small"))
        self.small_btn.pack(side="left")

    def _build_variant_section(self, parent):
        variant_frame = ttk.LabelFrame(parent, text="Font Variant")
        variant_frame.grid(row=4, column=0, sticky="ew", pady=(0, 8))
        variant_frame.columnconfigure(1, weight=1)
        variant_frame.columnconfigure(2, weight=1)

        ttk.Button(variant_frame, text="…", width=3, command=self._pick_font_folder).grid(row=0, column=0, padx=(0, 4), pady=4)

        self.font_path_entry = ttk.Entry(variant_frame, textvariable=self.font_path_var)
        self.font_path_entry.grid(row=0, column=1, sticky="ew", pady=4, padx=(0, 4))
        self.font_path_entry.bind("<Return>", self._commit_variant_inputs)
        self.font_path_entry.bind("<FocusOut>", self._commit_variant_inputs)
        self.font_path_entry.bind("<FocusOut>", lambda _event: self._show_entry_end(self.font_path_entry), add="+")

        self.font_name_combo = ttk.Combobox(
            variant_frame,
            textvariable=self.font_name_var,
            state="readonly",
        )
        self.font_name_combo.grid(row=0, column=2, sticky="ew", pady=4)
        self.font_name_combo.bind("<<ComboboxSelected>>", self._commit_variant_inputs)
        self.font_name_combo.bind("<FocusOut>", self._commit_variant_inputs)

        size_row = ttk.Frame(variant_frame)
        size_row.grid(row=1, column=0, columnspan=3, sticky="ew", pady=(0, 4))
        size_row.columnconfigure(1, weight=1)

        ttk.Label(size_row, text="Fontsize:").grid(row=0, column=0, sticky="w", padx=(0, 6))
        self.size_spin = tk.Spinbox(
            size_row,
            from_=1,
            to=72,
            textvariable=self.font_size_var,
            width=6,
            command=self._on_font_size_live_change,
        )
        self.size_spin.grid(row=0, column=1, sticky="w", padx=(0, 8))
        self.size_spin.bind("<Return>", self._commit_variant_inputs)
        self.size_spin.bind("<FocusOut>", self._commit_variant_inputs)
        self.size_spin.bind("<KeyRelease>", self._on_font_size_live_change)

        ttk.Label(size_row, text="Aliasing:").grid(row=0, column=2, sticky="w", padx=(8, 6))
        self.aliasing_combo = ttk.Combobox(
            size_row,
            textvariable=self.aliasing_var,
            values=ALIASING_MODES,
            state="readonly",
            width=16,
        )
        self.aliasing_combo.grid(row=0, column=3, sticky="ew")
        self.aliasing_combo.bind("<<ComboboxSelected>>", self._commit_variant_inputs)

        ttk.Button(
            variant_frame,
            text="Reset Nudging",
            command=self._reset_current_variant_nudging,
        ).grid(row=2, column=0, columnspan=3, sticky="ew", pady=(0, 4))

    def _build_output_section(self, parent):
        output_frame = ttk.LabelFrame(parent, text="Output")
        output_frame.grid(row=5, column=0, sticky="ew")
        output_frame.columnconfigure(0, weight=1)
        output_frame.columnconfigure(1, weight=1)

        self.output_combo = ttk.Combobox(
            output_frame,
            textvariable=self.output_target_var,
            values=OUTPUT_TARGETS,
            state="readonly",
        )
        
        self.output_combo.grid(row=0, column=0, sticky="ew", padx=4, pady=(4, 4))
        self.output_combo.bind("<<ComboboxSelected>>", self._on_output_target_selected)

        self.output_entry = ttk.Entry(output_frame, textvariable=self.output_basename_var)
        self.output_entry.grid(row=0, column=1, sticky="ew", padx=4, pady=(0, 4))
        self.output_entry.bind("<Return>", self._on_output_basename_commit)
        self.output_entry.bind("<FocusOut>", self._on_output_basename_commit)

        ttk.Button(output_frame, text="EXPORT FONT FILE", command=self._on_export).grid(row=2, column=0, columnspan=2, sticky="ew", padx=4, pady=(0, 4))

        self.export_status_label = ttk.Label(
            output_frame,
            textvariable=self.export_status_var,
            foreground="#606060",
            justify="left",
            wraplength=280,
        )
        self.export_status_label.grid(row=3, column=0, columnspan=2, sticky="w", padx=4, pady=(0, 6))

    def _build_instructions_section(self, parent):
        instructions_frame = ttk.LabelFrame(parent, text="Instructions")
        instructions_frame.grid(row=6, column=0, sticky="ew", pady=(8, 0))
        instructions_frame.columnconfigure(0, weight=1)

        instructions_text = (
            "Font area is draggable and selectable with left mouse button, "
            "and is zoomable with mouse wheel. Use the arrow keys to nudge "
            "the selected glyph."
        )
        instructions_label = ttk.Label(
            instructions_frame,
            text=instructions_text,
            justify="left",
            wraplength=280,
        )
        instructions_label.grid(row=0, column=0, sticky="w", padx=4, pady=(4, 6))    

    def _on_state_change(self, _state):
        self.project_path_var.set(str(self.app_state.project_path))
        self.encoding_var.set(self.app_state.encoding_name)
        self.output_target_var.set(self.app_state.output_target)
        self.output_basename_var.set(self.app_state.output_basename)
        self.font_data_debug_var.set(self.app_state.get_font_data_debug_text())
        self._populate_variant_controls_from_state()
        self._ensure_path_entries_show_end()
        self._refresh_view_buttons()
        self._refresh_preview()
        self.canvas.redraw()

    def _show_entry_end(self, entry_widget):
        entry_widget.icursor(tk.END)
        entry_widget.xview_moveto(1.0)

    def _ensure_path_entries_show_end(self):
        focused = self.focus_get()
        for entry_widget in (getattr(self, "project_entry", None), getattr(self, "font_path_entry", None)):
            if entry_widget is not None and focused is not entry_widget:
                self._show_entry_end(entry_widget)

    def _populate_variant_controls_from_state(self):
        variant = self.app_state.view_variant
        current = self.app_state.variants[variant]
        self.font_path_var.set(current["font_path"])
        self.font_name_var.set(current["font_name"])
        self._refresh_font_name_choices(select_default=False)
        self.font_size_var.set(int(current["size"]))
        self.aliasing_var.set(current["aliasing"])

    def _refresh_font_name_choices(self, select_default=True):
        names = []
        folder_text = self.font_path_var.get().strip()
        if folder_text:
            folder = Path(folder_text)
            if folder.is_dir():
                names = sorted(
                    path.name
                    for path in folder.iterdir()
                    if path.is_file() and path.suffix.lower() == ".ttf"
                )

        self.font_name_combo.configure(values=names)
        current_name = self.font_name_var.get().strip()
        if select_default and names and current_name not in names:
            self.font_name_var.set(names[0])

    def _refresh_view_buttons(self):
        if self.app_state.view_variant == "large":
            self.large_btn.state(["disabled"])
            self.small_btn.state(["!disabled"])
        else:
            self.small_btn.state(["disabled"])
            self.large_btn.state(["!disabled"])

    def _refresh_preview(self):
        font_data = self.app_state.current_font_data
        if font_data is None:
            self.preview_label.configure(image="")
            return

        codepoint = int(self.app_state.selected_glyph)
        variant = self.app_state.view_variant
        nudging = self.app_state.get_variant_nudging(variant).get(codepoint, (0, 0))
        glyph = font_data.get_nudged_glyph_image(variant, codepoint, nudging)
        zoomed = glyph.convert("L").resize((glyph.width * 8, glyph.height * 8), Image.Resampling.NEAREST)
        self.preview_photo = ImageTk.PhotoImage(zoomed)
        self.preview_label.configure(image=self.preview_photo)

    def _on_canvas_selection_change(self, _codepoint):
        self._refresh_preview()

    def _on_encoding_selected(self, _event=None):
        self.app_state.set_encoding(self.encoding_var.get())

    def _set_view_variant(self, variant: str):
        self._commit_variant_inputs()
        self.app_state.set_view_variant(variant)

    def _commit_variant_inputs(self, _event=None):
        variant = self.app_state.view_variant
        self.app_state.set_variant_font_path(variant, self.font_path_var.get().strip())
        self._refresh_font_name_choices()
        self.app_state.set_variant_font_name(variant, self.font_name_var.get().strip())
        size = self._parse_font_size_or_none()
        if size is not None:
            self.app_state.set_variant_font_size(variant, size)
        self.app_state.set_variant_aliasing(variant, self.aliasing_var.get())

    def _parse_font_size_or_none(self):
        value = str(self.font_size_var.get()).strip()
        if not value:
            return None
        if not value.isdigit():
            return None
        return max(1, int(value))

    def _on_font_size_live_change(self, _event=None):
        size = self._parse_font_size_or_none()
        if size is None:
            return
        self.app_state.set_variant_font_size(self.app_state.view_variant, size)

    def _reset_current_variant_nudging(self):
        self.app_state.reset_variant_nudging(self.app_state.view_variant)

    def _pick_font_folder(self):
        selected = filedialog.askdirectory(
            title="Choose Font Folder",
            initialdir=self.font_path_var.get() or str(self.app_state.root_dir),
        )
        if selected:
            self.font_path_var.set(selected)
            self._commit_variant_inputs()

    def _on_output_target_selected(self, _event=None):
        self.app_state.set_output_target(self.output_target_var.get())

    def _on_output_basename_commit(self, _event=None):
        value = self.output_basename_var.get()
        self.app_state.set_output_basename(value)

    def _on_project_path_commit(self, _event=None):
        value = self.project_path_var.get().strip()
        if value:
            self.app_state.set_project_path(value)

    def _save_project(self):
        initial = str(self.app_state.project_path)
        selected = filedialog.asksaveasfilename(
            title="Save Project",
            initialfile=Path(initial).name,
            initialdir=str(Path(initial).parent),
            defaultextension=".cefont",
            filetypes=[("CE Font Project", "*.cefont")],
        )
        if not selected:
            return

        try:
            self._commit_variant_inputs()
            self._on_output_basename_commit()
            self.app_state.save_project_file(selected)
            messagebox.showinfo("Project Saved", f"Saved project:\n{self.app_state.project_path}")
        except Exception as exc:
            messagebox.showerror("Save Failed", str(exc))

    def _load_project(self):
        selected = filedialog.askopenfilename(
            title="Load Project",
            initialdir=str(self.app_state.projects_dir),
            filetypes=[("CE Font Project", "*.cefont")],
        )
        if not selected:
            return

        try:
            self.app_state.load_project_file(selected)
            messagebox.showinfo("Project Loaded", f"Loaded project:\n{self.app_state.project_path}")
        except Exception as exc:
            messagebox.showerror("Load Failed", str(exc))

    def _on_export(self):
        self._commit_variant_inputs()
        self._on_output_basename_commit()

        try:
            if self.app_state.current_font_data is None:
                raise RuntimeError("No FontData is currently loaded.")

            export_font_data(
                font_data=self.app_state.current_font_data,
                file_name=self.app_state.output_basename,
                export_type=self.app_state.output_target,
                large_nudging={
                    int(codepoint): (int(delta[0]), int(delta[1]))
                    for codepoint, delta in self.app_state.get_variant_nudging("large").items()
                },
                small_nudging={
                    int(codepoint): (int(delta[0]), int(delta[1]))
                    for codepoint, delta in self.app_state.get_variant_nudging("small").items()
                },
            )
            self.export_status_label.configure(foreground="#1f7a1f")
            self.export_status_var.set("Export succeeded.")
        except Exception as exc:
            self.export_status_label.configure(foreground="#a12a2a")
            self.export_status_var.set(f"Export failed: {exc}")