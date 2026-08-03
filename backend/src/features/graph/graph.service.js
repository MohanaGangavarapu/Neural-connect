import { getSession } from '../../config/neo4j_pool.js';
import Word from '../../models/Word.js';

export const getUserGraphCanvas = async (userId) => {
  const session = getSession();
  const nodesMap = new Map();
  const edgesMap = new Map();

  try {
    // Cypher query returning caller's learned vocabulary network and all connected relationship edges
    const cypher = `
      MATCH (w1:Word)-[r]-(w2:Word)
      WHERE type(r) <> 'LEARNED' AND type(r) <> 'FRIEND_OF' AND type(r) <> 'PENDING_REQUEST'
      RETURN w1.text AS text, r, type(r) AS relType, w2.text AS connectedText
      LIMIT 300
    `;

    const res = await session.run(cypher, { userId });

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
  } catch (err) {
    console.warn(`Neo4j graph fetch fallback to MongoDB: ${err.message}`);
  } finally {
    await session.close();
  }

  // Fallback / Hybrid populate from MongoDB if Neo4j returned no nodes or edges
  if (nodesMap.size === 0 || edgesMap.size === 0) {
    const mongoWords = await Word.find().limit(50);
    const mongoWordTexts = new Set(mongoWords.map(w => w.word.toLowerCase()));

    for (const doc of mongoWords) {
      const wText = doc.word.toLowerCase();
      if (!nodesMap.has(wText)) {
        nodesMap.set(wText, { id: wText, label: 'Word', ownedByMe: true });
      }

      const relMappings = [
        { list: doc.synonyms || [], type: 'SYNONYM_OF' },
        { list: doc.antonyms || [], type: 'ANTONYM_OF' },
        { list: doc.similarWords || [], type: 'SIMILAR_TO' },
        { list: doc.relatedTerms || [], type: 'RELATED_TO' },
        { list: doc.hypernyms || [], type: 'HYPERNYM_OF' },
        { list: doc.hyponyms || [], type: 'HYPONYM_OF' }
      ];

      for (const relGroup of relMappings) {
        for (const targetWord of relGroup.list.slice(0, 5)) {
          const tText = targetWord.toLowerCase().trim();
          if (tText && tText !== wText) {
            if (!nodesMap.has(tText)) {
              nodesMap.set(tText, { id: tText, label: 'Word', ownedByMe: false });
            }
            const sortedIds = [wText, tText].sort();
            const edgeId = `${sortedIds[0]}_${sortedIds[1]}_${relGroup.type}`;
            if (!edgesMap.has(edgeId)) {
              edgesMap.set(edgeId, {
                id: edgeId,
                source: wText,
                target: tText,
                type: relGroup.type
              });
            }
          }
        }
      }
    }
  }

  return {
    nodes: Array.from(nodesMap.values()),
    edges: Array.from(edgesMap.values())
  };
};
