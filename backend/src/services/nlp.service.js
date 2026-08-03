import fetch from 'node-fetch';
import { pipeline } from '@xenova/transformers';

let extractorInstance = null;

// Initialize or retrieve the feature extraction pipeline singleton
export const getExtractor = async () => {
  if (!extractorInstance) {
    // We use a light and fast semantic sentence embedding model
    extractorInstance = await pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2');
  }
  return extractorInstance;
};

// Fetch word definitions, phonetics, and example sentences from Free Dictionary API
export const fetchDictionaryData = async (word) => {
  try {
    const res = await fetch(`https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(word)}`);
    if (!res.ok) {
      throw new Error(`Dictionary API returned status: ${res.status}`);
    }
    const data = await res.json();
    if (!Array.isArray(data) || data.length === 0) {
      throw new Error('Invalid dictionary API format');
    }
    return data[0];
  } catch (error) {
    console.warn(`Free Dictionary API lookup failed for "${word}": ${error.message}`);
    return null;
  }
};

// Fallback lookup via ConceptNet API to retrieve semantic synonyms/related terms (disabled)
export const fetchConceptNetData = async (word) => {
  return { synonyms: [], antonyms: [] };
};

// WordNet synonyms, antonyms, hypernyms, hyponyms, meronyms, holonyms, related terms, similar words, and homonyms query (via Datamuse keyless API)
export const fetchWordNetData = async (word) => {
  try {
    const [synRes, antRes, spcRes, genRes, mdmRes, mdhRes, trgRes, mlRes, homRes] = await Promise.all([
      fetch(`https://api.datamuse.com/words?rel_syn=${encodeURIComponent(word)}`),
      fetch(`https://api.datamuse.com/words?rel_ant=${encodeURIComponent(word)}`),
      fetch(`https://api.datamuse.com/words?rel_spc=${encodeURIComponent(word)}`),
      fetch(`https://api.datamuse.com/words?rel_gen=${encodeURIComponent(word)}`),
      fetch(`https://api.datamuse.com/words?rel_mdm=${encodeURIComponent(word)}`),
      fetch(`https://api.datamuse.com/words?rel_mdh=${encodeURIComponent(word)}`),
      fetch(`https://api.datamuse.com/words?rel_trg=${encodeURIComponent(word)}`),
      fetch(`https://api.datamuse.com/words?ml=${encodeURIComponent(word)}`),
      fetch(`https://api.datamuse.com/words?rel_hom=${encodeURIComponent(word)}`)
    ]);

    const synonyms = [];
    const antonyms = [];
    const hypernyms = [];
    const hyponyms = [];
    const meronyms = [];
    const holonyms = [];
    const relatedTerms = [];
    const similarWords = [];
    const homonyms = [];

    if (synRes.ok) {
      const data = await synRes.json();
      synonyms.push(...data.slice(0, 5).map(item => item.word.toLowerCase()));
    }
    if (antRes.ok) {
      const data = await antRes.json();
      antonyms.push(...data.slice(0, 5).map(item => item.word.toLowerCase()));
    }
    if (spcRes.ok) {
      const data = await spcRes.json();
      hypernyms.push(...data.slice(0, 5).map(item => item.word.toLowerCase()));
    }
    if (genRes.ok) {
      const data = await genRes.json();
      hyponyms.push(...data.slice(0, 5).map(item => item.word.toLowerCase()));
    }
    if (mdmRes.ok) {
      const data = await mdmRes.json();
      meronyms.push(...data.slice(0, 5).map(item => item.word.toLowerCase()));
    }
    if (mdhRes.ok) {
      const data = await mdhRes.json();
      holonyms.push(...data.slice(0, 5).map(item => item.word.toLowerCase()));
    }
    if (trgRes.ok) {
      const data = await trgRes.json();
      relatedTerms.push(...data.slice(0, 5).map(item => item.word.toLowerCase()));
    }
    if (mlRes.ok) {
      const data = await mlRes.json();
      similarWords.push(...data.slice(0, 5).map(item => item.word.toLowerCase()));
    }
    if (homRes.ok) {
      const data = await homRes.json();
      homonyms.push(...data.slice(0, 5).map(item => item.word.toLowerCase()));
    }

    return { synonyms, antonyms, hypernyms, hyponyms, meronyms, holonyms, relatedTerms, similarWords, homonyms };
  } catch (error) {
    console.warn(`WordNet/Datamuse lookup failed for "${word}": ${error.message}`);
    return {
      synonyms: [],
      antonyms: [],
      hypernyms: [],
      hyponyms: [],
      meronyms: [],
      holonyms: [],
      relatedTerms: [],
      similarWords: [],
      homonyms: []
    };
  }
};

// Urban Dictionary slang terms and definitions
export const fetchUrbanDictionaryData = async (word) => {
  try {
    const res = await fetch(`https://api.urbandictionary.com/v0/define?term=${encodeURIComponent(word)}`);
    if (!res.ok) {
      throw new Error(`Status: ${res.status}`);
    }
    const data = await res.json();
    const synonyms = [];

    if (data.list && data.list.length > 0) {
      // Parse linked bracket words from first 3 definitions as synonyms
      for (const item of data.list.slice(0, 3)) {
        const def = item.definition || '';
        const matches = def.match(/\[([^\]]+)\]/g);
        if (matches) {
          for (const m of matches) {
            const cleanWord = m.replace(/[\[\]]/g, '').trim().toLowerCase();
            if (cleanWord && cleanWord !== word.toLowerCase() && !synonyms.includes(cleanWord) && cleanWord.length < 20) {
              synonyms.push(cleanWord);
            }
          }
        }
      }
    }
    return { synonyms: synonyms.slice(0, 5) };
  } catch (error) {
    console.warn(`Urban Dictionary lookup failed for "${word}": ${error.message}`);
    return { synonyms: [] };
  }
};

// Wikipedia Search API to pull related articles/concepts (disabled)
export const fetchWikipediaData = async (word) => {
  return { related: [] };
};

// Wikipedia API page summary fetch
export const fetchWikipediaSummary = async (word) => {
  try {
    const res = await fetch(`https://en.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(word)}`);
    if (!res.ok) {
      throw new Error(`Status: ${res.status}`);
    }
    const data = await res.json();
    return data.extract || '';
  } catch (error) {
    console.warn(`Wikipedia summary lookup failed for "${word}": ${error.message}`);
    return '';
  }
};

// Wikidata Search API
export const fetchWikidataData = async (word) => {
  try {
    const res = await fetch(`https://www.wikidata.org/w/api.php?action=wbsearchentities&search=${encodeURIComponent(word)}&language=en&format=json`, {
      headers: {
        'User-Agent': 'WordClassifier/1.0'
      }
    });
    if (!res.ok) {
      throw new Error(`Status: ${res.status}`);
    }
    const data = await res.json();
    const results = [];
    if (data.search) {
      for (const item of data.search.slice(0, 5)) {
        results.push({
          id: item.id,
          label: item.label,
          description: item.description,
          concept_uri: item.concepturi
        });
      }
    }
    return results;
  } catch (error) {
    console.warn(`Wikidata lookup failed for "${word}": ${error.message}`);
    return [];
  }
};

// Abbreviations.com HTML scraping for acronym expansions/abbreviations
export const fetchAbbreviationsData = async (word) => {
  try {
    const res = await fetch(`https://www.abbreviations.com/${encodeURIComponent(word)}`, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'
      }
    });
    if (!res.ok) {
      throw new Error(`Status: ${res.status}`);
    }
    const html = await res.text();
    const abbreviations = [];

    const matches = html.match(/<p class="desc">([^<]+)<\/p>/g);
    if (matches) {
      for (const m of matches) {
        const desc = m.replace(/<p class="desc">|<\/p>/g, '').trim().toLowerCase();
        if (desc && desc !== word.toLowerCase() && !abbreviations.includes(desc) && desc.length < 35) {
          abbreviations.push(desc);
        }
      }
    }
    return { abbreviations: abbreviations.slice(0, 5) };
  } catch (error) {
    console.warn(`Abbreviations.com lookup failed for "${word}": ${error.message}`);
    return { abbreviations: [] };
  }
};

// Orchestrate dictionary fetching, fallback, and BERT vector embedding generation
export const processWordNLP = async (wordText) => {
  const normalizedWord = wordText.trim().toLowerCase();
  
  // 1. Run all dictionary & semantic source APIs concurrently
  const [dictData, conceptNet, wordNet, urbanDict, wiki, abbr, wikiSummary, wikidata] = await Promise.all([
    fetchDictionaryData(normalizedWord),
    fetchConceptNetData(normalizedWord),
    fetchWordNetData(normalizedWord),
    fetchUrbanDictionaryData(normalizedWord),
    fetchWikipediaData(normalizedWord),
    fetchAbbreviationsData(normalizedWord),
    fetchWikipediaSummary(normalizedWord),
    fetchWikidataData(normalizedWord)
  ]);

  let definition = 'No definition available.';
  let partOfSpeech = 'noun';
  let exampleSentence = '';
  let phonetic = '';
  
  // Aggregate synonyms and antonyms from all sources
  let synonyms = [];
  let antonyms = [];
  let hypernyms = wordNet ? wordNet.hypernyms : [];
  let homonyms = wordNet ? wordNet.homonyms : [];
  let hyponyms = wordNet ? wordNet.hyponyms : [];
  let meronyms = wordNet ? wordNet.meronyms : [];
  let holonyms = wordNet ? wordNet.holonyms : [];
  let relatedTerms = wordNet ? wordNet.relatedTerms : [];
  let similarWords = wordNet ? wordNet.similarWords : [];
  const meaningsList = [];

  if (dictData) {
    phonetic = dictData.phonetic || (dictData.phonetics && dictData.phonetics[0]?.text) || '';
    const meaning = dictData.meanings?.[0];
    if (meaning) {
      partOfSpeech = meaning.partOfSpeech || 'noun';
      definition = meaning.definitions?.[0]?.definition || definition;
      exampleSentence = meaning.definitions?.[0]?.example || '';
      
      if (meaning.synonyms) synonyms.push(...meaning.synonyms);
      if (meaning.antonyms) antonyms.push(...meaning.antonyms);
    }
    for (const m of (dictData.meanings || [])) {
      for (const defObj of (m.definitions || [])) {
        if (defObj.definition) {
          meaningsList.push(defObj.definition);
        }
      }
    }
  }

  // Fallback to Wikipedia summary, Wikidata, or Abbreviations if dictionary API fails
  if (definition === 'No definition available.') {
    if (wikiSummary) {
      definition = wikiSummary.split('. ')[0] + '.';
      partOfSpeech = 'noun';
    } else if (wikidata && wikidata.length > 0 && wikidata[0].description) {
      definition = wikidata[0].description;
      partOfSpeech = 'noun';
    } else if (abbr.abbreviations && abbr.abbreviations.length > 0) {
      definition = `Abbreviation for: ${abbr.abbreviations.join(', ')}`;
      partOfSpeech = 'noun';
    }
  }

  if (meaningsList.length === 0 && definition !== 'No definition available.') {
    meaningsList.push(definition);
  }

  // Merge ConceptNet, WordNet, and Urban Dictionary synonyms/antonyms
  if (conceptNet.synonyms.length > 0) synonyms.push(...conceptNet.synonyms);
  if (conceptNet.antonyms.length > 0) antonyms.push(...conceptNet.antonyms);

  if (wordNet.synonyms.length > 0) synonyms.push(...wordNet.synonyms);
  if (wordNet.antonyms.length > 0) antonyms.push(...wordNet.antonyms);

  if (urbanDict.synonyms.length > 0) synonyms.push(...urbanDict.synonyms);

  // Clean duplicate entries and normalize
  synonyms = [...new Set(synonyms.map(s => s.toLowerCase()))].filter(s => s !== normalizedWord);
  antonyms = [...new Set(antonyms.map(a => a.toLowerCase()))].filter(a => a !== normalizedWord);
  hypernyms = [...new Set(hypernyms.map(h => h.toLowerCase()))].filter(h => h !== normalizedWord);
  homonyms = [...new Set(homonyms.map(h => h.toLowerCase()))].filter(h => h !== normalizedWord);
  hyponyms = [...new Set(hyponyms.map(h => h.toLowerCase()))].filter(h => h !== normalizedWord);
  meronyms = [...new Set(meronyms.map(m => m.toLowerCase()))].filter(m => m !== normalizedWord);
  holonyms = [...new Set(holonyms.map(h => h.toLowerCase()))].filter(h => h !== normalizedWord);
  relatedTerms = [...new Set(relatedTerms.map(r => r.toLowerCase()))].filter(r => r !== normalizedWord);
  similarWords = [...new Set(similarWords.map(s => s.toLowerCase()))].filter(s => s !== normalizedWord);

  // Build the profile text for embedding generation
  let embeddingText = normalizedWord;
  if (wikiSummary) {
    embeddingText += " " + wikiSummary;
  }
  for (const m of meaningsList) {
    embeddingText += " " + m;
  }

  // 2. Generate Semantic BERT Vector Embedding
  let embedding = [];
  try {
    const extractor = await getExtractor();
    const output = await extractor(embeddingText, { pooling: 'mean', normalize: true });
    embedding = Array.from(output.data);
  } catch (embeddingError) {
    console.error(`BERT embedding extraction failed for "${normalizedWord}": ${embeddingError.message}`);
  }

  return {
    word: normalizedWord,
    partOfSpeech,
    definition,
    exampleSentence,
    synonyms,
    antonyms,
    hypernyms,
    hyponyms,
    meronyms,
    holonyms,
    relatedTerms,
    similarWords,
    homonyms,
    phonetic,
    wikipedia: wiki.related,
    abbreviations: abbr.abbreviations,
    embedding,
    wikidata,
    wikiSummary,
    urbanDefinitions: urbanDict.synonyms,
    meanings: meaningsList
  };
};

// Resolve a word text to its primary Wikidata entity ID (Q-id)
export const resolveWordToQid = async (word) => {
  try {
    const results = await fetchWikidataData(word);
    if (results && results.length > 0) {
      return results[0].id;
    }
  } catch (err) {
    console.warn(`Failed to resolve word "${word}" to Qid: ${err.message}`);
  }
  return null;
};

// Query the Wikidata SPARQL endpoint to find if there is a direct claim linking two entity IDs
export const checkWikidataRelation = async (q1, q2) => {
  const query = `
    SELECT ?prop ?propLabel WHERE {
      {
        wd:${q1} ?p wd:${q2} .
      } UNION {
        wd:${q2} ?p wd:${q1} .
      }
      FILTER(STRSTARTS(STR(?p), "http://www.wikidata.org/prop/direct/"))
      BIND(URI(REPLACE(STR(?p), "http://www.wikidata.org/prop/direct/", "http://www.wikidata.org/entity/")) AS ?prop)
      SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
    } LIMIT 5
  `;
  const url = `https://query.wikidata.org/sparql?query=${encodeURIComponent(query)}&format=json`;
  try {
    const res = await fetch(url, {
      headers: {
        'User-Agent': 'VocabFlowRelationDiscoverer/1.0 (admin@vocabflow.com)',
        'Accept': 'application/sparql-results+json'
      }
    });
    if (!res.ok) {
      return null;
    }
    const data = await res.json();
    const bindings = data.results?.bindings || [];
    if (bindings.length > 0) {
      const first = bindings[0];
      const propUrl = first.prop?.value || '';
      const propId = propUrl.split('/').pop() || '';
      const propLabel = first.propLabel?.value || '';
      return { propId, propLabel };
    }
    return null;
  } catch (error) {
    console.warn(`Wikidata SPARQL query failed for ${q1} <-> ${q2}: ${error.message}`);
    return null;
  }
};
