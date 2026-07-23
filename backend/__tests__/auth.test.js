import request from 'supertest';
import app from '../src/app.js';
import mongoose from 'mongoose';
import User from '../src/models/User.js';
import driver from '../src/config/neo4j_pool.js';

beforeAll(async () => {
  const originalIsArray = Array.isArray;
  Array.isArray = (value) => {
    if (value?.constructor?.name === 'Float32Array' || value?.constructor?.name === 'BigInt64Array') {
      return true;
    }
    return originalIsArray(value);
  };

  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/vocabflow_test');
});

afterAll(async () => {
  await User.deleteMany({});
  await mongoose.connection.close();
  
  const session = process.env.SKIP_NEO4J === 'true' ? { run: async () => {}, close: async () => {} } : driver.session();
  await session.run('MATCH (u:User {username: "testuser"}) DETACH DELETE u');
  await session.close();
  if (driver) await driver.close();
});

describe('Auth Endpoints', () => {
  it('should register a new user successfully', async () => {
    const res = await request(app).post('/api/v1/auth/register').send({
      username: 'testuser',
      email: 'test@example.com',
      password: 'password123',
    });
    expect(res.statusCode).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.token).toBeDefined();
    expect(res.body.data.user.username).toBe('testuser');
  });

  it('should fail registration with duplicate email', async () => {
    const res = await request(app).post('/api/v1/auth/register').send({
      username: 'testuser2',
      email: 'test@example.com',
      password: 'password123',
    });
    expect(res.statusCode).toBe(400);
    expect(res.body.success).toBe(false);
  });

  it('should login an existing user', async () => {
    const res = await request(app).post('/api/v1/auth/login').send({
      email: 'test@example.com',
      password: 'password123',
    });
    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.token).toBeDefined();
  });
});
