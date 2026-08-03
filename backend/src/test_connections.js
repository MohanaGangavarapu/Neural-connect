import dotenv from 'dotenv';
dotenv.config({ override: true });

// Override SKIP_NEO4J before importing the pools
process.env.SKIP_NEO4J = 'false';

console.log("Starting test connections with dynamic import...");
try {
  const { default: connectMongo } = await import('./config/mongo_pool.js');
  const { connectNeo4j } = await import('./config/neo4j_pool.js');

  await connectMongo();
  console.log("MongoDB is accessible!");
  
  await connectNeo4j();
  console.log("Neo4j connectivity verified successfully!");
  
  process.exit(0);
} catch (error) {
  console.error("Connection failed:", error);
  process.exit(1);
}
