import request from 'supertest';
import app from '../src/app.js';
import mongoose from 'mongoose';
import User from '../src/models/User.js';
import Word from '../src/models/Word.js';
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET || 'vocabflow_dev_secret_key';

describe('Word Retrieval, Dashboards, and Bookmarks Endpoints', () => {
  let token;
  let userId;
  let wordId1;
  let wordId2;

  beforeAll(async () => {
    // Patch Jest VM environment global type array mismatch for ONNX Runtime
    const originalIsArray = Array.isArray;
    Array.isArray = (value) => {
      if (value?.constructor?.name === 'Float32Array' || value?.constructor?.name === 'BigInt64Array') {
        return true;
      }
      return originalIsArray(value);
    };

    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/vocabflow_test');
    await User.deleteMany({});
    await Word.deleteMany({});

    // Create tester user
    const testUser = new User({
      username: 'retrieval',
      email: 'retrieval@example.com',
      passwordHash: 'hashed_password'
    });
    await testUser.save();
    userId = testUser._id.toString();

    token = jwt.sign(
      { id: testUser._id, username: testUser.username },
      JWT_SECRET,
      { expiresIn: '1h' }
    );

    // Seed Word entries in Mongo cache
    const word1 = new Word({
      word: 'ephemeral',
      partOfSpeech: 'adjective',
      definition: 'Lasting for a very short time.',
      exampleSentence: 'Fame is ephemeral.',
      embedding: [0.1, 0.2, 0.3]
    });
    await word1.save();
    wordId1 = word1._id.toString();

    const word2 = new Word({
      word: 'resilient',
      partOfSpeech: 'adjective',
      definition: 'Able to recover quickly.',
      exampleSentence: 'A resilient athlete.',
      embedding: [0.4, 0.5, 0.6]
    });
    await word2.save();
    wordId2 = word2._id.toString();
  });

  afterAll(async () => {
    await User.deleteMany({});
    await Word.deleteMany({});
    await mongoose.connection.close();
  });

  it('should toggle bookmark successfully on a word', async () => {
    // 1. Bookmark word1
    const res1 = await request(app)
      .post(`/api/v1/words/${wordId1}/bookmark`)
      .set('Authorization', `Bearer ${token}`);

    expect(res1.statusCode).toBe(200);
    expect(res1.body.success).toBe(true);
    expect(res1.body.data.isBookmarked).toBe(true);

    const userCheck = await User.findById(userId);
    expect(userCheck.bookmarks).toContainEqual(new mongoose.Types.ObjectId(wordId1));

    // 2. Unbookmark word1
    const res2 = await request(app)
      .post(`/api/v1/words/${wordId1}/bookmark`)
      .set('Authorization', `Bearer ${token}`);

    expect(res2.statusCode).toBe(200);
    expect(res2.body.success).toBe(true);
    expect(res2.body.data.isBookmarked).toBe(false);
  });

  it('should return 404 when trying to bookmark an invalid/non-existent word ID', async () => {
    const fakeId = new mongoose.Types.ObjectId().toString();
    const res = await request(app)
      .post(`/api/v1/words/${fakeId}/bookmark`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.statusCode).toBe(404);
    expect(res.body.success).toBe(false);
  });
});
