import mongoose from 'mongoose';
import dotenv from 'dotenv';

dotenv.config({ override: true });

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/vocabflow';

const connectMongo = async () => {
  try {
    const conn = await mongoose.connect(MONGODB_URI, {
      maxPoolSize: 10, // Maintain up to 10 socket connections
      serverSelectionTimeoutMS: 5000, // Keep trying to send operations for 5 seconds
      socketTimeoutMS: 45000, // Close sockets after 45 seconds of inactivity
    });
    console.log(`MongoDB Connected: ${conn.connection.host}`);
    return conn;
  } catch (error) {
    console.error(`❌ Error connecting to MongoDB: ${error.message}`);
    if (error.message.includes('authentication failed') || error.message.includes('bad auth')) {
      console.error(`👉 MongoDB Atlas Authentication Failed! Please verify the username and password in backend/.env under MONGODB_URI.`);
    } else if (error.message.includes('ECONNREFUSED')) {
      console.error(`👉 Could not connect to local MongoDB. Ensure MongoDB service is running on mongodb://localhost:27017 or provide a valid MongoDB Atlas URI in backend/.env.`);
    }
    process.exit(1);
  }
};

export default connectMongo;
