import Notification from '../../models/Notification.js';
import User from '../../models/User.js';
import { getSession } from '../../config/neo4j_pool.js';

export const getUserNotifications = async (userId) => {
  return Notification.find({ userId }).sort({ createdAt: -1 });
};

export const markAsRead = async (userId, notificationId) => {
  const notif = await Notification.findOne({ _id: notificationId, userId });
  if (!notif) {
    const err = new Error('Notification not found.');
    err.statusCode = 404;
    throw err;
  }
  notif.read = true;
  await notif.save();
  return notif;
};

export const createNotification = async (userId, type, message) => {
  const notif = new Notification({ userId, type, message });
  await notif.save();
  return notif;
};

// Social Trigger: Notify friends when user learns a new word
export const triggerWordLearnedNotifications = async (userId, wordText) => {
  const session = getSession();
  try {
    // 1. Fetch user's username
    const user = await User.findById(userId);
    if (!user) return;

    // 2. Query Neo4j for all friends
    const cypher = `
      MATCH (:User {mongo_id: $userId})-[:FRIEND_OF]-(f:User)
      RETURN f.mongo_id AS friendId
    `;
    const res = await session.run(cypher, { userId });
    const friendIds = res.records.map(rec => rec.get('friendId'));

    // 3. Create a notification for each friend
    for (const friendId of friendIds) {
      await createNotification(
        friendId,
        'FRIEND_WORD',
        `${user.username} just learned the word "${wordText}"!`
      );
    }
  } catch (err) {
    console.error(`Failed to trigger friend word notifications: ${err.message}`);
  } finally {
    await session.close();
  }
};

// Inactivity Trigger: Check daily inactivity for all users
export const checkInactivityNotifications = async () => {
  const session = getSession();
  try {
    // Query last learned timestamp for all users
    const cypher = `
      MATCH (u:User)
      OPTIONAL MATCH (u)-[r:LEARNED]->(w:Word)
      RETURN u.mongo_id AS userId, u.username AS username, max(r.added_at) AS lastAdded
    `;
    const res = await session.run(cypher);
    const now = new Date();

    for (const record of res.records) {
      const userId = record.get('userId');
      const lastAddedVal = record.get('lastAdded');

      if (!userId) continue;

      let shouldAlert = false;
      if (!lastAddedVal) {
        // User has never added a word. Check if registered > 24h ago
        const userDoc = await User.findById(userId);
        if (userDoc && (now.getTime() - newDocTime(userDoc.createdAt)) > 24 * 60 * 60 * 1000) {
          shouldAlert = true;
        }
      } else {
        // Compare last added datetime
        const lastAddedDate = new Date(lastAddedVal.toString());
        if ((now.getTime() - lastAddedDate.getTime()) > 24 * 60 * 60 * 1000) {
          shouldAlert = true;
        }
      }

      if (shouldAlert) {
        // Avoid duplicate spam: check if they already received an unread inactivity notification in last 24h
        const existing = await Notification.findOne({
          userId,
          type: 'INACTIVITY',
          read: false,
          createdAt: { $gte: new Date(now.getTime() - 24 * 60 * 60 * 1000) }
        });

        if (!existing) {
          await createNotification(
            userId,
            'INACTIVITY',
            "You haven't added any new words today. Keep your learning streak alive!"
          );
        }
      }
    }
  } catch (err) {
    console.error(`Inactivity alert checker failed: ${err.message}`);
  } finally {
    await session.close();
  }
};

const newDocTime = (createdAt) => {
  return createdAt ? new Date(createdAt).getTime() : 0;
};
