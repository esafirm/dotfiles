#!/usr/bin/env python3

import os
import sys
import shutil
import glob
from pathlib import Path

# Choices prompt
import inquirer


questions = [
    inquirer.List(
        'platform',
        message="What IDE you want to check",
        choices=["Android Studio", "IntelliJ"]
    )
]
answers = inquirer.prompt(questions)

# Determine the directory
platform = answers['platform']
if platform == 'Android Studio':
    base_dir = str(Path.home()) + "/Library/Application Support/Google/"
elif platform == 'IntelliJ':
    base_dir = str(Path.home()) + "/Library/Application Support/JetBrains/"

# Get path for choices
path_choices = []
for path in glob.glob(base_dir + "*"):
    segments = path.split('/')
    item = segments[len(segments) - 1]
    path_choices.append(item)

questions = [
    inquirer.List(
        'path',
        message="In what directory you want to install this?",
        choices=path_choices
    )
]
answers = inquirer.prompt(questions)

current_path = os.getcwd()
install_path = base_dir + answers['path'] + "/"

print("Path: " + install_path)
answer = input("Is this the right path? Y/n:  ")

if answer != "Y":
    print("Run again if you have the right path")
    sys.exit()

if os.path.exists(install_path) == False:
    print("IDE path not exist")
    sys.exit()

files = []
for file in os.listdir(current_path):
    if "." not in file:
        files.append(file)

print("Files ready to be replaced: {}".format(len(files)))

for file in files:
    studio_file = install_path + file
    current_file = current_path + "/" + file

    # Removing files in IDE dir
    if os.path.exists(studio_file):
        shutil.rmtree(studio_file)
        print("Removing: {}".format(studio_file))

    # Copy dotfiles to IDE dir
    os.symlink(current_file, studio_file)
    print("Create link for: {}".format(current_file))


print("Done.")
