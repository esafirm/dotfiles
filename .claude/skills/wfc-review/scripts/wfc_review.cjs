#!/usr/bin/env node

/**
 * WFC Review Generator - Interactive Claude Code Version
 * This script is designed to work with Claude Code's AskUserQuestion functionality
 * Workflow: Collect metrics → Analyze online reviews → User input → Generate markdown → Create badge
 */

const fs = require('fs');
const path = require('path');

const reviewTemplates = {
  excellent: {
    atmosphere: ['Vibrant and welcoming', 'Cozy and comfortable', 'Modern and stylish', 'Warm and inviting'],
    service: ['Exceptionally friendly staff', 'Quick and efficient service', 'Attentive and helpful', 'Outstanding customer service'],
    food: ['Delicious and fresh', 'High-quality ingredients', 'Perfectly prepared', 'Amazing flavor combinations'],
    recommendation: ['Highly recommended', 'A must-try', 'Definitely worth visiting', 'One of my favorites']
  },
  good: {
    atmosphere: ['Pleasant environment', 'Nice ambiance', 'Comfortable seating', 'Good overall vibe'],
    service: ['Friendly staff', 'Helpful team', 'Quick service', 'Professional service'],
    food: ['Tasty options', 'Good quality', 'Satisfying meals', 'Solid choices'],
    recommendation: ['Worth a visit', 'Good option for quick meal', 'Would recommend', 'Solid choice']
  },
  average: {
    atmosphere: ['Standard food court setting', 'Typical WFC environment', 'Basic seating', 'Functional space'],
    service: ['Standard service', 'Average speed', 'Helpful when needed', 'Routine experience'],
    food: ['Okay quality', 'Standard offerings', 'Decent options', 'Acceptable meals'],
    recommendation: ['Fine for quick bite', 'Standard WFC experience', 'Basic but reliable', 'Nothing special but functional']
  }
};

function getRandom(array) {
  return array[Math.floor(Math.random() * array.length)];
}

function getTemplate(rating) {
  if (rating >= 4.5) return 'excellent';
  if (rating >= 3.5) return 'good';
  return 'average';
}

function detectCurrentLocation() {
  // Try to get location from environment
  try {
    // Check for common environment variables or system info
    if (process.env.TZ) {
      const timezone = process.env.TZ;
      if (timezone.includes('Australia/Sydney')) return 'Sydney, Australia';
      if (timezone.includes('America/New_York')) return 'New York, USA';
      if (timezone.includes('America/Los_Angeles')) return 'Los Angeles, USA';
      if (timezone.includes('Europe/London')) return 'London, UK';
      if (timezone.includes('Asia/Tokyo')) return 'Tokyo, Japan';
      if (timezone.includes('Asia/Singapore')) return 'Singapore';
      if (timezone.includes('Asia/Jakarta')) return 'Jakarta, Indonesia';
    }
  } catch (error) {
    // Silently fall back
  }

  // Default fallback
  return 'Current Location';
}

function generateBadgeHtml(name, wifiSpeed, temperature, rating, wfcSuitability, currentLocation, powerOutlets) {
  const stars = '⭐'.repeat(Math.floor(rating)) + (rating % 1 >= 0.5 ? '⭐' : '');
  const suitabilityColor = wfcSuitability === 'Excellent' ? '#22c55e' : wfcSuitability === 'Good' ? '#3b82f6' : '#f97316';
  
  // Format location: Try to split "City, Country" or similar
  let locationDisplay = currentLocation.toUpperCase();
  if (currentLocation.includes(',')) {
    const parts = currentLocation.split(',').map(p => p.trim().toUpperCase());
    if (parts.length >= 2) {
      locationDisplay = `${parts[0]}${parts[2] ? `, ${parts[1]}` : ''}, ${parts[parts.length-1]}`;
    }
  }

  return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>${name} - WFC Badge</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Lexend:wght@400;700;800&display=swap');

        body {
            margin: 0;
            padding: 40px;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            background-color: #fef3c7;
            background-image: radial-gradient(#d1d5db 1px, transparent 1px);
            background-size: 20px 20px;
            font-family: 'Lexend', sans-serif;
        }

        .badge {
            background: #fffcf2;
            border: 4px solid #000;
            border-radius: 4px;
            padding: 32px;
            box-shadow: 12px 12px 0px 0px #000;
            text-align: left;
            width: 380px;
            position: relative;
            overflow: hidden;
        }

        .icon-box {
            position: absolute;
            top: 20px;
            right: 20px;
            width: 48px;
            height: 48px;
            background: #ea580c;
            border: 3px solid #000;
            box-shadow: 4px 4px 0px 0px #000;
            display: flex;
            justify-content: center;
            align-items: center;
            font-size: 24px;
        }

        .subtitle {
            font-weight: 800;
            font-size: 14px;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 8px;
            color: #000;
        }

        h1 {
            margin: 0;
            font-size: 32px;
            font-weight: 800;
            color: #000;
            line-height: 1.1;
            display: block;
        }

        .squiggle-container {
            width: 120px;
            height: 12px;
            margin: 8px 0 24px 0;
        }

        .rating-container {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 24px;
        }

        .rating-box {
            background: #fef3c7;
            border: 3px solid #000;
            padding: 8px 16px;
            font-weight: 800;
            box-shadow: 4px 4px 0px 0px #000;
        }

        .metrics {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 12px;
            margin-top: 24px;
        }

        .metric {
            background: #fff;
            border: 3px solid #000;
            padding: 12px;
            box-shadow: 4px 4px 0px 0px #000;
        }

        .metric.full {
            grid-column: span 2;
        }

        .metric .label {
            display: block;
            font-size: 10px;
            font-weight: 800;
            text-transform: uppercase;
            color: #4b5563;
            margin-bottom: 4px;
        }

        .metric .value {
            font-size: 16px;
            font-weight: 800;
            color: #000;
        }

        .wfc-tag {
            background: ${suitabilityColor};
            border: 3px solid #000;
            padding: 10px;
            font-weight: 800;
            text-align: center;
            text-transform: uppercase;
            font-size: 14px;
            margin-top: 24px;
            box-shadow: 6px 6px 0px 0px #000;
        }

        .footer {
            margin-top: 32px;
            font-size: 11px;
            font-weight: 700;
            display: flex;
            align-items: center;
            gap: 6px;
            color: #4b5563;
        }

        .dot {
            width: 8px;
            height: 8px;
            background: #ea580c;
            border: 2px solid #000;
            border-radius: 50%;
        }
    </style>
</head>
<body>
    <div class="badge">
        <div class="icon-box">☕</div>
        <div class="subtitle">WFC Verified Spot</div>
        <h1>${name}</h1>
        <div class="squiggle-container">
            <svg width="120" height="12" viewBox="0 0 120 12" xmlns="http://www.w3.org/2000/svg">
                <path d="M0 6 C 10 0, 20 12, 30 6 C 40 0, 50 12, 60 6 C 70 0, 80 12, 90 6 C 100 0, 110 12, 120 6" stroke="black" stroke-width="4" fill="none" stroke-linecap="round" style="transform: translate(2px, 2px); opacity: 0.2;"/>
                <path d="M0 6 C 10 0, 20 12, 30 6 C 40 0, 50 12, 60 6 C 70 0, 80 12, 90 6 C 100 0, 110 12, 120 6" stroke="#ea580c" stroke-width="4" fill="none" stroke-linecap="round"/>
            </svg>
        </div>

        <div class="rating-container">
            <div class="rating-box">${rating} / 5.0</div>
            <div style="font-size: 20px;">${stars}</div>
        </div>

        <div class="metrics">
            <div class="metric">
                <span class="label">WiFi Speed</span>
                <span class="value">⚡ ${wifiSpeed}</span>
            </div>
            <div class="metric">
                <span class="label">Comfort</span>
                <span class="value">🌡️ ${temperature}</span>
            </div>
            <div class="metric full">
                <span class="label">Power Access</span>
                <span class="value">🔌 ${powerOutlets}</span>
            </div>
        </div>

        <div class="wfc-tag">Status: ${wfcSuitability}</div>

        <div class="footer">
            <div class="dot"></div>
            <span>LOCATED IN ${locationDisplay}</span>
        </div>
    </div>
</body>
</html>`;
}

function generateMarkdownReview(name, location, rating, wifiSpeed, temperature, onlineReviews, userExperience, atmosphere, service, food, highlights, verdict, currentLocation, powerOutlets) {
  const stars = '⭐'.repeat(Math.floor(rating)) + (rating % 1 >= 0.5 ? '⭐' : '');
  const wfcSuitability = rating >= 4.5 ? 'Excellent' : rating >= 3.5 ? 'Good' : 'Average';

  return `# ${name} @ ${location}

## 📊 Rating
**${rating}/5** ${stars}

## 📍 Location Context
**Reviewer Location:** ${currentLocation}

## 🌡️ Technical Metrics
- **WiFi Speed:** ${wifiSpeed}
- **Temperature:** ${temperature}
- **Power Outlets:** ${powerOutlets}

## 📋 Online Review Summary
${onlineReviews}

## 👤 Personal Experience
${userExperience}

## 🏢 Atmosphere & Ambiance
${atmosphere}

## 👥 Service Quality
${service}

## 🍽️ Food & Drink
${food}

${highlights ? `## ✨ Highlights
${highlights.split(',').map(h => `- ${h.trim()}`).join('\n')}` : ''}

## 📝 Final Verdict
${verdict}

## 🎯 WFC Suitability
**${wfcSuitability}** - This location is ${wfcSuitability.toLowerCase()} for working from cafe.

---
*Generated on ${new Date().toLocaleDateString()} • WFC Review Generator*`;
}

function generateNotionMarkdown(name, location, rating, wifiSpeed, temperature, onlineReviews, userExperience, atmosphere, service, food, highlights, verdict, currentLocation, powerOutlets) {
  const stars = '⭐'.repeat(Math.floor(rating)) + (rating % 1 >= 0.5 ? '⭐' : '');
  const wfcSuitability = rating >= 4.5 ? 'Excellent' : rating >= 3.5 ? 'Good' : 'Average';

  return `# ${name} @ ${location}

> **Verdict:** ${verdict} — ${wfcSuitability} for WFC ${stars}

## 📋 Properties
| Property | Value |
| :--- | :--- |
| **Rating** | ${rating}/5 |
| **WiFi** | ${wifiSpeed} |
| **Temp** | ${temperature} |
| **Power Access** | ${powerOutlets} |
| **Suitability** | ${wfcSuitability} |
| **Location** | ${location} |
| **Reviewed From** | ${currentLocation} |
| **Date** | ${new Date().toLocaleDateString()} |

## ✨ Highlights
${highlights ? highlights.split(',').map(h => `- ${h.trim()}`).join('\n') : '- No specific highlights noted.'}

## 👤 My Experience
${userExperience}

## 🔍 Detailed Breakdown
- **Atmosphere**: ${atmosphere}
- **Service**: ${service}
- **Food & Drink**: ${food}

## 🌐 What Others Say (Online Summary)
<details>
<summary>Click to expand online review summary</summary>

${onlineReviews}
</details>

---
*Generated by WFC Reviewer Skill*`;
}

function generateJSONData(name, location, rating, wifiSpeed, temperature, onlineReviews, userExperience, atmosphere, service, food, highlights, verdict, currentLocation, powerOutlets) {
  return JSON.stringify({
    name,
    location,
    rating,
    wifiSpeed,
    temperature,
    powerOutlets,
    onlineReviews,
    userExperience,
    atmosphere,
    service,
    food,
    highlights,
    verdict,
    currentLocation,
    date: new Date().toISOString(),
    wfcSuitability: rating >= 4.5 ? 'Excellent' : rating >= 3.5 ? 'Good' : 'Average'
  }, null, 2);
}

function saveReviewPackage(name, outputs) {
  const safeName = name.toLowerCase().replace(/[^a-z0-9]/g, '-');
  const dir = path.join(process.cwd(), 'reviews', safeName);

  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  fs.writeFileSync(path.join(dir, 'notion.md'), outputs.notionMarkdown);
  fs.writeFileSync(path.join(dir, 'google-maps.txt'), outputs.googleMapsReview);
  fs.writeFileSync(path.join(dir, 'review.md'), outputs.markdownReview);
  fs.writeFileSync(path.join(dir, 'badge.html'), outputs.badgeHtml);
  fs.writeFileSync(path.join(dir, 'full-review.html'), outputs.webReview);
  fs.writeFileSync(path.join(dir, 'data.json'), outputs.jsonData);

  return dir;
}

function generateReviewOutputs(name, location, rating, wifiSpeed, temperature, onlineReviews, userExperience, atmosphere, service, food, highlights, verdict, currentLocation, powerOutlets) {
  const stars = '⭐'.repeat(Math.floor(rating)) + (rating % 1 >= 0.5 ? '⭐' : '');
  const wfcSuitability = rating >= 4.5 ? 'Excellent' : rating >= 3.5 ? 'Good' : 'Average';

  // Google Maps Review Format
  const googleMapsReview = `
${name} @ ${location}
Rating: ${rating}/5 ${stars}

Quick Summary: ${verdict}

WiFi: ${wifiSpeed} | Temp: ${temperature} | Power: ${powerOutlets}

Atmosphere: ${atmosphere}
Service: ${service}
Food: ${food}

${highlights ? `Highlights: ${highlights}` : ''}
  `.trim();

  // Web/HTML Format
  const webReview = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${name} @ ${location} - WFC Review</title>
    <style>
        body { font-family: system-ui; max-width: 800px; margin: 40px auto; padding: 20px; background: #f8fafc; color: #1e293b; line-height: 1.6; }
        .card { background: white; padding: 40px; border-radius: 24px; box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1); border: 1px solid #e2e8f0; }
        h1 { margin: 0; font-size: 32px; font-weight: 800; }
        .rating { font-size: 24px; color: #f59e0b; margin: 8px 0 24px 0; }
        .grid { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 16px; margin-bottom: 32px; }
        .stat { background: #f1f5f9; padding: 20px; border-radius: 16px; text-align: center; }
        .stat-val { font-size: 20px; font-weight: 700; display: block; }
        .stat-lbl { font-size: 10px; color: #64748b; text-transform: uppercase; font-weight: 600; }
        .section { margin-top: 32px; }
        .section h3 { font-size: 18px; margin-bottom: 8px; color: #334155; border-bottom: 2px solid #f1f5f9; padding-bottom: 4px; }
        .verdict { background: #0f172a; color: white; padding: 24px; border-radius: 16px; margin-bottom: 32px; }
    </style>
</head>
<body>
    <div class="card">
        <p style="color: #64748b; margin-bottom: 8px;">WFC Review</p>
        <h1>${name}</h1>
        <div class="rating">${stars} ${rating}/5</div>

        <div class="verdict">
            <h3 style="color: #94a3b8; border: 0; margin-top: 0;">Verdict</h3>
            <p style="margin: 0; font-size: 18px;">${verdict}</p>
        </div>

        <div class="grid">
            <div class="stat"><span class="stat-val">${wifiSpeed}</span><span class="stat-lbl">WiFi Speed</span></div>
            <div class="stat"><span class="stat-val">${temperature}</span><span class="stat-lbl">Temp</span></div>
            <div class="stat"><span class="stat-val">${powerOutlets}</span><span class="stat-lbl">Power</span></div>
        </div>

        <div class="section"><h3>Experience</h3><p>${userExperience}</p></div>
        <div class="section"><h3>Atmosphere</h3><p>${atmosphere}</p></div>
        <div class="section"><h3>Highlights</h3><p>${highlights || 'None'}</p></div>
    </div>
</body>
</html>`;

  // Markdown Formats
  const markdownReview = generateMarkdownReview(name, location, rating, wifiSpeed, temperature, onlineReviews, userExperience, atmosphere, service, food, highlights, verdict, currentLocation, powerOutlets);
  const notionMarkdown = generateNotionMarkdown(name, location, rating, wifiSpeed, temperature, onlineReviews, userExperience, atmosphere, service, food, highlights, verdict, currentLocation, powerOutlets);

  // Data Formats
  const badgeHtml = generateBadgeHtml(name, wifiSpeed, temperature, rating, wfcSuitability, currentLocation, powerOutlets);
  const jsonData = generateJSONData(name, location, rating, wifiSpeed, temperature, onlineReviews, userExperience, atmosphere, service, food, highlights, verdict, currentLocation, powerOutlets);

  return { googleMapsReview, webReview, markdownReview, notionMarkdown, badgeHtml, jsonData, wfcSuitability };
}

function displayOutputs(name, outputs) {
  const dir = saveReviewPackage(name, outputs);

  console.log('\n' + '✨'.repeat(25));
  console.log('🏁 WFC REVIEW COMPLETE');
  console.log('✨'.repeat(25));

  console.log(`\n📍 Place: ${name}`);
  console.log(`⭐ Rating: ${outputs.wfcSuitability} (${outputs.jsonData.rating || 'N/A'}/5)`);

  console.log('\n📦 REVIEW PACKAGE GENERATED:');
  console.log(`📁 Path: ${dir}`);
  console.log('  📄 notion.md        <- Best for Notion paste');
  console.log('  📄 badge.html       <- Open & screenshot for social');
  console.log('  📄 google-maps.txt  <- Quick copy for Google');
  console.log('  📄 data.json        <- Structured data for your database');

  console.log('\n💡 PRO TIP: Paste the content of notion.md into a Notion page for a beautiful layout!');
}

// Export for Claude Code usage
module.exports = {
  reviewTemplates,
  getRandom,
  getTemplate,
  detectCurrentLocation,
  generateReviewOutputs,
  generateBadgeHtml,
  generateMarkdownReview,
  generateNotionMarkdown,
  generateJSONData,
  saveReviewPackage,
  displayOutputs
};

// If run with arguments, use command line mode (uses placeholder metrics)
const args = process.argv.slice(2);
if (args.length > 0) {
  const name = args[0];
  const location = args[1] || 'WFC';
  const rating = args[2] || '4.0';

  const currentLocation = detectCurrentLocation();

  const templateKey = getTemplate(parseFloat(rating));
  const template = reviewTemplates[templateKey];

  const atmosphere = getRandom(template.atmosphere);
  const service = getRandom(template.service);
  const food = getRandom(template.food);
  const verdict = getRandom(template.recommendation);

  const nameLower = name.toLowerCase();
  let onlineReviews = 'Multiple positive reviews highlighting good atmosphere and reliable service.';
  let userExperience = 'Pleasant working environment with adequate amenities for remote work.';

  if (nameLower.includes('coffee') || nameLower.includes('cafe')) {
    onlineReviews = 'Customers consistently praise the coffee quality and cozy atmosphere. Many mention it as a great spot for working or studying.';
  } else if (nameLower.includes('tea') || nameLower.includes('bubble') || nameLower.includes('chatime')) {
    onlineReviews = 'Reviewers highlight the wide variety of tea options and consistent quality. Popular among students and remote workers.';
  }

  // Use placeholder metrics (interactive mode collects real data)
  const wifiSpeed = '50 Mbps';
  const temperature = '22°C';

  const outputs = generateReviewOutputs(
    name, location, rating, wifiSpeed, temperature, onlineReviews, userExperience,
    atmosphere, service, food, '', verdict, currentLocation
  );

  displayOutputs(name, outputs);

  console.log('\n💡 Tip: Use the badge HTML to create a visual badge image for sharing!');
  console.log('💡 Tip: The markdown review is comprehensive and ready for documentation!');
  console.log('💡 Note: Command line mode uses placeholder metrics. Use /wfc-review for real data collection.');
} else {
  console.log('🍽️  WFC Review Generator - Interactive Mode');
  console.log('\nWorkflow when invoked via /wfc-review:');
  console.log('1. Automatically detect your current location');
  console.log('2. Ask for place information (name, location)');
  console.log('3. Automatically collect technical metrics (WiFi speed, temperature)');
  console.log('4. Analyze online reviews for WFC suitability');
  console.log('5. Gather user experience and preferences');
  console.log('6. Generate formatted markdown review');
  console.log('7. Create visual badge with key metrics');
  console.log('\nCommand Line Usage (placeholder metrics):');
  console.log('  node scripts/wfc_review.cjs "Name" [Location] [Rating]');
  console.log('\nExamples:');
  console.log('  node scripts/wfc_review.cjs "Starbucks"');
  console.log('  node scripts/wfc_review.cjs "Chatime" "Chatswood" 4.5');
}
