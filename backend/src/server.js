import app from './app.js';
import connectMongo from './config/mongo_pool.js';
import { connectNeo4j, getSession } from './config/neo4j_pool.js';
import dotenv from 'dotenv';
import bcrypt from 'bcryptjs';
import User from './models/User.js';
import Word from './models/Word.js';
import { processWordNLP } from './services/nlp.service.js';

dotenv.config({ override: true });

const PORT = process.env.PORT || 3000;

const seedAdminUser = async () => {
  try {
    const adminEmail = 'admin@vocabflow.com';
    const existingAdmin = await User.findOne({ email: adminEmail });
    if (!existingAdmin) {
      const passwordHash = await bcrypt.hash('AdminPassword123!', 10);
      const adminUser = new User({
        username: 'admin',
        email: adminEmail,
        passwordHash,
        isAdmin: true
      });
      await adminUser.save();

      // Seed in Neo4j as well
      const session = getSession();
      try {
        await session.executeWrite((tx) =>
          tx.run(
            'MERGE (u:User {mongo_id: $id}) SET u.username = $username RETURN u',
            { id: adminUser._id.toString(), username: 'admin' }
          )
        );
      } finally {
        await session.close();
      }
      console.log('Seeded default admin user successfully.');
    }
  } catch (err) {
    console.error('Failed to seed default admin user:', err.message);
  }
};

const fixMissingDefinitions = async () => {
  try {
    const problematicWords = await Word.find({ definition: 'No definition available.' });
    if (problematicWords.length > 0) {
      console.log(`Found ${problematicWords.length} cached words with missing definitions. Attempting fallback retrieval...`);
    }
    for (const w of problematicWords) {
      console.log(`Fixing definition for cached word: "${w.word}"`);
      const data = await processWordNLP(w.word);
      if (data && data.definition !== 'No definition available.') {
        w.definition = data.definition;
        w.partOfSpeech = data.partOfSpeech;
        w.exampleSentence = data.exampleSentence;
        w.embedding = data.embedding;
        await w.save();
        console.log(`Successfully fixed definition for "${w.word}"`);
      }
    }
  } catch (err) {
    console.error('Failed to run fallback definition migrations:', err.message);
  }
};

const cleanupIncorrectRelationships = async () => {
  const session = getSession();
  try {
    const query = `
      MATCH (w1:Word {text: 'happy'})-[r:SYNONYM_OF]-(w2:Word {text: 'river'})
      DELETE r
      RETURN count(r) AS deletedCount
    `;
    const result = await session.executeWrite((tx) => tx.run(query));
    const deletedCount = result.records[0]?.get('deletedCount').toNumber() || 0;
    if (deletedCount > 0) {
      console.log(`Cleaned up ${deletedCount} incorrect synonym relationship(s) between 'happy' and 'river'.`);
    }
  } catch (err) {
    console.error('Failed to cleanup incorrect relationships:', err.message);
  } finally {
    await session.close();
  }
};

const seedCrews = async () => {
  const session = getSession();
  try {
    const query = `
      MERGE (c1:Crew {name: 'Polyglots Guild'})
      ON CREATE SET c1.avatar = '🗣️', c1.description = 'Multilingual enthusiasts mastering vocabulary.', c1.memberCount = 12
      MERGE (c2:Crew {name: 'Word Wizards'})
      ON CREATE SET c2.avatar = '🧙', c2.description = 'Exploring advanced etymology and word structures.', c2.memberCount = 8
      MERGE (c3:Crew {name: 'Verbalist Elites'})
      ON CREATE SET c3.avatar = '✨', c3.description = 'High-end rhetoric and expressive linguistic skills.', c3.memberCount = 5
      RETURN c1, c2, c3
    `;
    await session.executeWrite((tx) => tx.run(query));
    console.log('Seeded default crews successfully in Neo4j.');
  } catch (err) {
    console.error('Failed to seed default crews:', err.message);
  } finally {
    await session.close();
  }
};

const syncMongoToNeo4j = async () => {
  const session = getSession();
  try {
    const words = await Word.find({});
    console.log(`Syncing ${words.length} MongoDB word(s) into Neo4j graph...`);

    const allWordTexts = words.map(w => w.word.toLowerCase().trim());
    await session.executeWrite((tx) =>
      tx.run(
        `UNWIND $words AS wText
         MERGE (w:Word {text: wText})`,
        { words: allWordTexts }
      )
    );

    const relMap = {
      'SYNONYM_OF': { field: 'synonyms', relation: 'synonym' },
      'ANTONYM_OF': { field: 'antonyms', relation: 'antonym' },
      'HYPERNYM_OF': { field: 'hypernyms', relation: 'hypernym' },
      'HYPONYM_OF': { field: 'hyponyms', relation: 'hyponym' },
      'RELATED_TO': { field: 'relatedTerms', relation: 'related term' },
      'SIMILAR_TO': { field: 'similarWords', relation: 'similar word' }
    };

    for (const [relLabel, meta] of Object.entries(relMap)) {
      const pairs = [];
      for (const w of words) {
        const w1 = w.word.toLowerCase().trim();
        const list = w[meta.field] || [];
        for (const t of list.slice(0, 5)) {
          const w2 = t.toLowerCase().trim();
          if (w2 && w2 !== w1) {
            pairs.push({ w1, w2, relation: meta.relation });
          }
        }
      }

      if (pairs.length > 0) {
        await session.executeWrite((tx) =>
          tx.run(
            `UNWIND $pairs AS p
             MERGE (w1:Word {text: p.w1})
             MERGE (w2:Word {text: p.w2})
             MERGE (w1)-[r:${relLabel}]->(w2)
             SET r.source = "lexical", r.relation = p.relation, r.confidence = 0.95`,
            { pairs }
          )
        );
      }
    }
    console.log('Neo4j graph database synchronization completed successfully.');
  } catch (err) {
    console.error('Failed to sync Mongo words to Neo4j:', err.message);
  } finally {
    await session.close();
  }
};

const startServer = async () => {
  // Initialize connection pools
  await connectMongo();
  await connectNeo4j();

  // Seed default admin
  await seedAdminUser();

  // Seed default crews
  await seedCrews();

  // Sync all MongoDB words and relationships into Neo4j
  await syncMongoToNeo4j();

  // Auto-heal missing definitions for previously cached items
  await fixMissingDefinitions();

  // Clean up incorrect synonym relationships (e.g. between 'happy' and 'river')
  await cleanupIncorrectRelationships();

  app.listen(PORT, () => {
    console.log(`Server is running in ${process.env.NODE_ENV || 'development'} mode on port ${PORT}`);
  });
};

startServer();
