import * as authService from './auth.service.js';

export const register = async (req, res) => {
  try {
    const { username, email, password } = req.body;
    
    if (!username || !email || !password) {
      return res.status(400).json({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'Username, email, and password are required.' }
      });
    }

    const data = await authService.registerUser(username, email, password);
    res.status(201).json({ success: true, data });
  } catch (error) {
    if (error.message.includes('already in use')) {
      return res.status(400).json({
        success: false,
        error: { code: 'CONFLICT', message: error.message }
      });
    }
    console.error(error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_SERVER_ERROR', message: 'Failed to register user.' }
    });
  }
};

export const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'Email and password are required.' }
      });
    }

    const data = await authService.loginUser(email, password);
    res.status(200).json({ success: true, data });
  } catch (error) {
    if (error.message.includes('Invalid email or password')) {
      return res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: error.message }
      });
    }
    console.error(error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_SERVER_ERROR', message: 'Failed to log in.' }
    });
  }
};

export const deleteAccount = async (req, res, next) => {
  try {
    const userId = req.user.id;
    await authService.deleteUserAccount(userId);
    res.status(200).json({ success: true, message: 'Account successfully deleted.' });
  } catch (error) {
    next(error);
  }
};
