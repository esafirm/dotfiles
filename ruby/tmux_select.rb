#!/usr/bin/env ruby

# frozen_string_literal: true

require 'tty-prompt'

# Get list of tmux sessions
sessions_raw = `tmux ls 2>/dev/null`.chomp
if sessions_raw.empty?
  puts "No tmux sessions found. Creating a new one..."
  exec "tmux new-session"
end

sessions = sessions_raw.split("\n").map { |line| line.split(':').first }

prompt = TTY::Prompt.new
selected = prompt.select("Choose tmux session to attach:", sessions + ["(New Session)", "(Exit)"], filter: true)

case selected
when "(Exit)"
  exit
when "(New Session)"
  print "Enter new session name: "
  name = gets.chomp
  exec "tmux new-session -s #{name}" unless name.empty?
  exec "tmux new-session"
else
  exec "tmux attach -t #{selected}"
end
