import Word from '../../models/Word.js';
import User from '../../models/User.js';
import { getSession } from '../../config/neo4j_pool.js';
import { processWordNLP, resolveWordToQid, checkWikidataRelation } from '../../services/nlp.service.js';
import { triggerWordLearnedNotifications } from '../notifications/notifications.service.js';

// Calculate cosine similarity between two vector float arrays
export const calculateCosineSimilarity = (vecA, vecB) => {
  if (!vecA || !vecB || vecA.length !== vecB.length || vecA.length === 0) return 0;
  let dotProduct = 0;
  let normA = 0;
  let normB = 0;
  for (let i = 0; i < vecA.length; i++) {
    dotProduct += vecA[i] * vecB[i];
    normA += vecA[i] * vecA[i];
    normB += vecB[i] * vecB[i];
  }
  if (normA === 0 || normB === 0) return 0;
  return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
};

export const createWordEntry = async (userId, wordText) => {
  const normalizedWord = wordText.trim().toLowerCase();

  // 1. Double check if relationship already exists for user to avoid duplicate LEARNED links
  const session = getSession();
  try {
    const checkResult = await session.executeWrite((tx) =>
      tx.run(
        'MATCH (u:User {mongo_id: $userId})-[:LEARNED]->(w:Word {text: $word}) RETURN w',
        { userId, word: normalizedWord }
      )
    );
    if (checkResult.records.length > 0) {
      const err = new Error('Word already exists in user\'s profile graph.');
      err.statusCode = 400;
      throw err;
    }
  } finally {
    await session.close();
  }

  // 2. Fetch or create word details inside MONGODB global cache
  let dbWord = await Word.findOne({ word: normalizedWord });
  let nlpData = null;

  if (!dbWord) {
    // Process NLP parsing pipeline (Dict fetch + ConceptNet fallback + BERT embedding calculation)
    nlpData = await processWordNLP(normalizedWord);
    if (!nlpData.embedding || nlpData.embedding.length === 0) {
      const err = new Error('Word could not be resolved by dictionary APIs or embedding pipeline.');
      err.statusCode = 404;
      throw err;
    }
    dbWord = new Word({
      word: nlpData.word,
      partOfSpeech: nlpData.partOfSpeech,
      definition: nlpData.definition,
      exampleSentence: nlpData.exampleSentence,
      meanings: nlpData.meanings || [],
      abbreviations: nlpData.abbreviations || [],
      synonyms: nlpData.synonyms || [],
      antonyms: nlpData.antonyms || [],
      hypernyms: nlpData.hypernyms || [],
      hyponyms: nlpData.hyponyms || [],
      meronyms: nlpData.meronyms || [],
      holonyms: nlpData.holonyms || [],
      relatedTerms: nlpData.relatedTerms || [],
      similarWords: nlpData.similarWords || [],
      homonyms: nlpData.homonyms || [],
      phonetic: nlpData.phonetic || '',
      embedding: nlpData.embedding
    });
    await dbWord.save();
  } else {
    nlpData = dbWord;
  }

  // 3. Sync to NEO4J graph
  const writeSession = getSession();
  try {
    const userDoc = await User.findById(userId);
    const username = userDoc ? userDoc.username : '';

    // A. Create User node index if missing and merge Word node
    await writeSession.executeWrite((tx) =>
      tx.run(
        `MERGE (w:Word {text: $word})
         MERGE (u:User {mongo_id: $userId})
         SET u.username = $username
         MERGE (u)-[r:LEARNED]->(w)
         ON CREATE SET r.added_at = datetime()
         RETURN w`,
        { word: normalizedWord, userId, username }
      )
    );

    // B. Build global semantic edges based on direct lexical relationships (Step 2)
    // We will extract all related words from lexical lists, check if they exist in Neo4j,
    // and if they do, create a directed edge with relation properties (Step 5 confidence: 0.95)
    
    // We check synonyms, antonyms, hypernyms, hyponyms, meronyms, holonyms, relatedTerms, similarWords, and abbreviations.
    const lexicalRelations = [
      { list: nlpData.synonyms || [], label: 'SYNONYM_OF', relation: 'synonym' },
      { list: nlpData.antonyms || [], label: 'ANTONYM_OF', relation: 'antonym' },
      { list: nlpData.hypernyms || [], label: 'HYPERNYM_OF', relation: 'hypernym' },
      { list: nlpData.hyponyms || [], label: 'HYPONYM_OF', relation: 'hyponym' },
      { list: nlpData.meronyms || [], label: 'MERONYM_OF', relation: 'meronym' },
      { list: nlpData.holonyms || [], label: 'HOLONYM_OF', relation: 'holonym' },
      { list: nlpData.relatedTerms || [], label: 'RELATED_TO', relation: 'related term' },
      { list: nlpData.similarWords || [], label: 'SIMILAR_TO', relation: 'similar word' },
      { list: nlpData.abbreviations || [], label: 'ABBREVIATION_OF', relation: 'abbreviation' }
    ];

    for (const relGroup of lexicalRelations) {
      for (const targetWord of relGroup.list.slice(0, 10)) {
        const normalizedTarget = targetWord.toLowerCase().trim();
        if (!normalizedTarget || normalizedTarget === normalizedWord) continue;

        // Check if target word exists as a LEARNED word for this user, and if so, create edge
        await writeSession.executeWrite((tx) =>
          tx.run(
            `MATCH (u:User {mongo_id: $userId})
             MATCH (w1:Word {text: $word1}), (w2:Word {text: $word2})
             WHERE (u)-[:LEARNED]->(w1) AND (u)-[:LEARNED]->(w2)
             MERGE (w1)-[r:${relGroup.label}]->(w2)
             SET r.source = "lexical", r.relation = $relation, r.confidence = 0.95
             RETURN r`,
            {
              userId,
              word1: normalizedWord,
              word2: normalizedTarget,
              relation: relGroup.relation
            }
          )
        );
      }
    }

    // C. Semantic Similarity Discovery & Wikidata Verification (Steps 3 & 4)
    const allMongoWords = await Word.find({ word: { $ne: normalizedWord } });
    const currentEmbedding = dbWord.embedding;
    const similarityThreshold = Number(process.env.SIMILARITY_THRESHOLD) || 0.75;

    const similarityCandidates = [];

    for (const otherWord of allMongoWords) {
      if (otherWord.embedding && otherWord.embedding.length > 0) {
        const similarity = calculateCosineSimilarity(currentEmbedding, otherWord.embedding);
        if (similarity >= similarityThreshold) {
          similarityCandidates.push({ word: otherWord.word, similarity });
        }
      }
    }

    // Resolve Qid for the input word
    const inputQid = await resolveWordToQid(normalizedWord);

    for (const candidate of similarityCandidates) {
      const candidateQid = await resolveWordToQid(candidate.word);
      let wikidataVerified = false;
      let wikidataProp = null;

      if (inputQid && candidateQid) {
        // Query SPARQL endpoint to see if a direct relation exists
        wikidataProp = await checkWikidataRelation(inputQid, candidateQid);
        if (wikidataProp) {
          wikidataVerified = true;
        }
      }

      if (wikidataVerified && wikidataProp) {
        // Step 4 & 5: Wikidata verified relation -> Medium-High confidence (0.90)
        const propLabel = wikidataProp.propLabel || 'associated concept';
        const cleanType = propLabel.trim().toUpperCase().replace(/[-\s]+/g, '_');
        const safeType = /^[A-Z_]{3,20}$/.test(cleanType) ? cleanType : 'RELATED_TO';

        await writeSession.executeWrite((tx) =>
          tx.run(
            `MATCH (u:User {mongo_id: $userId})
             MATCH (w1:Word {text: $word1}), (w2:Word {text: $word2})
             WHERE (u)-[:LEARNED]->(w1) AND (u)-[:LEARNED]->(w2)
             MERGE (w1)-[r:${safeType}]->(w2)
             SET r.source = "wikidata", r.relation = $relation, r.confidence = 0.90
             RETURN r`,
            {
              userId,
              word1: normalizedWord,
              word2: candidate.word,
              relation: propLabel.toLowerCase()
            }
          )
        );
        console.log(`[Wikidata Edge] Mapped (${normalizedWord}) -[:${safeType} {relation: "${propLabel}", confidence: 0.90}]-> (${candidate.word})`);
      } else {
        // Similarity-only relation -> Low confidence (0.6 - 0.8)
        const confidence = Math.min(0.80, Math.max(0.60, candidate.similarity));
        await writeSession.executeWrite((tx) =>
          tx.run(
            `MATCH (u:User {mongo_id: $userId})
             MATCH (w1:Word {text: $word1}), (w2:Word {text: $word2})
             WHERE (u)-[:LEARNED]->(w1) AND (u)-[:LEARNED]->(w2)
             MERGE (w1)-[r:SIMILAR_TO]->(w2)
             SET r.source = "similarity", r.relation = "similar to", r.confidence = $confidence
             RETURN r`,
            {
              userId,
              word1: normalizedWord,
              word2: candidate.word,
              confidence
            }
          )
        );
        console.log(`[Similarity Edge] Mapped (${normalizedWord}) -[:SIMILAR_TO {confidence: ${confidence}}]-> (${candidate.word})`);
      }
    }
  } catch (neo4jError) {
    console.error(`Neo4j word sync pipeline crashed: ${neo4jError.message}`);
    throw neo4jError;
  } finally {
    await writeSession.close();
  }

  // 4. Retrieve newly formed graph connections to send to client
  const readSession = getSession();
  let graphConnections = [];
  try {
    const result = await readSession.run(
      `MATCH (u:User {mongo_id: $userId})
       MATCH (w1:Word {text: $word})-[r]-(w2:Word)
       WHERE (u)-[:LEARNED]->(w1) AND (u)-[:LEARNED]->(w2) AND type(r) <> 'LEARNED'
       RETURN w1.text AS from, w2.text AS to, type(r) AS type`,
      { userId, word: normalizedWord }
    );
    graphConnections = result.records.map(rec => ({
      from: rec.get('from'),
      to: rec.get('to'),
      type: rec.get('type')
    }));
  } finally {
    await readSession.close();
  }

  // Trigger notifications asynchronously for friends
  triggerWordLearnedNotifications(userId, normalizedWord).catch(err => {
    console.error(`Error triggering word notifications: ${err.message}`);
  });

  return {
    wordInfo: {
      id: dbWord._id,
      word: dbWord.word,
      partOfSpeech: dbWord.partOfSpeech,
      definition: dbWord.definition,
      exampleSentence: dbWord.exampleSentence,
      meanings: dbWord.meanings || [],
      abbreviations: dbWord.abbreviations || [],
      synonyms: dbWord.synonyms || [],
      antonyms: dbWord.antonyms || [],
      hypernyms: dbWord.hypernyms || [],
      hyponyms: dbWord.hyponyms || [],
      meronyms: dbWord.meronyms || [],
      holonyms: dbWord.holonyms || [],
      relatedTerms: dbWord.relatedTerms || [],
      similarWords: dbWord.similarWords || [],
      homonyms: dbWord.homonyms || [],
      phonetic: dbWord.phonetic || ''
    },
    graphConnections
  };
};

import { getWordsPaginated, toggleWordBookmark } from './words.repository.js';

export const searchWords = async (userId, options) => {
  return getWordsPaginated(userId, options);
};

export const toggleBookmark = async (userId, wordId) => {
  return toggleWordBookmark(userId, wordId);
};

export const addCustomRelationship = async (userId, word1, word2, type) => {
  const w1 = word1.trim().toLowerCase();
  const w2 = word2.trim().toLowerCase();
  const cleanType = type.trim().toUpperCase().replace(/[-\s]+/g, '_');

  // Verify relation type format strictly to prevent Cypher injection
  if (!/^[A-Z_]{3,20}$/.test(cleanType)) {
    const err = new Error('Invalid relationship type format. Must contain 3-20 uppercase letters/underscores only.');
    err.statusCode = 400;
    throw err;
  }

  const session = getSession();
  try {
    // Verify both words are learned by the user
    const checkQuery = `
      MATCH (u:User {mongo_id: $userId})
      MATCH (w1:Word {text: $w1}), (w2:Word {text: $w2})
      WHERE (u)-[:LEARNED]->(w1) AND (u)-[:LEARNED]->(w2)
      RETURN w1, w2
    `;
    const checkRes = await session.run(checkQuery, { userId, w1, w2 });
    if (checkRes.records.length === 0) {
      const err = new Error('Both words must be learned by you before establishing a relationship.');
      err.statusCode = 400;
      throw err;
    }

    // Merge the custom edge
    const mergeQuery = `
      MATCH (w1:Word {text: $w1}), (w2:Word {text: $w2})
      MERGE (w1)-[r:${cleanType}]->(w2)
      RETURN r
    `;
    await session.executeWrite((tx) => tx.run(mergeQuery, { w1, w2 }));

    return { from: w1, to: w2, type: cleanType };
  } finally {
    await session.close();
  }
};

export const removeRelationship = async (userId, word1, word2, type) => {
  const w1 = word1.trim().toLowerCase();
  const w2 = word2.trim().toLowerCase();
  const cleanType = type.trim().toUpperCase().replace(/[-\s]+/g, '_');

  if (!/^[A-Z_]{3,20}$/.test(cleanType)) {
    const err = new Error('Invalid relationship type format.');
    err.statusCode = 400;
    throw err;
  }

  const session = getSession();
  try {
    const deleteQuery = `
      MATCH (w1:Word {text: $w1})-[r:${cleanType}]-(w2:Word {text: $w2})
      DELETE r
    `;
    await session.executeWrite((tx) => tx.run(deleteQuery, { w1, w2 }));
  } finally {
    await session.close();
  }
};

export const getRelationshipsForWord = async (word) => {
  const normalizedWord = word.trim().toLowerCase();
  const session = getSession();
  try {
    const query = `
      MATCH (w:Word {text: $word})-[r]-(connectedWord:Word)
      WHERE type(r) <> 'LEARNED' AND type(r) <> 'FRIEND_OF' AND type(r) <> 'PENDING_REQUEST'
      RETURN connectedWord.text AS targetWord, type(r) AS type
    `;
    const res = await session.run(query, { word: normalizedWord });
    return res.records.map(rec => ({
      targetWord: rec.get('targetWord'),
      type: rec.get('type')
    }));
  } finally {
    await session.close();
  }
};

export const getOrFetchWordDetail = async (wordText) => {
  const normalizedWord = wordText.trim().toLowerCase();
  let dbWord = await Word.findOne({ word: normalizedWord });
  if (!dbWord) {
    const nlpData = await processWordNLP(normalizedWord);
    if (!nlpData.embedding || nlpData.embedding.length === 0) {
      const err = new Error('Word could not be resolved by dictionary APIs or embedding pipeline.');
      err.statusCode = 404;
      throw err;
    }
    dbWord = new Word({
      word: nlpData.word,
      partOfSpeech: nlpData.partOfSpeech,
      definition: nlpData.definition,
      exampleSentence: nlpData.exampleSentence,
      meanings: nlpData.meanings || [],
      abbreviations: nlpData.abbreviations || [],
      synonyms: nlpData.synonyms || [],
      antonyms: nlpData.antonyms || [],
      hypernyms: nlpData.hypernyms || [],
      hyponyms: nlpData.hyponyms || [],
      meronyms: nlpData.meronyms || [],
      holonyms: nlpData.holonyms || [],
      relatedTerms: nlpData.relatedTerms || [],
      similarWords: nlpData.similarWords || [],
      homonyms: nlpData.homonyms || [],
      phonetic: nlpData.phonetic || '',
      embedding: nlpData.embedding
    });
    await dbWord.save();
  }
  return dbWord;
};

