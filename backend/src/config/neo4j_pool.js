import neo4j from 'neo4j-driver';
import dotenv from 'dotenv';

dotenv.config({ override: true });

const NEO4J_URI = process.env.NEO4J_URI || 'bolt://localhost:7687';
const NEO4J_USER = process.env.NEO4J_USERNAME || process.env.NEO4J_USER || 'neo4j';
const NEO4J_PASSWORD = process.env.NEO4J_PASSWORD || 'password';

// Create a single persistent driver instance (Connection Pool) or mock if SKIP_NEO4J is true
const SKIP_NEO4J = process.env.SKIP_NEO4J === 'true';

const driver = SKIP_NEO4J ? null : neo4j.driver(
  NEO4J_URI,
  neo4j.auth.basic(NEO4J_USER, NEO4J_PASSWORD),
  {
    maxConnectionPoolSize: 10,
    connectionAcquisitionTimeout: 20000,
  }
);

// Global In-Memory Graph Data Store for Development Bypasses
const mockGraph = {
  users: new Map(), // mongo_id -> { mongo_id, username }
  words: new Map(), // text -> { text }
  relationships: [] // array of { from, to, type, properties }
};

class MockRecord {
  constructor(data) {
    this.data = data;
  }
  get(key) {
    const val = this.data[key];
    if (val !== undefined && val !== null) {
      if (typeof val === 'number') {
        return {
          toNumber: () => val,
          low: val,
          high: 0
        };
      }
      return val;
    }
    return null;
  }
}

const mockRun = async (query, params = {}) => {
  const q = query.replace(/\s+/g, ' ').trim();

  // 1. CREATE / MERGE User node
  if (q.includes('CREATE (u:User') || q.includes('MERGE (u:User')) {
    const id = params.id || params.userId;
    const username = params.username;
    if (id) {
      mockGraph.users.set(id, { mongo_id: id, username: username || '' });
    }
    return { records: [new MockRecord({ u: { properties: { mongo_id: id, username } } })] };
  }

  // 2. Check duplicate LEARNED link
  if (q.includes('MATCH (u:User {mongo_id: $userId})-[:LEARNED]->(w:Word {text: $word})')) {
    const exists = mockGraph.relationships.some(
      r => r.from === params.userId && r.to === params.word && r.type === 'LEARNED'
    );
    if (exists) {
      return { records: [new MockRecord({ w: { properties: { text: params.word } } })] };
    }
    return { records: [] };
  }

  // 3. Create Word node & LEARNED link
  if (q.includes('MERGE (w:Word {text: $word})') && q.includes('LEARNED')) {
    const word = params.word;
    const userId = params.userId;
    mockGraph.words.set(word, { text: word });
    const exists = mockGraph.relationships.some(
      r => r.from === userId && r.to === word && r.type === 'LEARNED'
    );
    if (!exists) {
      mockGraph.relationships.push({
        from: userId,
        to: word,
        type: 'LEARNED',
        properties: { added_at: new Date().toISOString() }
      });
    }
    return { records: [new MockRecord({ w: { properties: { text: word } } })] };
  }

  // 4. Create SYNONYM_OF link
  if (q.includes('SYNONYM_OF') && (q.includes('$syn') || q.includes('$other'))) {
    const word = params.word;
    const syn = params.syn || params.other;
    mockGraph.words.set(word, { text: word });
    mockGraph.words.set(syn, { text: syn });
    const exists = mockGraph.relationships.some(
      r => ((r.from === word && r.to === syn) || (r.from === syn && r.to === word)) && r.type === 'SYNONYM_OF'
    );
    if (!exists) {
      mockGraph.relationships.push({ from: word, to: syn, type: 'SYNONYM_OF', properties: {} });
    }
    return { records: [] };
  }

  // 5. Create ANTONYM_OF link
  if (q.includes('ANTONYM_OF') && q.includes('$ant')) {
    const word = params.word;
    const ant = params.ant;
    mockGraph.words.set(word, { text: word });
    mockGraph.words.set(ant, { text: ant });
    const exists = mockGraph.relationships.some(
      r => ((r.from === word && r.to === ant) || (r.from === ant && r.to === word)) && r.type === 'ANTONYM_OF'
    );
    if (!exists) {
      mockGraph.relationships.push({ from: word, to: ant, type: 'ANTONYM_OF', properties: {} });
    }
    return { records: [] };
  }

  // 6. Fetch word semantic links
  if (q.includes('MATCH (w1:Word {text: $word})-[r:SYNONYM_OF|ANTONYM_OF]-(w2:Word)')) {
    const word = params.word;
    const recs = [];
    for (const r of mockGraph.relationships) {
      if (r.type === 'SYNONYM_OF' || r.type === 'ANTONYM_OF') {
        if (r.from === word) {
          recs.push(new MockRecord({ from: word, to: r.to, type: r.type }));
        } else if (r.to === word) {
          recs.push(new MockRecord({ from: word, to: r.from, type: r.type }));
        }
      }
    }
    return { records: recs };
  }

  // 6b. Generic fetch custom relationship (for our new endpoints)
  if (q.includes('MATCH (w:Word {text: $word})-[r]-(connectedWord:Word) WHERE type(r) <> \'LEARNED\'')) {
    const word = params.word;
    const recs = [];
    for (const r of mockGraph.relationships) {
      if (r.type !== 'LEARNED' && r.type !== 'FRIEND_OF' && r.type !== 'PENDING_REQUEST') {
        if (r.from === word) {
          recs.push(new MockRecord({ targetWord: r.to, type: r.type }));
        } else if (r.to === word) {
          recs.push(new MockRecord({ targetWord: r.from, type: r.type }));
        }
      }
    }
    return { records: recs };
  }

  // 6c. MERGE custom relationship
  if (q.includes('MERGE (w1)-[r:') && q.includes(']->(w2)')) {
    const word1 = params.word1;
    const word2 = params.word2;
    // Extract relationship type dynamically from string
    const match = query.match(/-\[r:([A-Z_]+)\]->/);
    const relType = match ? match[1] : 'SYNONYM_OF';
    const exists = mockGraph.relationships.some(
      r => r.from === word1 && r.to === word2 && r.type === relType
    );
    if (!exists) {
      mockGraph.relationships.push({ from: word1, to: word2, type: relType, properties: {} });
    }
    return { records: [new MockRecord({ r: {} })] };
  }

  // 6d. DELETE relationship
  if (q.includes('MATCH (w1:Word {text: $word1})-[r:') && q.includes('DELETE r')) {
    const word1 = params.word1;
    const word2 = params.word2;
    const match = query.match(/-\[r:([A-Z_]+)\]-/);
    const relType = match ? match[1] : null;
    mockGraph.relationships = mockGraph.relationships.filter(
      r => {
        const matchesWords = (r.from === word1 && r.to === word2) || (r.from === word2 && r.to === word1);
        const matchesType = !relType || r.type === relType;
        return !(matchesWords && matchesType);
      }
    );
    return { records: [] };
  }

  // 7. Get learned words
  if (q.includes('MATCH (u:User {mongo_id: $userId})-[:LEARNED]->(w:Word) RETURN w.text AS text') ||
      q.includes('MATCH (u:User {mongo_id: $userId})-[:LEARNED]->(w:Word) RETURN w.text')) {
    const userId = params.userId;
    const recs = [];
    for (const r of mockGraph.relationships) {
      if (r.from === userId && r.type === 'LEARNED') {
        recs.push(new MockRecord({ text: r.to }));
      }
    }
    return { records: recs };
  }

  // 8. Count learned words
  if (q.includes('count(w) AS totalWords')) {
    const userId = params.userId;
    let count = 0;
    for (const r of mockGraph.relationships) {
      if (r.from === userId && r.type === 'LEARNED') count++;
    }
    return { records: [new MockRecord({ totalWords: count })] };
  }

  // 9. Count friends
  if (q.includes('count(f) AS totalFriends')) {
    const userId = params.userId;
    let count = 0;
    for (const r of mockGraph.relationships) {
      if ((r.from === userId || r.to === userId) && r.type === 'FRIEND_OF') count++;
    }
    return { records: [new MockRecord({ totalFriends: count })] };
  }

  // 10. Social connections directory statuses
  if (q.includes('OPTIONAL MATCH (u1)-[sent:PENDING_REQUEST]->(u2)') || q.includes('OPTIONAL MATCH (u1)-[r:FRIEND_OF|REQUESTED]-(u2)')) {
    const userId = params.userId;
    const targetId = params.targetId;

    const isFriend = mockGraph.relationships.some(
      r => ((r.from === userId && r.to === targetId) || (r.from === targetId && r.to === userId)) && r.type === 'FRIEND_OF'
    );
    const sentReq = mockGraph.relationships.some(
      r => r.from === userId && r.to === targetId && r.type === 'PENDING_REQUEST'
    );
    const recvReq = mockGraph.relationships.some(
      r => r.from === targetId && r.to === userId && r.type === 'PENDING_REQUEST'
    );

    return {
      records: [
        new MockRecord({
          isFriend,
          sentReq,
          recvReq,
          relType: isFriend ? 'FRIEND_OF' : (sentReq || recvReq ? 'REQUESTED' : null)
        })
      ]
    };
  }

  // 11. Send friend request
  if (q.includes('MERGE (u1)-[:PENDING_REQUEST]->(u2)')) {
    const userId = params.userId;
    const targetId = params.targetId;
    const exists = mockGraph.relationships.some(
      r => r.from === userId && r.to === targetId && r.type === 'PENDING_REQUEST'
    );
    if (!exists) {
      mockGraph.relationships.push({ from: userId, to: targetId, type: 'PENDING_REQUEST', properties: {} });
    }
    return { records: [] };
  }

  // 12. Accept friend request
  if (q.includes('DELETE p MERGE (u1)-[:FRIEND_OF]-(u2)')) {
    const userId = params.userId;
    const requesterId = params.requesterId;

    mockGraph.relationships = mockGraph.relationships.filter(
      r => !(r.from === requesterId && r.to === userId && r.type === 'PENDING_REQUEST')
    );

    const exists = mockGraph.relationships.some(
      r => ((r.from === userId && r.to === requesterId) || (r.from === requesterId && r.to === userId)) && r.type === 'FRIEND_OF'
    );
    if (!exists) {
      mockGraph.relationships.push({ from: userId, to: requesterId, type: 'FRIEND_OF', properties: {} });
    }
    return { records: [] };
  }

  // 13. Decline friend request
  if (q.includes('DELETE p') && q.includes('PENDING_REQUEST')) {
    const userId = params.userId;
    const requesterId = params.requesterId;

    mockGraph.relationships = mockGraph.relationships.filter(
      r => !(r.from === requesterId && r.to === userId && r.type === 'PENDING_REQUEST')
    );
    return { records: [] };
  }

  // 14. Verify friendship FRIEND_OF
  if (q.includes('MATCH (u1:User {mongo_id: $userId})-[r:FRIEND_OF]-(u2:User {mongo_id: $friendId})')) {
    const userId = params.userId;
    const friendId = params.friendId;
    const exists = mockGraph.relationships.some(
      r => ((r.from === userId && r.to === friendId) || (r.from === friendId && r.to === userId)) && r.type === 'FRIEND_OF'
    );
    if (exists) {
      return { records: [new MockRecord({ r: {} })] };
    }
    return { records: [] };
  }

  // 15. Canvas graph fetch
  if (q.includes('connectedWord:Word')) {
    const userId = params.userId;

    const userWords = new Set();
    for (const r of mockGraph.relationships) {
      if (r.from === userId && r.type === 'LEARNED') {
        userWords.add(r.to);
      }
    }

    const recs = [];
    for (const w of userWords) {
      let foundAny = false;

      for (const r of mockGraph.relationships) {
        if (r.type !== 'LEARNED' && r.type !== 'FRIEND_OF' && r.type !== 'PENDING_REQUEST') {
          let connectedWord = null;
          if (r.from === w) {
            connectedWord = r.to;
          } else if (r.to === w) {
            connectedWord = r.from;
          }

          if (connectedWord) {
            const isConnectedOwned = userWords.has(connectedWord);
            recs.push(new MockRecord({
              text: w,
              relType: r.type,
              connectedText: connectedWord,
              isConnectedOwned
            }));
            foundAny = true;
          }
        }
      }
      if (!foundAny) {
        recs.push(new MockRecord({
          text: w,
          relType: null,
          connectedText: null,
          isConnectedOwned: false
        }));
      }
    }

    return { records: recs };
  }

  // 16. Hard delete user node & relations
  if (q.includes('DETACH DELETE u')) {
    const userId = params.userId;
    // Remove all relationships involving user
    mockGraph.relationships = mockGraph.relationships.filter(
      r => r.from !== userId && r.to !== userId
    );
    // Delete user
    mockGraph.users.delete(userId);
    return { records: [] };
  }

  return { records: [] };
};

let isConnected = false;

export const connectNeo4j = async () => {
  if (SKIP_NEO4J) {
    console.log('Neo4j connection skipped (SKIP_NEO4J=true) - Running Graph Simulator Mode');
    return;
  }
  try {
    await driver.verifyConnectivity();
    isConnected = true;
    console.log('Neo4j Connected: Driver successfully verified connectivity');
  } catch (error) {
    isConnected = false;
    console.error(`Error connecting to Neo4j: ${error.message}`);
    console.warn('Backend server running in fallback Graph Simulator Mode until Neo4j is available.');
  }
};

export const getSession = () => {
  if (SKIP_NEO4J || !isConnected) {
    return {
      executeWrite: async (fn) => {
        const mockTx = {
          run: mockRun
        };
        return fn(mockTx);
      },
      run: mockRun,
      close: async () => {}
    };
  }
  return driver.session();
};

export const closeNeo4j = async () => {
  if (SKIP_NEO4J) return;
  await driver.close();
};

export default driver;

