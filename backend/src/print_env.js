import dotenv from 'dotenv';
dotenv.config({ override: true });

console.log("Loaded Environment Variables:");
console.log("MONGODB_URI:", process.env.MONGODB_URI);
console.log("NEO4J_URI:", process.env.NEO4J_URI);
console.log("NEO4J_USERNAME:", process.env.NEO4J_USERNAME);
console.log("NEO4J_USER:", process.env.NEO4J_USER);
console.log("SKIP_NEO4J:", process.env.SKIP_NEO4J);
process.exit(0);
