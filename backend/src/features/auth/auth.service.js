import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import User from '../../models/User.js';
import Notification from '../../models/Notification.js';
import { getSession } from '../../config/neo4j_pool.js';

const JWT_SECRET = process.env.JWT_SECRET || 'vocabflow_dev_secret_key';

export const registerUser = async (username, email, password) => {
  // Check if user exists in Mongo
  const existingUser = await User.findOne({ $or: [{ email }, { username }] });
  if (existingUser) {
    throw new Error('Username or email already in use.');
  }

  // Hash password
  const salt = await bcrypt.genSalt(10);
  const passwordHash = await bcrypt.hash(password, salt);

  // Create Mongo document
  const newUser = new User({ username, email, passwordHash });
  await newUser.save();

  // Create Neo4j Node
  const session = getSession();
  try {
    await session.executeWrite((tx) =>
      tx.run(
        'CREATE (u:User {mongo_id: $id, username: $username, displayName: $username, bio: "", avatarUrl: ""}) RETURN u',
        { id: newUser._id.toString(), username: newUser.username }
      )
    );
  } catch (neo4jError) {
    // Rollback Mongo doc if Neo4j fails
    await User.findByIdAndDelete(newUser._id);
    throw new Error(`Graph sync failed: ${neo4jError.message}`);
  } finally {
    await session.close();
  }

  // Generate Token
  const token = jwt.sign(
    { id: newUser._id, username: newUser.username, isAdmin: newUser.isAdmin },
    JWT_SECRET,
    { expiresIn: '7d' }
  );

  return { token, user: { id: newUser._id, username: newUser.username, email: newUser.email, isAdmin: newUser.isAdmin } };
};

export const loginUser = async (email, password) => {
  const user = await User.findOne({ email });
  if (!user) {
    throw new Error('Invalid email or password.');
  }

  const isMatch = await bcrypt.compare(password, user.passwordHash);
  if (!isMatch) {
    throw new Error('Invalid email or password.');
  }

  const token = jwt.sign(
    { id: user._id, username: user.username, isAdmin: user.isAdmin },
    JWT_SECRET,
    { expiresIn: '7d' }
  );

  return { token, user: { id: user._id, username: user.username, isAdmin: user.isAdmin } };
};

export const deleteUserAccount = async (userId) => {
  const session = getSession();
  try {
    // 1. Delete Neo4j user node and all relationships
    await session.executeWrite((tx) =>
      tx.run(
        'MATCH (u:User {mongo_id: $userId}) DETACH DELETE u',
        { userId }
      )
    );
  } catch (neo4jError) {
    console.error(`Neo4j user deletion failed: ${neo4jError.message}`);
    throw new Error(`Graph deletion failed: ${neo4jError.message}`);
  } finally {
    await session.close();
  }

  // 2. Delete notifications in MongoDB
  await Notification.deleteMany({ userId });

  // 3. Delete User in MongoDB
  await User.findByIdAndDelete(userId);
};
