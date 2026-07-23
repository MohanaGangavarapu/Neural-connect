import Word from '../../models/Word.js';
import User from '../../models/User.js';
import { getSession } from '../../config/neo4j_pool.js';

export const getWordsPaginated = async (userId, { query, limit = 10, page = 1, partOfSpeech, relationType, onlyBookmarks }) => {
  const skip = (page - 1) * limit;

  // Resolve user bookmarks from MongoDB
  const user = await User.findById(userId);
  const bookmarkIds = user?.bookmarks || [];

  // 1. Resolve all words present in user's graph canvas network (learned + friend connected)
  const session = getSession();
  let learnedWordTexts = [];
  try {
    const cypher = `
      MATCH (u:User {mongo_id: $userId})-[:LEARNED]->(w:Word)
      OPTIONAL MATCH (w)-[r]-(c:Word)
      WHERE type(r) <> 'LEARNED' AND type(r) <> 'FRIEND_OF' AND type(r) <> 'PENDING_REQUEST'
        AND ((u)-[:LEARNED]->(c) OR (u)-[:FRIEND_OF]-()-[:LEARNED]->(c))
      WITH w, c
      UNWIND [w.text, c.text] AS wordText
      WITH wordText WHERE wordText IS NOT NULL
      RETURN DISTINCT wordText AS text
    `;
    
    const res = await session.run(cypher, { userId });
    learnedWordTexts = res.records.map(rec => rec.get('text'));
  } finally {
    await session.close();
  }

  // 2. Build MongoDB filters
  const mongoFilter = {};

  if (onlyBookmarks === 'true') {
    mongoFilter._id = { $in: bookmarkIds };
  } else {
    // Standard behavior: limit results to user's learned vocabulary
    mongoFilter.word = { $in: learnedWordTexts };
  }

  if (query) {
    mongoFilter.word = { ...mongoFilter.word, $regex: query, $options: 'i' };
  }

  if (partOfSpeech) {
    mongoFilter.partOfSpeech = partOfSpeech.toLowerCase();
  }

  // 3. Query documents in Mongo
  const docs = await Word.find(mongoFilter)
    .sort({ createdAt: -1 })
    .skip(skip)
    .limit(Number(limit));

  const total = await Word.countDocuments(mongoFilter);

  return {
    words: docs.map(doc => ({
      id: doc._id,
      word: doc.word,
      partOfSpeech: doc.partOfSpeech,
      definition: doc.definition,
      exampleSentence: doc.exampleSentence,
      meanings: doc.meanings || [],
      abbreviations: doc.abbreviations || [],
      synonyms: doc.synonyms || [],
      antonyms: doc.antonyms || [],
      hypernyms: doc.hypernyms || [],
      hyponyms: doc.hyponyms || [],
      meronyms: doc.meronyms || [],
      holonyms: doc.holonyms || [],
      relatedTerms: doc.relatedTerms || [],
      similarWords: doc.similarWords || [],
      homonyms: doc.homonyms || [],
      phonetic: doc.phonetic || '',
      createdAt: doc.createdAt
    })),
    total,
    page: Number(page),
    limit: Number(limit),
    bookmarkedWordIds: bookmarkIds.map(id => id.toString())
  };
};

export const toggleWordBookmark = async (userId, wordId) => {
  const user = await User.findById(userId);
  if (!user) {
    throw new Error('User not found');
  }

  const word = await Word.findById(wordId);
  if (!word) {
    const err = new Error('Word not found');
    err.statusCode = 404;
    throw err;
  }

  const index = user.bookmarks.indexOf(wordId);
  let isBookmarked = false;

  if (index > -1) {
    user.bookmarks.splice(index, 1);
  } else {
    user.bookmarks.push(wordId);
    isBookmarked = true;
  }

  await user.save();
  return { isBookmarked, wordId };
};
