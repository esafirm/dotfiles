#!/usr/bin/env ruby

# frozen_string_literal: true

require 'tty-prompt'

git_command = ARGV[0]

## Translate git command cause the limitation of git alias
git_command = 'git branch --sort=-committerdate' if git_command == 'recent'

abort('Empty git command passed') if git_command.nil?

git_result = `#{git_command}`.chomp.split("\n")

abort('Invalid git command') if git_result.nil?

prompt = TTY::Prompt.new
selected = prompt.select('Choose branch:', git_result, filter: true)

return if selected.include?('*')

system "git checkout #{selected}"
