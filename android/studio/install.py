#!/usr/bin/env python3

import os
import sys
import shutil
from pathlib import Path

if len(sys.argv) < 2:
	print("./install.py [version] [variant]")
	print("\nvariants: \n- prod (default)\n- preview")
	sys.exit()

current_path = os.getcwd()
studio_path = str(Path.home()) + "/Library/Application\ Support/Google/AndroidStudioPreview" + sys.argv[1] + "/"

print("Path: " + studio_path)
answer = input("Is this the right path? Y/N")

if answer != "Y":
	sys.exit()

if os.path.exists(studio_path):
	print("Android Studio path not exist")
	sys.exit()

files = []
for file in os.listdir(current_path):
	if "." not in file:
		files.append(file)

for file in files:
	studio_file = studio_path + file
	current_file = current_path + "/" + file

	# Removing files in studio dir
	if os.path.exists(studio_file):
		shutil.rmtree(studio_file)

	# Copy dotfiles to studio dir
	os.system("ln -sF {} {}".format(current_file, studio_file))


print("Done.")