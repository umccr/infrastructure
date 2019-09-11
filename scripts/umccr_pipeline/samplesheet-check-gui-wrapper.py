from tkinter import filedialog
from tkinter import Tk
from tkinter import messagebox
ss = __import__('samplesheet-check')


root = Tk()
root.filename = filedialog.askopenfilename(
    initialdir="/",
    title="Select file",
    filetypes=(("jpeg files", "*.jpg"), ("all files", "*.*"), ("CSV files", "*.csv")))

print(root.filename)

message = "All OK."
try:
    ss.main(root.filename, True)
except ValueError as ve:
    message = ve

messagebox.showinfo("Validation Result", message)
