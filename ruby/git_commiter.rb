#!/usr/bin/env ruby

# frozen_string_literal: true

require 'tty-prompt'

commit_msg = ARGV.empty? ? abort('No commit message provided') : ARGV.first

## JIRA ticket pattern
ticket_pattern = /([A-Z])+\-([0-9])+/

if ticket_pattern.match?(commit_msg)
  ticket = commit_msg.match(ticket_pattern)[0]
  
  # Ticket found!
  if commit_msg.index(ticket) != 0
    abort('Ticket is provided but not in the beginning of the commit message')
  end
else
  
  # Check if branch include ticket number
  branch = `git branch --show-current`.chomp
  if ticket_pattern.match?(branch)
    ticket = branch.match(ticket_pattern)[0]
    commit_msg = "#{ticket}: #{commit_msg}"
  else
    abort('No ticket number found in the commit message or branch name')
  end
end

# Get other arguments and passed it to git commit
system "git commit -m '#{commit_msg}' #{ARGV[1..-1].join(" ")}"
