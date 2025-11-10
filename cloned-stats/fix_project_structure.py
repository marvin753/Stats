#!/usr/bin/env python3
"""
Fix Xcode project.pbxproj file to correctly organize file references.

This script:
1. Removes 4 quiz Swift files from the Products group
2. Removes 3 screenshot Swift files from the Products group
3. Removes 3 screenshot Swift files from the Views group
4. Adds all 7 files to the Modules group
"""

import re
import sys
from pathlib import Path
from typing import Tuple, List


def read_project_file(file_path: Path) -> str:
    """Read the project.pbxproj file content."""
    with open(file_path, 'r', encoding='utf-8') as f:
        return f.read()


def write_project_file(file_path: Path, content: str) -> None:
    """Write the project.pbxproj file content."""
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)


def fix_group_children(content: str, group_uuid: str, uuids_to_remove: set[str],
                       uuids_to_add: List[Tuple[str, str]] = None) -> str:
    """
    Fix children array for a specific group.

    Args:
        content: Full file content
        group_uuid: UUID of the group to fix
        uuids_to_remove: Set of UUIDs to remove from children
        uuids_to_add: Optional list of (UUID, comment) tuples to add

    Returns:
        Updated content
    """
    # Find the group definition with its children array
    # Pattern: UUID /* name */ = { isa = PBXGroup; children = ( ... );
    pattern = rf'{group_uuid}\s*/\*[^*]*\*/\s*=\s*{{\s*isa\s*=\s*PBXGroup;\s*children\s*=\s*\('

    match = re.search(pattern, content, re.DOTALL)
    if not match:
        print(f"Warning: Could not find group {group_uuid}")
        return content

    # Find the start and end of the children array
    children_start = match.end()

    # Find the closing ); for the children array
    depth = 1
    i = children_start
    while i < len(content) and depth > 0:
        if content[i] == '(':
            depth += 1
        elif content[i] == ')':
            depth -= 1
            if depth == 0:
                # Check if followed by semicolon
                j = i + 1
                while j < len(content) and content[j] in ' \t\n':
                    j += 1
                if j < len(content) and content[j] == ';':
                    break
        i += 1

    children_end = i

    # Extract the children content
    children_content = content[children_start:children_end]

    # Parse each line in the children array
    lines = children_content.split('\n')
    new_lines = []

    for line in lines:
        # Check if line contains a UUID
        uuid_match = re.match(r'\s*([A-F0-9]{24})\s*/\*', line)
        if uuid_match:
            uuid = uuid_match.group(1)
            if uuid not in uuids_to_remove:
                new_lines.append(line)
        else:
            # Keep non-UUID lines (empty lines, whitespace)
            if line.strip():
                new_lines.append(line)

    # Add new entries if specified
    if uuids_to_add:
        # Determine indentation from existing lines
        indent = '\t\t\t\t'
        for line in new_lines:
            if line.strip() and not line.strip().startswith('/*'):
                indent_match = re.match(r'^(\s*)', line)
                if indent_match:
                    indent = indent_match.group(1)
                    break

        for uuid, comment in uuids_to_add:
            new_lines.append(f'{indent}{uuid} /* {comment} */,')

    # Reconstruct the children array
    new_children_content = '\n' + '\n'.join(new_lines) + '\n\t\t\t'

    # Replace in original content
    new_content = content[:children_start] + new_children_content + content[children_end:]

    return new_content


def main():
    """Main function to fix the project.pbxproj file."""
    project_file = Path('/Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats/Stats.xcodeproj/project.pbxproj')

    if not project_file.exists():
        print(f"Error: Project file not found at {project_file}")
        sys.exit(1)

    print("Reading project.pbxproj file...")
    content = read_project_file(project_file)
    original_size = len(content)
    print(f"Original file size: {original_size} bytes")

    # Define UUIDs
    quiz_uuids = {
        'CE7846D62EBA55C90007B6A3',  # KeyboardShortcutManager.swift
        'CE7846D72EBA55C90007B6A3',  # QuizAnimationController.swift
        'CE7846D82EBA55C90007B6A3',  # QuizHTTPServer.swift
        'CE7846D92EBA55C90007B6A3',  # QuizIntegrationManager.swift
    }

    screenshot_uuids = {
        'CE95E6522EC2896F0054DD69',  # ScreenshotCapture.swift
        'CE95E6542EC289960054DD69',  # ScreenshotStateManager.swift
        'CE95E6562EC289B20054DD69',  # VisionAIService.swift
    }

    all_uuids_to_add = [
        ('CE7846D62EBA55C90007B6A3', 'KeyboardShortcutManager.swift'),
        ('CE7846D72EBA55C90007B6A3', 'QuizAnimationController.swift'),
        ('CE7846D82EBA55C90007B6A3', 'QuizHTTPServer.swift'),
        ('CE7846D92EBA55C90007B6A3', 'QuizIntegrationManager.swift'),
        ('CE95E6522EC2896F0054DD69', 'ScreenshotCapture.swift'),
        ('CE95E6542EC289960054DD69', 'ScreenshotStateManager.swift'),
        ('CE95E6562EC289B20054DD69', 'VisionAIService.swift'),
    ]

    print("\n1. Removing quiz and screenshot files from Products group...")
    content = fix_group_children(
        content,
        '9A1410F6229E721100D29793',  # Products group
        quiz_uuids | screenshot_uuids
    )

    print("2. Removing screenshot files from Views group...")
    content = fix_group_children(
        content,
        '9A81C74A24499C4B00825D92',  # Views group
        screenshot_uuids
    )

    print("3. Adding all 7 files to Modules group...")
    content = fix_group_children(
        content,
        '9AB14B75248CEEC600DC6731',  # Modules group
        set(),  # Don't remove anything
        all_uuids_to_add
    )

    print("\nWriting updated project.pbxproj file...")
    write_project_file(project_file, content)
    new_size = len(content)
    print(f"New file size: {new_size} bytes (diff: {new_size - original_size:+d} bytes)")

    print("\n✓ Project file successfully updated!")
    print("\nNext steps:")
    print("1. Run: plutil -lint Stats.xcodeproj/project.pbxproj")
    print("2. Run: ./build-swift.sh")


if __name__ == '__main__':
    main()
