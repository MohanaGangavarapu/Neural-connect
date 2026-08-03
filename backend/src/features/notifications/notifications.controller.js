import * as notifService from './notifications.service.js';

export const getNotifications = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const data = await notifService.getUserNotifications(userId);
    return res.status(200).json({ success: true, data });
  } catch (error) {
    next(error);
  }
};

export const readNotification = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;
    const data = await notifService.markAsRead(userId, id);
    return res.status(200).json({ success: true, data });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({
        success: false,
        error: { code: 'NOT_FOUND', message: error.message }
      });
    }
    next(error);
  }
};
