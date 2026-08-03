import User from '../../models/User.js';
import Word from '../../models/Word.js';
import { getSession } from '../../config/neo4j_pool.js';
import { checkInactivityNotifications } from '../notifications/notifications.service.js';

export const getAdminStats = async () => {
  const totalUsers = await User.countDocuments();
  const totalWords = await Word.countDocuments();

  const session = getSession();
  let totalRelationships = 0;
  try {
    const res = await session.run('MATCH ()-[r]->() RETURN count(r) AS count');
    if (res.records.length > 0) {
      totalRelationships = res.records[0].get('count').toNumber();
    }
  } catch (err) {
    console.error(`Failed to get relationship count: ${err.message}`);
  } finally {
    await session.close();
  }

  return {
    totalUsers,
    totalWords,
    totalRelationships
  };
};

export const triggerInactivityCheck = async () => {
  await checkInactivityNotifications();
  return { success: true, message: 'Inactivity checks completed successfully.' };
};
