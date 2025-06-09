#!/usr/bin/env ruby

# frozen_string_literal: true

require 'tty-prompt'
require_relative 'arg_parser'

# Get available git branches
def get_git_branches
  output = `git branch -a`
  
  if $?.success?
    branches = output.split("\n").map { |branch| branch.gsub('*', '').strip }
    branches.reject(&:empty?)
  else
    puts "Error: Not a git repository or git command failed"
    exit 1
  end
end

# Get git log data
def get_git_commits(limit = 20, format = '%h | %s', branch = nil)
  branch_arg = branch ? "#{branch} " : ""
  output = `git log #{branch_arg}-n #{limit} --pretty=format:'#{format}'`
  
  if $?.success?
    output.split("\n")
  else
    puts "Error: Not a git repository or git command failed"
    exit 1
  end
end

# Extract commit hash from the selected line
def extract_commit_hash(selected_line)
  selected_line.split('|').first.strip
end

# Copy to clipboard (macOS)
def copy_to_clipboard(text)
  begin
    clip = IO.popen('pbcopy', 'w')
    clip.puts(text)
    clip.close
    true
  rescue StandardError => e
    puts "Failed to copy to clipboard: #{e.message}"
    false
  end
end

# Main execution
ARGS = ARGV.parse_named_params
select_branch, limit = ARGS.values_at(
  :select_branch, :limit
)

limit = limit.to_i > 0 ? limit.to_i : 20  # Default to 20 if not specified
format = '%h | %s | %an | %ar'  # hash | subject | author name | relative date

prompt = TTY::Prompt.new

# Get branches and allow selection
if select_branch
  branches = get_git_branches
  branch_choices = ["current branch"] + branches
  selected_branch = prompt.select("Select a branch:", branch_choices, filter: true, per_page: 10)

  # Get commits from selected branch
  branch_arg = selected_branch == "current branch" ? nil : selected_branch
  commits = get_git_commits(limit, format, branch_arg)
else
  commits = get_git_commits(limit, format)
end

if commits.empty?
  puts "No commits found"
  exit 0
end

selected_commit_line = prompt.select('Select a commit:', commits, filter: true, per_page: 10)
commit_hash = extract_commit_hash(selected_commit_line)

puts "Selected commit hash: #{commit_hash}"

if copy_to_clipboard(commit_hash)
  puts "Commit hash copied to clipboard!"
end
