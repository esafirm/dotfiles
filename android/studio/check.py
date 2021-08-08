#!/usr/bin/env python3

import sys
import inquirer
import glob

IS_INTELLIJ = False

if len(sys.argv) < 2:
    questions = [
        inquirer.List(
            'platform',
            message="What IDE you want to check",
            choices=["Android Studio", "IntelliJ"]
        )
    ]
    answers = inquirer.prompt(questions)

    IS_INTELLIJ = answers['platform'] == "IntelliJ"
else:
    input = sys.argv[2]
    if input != "studio" and input != "intellij":
        print("You must choose between 'studio' or 'intellij' to check")
        sys.exit()

results = glob.glob("/Users/esafirm/Library/Application Support/JetBrains/*")

for res in results:
    paths = res.split('/')
    item = paths[len(paths) - 1]
    print(item)
