#!/usr/bin/env node

/**
 * Maven Central Download Script
 * Usage: node maven_download.cjs <groupId> <artifactId> <version> [classifier] [extension] [outputDir]
 */

const https = require('https');
const fs = require('fs');
const path = require('path');

const groupId = process.argv[2];
const artifactId = process.argv[3];
const version = process.argv[4];
const classifier = process.argv[5] || '';
const extension = process.argv[6] || 'jar';
const outputDir = process.argv[7] || '.';

if (!groupId || !artifactId || !version) {
  console.error('Usage: node maven_download.cjs <groupId> <artifactId> <version> [classifier] [extension] [outputDir]');
  console.error('Example: node maven_download.cjs com.google.guava guava 31.1-jre "" jar .');
  console.error('Example: node maven_download.cjs com.google.guava guava 31.1-jre sources jar .');
  process.exit(1);
}

const groupPath = groupId.replace(/\./g, '/');
const filename = classifier 
  ? `${artifactId}-${version}-${classifier}.${extension}`
  : `${artifactId}-${version}.${extension}`;

const url = `https://repo1.maven.org/maven2/${groupPath}/${artifactId}/${version}/${filename}`;

if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

const outputPath = path.join(outputDir, filename);
const file = fs.createWriteStream(outputPath);

console.log(`Downloading ${url}...`);

const options = {
  headers: {
    'User-Agent': 'Mozilla/5.0 (Gemini CLI; Maven Central Skill)'
  }
};

https.get(url, options, (res) => {
  if (res.statusCode !== 200) {
    console.error(`Error: Received status code ${res.statusCode}`);
    fs.unlinkSync(outputPath);
    process.exit(1);
  }

  res.pipe(file);

  file.on('finish', () => {
    file.close();
    console.log(`Downloaded to ${outputPath}`);
  });
}).on('error', (err) => {
  console.error('Error downloading artifact:', err.message);
  fs.unlinkSync(outputPath);
  process.exit(1);
});
