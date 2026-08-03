import { Router } from 'express';
import * as adminController from './admin.controller.js';
import { requireAuth, requireAdmin } from '../../middleware/auth.guard.js';

const router = Router();

router.get('/stats', requireAuth, requireAdmin, adminController.getStats);
router.post('/trigger-inactivity-check', requireAuth, requireAdmin, adminController.runInactivityCheck);

export default router;
