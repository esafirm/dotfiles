import zipfile
import sys
import os

def list_jar(jar_path):
    with zipfile.ZipFile(jar_path, 'r') as jar:
        for info in jar.infolist():
            print(info.filename)

def view_manifest(jar_path):
    with zipfile.ZipFile(jar_path, 'r') as jar:
        try:
            manifest = jar.read('META-INF/MANIFEST.MF').decode('utf-8')
            print(manifest)
        except KeyError:
            print("Error: META-INF/MANIFEST.MF not found.")

def extract_file(jar_path, file_to_extract, dest_path='.'):
    with zipfile.ZipFile(jar_path, 'r') as jar:
        jar.extract(file_to_extract, path=dest_path)
        print(f"Extracted {file_to_extract} to {dest_path}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python jar_explorer.py <command> <jar_path> [args]")
        print("Commands: list, manifest, extract <file>")
        sys.exit(1)

    command = sys.argv[1]
    jar_path = sys.argv[2]

    if command == "list":
        list_jar(jar_path)
    elif command == "manifest":
        view_manifest(jar_path)
    elif command == "extract":
        if len(sys.argv) < 4:
            print("Error: Missing file to extract.")
            sys.exit(1)
        extract_file(jar_path, sys.argv[3])
    else:
        print(f"Unknown command: {command}")
