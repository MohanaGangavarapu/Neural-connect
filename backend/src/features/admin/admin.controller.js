import * as adminService from './admin.service.js';

export const getStats = async (req, res, next) => {
  try {
    const stats = await adminService.getAdminStats();
    res.status(200).json({ success: true, data: stats });
  } catch (error) {
    next(error);
  }
};

export const runInactivityCheck = async (req, res, next) => {
  try {
    const result = await adminService.triggerInactivityCheck();
    res.status(200).json({ success: true, data: result });
  } catch (error) {
    next(error);
  }
};
