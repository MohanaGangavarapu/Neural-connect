import { createWordEntry } from './words.service.js';
import Word from '../../models/Word.js';

export const addWord = async (req, res, next) => {
  try {
    const { word } = req.body;
    const userId = req.user.id; // from JWT middleware requireAuth

    if (!word || typeof word !== 'string' || !/^[a-zA-Z\s-]+$/.test(word)) {
      return res.status(400).json({
        success: false,
        error: {
          code: 'BAD_REQUEST',
          message: 'Word parameter is required and must consist of alphabetic characters only.'
        }
      });
    }

    const result = await createWordEntry(userId, word);
    return res.status(201).json({
      success: true,
      data: result
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({
        success: false,
        error: {
          code: error.statusCode === 400 ? 'BAD_REQUEST' : 'NOT_FOUND',
          message: error.message
        }
      });
    }
    next(error);
  }
};

import { searchWords, toggleBookmark } from './words.service.js';

export const getSearch = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { query, limit, page, partOfSpeech, relationType, onlyBookmarks } = req.query;

    const result = await searchWords(userId, {
      query,
      limit: limit ? Number(limit) : 10,
      page: page ? Number(page) : 1,
      partOfSpeech,
      relationType,
      onlyBookmarks
    });

    return res.status(200).json({
      success: true,
      data: result
    });
  } catch (error) {
    next(error);
  }
};

export const bookmarkWord = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { wordId } = req.params;

    const result = await toggleBookmark(userId, wordId);
    return res.status(200).json({
      success: true,
      data: result
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({
        success: false,
        error: {
          code: error.statusCode === 404 ? 'NOT_FOUND' : 'BAD_REQUEST',
          message: error.message
        }
      });
    }
    next(error);
  }
};

import { addCustomRelationship, removeRelationship, getRelationshipsForWord, getOrFetchWordDetail } from './words.service.js';

export const createRelationship = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { word1, word2, type } = req.body;

    if (!word1 || !word2 || !type) {
      return res.status(400).json({
        success: false,
        error: { code: 'BAD_REQUEST', message: 'Parameters word1, word2, and type are required.' }
      });
    }

    const result = await addCustomRelationship(userId, word1, word2, type);
    return res.status(201).json({ success: true, data: result });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({
        success: false,
        error: { code: 'BAD_REQUEST', message: error.message }
      });
    }
    next(error);
  }
};

export const deleteRelationship = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { word1, word2, type } = req.body;

    if (!word1 || !word2 || !type) {
      return res.status(400).json({
        success: false,
        error: { code: 'BAD_REQUEST', message: 'Parameters word1, word2, and type are required.' }
      });
    }

    await removeRelationship(userId, word1, word2, type);
    return res.status(200).json({ success: true, message: 'Relationship deleted successfully.' });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({
        success: false,
        error: { code: 'BAD_REQUEST', message: error.message }
      });
    }
    next(error);
  }
};

export const getWordRelationships = async (req, res, next) => {
  try {
    const { word } = req.params;
    const result = await getRelationshipsForWord(word);
    return res.status(200).json({ success: true, data: result });
  } catch (error) {
    next(error);
  }
};

export const getWordDetail = async (req, res, next) => {
  try {
    const { word } = req.params;
    const dbWord = await getOrFetchWordDetail(word);
    return res.status(200).json({
      success: true,
      data: {
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
      }
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({
        success: false,
        error: { code: error.statusCode === 404 ? 'NOT_FOUND' : 'BAD_REQUEST', message: error.message }
      });
    }
    next(error);
  }
};

export const updateExampleSentence = async (req, res, next) => {
  try {
    const { word } = req.params;
    const { exampleSentence } = req.body;

    if (exampleSentence === undefined || typeof exampleSentence !== 'string') {
      return res.status(400).json({
        success: false,
        error: { code: 'BAD_REQUEST', message: 'exampleSentence string is required.' }
      });
    }

    const updatedWord = await Word.findOneAndUpdate(
      { word: word.trim().toLowerCase() },
      { exampleSentence: exampleSentence.trim() },
      { new: true }
    );

    if (!updatedWord) {
      return res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Word not found in system cache.' }
      });
    }

    return res.status(200).json({
      success: true,
      data: {
        word: updatedWord.word,
        exampleSentence: updatedWord.exampleSentence
      }
    });
  } catch (error) {
    next(error);
  }
};

