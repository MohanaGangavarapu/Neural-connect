import fetch from 'node-fetch';

const testScrape = async () => {
  const word = 'html';
  try {
    console.log(`Fetching abbreviations page for: ${word}`);
    const res = await fetch(`https://www.abbreviations.com/${encodeURIComponent(word)}`, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'
      }
    });
    const html = await res.text();
    console.log("Status:", res.status);
    console.log("HTML length:", html.length);
    // Print lines containing some likely matches
    const lines = html.split('\n');
    console.log("Sample lines containing links or table cells:");
    const matches = lines.filter(l => l.includes('class="abbr-term"') || l.includes('/abbreviation/') || l.includes('class="desc"'));
    console.log(matches.slice(0, 15).join('\n'));
  } catch (error) {
    console.error("Scrape failed:", error);
  }
};

testScrape();
