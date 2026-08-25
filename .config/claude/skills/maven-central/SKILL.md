---
name: maven-central
description: Search for and download artifacts from the Maven Central repository. Use when you need to find dependency coordinates, check for the latest versions of a library, or download JAR/POM files directly.
---

# Maven Central

## Overview

This skill allows you to search for artifacts on Maven Central, list all available versions for a given groupId and artifactId, and download specific artifacts (JARs, POMs, sources, etc.) directly to your workspace.

## Capabilities

### 1. Search for Artifacts
Search Maven Central using keyword queries, or specific group/artifact criteria.

**Example Usage:**
- `node scripts/maven_search.cjs "guava"`
- `node scripts/maven_search.cjs "g:org.apache.logging.log4j AND a:log4j-core"`

### 2. List Versions
List available versions for a specific artifact.

**Example Usage:**
- `node scripts/maven_versions.cjs com.google.guava guava`

### 3. Download Artifacts
Download a specific version of an artifact. Supports JAR (default), sources, javadoc, and POM files.

**Example Usage:**
- Download JAR: `node scripts/maven_download.cjs com.google.guava guava 31.1-jre`
- Download Sources: `node scripts/maven_download.cjs com.google.guava guava 31.1-jre sources jar`
- Download POM: `node scripts/maven_download.cjs com.google.guava guava 31.1-jre "" pom`

## Workflow

1. **Search**: Start by searching for the library if you don't know the exact coordinates.
   - `node scripts/maven_search.cjs <query>`
2. **Identify Versions**: Once you have the `groupId` and `artifactId`, list the available versions.
   - `node scripts/maven_versions.cjs <groupId> <artifactId>`
3. **Download**: Download the desired version and classifier.
   - `node scripts/maven_download.cjs <groupId> <artifactId> <version> [classifier] [extension] [outputDir]`

## Resources

### scripts/
- `maven_search.cjs`: Search for artifacts.
- `maven_versions.cjs`: List versions for a specific artifact.
- `maven_download.cjs`: Download artifacts from Maven Central.
