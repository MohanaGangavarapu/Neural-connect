import { Router } from 'express';
import { getUsers, requestFriend, respondFriend, getStats, getFriendCollection, updateProfile } from './social.controller.js';
import { requireAuth } from '../../middleware/auth.guard.js';

const router = Router();

// Search and retrieve all profiles directories
router.get('/users', requireAuth, getUsers);

// Dispatch a friend request
router.post('/friends/request', requireAuth, requestFriend);

// Accept or decline incoming friend requests
router.put('/friends/respond', requireAuth, respondFriend);

// Retrieve user statistics metrics counts
router.get('/profile/stats', requireAuth, getStats);

// Update user profile details
router.put('/profile', requireAuth, updateProfile);

// View specific friend's shared words list
router.get('/friends/:friendId/words', requireAuth, getFriendCollection);

export default router;
