# Database Schema Specification: VocabFlow (Streamlined)

## 1. Architectural Responsibility Separation
To maximize efficiency and eliminate data redundancy, VocabFlow completely decouples state storage from relational mapping:
- **MongoDB Atlas (Data Store):** Acts as a flat data dictionary. It stores static records—who the users are, and what the words mean globally. It contains no relational or mapping data.
- **Neo4j Aura (Relationship Engine):** Acts as the dynamic mapping center. It stores all structural tracking—who is friends with whom, and exactly which user has added which word to their account.

---

## 2. MongoDB Collections

### 2.1 `users` Collection
Stores core account profiles, credentials, and configuration states.
```json
{
  "_id": "ObjectId",
  "username": "String (Unique, Lowercase, Indexed)",
  "email": "String (Unique, Indexed)",
  "passwordHash": "String",
  "createdAt": "ISODate"
}
2.2 words Collection
A global master dictionary cache. When any user adds a word, it is saved here so that future users adding the same word don't trigger redundant external API calls.

JSON
{
  "_id": "ObjectId",
  "word": "String (Unique, Lowercase, Indexed)",
  "partOfSpeech": "String",
  "definition": "String",
  "exampleSentence": "String (Optional)"
}
3. Neo4j Graph Structure (The Single Source of Mapping Truth)
3.1 Nodes
User Node: Repersents an active account.

mongo_id: String (Direct mapping key referencing users._id in MongoDB).

Word Node: Represents a unique vocabulary entity. No duplicates allowed globally.

text: String (The lowercase word token, mapping directly to words.word in MongoDB).

3.2 Relationships
(:User)-[:LEARNED {added_at: DateTime}]->(:Word): This single edge replaces the entire MongoDB user_words collection. It establishes that a specific user owns/learned this word.

(:User)-[:FRIEND_OF]->(:User): Mutually accepted social relationship.

(:Word)-[:SYNONYM_OF]->(:Word): Global semantic link between words across the entire app ecosystem.

(:Word)-[:ANTONYM_OF]->(:Word): Global opposite semantic link.

4. Operational Walkthroughs (How the Backend Resolves Data)
4.1 Adding a Word
User submits word "Resilient".

Backend checks if "Resilient" exists in MongoDB words collection. If not, it fetches data from the external API and creates it.

Backend ensures a (:Word {text: "resilient"}) node exists in Neo4j.

Backend draws a (:User {mongo_id: X})-[:LEARNED]->(:Word {text: "resilient"}) edge. If the external API returned synonyms that already exist as nodes in Neo4j, the backend draws [:SYNONYM_OF] edges between them globally.

4.2 Fetching the UI Graph View
The backend requests a filtered graph from Neo4j:

Cypher
MATCH (u:User {mongo_id: $current_user_id})-[:LEARNED]->(w:Word)
OPTIONAL MATCH (w)-[r:SYNONYM_OF|ANTONYM_OF]-(connectedWord:Word)
WHERE (u)-[:LEARNED]->(connectedWord) OR (u)-[:FRIEND_OF]-()-[:LEARNED]->(connectedWord)
RETURN w, r, connectedWord
This guarantees the UI only receives word nodes that the user owns, or words owned by friends that link directly to them.

5. Indexes & Constraints
MongoDB
Unique Fields: users.username, users.email, and words.word are strictly unique and indexed to maximize query fetch speeds.

Neo4j
Constraint: CONSTRAINT FOR (u:User) REQUIRE u.mongo_id IS UNIQUE

Constraint: CONSTRAINT FOR (w:Word) REQUIRE w.text IS UNIQUE (Guarantees no duplicate words exist).

Composite Property Constraint: CONSTRAINT FOR ()-[r:LEARNED]-() REQUIRE (r.from, r.to) IS UNIQUE (Guarantees a user can link to a word node only once).