#!/usr/bin/env node

/**
 * Maven Central Search Script
 * Usage: node maven_search.cjs <query> [rows]
 */

const https = require('https');

const query = process.argv[2];
const rows = process.argv[3] || 20;

if (!query) {
  console.error('Usage: node maven_search.cjs <query> [rows]');
  process.exit(1);
}

const url = `https://search.maven.org/solrsearch/select?q=${encodeURIComponent(query)}&rows=${rows}&wt=json`;

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
          console.log('No artifacts found.');
        } else {
          console.log(`Found ${json.response.numFound} artifacts (showing top ${docs.length}):\n`);
          docs.forEach((doc, index) => {
            console.log(`${index + 1}. ${doc.id} (Latest: ${doc.latestVersion})`);
            if (doc.g && doc.a) {
                console.log(`   Group: ${doc.g}, Artifact: ${doc.a}`);
            }
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
