''' Contains a custom tkinter canvas class with all associated functions.
    This drives the font preview and editing functionality of this application.
'''
import tkinter as tk

class FontCanvas(tk.Canvas):
    def __init__(self, master, **kwargs):
        super().__init__(master, **kwargs)
        self.grid_size = 16
        self.cell_width = 14
        self.cell_height = 12
        self.zoom_level = 1.0
        
        self.bind("<Button-1>", self.on_click)
        self.bind("<Button-3>", self.start_pan)
        self.bind("<B3-Motion>", self.do_pan)
        self.bind("<MouseWheel>", self.on_zoom)
        
        self.draw_grid()

    def draw_grid(self):
        self.delete("grid")
        # Basic grid drawing logic for skeleton
        for i in range(self.grid_size + 1):
            x = i * self.cell_width * 2 # Scalling for visibility in skeleton
            y = i * self.cell_height * 2
            self.create_line(0, y, self.grid_size * self.cell_width * 2, y, tags="grid", fill="gray")
            self.create_line(x, 0, x, self.grid_size * self.cell_height * 2, tags="grid", fill="gray")

    def on_click(self, event):
        pass

    def start_pan(self, event):
        pass

    def do_pan(self, event):
        pass

    def on_zoom(self, event):
        pass
