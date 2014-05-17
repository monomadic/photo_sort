#!/usr/bin/env ruby
require 'mini_exiftool'
require 'fileutils'
require 'pry'

INPUT_DIR   = 'in'
OUTPUT_DIR  = 'out'
DUPES_DIR   = 'out/_dupes'
ERROR_DIR   = 'error'
ROOT_DIR    = FileUtils.pwd

TEST_MODE = false

def write_dir_unless_exists(dir)
  unless Dir.exist?(dir)
    puts "  MKDIR -> #{dir}"
    FileUtils.mkdir dir
  end
end

def get_unique_filename(filename_pattern)
  increment = 1
  filename_to_attempt = filename_pattern.gsub('%%', increment.to_s)
  while File.exist?(filename_to_attempt)
    puts "Clashed: #{filename_to_attempt}"
    increment += 1

    # UGLY bit to test dupes of other sub-filenames.
    increment.each do |inc|
      if FileUtils.compare_file(filename_to_attempt, filename_pattern.gsub('%%', inc.to_s))
        fail "DUPE DETECTED: #{filename_to_attempt}, #{filename_pattern.gsub('%%', inc.to_s)}"
      end
    end
  end
  filename_pattern.gsub('%%', increment.to_s)
end

# check directories exist
[INPUT_DIR, OUTPUT_DIR, DUPES_DIR, ERROR_DIR].each do |dir|
  fail "Directory not found: #{dir}. Please create it." unless Dir.exist?(dir)
end

FileUtils.cd(INPUT_DIR, verbose: true)
Dir.glob('*.{jpg,JPG,jpeg,JPEG}') do |file|
  puts "Found: #{file}"
  photo = MiniExiftool.new(file)
  input_file = "#{ROOT_DIR}/#{INPUT_DIR}/#{file}"

  if photo.date_time_original.nil?
    puts "EXIF data not found for: #{file}"
    output_file = "#{ROOT_DIR}/#{ERROR_DIR}/#{file}"
  else
    date = photo.date_time_original.strftime '%Y-%m-%d-%H-%M-%S'
    output_file = "#{ROOT_DIR}/#{OUTPUT_DIR}/#{photo.date_time_original.year}/"
    output_file += "#{photo.date_time_original.month}/#{date}.jpg"

    if File.exist?(output_file)
      if FileUtils.compare_file(input_file, output_file)
        puts "  ** File duplicate found: #{output_file}"
        output_file = "#{ROOT_DIR}/#{DUPES_DIR}/#{date}.jpg"
      else
        output_file = "#{ROOT_DIR}/#{OUTPUT_DIR}/#{photo.date_time_original.year}/"
        output_file += "#{photo.date_time_original.month}/#{date}-%%.jpg"
        output_file = get_unique_filename(output_file)
        puts "  MV -> #{output_file}"
      end
    else
      # write year dir
      write_dir_unless_exists "#{ROOT_DIR}/#{OUTPUT_DIR}/#{photo.date_time_original.year}"
      # write month dir
      write_dir_unless_exists "#{ROOT_DIR}/#{OUTPUT_DIR}/#{photo.date_time_original.year}/#{photo.date_time_original.month}"
      puts "  MV -> #{output_file}"
    end
  end
  FileUtils.mv(input_file, output_file) unless File.exist?(output_file) || TEST_MODE
end
