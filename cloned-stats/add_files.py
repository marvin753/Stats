#!/usr/bin/env python3
"""
Simple script to add Swift files to Xcode project.pbxproj
"""
import os
import uuid
import re

def generate_uuid():
    """Generate a 24-character hex UUID for Xcode"""
    return uuid.uuid4().hex[:24].upper()

def add_files_to_project():
    project_file = 'Stats.xcodeproj/project.pbxproj'

    # Read the project file
    with open(project_file, 'r') as f:
        content = f.read()

    # Generate UUIDs for the new files
    files = {
        'ScreenshotCapture.swift': {
            'fileRef': generate_uuid(),
            'buildFile': generate_uuid()
        },
        'ScreenshotStateManager.swift': {
            'fileRef': generate_uuid(),
            'buildFile': generate_uuid()
        },
        'VisionAIService.swift': {
            'fileRef': generate_uuid(),
            'buildFile': generate_uuid()
        }
    }

    print("Generated UUIDs:")
    for filename, uuids in files.items():
        print(f"  {filename}:")
        print(f"    File Ref: {uuids['fileRef']}")
        print(f"    Build File: {uuids['buildFile']}")

    # Find the PBXBuildFile section
    build_file_section = re.search(r'(/\* Begin PBXBuildFile section \*/.*?/\* End PBXBuildFile section \*/)', content, re.DOTALL)
    if build_file_section:
        build_file_end = build_file_section.group(1)

        # Add new build files
        new_build_files = ""
        for filename, uuids in files.items():
            new_build_files += f"\t\t{uuids['buildFile']} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {uuids['fileRef']} /* {filename} */; }};\n"

        # Insert before "End PBXBuildFile"
        content = content.replace('/* End PBXBuildFile section */', new_build_files + '/* End PBXBuildFile section */')
        print("\n✅ Added PBXBuildFile entries")

    # Find the PBXFileReference section
    file_ref_section = re.search(r'(/\* Begin PBXFileReference section \*/.*?/\* End PBXFileReference section \*/)', content, re.DOTALL)
    if file_ref_section:
        # Add new file references
        new_file_refs = ""
        for filename, uuids in files.items():
            new_file_refs += f"\t\t{uuids['fileRef']} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};\n"

        # Insert before "End PBXFileReference"
        content = content.replace('/* End PBXFileReference section */', new_file_refs + '/* End PBXFileReference section */')
        print("✅ Added PBXFileReference entries")

    # Find the Modules group and add file references
    # Look for the Modules children array
    modules_pattern = r'(\/\* Modules \*\/ = \{[^}]+children = \([^)]+)\);'
    modules_match = re.search(modules_pattern, content, re.DOTALL)
    if modules_match:
        modules_children = modules_match.group(1)

        # Add new file references to Modules group
        new_refs = ""
        for filename, uuids in files.items():
            new_refs += f"\t\t\t\t{uuids['fileRef']} /* {filename} */,\n"

        content = content.replace(modules_children + ');', modules_children + ',\n' + new_refs + '\t\t\t);')
        print("✅ Added files to Modules group")

    # Find the Sources build phase and add build files
    # Look for PBXSourcesBuildPhase section for Stats target
    sources_pattern = r'(\/\* Sources \*\/ = \{[^}]+files = \([^)]+)\);'
    for match in re.finditer(sources_pattern, content, re.DOTALL):
        sources_files = match.group(1)

        # Add new build file references
        new_build_refs = ""
        for filename, uuids in files.items():
            new_build_refs += f"\t\t\t\t{uuids['buildFile']} /* {filename} in Sources */,\n"

        # Only add to the first (main) Sources phase
        content = content.replace(sources_files + ');', sources_files + ',\n' + new_build_refs + '\t\t\t);', 1)
        print("✅ Added files to Sources build phase")
        break

    # Write back the modified project file
    with open(project_file, 'w') as f:
        f.write(content)

    print("\n✅ Project file updated successfully!")
    print("📝 Added 3 new Swift files to the project")
    print("🔨 Ready to rebuild with ./build-swift.sh")

if __name__ == '__main__':
    add_files_to_project()
