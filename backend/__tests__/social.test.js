import request from 'supertest';
import app from '../src/app.js';
import mongoose from 'mongoose';
import User from '../src/models/User.js';
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET || 'vocabflow_dev_secret_key';

describe('Social Layer integration Endpoints', () => {
  let token1, token2;
  let user1Id, user2Id;

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

    // Seed test users
    const u1 = new User({ username: 'userone', email: 'one@example.com', passwordHash: 'hash' });
    await u1.save();
    user1Id = u1._id.toString();

    const u2 = new User({ username: 'usertwo', email: 'two@example.com', passwordHash: 'hash' });
    await u2.save();
    user2Id = u2._id.toString();

    token1 = jwt.sign({ id: u1._id, username: u1.username }, JWT_SECRET, { expiresIn: '1h' });
    token2 = jwt.sign({ id: u2._id, username: u2.username }, JWT_SECRET, { expiresIn: '1h' });
  });

  afterAll(async () => {
    await User.deleteMany({});
    await mongoose.connection.close();
  });

  it('should list other users in directory and display relation as NONE initially', async () => {
    const res = await request(app)
      .get('/api/v1/social/users')
      .set('Authorization', `Bearer ${token1}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.length).toBeGreaterThan(0);
    expect(res.body.data[0].relationship).toBe('NONE');
  });

  it('should successfully dispatch a pending friend request', async () => {
    const res = await request(app)
      .post('/api/v1/social/friends/request')
      .set('Authorization', `Bearer ${token1}`)
      .send({ targetUsername: 'usertwo' });

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
  });

  it('should retrieve user profile stats cleanly', async () => {
    const res = await request(app)
      .get('/api/v1/social/profile/stats')
      .set('Authorization', `Bearer ${token1}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.totalWords).toBeDefined();
    expect(res.body.data.totalBookmarks).toBeDefined();
  });

  it('should return 403 Forbidden when viewing words of a user who is not a friend', async () => {
    const res = await request(app)
      .get(`/api/v1/social/friends/${user2Id}/words`)
      .set('Authorization', `Bearer ${token1}`);

    expect(res.statusCode).toBe(403);
    expect(res.body.success).toBe(false);
  });
});
