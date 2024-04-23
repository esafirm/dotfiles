#!/usr/bin/env ruby

# frozen_string_literal: true

require 'tty-prompt'

# Dummy logs for demonstration
commits = [
  "Commit 1: Fix bug #123",
  "Commit 2: Implement feature XYZ",
  "Commit 3: Refactor codebase",
  "Commit 4: Update documentation"
]

prompt = TTY::Prompt.new

selected_commit = prompt.select('Select commit hash', commits, filter: true)

puts "Selected commit #{selected_commit}"
