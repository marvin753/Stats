#!/usr/bin/env ruby
require 'xcodeproj'

# Open the Xcode project
project_path = 'Stats.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the Stats target
target = project.targets.find { |t| t.name == 'Stats' }

# Find the Modules group
modules_group = project.main_group['Stats']['Modules']

# Files to add
files = [
  'ScreenshotCapture.swift',
  'ScreenshotStateManager.swift',
  'VisionAIService.swift'
]

files.each do |filename|
  file_path = "Stats/Modules/#{filename}"

  # Check if file already exists in project
  existing = modules_group.files.find { |f| f.path == filename }

  unless existing
    # Add file reference to the Modules group
    file_ref = modules_group.new_file(file_path)

    # Add file to the Stats target's compile sources
    target.add_file_references([file_ref])

    puts "✅ Added #{filename} to project"
  else
    puts "⚠️  #{filename} already in project"
  end
end

# Save the project
project.save

puts "\n✅ Project updated successfully!"
puts "📝 New files added to Stats target"
puts "🔨 Ready to rebuild"
