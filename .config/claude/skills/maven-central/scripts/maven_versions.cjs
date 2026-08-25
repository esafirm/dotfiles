#!/usr/bin/env node

/**
 * Maven Central Versions Script
 * Usage: node maven_versions.cjs <groupId> <artifactId> [rows]
 */

const https = require('https');

const groupId = process.argv[2];
const artifactId = process.argv[3];
const rows = process.argv[4] || 20;

if (!groupId || !artifactId) {
  console.error('Usage: node maven_versions.cjs <groupId> <artifactId> [rows]');
  process.exit(1);
}

const url = `https://search.maven.org/solrsearch/select?q=g:${encodeURIComponent(groupId)}+AND+a:${encodeURIComponent(artifactId)}&core=gav&rows=${rows}&wt=json`;

const options = {
  headers: {
    'User-Agent': 'Mozilla/5.0 (Gemini CLI; Maven Central Skill)'
  }
};

https.get(url, options, (res) => {
  let data = '';
  res.on('data', (chunk) => { data += chunk; });
  res.on('end', () => {
    try {
      const json = JSON.parse(data);
      if (json.response && json.response.docs) {
        const docs = json.response.docs;
        if (docs.length === 0) {
          console.log('No versions found.');
        } else {
          console.log(`Found ${json.response.numFound} versions (showing top ${docs.length}):\n`);
          docs.forEach((doc, index) => {
            console.log(`${index + 1}. ${doc.v}`);
          });
        }
      } else {
        console.error('Unexpected response format from Maven Central.');
      }
    } catch (e) {
      console.error('Error parsing response:', e.message);
    }
  });
}).on('error', (err) => {
  console.error('Error fetching data:', err.message);
});
