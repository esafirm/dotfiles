#!/usr/bin/env ruby

# frozen_string_literal: true

require 'tty-prompt'
require_relative 'arg_parser'

# Here's the options of the parameters
# command: recent
# mode: select, multiselect
# action: checkout, delete, log

ARGS = ARGV.parse_named_params
command, mode, action = ARGS.values_at(
  :command, :mode, :action
)

## Translate git command cause the limitation of git alias
git_command = 'git branch --sort=-committerdate' if command == 'recent'

abort('Empty git command passed') if git_command.nil?

git_result = `#{git_command}`.chomp.split("\n")

abort('Invalid git command') if git_result.nil?

## Show prompt
prompt = TTY::Prompt.new
label = "Choose branch to #{action}:"

case mode
when 'select'
  selected = prompt.select(label, git_result, filter: true)
when 'multiselect'
  selected = prompt.multi_select(label, git_result, filter: true)
else
  abort("Mode #{mode} is not defined")
end

return if selected.include?('*')

selected_string = selected.map(&:chomp).join(' ') if selected.is_a?(Array)

## Execute action
case action
when 'checkout'
  system "git checkout #{selected}"
when 'delete'
  system "git branch -D #{selected_string}"
when 'log'
  system "git log --pretty=format:'%C(yellow)%h %Cred%ad %Cblue%an%Cgreen%d %Creset%s' --date=relative #{selected}"
when 'rebase'
  system "git rebase #{selected}"
when 'merge'
  system "git merge #{selected}"
else
  abort("Action #{action} is not defined")
end
