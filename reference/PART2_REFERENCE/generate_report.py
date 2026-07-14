import os
import hashlib
import json
import difflib
import re
import shutil

PART1_DIR = r"C:\fun\BTC-price-prediction-using-sentimental-analysis"
PART2_DIR = r"D:\Clone Repo\BTC-price-prediction-using-sentimental-analysis"
OUTPUT_DIR = r"D:\Clone Repo\original_new_files"
EXCLUDE_DIRS = {".git"}

def get_files(directory):
    files_info = {}
    for root, dirs, files in os.walk(directory):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        for f in files:
            full_path = os.path.join(root, f)
            rel_path = os.path.relpath(full_path, directory)
            files_info[rel_path] = full_path
    return files_info

def compute_hash(filepath):
    h = hashlib.sha256()
    try:
        with open(filepath, 'rb') as f:
            while chunk := f.read(8192):
                h.update(chunk)
        return h.hexdigest()
    except Exception:
        return None

def extract_functions(filepath):
    ext = os.path.splitext(filepath)[1].lower()
    functions = []
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            if ext == '.py':
                functions = re.findall(r'^def\s+([a-zA-Z0-9_]+)\s*\(', content, re.MULTILINE)
            elif ext == '.m':
                functions = re.findall(r'^\s*function\s+.*?(?:=|\s)\s*([a-zA-Z0-9_]+)\s*\(', content, re.MULTILINE)
                if not functions:
                     functions = re.findall(r'^\s*function\s+([a-zA-Z0-9_]+)\s*\(', content, re.MULTILINE)
    except Exception:
        pass
    return functions

def count_loc(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            return sum(1 for line in f if line.strip() and not line.strip().startswith(('%', '#')))
    except Exception:
        return 0

def analyze():
    part1_files = get_files(PART1_DIR)
    part2_files = get_files(PART2_DIR)
    
    inventory = {}
    diffs = {}
    new_files_to_copy = []
    
    all_rel_paths = set(part1_files.keys()).union(set(part2_files.keys()))
    
    for rel_path in all_rel_paths:
        p1 = part1_files.get(rel_path)
        p2 = part2_files.get(rel_path)
        
        status = ""
        p1_hash, p2_hash = None, None
        p1_loc, p2_loc = 0, 0
        p1_funcs, p2_funcs = [], []
        
        if p1 and p2:
            p1_hash = compute_hash(p1)
            p2_hash = compute_hash(p2)
            if p1_hash == p2_hash:
                status = "IDENTICAL"
            else:
                status = "MODIFIED"
        elif p1 and not p2:
            status = "REMOVED"
        elif p2 and not p1:
            status = "NEW"
            new_files_to_copy.append(p2)
            
        inventory[rel_path] = {
            "status": status,
            "ext": os.path.splitext(rel_path)[1].lower()
        }
        
        # detailed analysis for modified files
        if status == "MODIFIED":
            if inventory[rel_path]["ext"] in ['.py', '.m']:
                p1_loc = count_loc(p1)
                p2_loc = count_loc(p2)
                p1_funcs = extract_functions(p1)
                p2_funcs = extract_functions(p2)
                
                try:
                    with open(p1, 'r', encoding='utf-8', errors='ignore') as f1, open(p2, 'r', encoding='utf-8', errors='ignore') as f2:
                        lines1 = f1.readlines()
                        lines2 = f2.readlines()
                        sm = difflib.SequenceMatcher(None, lines1, lines2)
                        similarity = sm.ratio()
                        
                        added = sum(1 for tag, i1, i2, j1, j2 in sm.get_opcodes() if tag in ('replace', 'insert') for _ in range(j1, j2))
                        removed = sum(1 for tag, i1, i2, j1, j2 in sm.get_opcodes() if tag in ('replace', 'delete') for _ in range(i1, i2))
                        
                        diffs[rel_path] = {
                            "similarity": round(similarity * 100, 2),
                            "loc_added": added,
                            "loc_removed": removed,
                            "net_growth": added - removed,
                            "funcs_added": list(set(p2_funcs) - set(p1_funcs)),
                            "funcs_removed": list(set(p1_funcs) - set(p2_funcs)),
                            "p1_loc": p1_loc,
                            "p2_loc": p2_loc
                        }
                except UnicodeDecodeError:
                    pass
                    
    # Copy new files to Original folder
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    for p2_file in new_files_to_copy:
        rel_path = os.path.relpath(p2_file, PART2_DIR)
        dest = os.path.join(OUTPUT_DIR, rel_path)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        try:
             shutil.copy2(p2_file, dest)
        except Exception as e:
             pass

    output_data = {
        "inventory": inventory,
        "diffs": diffs,
        "copied_new_files": len(new_files_to_copy)
    }
    
    with open("forensic_data.json", "w") as f:
        json.dump(output_data, f, indent=4)

if __name__ == "__main__":
    analyze()
