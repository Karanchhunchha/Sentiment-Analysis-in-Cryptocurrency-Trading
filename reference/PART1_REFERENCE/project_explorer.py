
import os
from pathlib import Path
from datetime import datetime

# ==============================================================================
# CONFIGURATION
# ==============================================================================

ROOT_FOLDER = r"C:\fun\BTC-price-prediction-using-sentimental-analysis"
PROJECT_NAME = Path(ROOT_FOLDER).name
OUTPUT_FILE = Path(ROOT_FOLDER) / f"{PROJECT_NAME}_Project_Report.txt"

FILE_TYPES = {
    ".py":"Python Source Code",".ipynb":"Jupyter Notebook",".md":"Markdown Documentation",
    ".txt":"Plain Text File",".json":"JSON Data",".yaml":"YAML Configuration",
    ".yml":"YAML Configuration",".toml":"TOML Configuration",".ini":"INI Configuration",
    ".cfg":"Configuration File",".html":"HTML Web Page",".css":"CSS Stylesheet",
    ".js":"JavaScript File",".jsx":"React Component",".ts":"TypeScript File",
    ".tsx":"React TypeScript Component",".java":"Java Source Code",".c":"C Source Code",
    ".cpp":"C++ Source Code",".cs":"C# Source Code",".php":"PHP Source Code",
    ".sql":"SQL Script",".db":"Database",".sqlite":"SQLite Database",
    ".csv":"CSV File",".xlsx":"Excel Workbook",".xls":"Excel Workbook",
    ".doc":"Word Document",".docx":"Word Document",".pdf":"PDF Document",
    ".png":"PNG Image",".jpg":"JPEG Image",".jpeg":"JPEG Image",".gif":"GIF Image",
    ".bmp":"Bitmap Image",".svg":"SVG Image",".ico":"Icon",
    ".mp3":"Audio",".wav":"Audio",".mp4":"Video",".mov":"Video",".avi":"Video",
    ".zip":"ZIP Archive",".rar":"RAR Archive",".7z":"7z Archive",
    ".exe":"Executable",".dll":"Dynamic Link Library",
    ".env":"Environment Variables",".gitignore":"Git Ignore Rules",
    ".gitattributes":"Git Attributes",".lock":"Dependency Lock File"
}

def desc(path: Path):
    return FILE_TYPES.get(path.suffix.lower(), "Unknown File Type")

def human(size):
    units=["B","KB","MB","GB","TB"]
    s=float(size)
    for u in units:
        if s<1024:
            return f"{s:.2f} {u}"
        s/=1024
    return f"{s:.2f} PB"

root=Path(ROOT_FOLDER)
if not root.exists():
    print("ERROR: Folder does not exist:")
    print(ROOT_FOLDER)
    raise SystemExit(1)

total_files=0
total_dirs=0
total_size=0
ext_count={}

with open(OUTPUT_FILE,"w",encoding="utf-8") as f:
    f.write("="*120+"\n")
    f.write("PROJECT EXPLORER REPORT\n")
    f.write("="*120+"\n\n")
    f.write(f"Project : {PROJECT_NAME}\n")
    f.write(f"Root    : {root.resolve()}\n")
    f.write(f"Created : {datetime.now()}\n\n")

    for current,dirs,files in os.walk(root):
        dirs.sort(); files.sort()
        current=Path(current)
        level=len(current.relative_to(root).parts)
        indent="│   "*level
        if level==0:
            f.write(f"📁 {current.name}\n")
        else:
            f.write(f"{indent}├── 📁 {current.name}\n")
        total_dirs+=1

        for file in files:
            total_files+=1
            fp=current/file
            try:
                st=fp.stat()
                size=st.st_size
                total_size+=size
                modified=datetime.fromtimestamp(st.st_mtime).strftime("%Y-%m-%d %H:%M:%S")
            except Exception:
                size=0
                modified="Unknown"

            ext=fp.suffix.lower() or "(none)"
            ext_count[ext]=ext_count.get(ext,0)+1

            f.write(f"{indent}│\n")
            f.write(f"{indent}├── 📄 {file}\n")
            f.write(f"{indent}│   Full Path : {fp.resolve()}\n")
            f.write(f"{indent}│   Extension : {ext}\n")
            f.write(f"{indent}│   Size      : {human(size)} ({size:,} bytes)\n")
            f.write(f"{indent}│   Modified  : {modified}\n")
            f.write(f"{indent}│   Type      : {desc(fp)}\n\n")

    f.write("\n"+"="*120+"\nSUMMARY\n"+"="*120+"\n")
    f.write(f"Folders : {total_dirs}\n")
    f.write(f"Files   : {total_files}\n")
    f.write(f"Size    : {human(total_size)} ({total_size:,} bytes)\n\n")
    f.write("FILE TYPES\n-----------\n")
    for ext,cnt in sorted(ext_count.items()):
        f.write(f"{ext:<15} {cnt}\n")

print("Done!")
print("Report:", OUTPUT_FILE)
