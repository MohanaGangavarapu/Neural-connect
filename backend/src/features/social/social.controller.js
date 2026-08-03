import * as socialService from './social.service.js';

export const getUsers = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const data = await socialService.getUsersDirectory(userId);
    return res.status(200).json({ success: true, data });
  } catch (error) {
    next(error);
  }
};

export const requestFriend = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { targetUsername } = req.body;

    if (!targetUsername) {
      return res.status(400).json({
        success: false,
        error: { code: 'BAD_REQUEST', message: 'Target username is required.' }
      });
    }

    const result = await socialService.sendFriendRequest(userId, targetUsername);
    return res.status(200).json(result);
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

export const respondFriend = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { requesterId, action } = req.body;

    if (!requesterId || !action) {
      return res.status(400).json({
        success: false,
        error: { code: 'BAD_REQUEST', message: 'requesterId and action parameters are required.' }
      });
    }

    const result = await socialService.respondToFriendRequest(userId, requesterId, action);
    return res.status(200).json(result);
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

export const getStats = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const data = await socialService.getProfileStats(userId);
    return res.status(200).json({ success: true, data });
  } catch (error) {
    next(error);
  }
};

export const getFriendCollection = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { friendId } = req.params;

    const data = await socialService.getFriendWords(userId, friendId);
    return res.status(200).json({ success: true, data });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({
        success: false,
        error: { code: 'FORBIDDEN', message: error.message }
      });
    }
    next(error);
  }
};

export const updateProfile = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { displayName, bio, avatarUrl } = req.body;

    const result = await socialService.updateProfileDetails(userId, {
      displayName,
      bio,
      avatarUrl
    });

    return res.status(200).json({
      success: true,
      data: result
    });
  } catch (error) {
    next(error);
  }
};

