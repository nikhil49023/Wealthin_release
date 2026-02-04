#!/usr/bin/env python3
"""
Script to fix withOpacity deprecation warnings in Flutter code.
Replaces .withOpacity(x) with .withValues(alpha: x)
"""
import os
import re
from pathlib import Path

def fix_with_opacity(content):
    """Replace .withOpacity(value) with .withValues(alpha: value)"""
    # Pattern matches: .withOpacity(0.5) or .withOpacity(0.5,)
    pattern = r'\.withOpacity\(([^)]+)\)'
    
    def replacer(match):
        opacity_value = match.group(1).strip().rstrip(',')
        return f'.withValues(alpha: {opacity_value})'
    
    return re.sub(pattern, replacer, content)

def process_dart_file(file_path):
    """Process a single Dart file"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original = content
        fixed = fix_with_opacity(content)
        
        if fixed != original:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(fixed)
            return True
        return False
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return False

def main():
    """Process all Dart files in lib directory"""
    lib_dir = Path('lib')
    dart_files = list(lib_dir.rglob('*.dart'))
    
    print(f"Found {len(dart_files)} Dart files")
    fixed_count = 0
    
    for dart_file in dart_files:
        if process_dart_file(dart_file):
            fixed_count += 1
            print(f"✓ Fixed: {dart_file}")
    
    print(f"\n✅ Fixed {fixed_count} files")

if __name__ == '__main__':
    main()
