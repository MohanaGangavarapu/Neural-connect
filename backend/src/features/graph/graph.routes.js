import { Router } from 'express';
import { getCanvas } from './graph.controller.js';
import { requireAuth } from '../../middleware/auth.guard.js';

const router = Router();

// Retrieve filtered neighborhood vocabulary canvas
router.get('/canvas', requireAuth, getCanvas);

export default router;
