#!/usr/bin/env python3

import os
import sys
import shutil
from pathlib import Path

if len(sys.argv) < 2:
    print("./install.py [version] [variant]")
    print("\nvariants: \n- prod (default)\n- preview")
    sys.exit()

FLAVOR = sys.argv[2] if len(sys.argv) == 3 else "prod"
DIR_NAME = "AndroidStudioPreview" if FLAVOR == "preview" else "AndroidStudio"

current_path = os.getcwd()
studio_path = str(Path.home()) + "/Library/Application Support/Google/" + DIR_NAME + sys.argv[1] + "/"

print("Path: " + studio_path)
answer = input("Is this the right path? Y/n:  ")

if answer != "Y":
    print("Run again if you have the right path")
    sys.exit()

if os.path.exists(studio_path) == False:
    print("Android Studio path not exist")
    sys.exit()

files = []
for file in os.listdir(current_path):
    if "." not in file:
        files.append(file)

print("Files ready to be replaced: {}".format(len(files)))

for file in files:
    studio_file = studio_path + file
    current_file = current_path + "/" + file

    # Removing files in studio dir
    if os.path.exists(studio_file):
        shutil.rmtree(studio_file)
        print("Removing: {}".format(studio_file))

    # Copy dotfiles to studio dir
    os.symlink(current_file, studio_file)
    print("Create link for: {}".format(current_file))


print("Done.")
