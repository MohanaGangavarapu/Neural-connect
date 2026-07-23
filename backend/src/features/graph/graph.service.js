import { getSession } from '../../config/neo4j_pool.js';

export const getUserGraphCanvas = async (userId) => {
  const session = getSession();
  try {
    // Cypher query returning caller's learned vocabulary network and edges connecting learned words
    const cypher = `
      MATCH (u:User {mongo_id: $userId})-[:LEARNED]->(w1:Word)
      OPTIONAL MATCH (w1)-[r]-(w2:Word)
      WHERE type(r) <> 'LEARNED' AND type(r) <> 'FRIEND_OF' AND type(r) <> 'PENDING_REQUEST'
        AND (u)-[:LEARNED]->(w2)
      RETURN w1.text AS text, r, type(r) AS relType, w2.text AS connectedText
    `;

    const res = await session.run(cypher, { userId });
    const nodesMap = new Map();
    const edgesMap = new Map();

    for (const record of res.records) {
      const wText = record.get('text');
      const relType = record.get('relType');
      const connectedText = record.get('connectedText');

      if (wText && !nodesMap.has(wText)) {
        nodesMap.set(wText, { id: wText, label: 'Word', ownedByMe: true });
      }

      if (connectedText) {
        if (!nodesMap.has(connectedText)) {
          nodesMap.set(connectedText, { id: connectedText, label: 'Word', ownedByMe: true });
        }

        const sortedIds = [wText, connectedText].sort();
        const edgeId = `${sortedIds[0]}_${sortedIds[1]}_${relType}`;

        if (!edgesMap.has(edgeId)) {
          edgesMap.set(edgeId, {
            id: edgeId,
            source: wText,
            target: connectedText,
            type: relType
          });
        }
      }
    }

    return {
      nodes: Array.from(nodesMap.values()),
      edges: Array.from(edgesMap.values())
    };
  } finally {
    await session.close();
  }
};
