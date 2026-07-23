import request from 'supertest';
import app from '../src/app.js';
import mongoose from 'mongoose';
import User from '../src/models/User.js';
import Word from '../src/models/Word.js';
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET || 'vocabflow_dev_secret_key';

describe('NLP & Word Entry Pipeline', () => {
  let token;
  let userId;

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
    
    // Clear databases
    await User.deleteMany({});
    await Word.deleteMany({});

    // Create a mock user for testing
    const testUser = new User({
      username: 'nlp_tester',
      email: 'nlp@example.com',
      passwordHash: 'hashed_password'
    });
    await testUser.save();
    userId = testUser._id.toString();

    token = jwt.sign(
      { id: testUser._id, username: testUser.username },
      JWT_SECRET,
      { expiresIn: '1h' }
    );
  });

  afterAll(async () => {
    await User.deleteMany({});
    await Word.deleteMany({});
    await mongoose.connection.close();
  });

  it('should successfully fetch, embed, and dual-store a new word', async () => {
    const res = await request(app)
      .post('/api/v1/words')
      .set('Authorization', `Bearer ${token}`)
      .send({ word: 'resilient' });

    expect(res.statusCode).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.wordInfo.word).toBe('resilient');
    expect(res.body.data.wordInfo.definition).toBeDefined();

    // Confirm it exists in MongoDB cache
    const mongoWord = await Word.findOne({ word: 'resilient' });
    expect(mongoWord).toBeDefined();
    expect(mongoWord.embedding.length).toBeGreaterThan(0);
  }, 30000);

  it('should throw validation error for invalid word formats', async () => {
    const res = await request(app)
      .post('/api/v1/words')
      .set('Authorization', `Bearer ${token}`)
      .send({ word: 'resilient123' });

    expect(res.statusCode).toBe(400);
    expect(res.body.success).toBe(false);
  });
});
