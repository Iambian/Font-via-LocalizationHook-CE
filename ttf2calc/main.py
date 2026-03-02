''' TTF font to TI-84 CE font converter
'''
import tkinter as tk
from src.ui import MainApplication
from src.core import AppState

def main():
    root = tk.Tk()
    root.title("TTF to TI-84 CE Font Converter")
    root.geometry("800x600")

    app_state = AppState()
    app = MainApplication(master=root, app_state=app_state)
    
    root.mainloop()

if __name__ == "__main__":
    main()




