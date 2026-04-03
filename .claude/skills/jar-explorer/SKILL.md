---
name: jar-explorer
description: Explore contents of JAR files and decompile Java class files. Use when you need to understand the internal structure of a JAR, view its manifest, or read the source code of a compiled .class file.
---

# JAR Explorer Skill

This skill provides tools and procedures for exploring Java Archive (JAR) files and decompiling their contents into readable Java source code.

## Key Features

1.  **List JAR Contents**: Enumerate all files and directories inside a JAR.
2.  **View Manifest**: Extract and display the `META-INF/MANIFEST.MF` file.
3.  **Decompile Class Files**: Convert `.class` files back to `.java` source code using the bundled CFR decompiler.
4.  **Extract Resources**: Extract any file from the JAR to the local filesystem.

## Workflows

### 1. List Contents of a JAR
To see what's inside a JAR file, use the `jar_explorer.py` script:
```bash
python3 scripts/jar_explorer.py list <path_to_jar>
```

### 2. View the Manifest
The manifest file often contains metadata like the version and main class:
```bash
python3 scripts/jar_explorer.py manifest <path_to_jar>
```

### 3. Decompile a Class File
To decompile a specific class file into Java source, use the `decompile.sh` script. This requires Java (JRE) to be installed in the environment.
```bash
# Example: Decompile com.example.MyClass from myapp.jar into the current directory
./scripts/decompile.sh <path_to_jar> <fully_qualified_class_name> [output_directory]
```
The script uses the CFR decompiler (`assets/cfr-0.152.jar`).

### 4. Extract a Specific File
If you need to pull a resource (e.g., a `.properties` or `.xml` file) out of the JAR:
```bash
python3 scripts/jar_explorer.py extract <path_to_jar> <file_path_in_jar>
```

## Troubleshooting

- **Java Not Found**: The decompiler requires Java. If `java` is not in your path, you will only be able to list and extract files.
- **Class Not Found**: When decompiling, ensure you use the fully qualified class name (e.g., `com.example.Main`) or the path inside the JAR (e.g., `com/example/Main.class`).
- **Permissions**: Ensure scripts in the `scripts/` directory have execution permissions (`chmod +x scripts/decompile.sh`).

## Bundled Resources

- **scripts/jar_explorer.py**: Python script for listing, manifest viewing, and extraction.
- **scripts/decompile.sh**: Shell script wrapper for the CFR decompiler.
- **assets/cfr-0.152.jar**: The CFR Java decompiler.
