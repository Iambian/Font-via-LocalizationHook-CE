''' Part of the ttf2calc project. This file contains most of the UI elements
    and their associated functions. The main application window is initialized
    here and is where the main loop lives.
    The font canvas, notably, is *not* in this file. It is, rather, in
    its own dedicated file and must be imported and used here.
'''
import tkinter as tk
from tkinter import ttk
from .canvas import FontCanvas

class MainApplication(tk.Frame):
    def __init__(self, master=None):
        super().__init__(master)
        self.master = master
        self.pack(fill="both", expand=True)
        self.create_widgets()

    def create_widgets(self):
        # Top Bar (Folder and Font Selection)
        top_frame = tk.Frame(self)
        top_frame.pack(side="top", fill="x", padx=5, pady=5)
        
        self.btn_folder = tk.Button(top_frame, text="📁")
        self.btn_folder.pack(side="left")
        
        self.lbl_folder_path = tk.Label(top_frame, text="examples/", relief="sunken", anchor="w")
        self.lbl_folder_path.pack(side="left", fill="x", expand=True, padx=5)
        
        self.font_var = tk.StringVar()
        self.combo_font = ttk.Combobox(top_frame, textvariable=self.font_var)
        self.combo_font.pack(side="left", padx=5)
        
        # System Fonts Checkbox Row
        sys_font_frame = tk.Frame(self)
        sys_font_frame.pack(side="top", fill="x", padx=5)
        self.check_sys_fonts = tk.Checkbutton(sys_font_frame, text="Use system fonts")
        self.check_sys_fonts.pack(side="left")

        # Main Content Area
        content_frame = tk.Frame(self)
        content_frame.pack(side="top", fill="both", expand=True, padx=5, pady=5)

        # Left: Font Canvas
        self.canvas = FontCanvas(content_frame, bg="white", width=400, height=400)
        self.canvas.pack(side="left", fill="both", expand=True)

        # Right: Preview and Controls
        right_frame = tk.Frame(content_frame)
        right_frame.pack(side="right", fill="y", padx=5)

        # (3) Zoomed View
        self.preview_canvas = tk.Canvas(right_frame, width=112, height=128, bg="white", highlightthickness=1, highlightbackground="black")
        self.preview_canvas.pack(side="top", pady=5)

        # (5) Controls
        controls_frame = tk.Frame(right_frame)
        controls_frame.pack(side="top", fill="x", pady=10)

        self.check_small_font = tk.Checkbutton(controls_frame, text="Small font")
        self.check_small_font.pack(anchor="w")

        tk.Label(controls_frame, text="Encoding:").pack(anchor="w")
        self.combo_encoding = ttk.Combobox(controls_frame, values=[
            "Alphanumeric characters only",
            "All ASCII characters",
            "TI-84 Plus CE character set",
            "Custom"
        ], state="readonly")
        self.combo_encoding.current(0)
        self.combo_encoding.pack(fill="x", pady=(0, 5))

        self.check_self_install = tk.Checkbutton(controls_frame, text="Self-installing")
        self.check_self_install.pack(anchor="w")

        tk.Label(controls_frame, text="Calculator filename:").pack(anchor="w")
        self.entry_filename = tk.Entry(controls_frame)
        self.entry_filename.pack(fill="x")

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




