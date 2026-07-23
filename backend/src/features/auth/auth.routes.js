import { Router } from 'express';
import * as authController from './auth.controller.js';
import { requireAuth } from '../../middleware/auth.guard.js';

const router = Router();

router.post('/register', authController.register);
router.post('/login', authController.login);
router.delete('/account', requireAuth, authController.deleteAccount);

export default router;
