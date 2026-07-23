import { getUserGraphCanvas } from './graph.service.js';

export const getCanvas = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const result = await getUserGraphCanvas(userId);
    return res.status(200).json({
      success: true,
      data: result
    });
  } catch (error) {
    next(error);
  }
};
