import request from 'supertest';
import app from '../src/app.js';
import mongoose from 'mongoose';
import User from '../src/models/User.js';
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET || 'vocabflow_dev_secret_key';

describe('Graph Sub-Neighborhood Canvas Endpoints', () => {
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
    await User.deleteMany({});

    const testUser = new User({
      username: 'graphuser',
      email: 'graph@example.com',
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
    await mongoose.connection.close();
  });

  it('should successfully fetch the neighborhood canvas arrays', async () => {
    const res = await request(app)
      .get('/api/v1/graph/canvas')
      .set('Authorization', `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.nodes).toBeDefined();
    expect(res.body.data.edges).toBeDefined();
  });
});
