import os
import shutil

PART1_DIR = r"C:\fun\BTC-price-prediction-using-sentimental-analysis"
PART2_DIR = r"D:\Clone Repo\BTC-price-prediction-using-sentimental-analysis"
PART3_DIR = r"D:\Sentiment Analysis in Cryptocurrency Trading"

# Directories to create
PART3_DIRS = [
    "docs", "analysis", "migration", "reports", "reference", 
    "generated", "new", "legacy"
]

# Modules to preserve exactly as they are from PART-2
PRESERVE_MODULES = [
    "dashboard", "portfolio", "forecasting", "database", 
    "sentiment_analysis", "data_ingestion", "best_model", "core.py"
]

# Ignore files to save space in reference folders
def ignore_patterns(path, names):
    return [n for n in names if n.endswith('.csv') or n.endswith('.mat') or n == '.git' or n == '.env' or n == '__pycache__']

def setup_directories():
    print(f"Creating base structure in {PART3_DIR}")
    for d in PART3_DIRS:
        os.makedirs(os.path.join(PART3_DIR, d), exist_ok=True)

def copy_references():
    ref_part1 = os.path.join(PART3_DIR, "reference", "PART1_REFERENCE")
    ref_part2 = os.path.join(PART3_DIR, "reference", "PART2_REFERENCE")
    
    print("Copying PART-1 reference...")
    if not os.path.exists(ref_part1):
        shutil.copytree(PART1_DIR, ref_part1, ignore=ignore_patterns)
        
    print("Copying PART-2 reference...")
    if not os.path.exists(ref_part2):
        shutil.copytree(PART2_DIR, ref_part2, ignore=ignore_patterns)

def migrate_preserved_modules():
    print("Migrating preserved modules from PART-2...")
    for mod in PRESERVE_MODULES:
        src = os.path.join(PART2_DIR, mod)
        dest = os.path.join(PART3_DIR, mod)
        
        if os.path.exists(src):
            if os.path.isdir(src):
                if not os.path.exists(dest):
                    shutil.copytree(src, dest)
            else:
                shutil.copy2(src, dest)

if __name__ == "__main__":
    setup_directories()
    copy_references()
    migrate_preserved_modules()
    print("Phase 1 & 2 Migration Complete.")
