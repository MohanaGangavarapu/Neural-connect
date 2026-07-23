import { Router } from 'express';
import { addWord, getSearch, bookmarkWord, createRelationship, deleteRelationship, getWordRelationships, getWordDetail, updateExampleSentence } from './words.controller.js';
import { requireAuth } from '../../middleware/auth.guard.js';

const router = Router();

// Ingest a new vocabulary word into user profile
router.post('/', requireAuth, addWord);

// Search user's learned words
router.get('/search', requireAuth, getSearch);

// Fetch details for any word globally in cache
router.get('/detail/:word', requireAuth, getWordDetail);

// Bookmark / Favorite a specific word by its MongoDB ID
router.post('/:wordId/bookmark', requireAuth, bookmarkWord);

// Custom example sentence
router.put('/:word/example', requireAuth, updateExampleSentence);

// Custom Relationships Override
router.post('/relationships', requireAuth, createRelationship);
router.delete('/relationships', requireAuth, deleteRelationship);
router.get('/:word/relationships', requireAuth, getWordRelationships);

export default router;
