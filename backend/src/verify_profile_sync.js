import dotenv from 'dotenv';
import mongoose from 'mongoose';
import connectMongo from './config/mongo_pool.js';
import User from './models/User.js';
import { updateProfileDetails } from './features/social/social.service.js';
import { getSession } from './config/neo4j_pool.js';

dotenv.config({ override: true });

async function run() {
  console.log("--- START PROFILE UPDATE SYNC TEST ---");
  await connectMongo();

  // 1. Find or create the test user
  const username = "neo4jtestuser";
  let user = await User.findOne({ username });
  if (!user) {
    user = new User({
      username,
      email: "neo4jtestuser@example.com",
      passwordHash: "dummy"
    });
    await user.save();
    console.log("[MongoDB] Created test user.");
  }

  // 2. Perform profile updates through social service
  console.log("[Service] Updating profile details...");
  const updateData = {
    displayName: "Super Learner 🚀",
    bio: "Obsessed with learning vocabularies in lightspeed!",
    avatarUrl: "🦊"
  };

  const updatedProfile = await updateProfileDetails(user._id.toString(), updateData);
  console.log("[Service] MongoDB profile updated:", updatedProfile);

  // 3. Query Neo4j to check if properties synced
  console.log("[Neo4j] Querying node properties for user node...");
  const session = getSession();
  try {
    const res = await session.run(
      `MATCH (u:User {mongo_id: $userId})
       RETURN u.mongo_id AS mongo_id, u.username AS username, u.displayName AS displayName, u.bio AS bio, u.avatarUrl AS avatarUrl`,
      { userId: user._id.toString() }
    );

    if (res.records.length > 0) {
      const rec = res.records[0];
      console.log("\n[SUCCESS] Neo4j Aura node synced successfully!");
      console.log(` - ID: ${rec.get('mongo_id')}`);
      console.log(` - Username: ${rec.get('username')}`);
      console.log(` - Display Name: ${rec.get('displayName')}`);
      console.log(` - Bio: ${rec.get('bio')}`);
      console.log(` - Avatar: ${rec.get('avatarUrl')}`);

      if (
        rec.get('displayName') === updateData.displayName &&
        rec.get('bio') === updateData.bio &&
        rec.get('avatarUrl') === updateData.avatarUrl
      ) {
        console.log("\n[VERIFIED] All profile updates successfully synced to Neo4j database!");
      } else {
        console.log("\n[FAILURE] Mismatch in synced properties.");
      }
    } else {
      console.log("\n[FAILURE] User node not found in Neo4j.");
    }
  } catch (err) {
    console.error("Neo4j verification query error:", err);
  } finally {
    await session.close();
  }

  await mongoose.disconnect();
  console.log("\nDisconnected from MongoDB.");
  process.exit(0);
}

run().catch(err => {
  console.error("Error running profile test:", err);
  process.exit(1);
});
