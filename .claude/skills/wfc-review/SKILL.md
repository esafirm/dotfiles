---
name: wfc-review
description: Generate reviews for WFC (Work From Cafe) spots, primarily cafes. Use when you need to create a review for a place to work from, especially for Google Maps or web publishing.
---

# WFC Review Generator

## Overview

This skill generates detailed reviews for WFC spots (Work From Cafe locations). It creates comprehensive reviews suitable for personal documentation (Notion), Google Maps, and public sharing with high-quality visual badges.

## Workflow

The review generation follows this sequence:

1. **Detect Current Location**: Automatically determine your current location for context
2. **Ask for Place Information**: Cafe/restaurant name and specific location
3. **Collect Technical Metrics**: Automatically measure WiFi speed and temperature
4. **Research Online Reviews**: Fetch and summarize internet reviews for WFC suitability
5. **Gather User Input**: Personal experience and additional details
6. **Generate Formatted Review Package**: A folder containing all output formats

## Usage

### Interactive Mode
Simply invoke `/wfc-review` and I will:
1. Detect your location and ask for the cafe name.
2. Measure WiFi speed and temperature from your environment.
3. Analyze online reviews and gather your personal input.
4. **Generate a Review Package** in the `reviews/` folder.

### Command Line Mode
`node scripts/wfc_review.cjs "Name" "Location" 4.5`

## Output Formats (Review Package)

Each review creates a folder in `reviews/` with:

- **`notion.md`**: Optimized for Notion's "Paste" feature with properties, callouts, and clean layout.
- **`badge.html`**: A modern Glassmorphism visual badge. Open and screenshot to share!
- **`google-maps.txt`**: A concise version ready for Google Maps.
- **`review.md`**: A standard detailed markdown document.
- **`data.json`**: Structured JSON for personal databases or automation.

## Features

### 🚀 Notion-Optimized
Generate reviews that look beautiful in Notion instantly. Just copy and paste the content of `notion.md`.

### 🎨 Modern Visual Badges
Create high-quality, glassmorphism-style badges that show key metrics (WiFi, Temp, Rating) at a glance.

### 📶 Automatic Metrics
Claude automatically collects real-time WiFi speed and temperature data from your current environment.

### 📂 Automated Archiving
All reviews are automatically organized in a local `reviews/` directory for easy reference.

## Resources

### scripts/
- `wfc_review.cjs`: Main review generator and package creator
