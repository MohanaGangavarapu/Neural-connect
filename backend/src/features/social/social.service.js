import { getSession } from '../../config/neo4j_pool.js';
import User from '../../models/User.js';
import Word from '../../models/Word.js';
import { createNotification } from '../notifications/notifications.service.js';

export const getUsersDirectory = async (userId) => {
  // Resolve other users from MongoDB first
  const currentMongoUser = await User.findById(userId);
  const otherUsers = await User.find({ _id: { $ne: userId } });

  const session = getSession();
  try {
    const list = [];
    for (const u of otherUsers) {
      const targetId = u._id.toString();

      // Check current relationship in Neo4j
      const cypher = `
        MATCH (u1:User {mongo_id: $userId})
        MATCH (u2:User {mongo_id: $targetId})
        OPTIONAL MATCH (u1)-[r:FRIEND_OF]-(u2)
        OPTIONAL MATCH (u1)-[sent:PENDING_REQUEST]->(u2)
        OPTIONAL MATCH (u2)-[recv:PENDING_REQUEST]->(u1)
        RETURN r IS NOT NULL AS isFriend, sent IS NOT NULL AS sentReq, recv IS NOT NULL AS recvReq
      `;

      const res = await session.run(cypher, { userId, targetId });
      let status = 'NONE';

      if (res.records.length > 0) {
        const isFriend = res.records[0].get('isFriend');
        const sentReq = res.records[0].get('sentReq');
        const recvReq = res.records[0].get('recvReq');

        if (isFriend) status = 'FRIENDS';
        else if (sentReq) status = 'PENDING_SENT';
        else if (recvReq) status = 'PENDING_RECEIVED';
      }

      list.push({
        id: targetId,
        username: u.username,
        relationship: status
      });
    }
    return list;
  } finally {
    await session.close();
  }
};

export const sendFriendRequest = async (userId, targetUsername) => {
  const targetUser = await User.findOne({ username: targetUsername.trim().toLowerCase() });
  if (!targetUser) {
    const err = new Error('Target user handle does not exist.');
    err.statusCode = 404;
    throw err;
  }

  const targetId = targetUser._id.toString();
  if (targetId === userId) {
    const err = new Error('Attempting to add oneself is not permitted.');
    err.statusCode = 400;
    throw err;
  }

  const session = getSession();
  try {
    // Check if relationships already exist
    const checkQuery = `
      MATCH (u1:User {mongo_id: $userId})
      MATCH (u2:User {mongo_id: $targetId})
      OPTIONAL MATCH (u1)-[r:FRIEND_OF]-(u2)
      OPTIONAL MATCH (u1)-[p:PENDING_REQUEST]-(u2)
      RETURN r IS NOT NULL AS isFriend, p IS NOT NULL AS isPending
    `;
    const checkRes = await session.run(checkQuery, { userId, targetId });

    if (checkRes.records.length > 0) {
      if (checkRes.records[0].get('isFriend')) {
        const err = new Error('Users are already friends.');
        err.statusCode = 400;
        throw err;
      }
      if (checkRes.records[0].get('isPending')) {
        const err = new Error('A friend request is already pending between these users.');
        err.statusCode = 400;
        throw err;
      }
    }

    await session.executeWrite((tx) =>
      tx.run(
        `MATCH (u1:User {mongo_id: $userId}), (u2:User {mongo_id: $targetId})
         MERGE (u1)-[:PENDING_REQUEST]->(u2)`,
        { userId, targetId }
      )
    );

    // Trigger notification
    const sender = await User.findById(userId);
    const senderUsername = sender ? sender.username : 'Someone';
    await createNotification(
      targetId,
      'FRIEND_REQUEST',
      `${senderUsername} sent you a friend request.`
    );

    return { success: true, message: `Friend request successfully dispatched to ${targetUsername}.` };
  } finally {
    await session.close();
  }
};

export const respondToFriendRequest = async (userId, requesterId, action) => {
  if (action !== 'accept' && action !== 'decline') {
    const err = new Error('Action must match accept or decline.');
    err.statusCode = 400;
    throw err;
  }

  const session = getSession();
  try {
    if (action === 'accept') {
      await session.executeWrite((tx) =>
        tx.run(
          `MATCH (u1:User {mongo_id: $userId})<-[p:PENDING_REQUEST]-(u2:User {mongo_id: $requesterId})
           DELETE p
           MERGE (u1)-[:FRIEND_OF]-(u2)`,
          { userId, requesterId }
        )
      );

      // Trigger notifications for both users
      const acceptor = await User.findById(userId);
      const requester = await User.findById(requesterId);
      const acceptorUsername = acceptor ? acceptor.username : 'Someone';
      const requesterUsername = requester ? requester.username : 'Someone';

      await createNotification(
        requesterId,
        'FRIEND_ACCEPTED',
        `${acceptorUsername} accepted your friend request.`
      );
      await createNotification(
        userId,
        'FRIEND_ACCEPTED',
        `${requesterUsername} is now your friend.`
      );

      return { success: true, message: 'Friend connection established successfully.' };
    } else {
      await session.executeWrite((tx) =>
        tx.run(
          `MATCH (u1:User {mongo_id: $userId})<-[p:PENDING_REQUEST]-(u2:User {mongo_id: $requesterId})
           DELETE p`,
          { userId, requesterId }
        )
      );
      return { success: true, message: 'Friend request declined successfully.' };
    }
  } finally {
    await session.close();
  }
};

export const getProfileStats = async (userId) => {
  const user = await User.findById(userId);
  if (!user) {
    throw new Error('User not found');
  }
  const bookmarkCount = user.bookmarks?.length || 0;

  const session = getSession();
  let wordsCount = 0;
  let friendsCount = 0;
  let friendIds = [];
  let learnedTexts = [];
  let crews = [];

  // Calculate streaks, activity calendar, and weekly progress from Neo4j
  let currentStreak = 0;
  let longestStreak = 0;
  let wordsAddedThisWeek = 0;
  const activityMap = {};
  const weeklyProgress = [];

  try {
    // 1. Query total words learned
    const wordsRes = await session.run(
      'MATCH (:User {mongo_id: $userId})-[:LEARNED]->(w:Word) RETURN count(w) AS totalWords',
      { userId }
    );
    if (wordsRes.records.length > 0) {
      wordsCount = wordsRes.records[0].get('totalWords').toNumber();
    }

    // 2. Query total friends count and IDs
    const friendsRes = await session.run(
      'MATCH (:User {mongo_id: $userId})-[:FRIEND_OF]-(f:User) RETURN f.mongo_id AS id',
      { userId }
    );
    friendIds = friendsRes.records.map(rec => rec.get('id'));
    friendsCount = friendIds.length;

    // 3. Query learned timestamps to compute streaks & calendars
    const streakRes = await session.run(
      `MATCH (:User {mongo_id: $userId})-[r:LEARNED]->(w:Word)
       RETURN r.added_at AS addedAt, w.text AS text
       ORDER BY r.added_at ASC`,
      { userId }
    );

    const dates = [];
    for (const record of streakRes.records) {
      const addedAt = record.get('addedAt');
      const wText = record.get('text');
      if (wText) {
        learnedTexts.push(wText);
      }
      if (addedAt) {
        let dateStr = '';
        if (typeof addedAt === 'string') {
          dateStr = addedAt.split('T')[0];
        } else if (addedAt.toString) {
          dateStr = addedAt.toString().split('T')[0];
        }
        if (dateStr && /^\d{4}-\d{2}-\d{2}$/.test(dateStr)) {
          dates.push(dateStr);
        }
      }
    }

    // Group activities per day
    for (const date of dates) {
      activityMap[date] = (activityMap[date] || 0) + 1;
    }
    const uniqueDates = Object.keys(activityMap).sort();

    // Streak calculation algorithm
    if (uniqueDates.length > 0) {
      const today = new Date();
      const todayStr = today.toISOString().split('T')[0];
      const yesterday = new Date(today);
      yesterday.setDate(yesterday.getDate() - 1);
      const yesterdayStr = yesterday.toISOString().split('T')[0];

      let lastDate = new Date(uniqueDates[uniqueDates.length - 1]);
      const lastDateStr = uniqueDates[uniqueDates.length - 1];

      // Check if current streak is active (today or yesterday)
      if (lastDateStr === todayStr || lastDateStr === yesterdayStr) {
        currentStreak = 1;
        for (let i = uniqueDates.length - 2; i >= 0; i--) {
          const prevDate = new Date(uniqueDates[i]);
          const diffTime = Math.abs(lastDate - prevDate);
          const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
          if (diffDays === 1) {
            currentStreak++;
            lastDate = prevDate;
          } else if (diffDays > 1) {
            break;
          }
        }
      }

      // Calculate longest streak
      let tempStreak = 1;
      let prev = new Date(uniqueDates[0]);
      for (let i = 1; i < uniqueDates.length; i++) {
        const curr = new Date(uniqueDates[i]);
        const diffTime = Math.abs(curr - prev);
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        if (diffDays === 1) {
          tempStreak++;
        } else if (diffDays > 1) {
          if (tempStreak > longestStreak) longestStreak = tempStreak;
          tempStreak = 1;
        }
        prev = curr;
      }
      if (tempStreak > longestStreak) longestStreak = tempStreak;
    }

    // Populate weekly activity progress
    const today = new Date();
    for (let i = 6; i >= 0; i--) {
      const d = new Date(today);
      d.setDate(d.getDate() - i);
      const dStr = d.toISOString().split('T')[0];
      const count = activityMap[dStr] || 0;
      weeklyProgress.push({ date: dStr, count });
      wordsAddedThisWeek += count;
    }

    // 4. Query user crews memberships
    const crewsRes = await session.run(
      `MATCH (u:User {mongo_id: $userId})-[r:MEMBER_OF]->(c:Crew)
       RETURN c.name AS name, c.avatar AS avatar, c.memberCount AS memberCount, r.role AS role`,
      { userId }
    );
    if (crewsRes.records.length > 0) {
      crews = crewsRes.records.map(rec => ({
        name: rec.get('name'),
        avatar: rec.get('avatar') || '🧙',
        memberCount: rec.get('memberCount')?.toNumber() || 1,
        role: rec.get('role') || 'Member'
      }));
    } else {
      // Auto-join first-time user to Word Wizards default crew
      await session.executeWrite((tx) =>
        tx.run(
          `MATCH (u:User {mongo_id: $userId}), (c:Crew {name: 'Word Wizards'})
           MERGE (u)-[:MEMBER_OF {role: 'Member'}]->(c)
           RETURN c`,
          { userId }
        )
      );
      crews = [{
        name: 'Word Wizards',
        avatar: '🧙',
        memberCount: 9,
        role: 'Member'
      }];
    }
  } finally {
    await session.close();
  }

  // 5. Query MongoDB Bookmarks details
  const recentBookmarks = await Word.find({ _id: { $in: user.bookmarks || [] } })
    .sort({ createdAt: -1 })
    .limit(5);
  const bookmarksList = recentBookmarks.map(w => ({
    id: w._id,
    word: w.word,
    definition: w.definition,
    createdAt: w.createdAt
  }));

  // 6. Query MongoDB Connections details
  const recentFriends = await User.find({ _id: { $in: friendIds } }).limit(5);
  const connectionsList = recentFriends.map(f => ({
    id: f._id,
    username: f.username,
    displayName: f.displayName || f.username,
    avatarUrl: f.avatarUrl || ''
  }));

  // 7. Calculate Part of Speech counts
  const learnedWordsDocs = await Word.find({ word: { $in: learnedTexts } });
  const categoryCounts = { noun: 0, verb: 0, adjective: 0, adverb: 0, other: 0 };
  for (const w of learnedWordsDocs) {
    const pos = (w.partOfSpeech || '').toLowerCase().trim();
    if (pos.includes('noun')) {
      categoryCounts.noun++;
    } else if (pos.includes('verb')) {
      categoryCounts.verb++;
    } else if (pos.includes('adj')) {
      categoryCounts.adjective++;
    } else if (pos.includes('adv')) {
      categoryCounts.adverb++;
    } else {
      categoryCounts.other++;
    }
  }

  // 8. Achievements List Checking
  const achievements = [
    {
      id: 'first_word',
      name: 'First Word Added',
      description: 'Ingested your first word to the vocabulary galaxy.',
      unlocked: wordsCount >= 1,
      progress: Math.min(1.0, wordsCount / 1.0)
    },
    {
      id: 'streak_7',
      name: '7-Day Streak',
      description: 'Maintained a word learning streak for 7 consecutive days.',
      unlocked: longestStreak >= 7,
      progress: Math.min(1.0, longestStreak / 7.0)
    },
    {
      id: 'streak_30',
      name: '30-Day Streak',
      description: 'Maintained a word learning streak for 30 consecutive days.',
      unlocked: longestStreak >= 30,
      progress: Math.min(1.0, longestStreak / 30.0)
    },
    {
      id: 'words_100',
      name: '100 Words Learned',
      description: 'Expanded your galaxy to contain 100 learned words.',
      unlocked: wordsCount >= 100,
      progress: Math.min(1.0, wordsCount / 100.0)
    },
    {
      id: 'crew_contributor',
      name: 'Crew Contributor',
      description: 'Joined a vocabulary learning crew.',
      unlocked: crews.length >= 1,
      progress: crews.length >= 1 ? 1.0 : 0.0
    }
  ];

  return {
    totalWords: wordsCount,
    totalBookmarks: bookmarkCount,
    totalFriends: friendsCount,
    isAdmin: user.isAdmin || false,
    profile: {
      username: user.username,
      displayName: user.displayName || user.username,
      bio: user.bio || '',
      avatarUrl: user.avatarUrl || '',
      learningLevel: wordsCount < 10 ? 'Novice' : (wordsCount < 50 ? 'Scholar' : 'Lexicographer')
    },
    streak: {
      currentStreak,
      longestStreak,
      wordsAddedThisWeek,
      weeklyProgress,
      calendar: activityMap
    },
    crews,
    recentBookmarks: bookmarksList,
    recentConnections: connectionsList,
    categories: categoryCounts,
    achievements
  };
};

export const updateProfileDetails = async (userId, { displayName, bio, avatarUrl }) => {
  const updates = {};
  if (displayName !== undefined) updates.displayName = displayName.trim();
  if (bio !== undefined) updates.bio = bio.trim();
  if (avatarUrl !== undefined) updates.avatarUrl = avatarUrl.trim();

  const user = await User.findByIdAndUpdate(userId, updates, { new: true });
  if (!user) {
    throw new Error('User not found');
  }

  // Sync profile updates to Neo4j User Node
  const session = getSession();
  try {
    await session.executeWrite((tx) =>
      tx.run(
        `MATCH (u:User {mongo_id: $userId})
         SET u.displayName = $displayName,
             u.bio = $bio,
             u.avatarUrl = $avatarUrl`,
        {
          userId,
          displayName: user.displayName || user.username,
          bio: user.bio || '',
          avatarUrl: user.avatarUrl || ''
        }
      )
    );
  } catch (neo4jError) {
    console.error(`Failed to sync profile updates to Neo4j: ${neo4jError.message}`);
  } finally {
    await session.close();
  }

  return {
    username: user.username,
    displayName: user.displayName || user.username,
    bio: user.bio || '',
    avatarUrl: user.avatarUrl || ''
  };
};

export const getFriendWords = async (userId, friendId) => {
  const session = getSession();
  try {
    // 1. Verify mutual friendship in Neo4j first
    const friendCheck = await session.run(
      `MATCH (u1:User {mongo_id: $userId})-[r:FRIEND_OF]-(u2:User {mongo_id: $friendId})
       RETURN r`,
      { userId, friendId }
    );

    if (friendCheck.records.length === 0) {
      const err = new Error('Forbidden: Users are not mutually linked via FRIEND_OF relationships.');
      err.statusCode = 403;
      throw err;
    }

    // 2. Fetch friend's learned words
    const wordsRes = await session.run(
      'MATCH (u:User {mongo_id: $friendId})-[:LEARNED]->(w:Word) RETURN w.text AS text',
      { friendId }
    );
    const learnedTexts = wordsRes.records.map(rec => rec.get('text'));

    // 3. Resolve details from MongoDB
    const words = await Word.find({ word: { $in: learnedTexts } });
    return words.map(w => ({
      word: w.word,
      partOfSpeech: w.partOfSpeech,
      definition: w.definition
    }));
  } finally {
    await session.close();
  }
};

