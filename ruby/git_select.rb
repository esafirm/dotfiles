#!/usr/bin/env ruby

# frozen_string_literal: true

require 'tty-prompt'

git_command = ARGV[0]

abort('Empty git command passed') if git_command.nil?

git_result = `git branch`.chomp.split("\n")

abort('Invalid git command') if git_result.nil?

prompt = TTY::Prompt.new
selected = prompt.select('Choose branch:', git_result)

return if selected.include?('*')

system "git checkout #{selected}"
