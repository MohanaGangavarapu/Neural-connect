import { Router } from 'express';
import { getNotifications, readNotification } from './notifications.controller.js';
import { requireAuth } from '../../middleware/auth.guard.js';

const router = Router();

router.get('/', requireAuth, getNotifications);
router.post('/:id/read', requireAuth, readNotification);

export default router;
