#!/bin/bash
# Usage: ./flatten_project.sh [source_dir] [target_dir]
SOURCE_DIR="${1:-.}"
TARGET_DIR="${2:-flattened_output}"

# Create target directory
mkdir -p "$TARGET_DIR"

# Find all files, excluding node_modules and hidden folders
find "$SOURCE_DIR" -type f -not -path "*/node_modules/*" -not -path "*/\.*/*" | while read -r filepath; do
    filename=$(basename "$filepath")
    
    # Ensure no filename conflict
    if [[ -e "$TARGET_DIR/$filename" ]]; then
        base="${filename%.*}"
        ext="${filename##*.}"
        if [[ "$base" == "$ext" ]]; then
            ext=""
        else
            ext=".$ext"
        fi
        filename="${base}_$(date +%s%N)$ext"
    fi
    
    cp "$filepath" "$TARGET_DIR/$filename"
    echo "Copied: $filepath -> $TARGET_DIR/$filename"
done

echo "✅ All files copied to '$TARGET_DIR', excluding node_modules and hidden folders."