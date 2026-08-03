# Project Specification: VocabFlow

## 1. Vision
VocabFlow aims to revolutionize language acquisition by shifting vocabulary building from isolated, rote memorization to contextual, interconnected learning. By combining a cross-platform Flutter frontend with a hybrid storage layer (document + graph), the application visualizes a user's vocabulary journey as a dynamic Knowledge Graph. The ultimate vision is to map language acquisition in the exact way the human brain retains it—through semantic relationships, associations, and contextual webs, fully automated via open-source tools.

---

## 2. User Roles
- **Guest / Unauthenticated User:** Can download the app, view an introductory onboarding sequence, and read basic application information. Cannot save words, view graphs, or interact with the community.
- **Standard Learner:** A fully authenticated user. Can manage their personal dictionary, interact with their personal knowledge graph, receive automated smart notifications, and connect with friends to view shared vocabulary maps.
- **System Administrator (Internal):** Access to backend scripts/dashboards to monitor database health, manage community guidelines/abusive behavior, and update global dictionary fallback seeds.

---

## 3. Features (High-Level)
- **Automated Semantic Mapping:** Instantly fetches definitions, synonyms, and antonyms upon word entry to automatically link new nodes to the user's existing graph.
- **Interactive Knowledge Graph Canvas:** Visual rendering of words as nodes and semantic relationships as edges.
- **Dual-Engine Dictionary Management:** Text-based search/filter alongside the visual node explorer.
- **Social Graph Sharing:** Friend request system allowing users to cross-examine and learn from each other's vocabulary maps.
- **Multi-Trigger Notification Hub:** Engagement reminders based on daily learning streaks, friend activity, and social connections.

---

## 4. Business Rules
*BR-01 (Data Isolation):* A learner's knowledge graph is strictly private by default. It only becomes viewable to another user once a mutual friend request is accepted.
*BR-02 (Unique Node Constraint):* A user cannot add duplicate word nodes to their graph. If a word already exists, attempting to add it redirects the user to edit/expand the existing node.
*BR-03 (Edge Validation):* A relationship (edge) cannot exist without pointing to two valid, existing word nodes belonging to that specific user.
*BR-04 (Account Deletion):* When a user deletes their account, all corresponding user metadata in MongoDB and graph nodes/edges in Neo4j must be hard-deleted to comply with privacy regulations.
*BR-05 (Zero-Cost Infrastructure):* All external resources, dictionary APIs, database instances (MongoDB Atlas Free Tier, Neo4j Aura Free Tier), and notification services must operate completely within free, non-expiring tiers.

---

## 5. Functional Requirements (FR)

### 5.1 Authentication & User Management
- **FR-1.1:** System must authenticate users via JWT using email/password login.
- **FR-1.2:** System must provide a profile setup capturing username, email.

### 5.2 Automated Vocabulary & Relationship Management
- **FR-2.1:** When a user enters a word, the system must query a free, public dictionary API (e.g., Free Dictionary API) to automatically pull definitions, parts of speech, synonyms, and antonyms.
- **FR-2.2:** The backend must parse the fetched synonyms/antonyms, check if any of those words already exist in the user's personal dictionary, and automatically create connecting edges (*synonym_of*, *antonym_of*) in the graph database.
- **FR-2.3:** User must be able to manually override or add their own custom named relationships (e.g., *root_of*, *used_with*) between any two words in their dictionary.
- **FR-2.2:** User must be able to delete a relationship edge without deleting the underlying word nodes.

### 5.3 Knowledge Graph Interaction
- **FR-3.1:** The Flutter interface must display an interactive 2D graph layout handling zoom, pan, and dragging of nodes.
- **FR-3.2:** Tapping a word node must trigger a "Focus Panel" detailing the word's definition and highlighting its immediate adjacent connections.

### 5.4 Social Layer
- **FR-4.1:** Users must be able to look up other users via an exact match of their unique username.
- **FR-4.2:** Users must be able to send, accept, decline, or retract friend requests.

### 5.5 Notification Engine
- **FR-5.1 (Social Trigger):** System must dispatch a notification to a user when an accepted friend adds a new word to their vocabulary graph.
- **FR-5.2 (Inactivity Trigger):** System must evaluate user activity daily. If a user has not learned/added at least one word by a designated evening hour, a reminder notification must be dispatched.
- **FR-5.3 (Connection Trigger):** System must immediately dispatch a push notification when an incoming friend request is received.


### 5.6 Automated Word Ingestion & Relationship Mining Pipeline
When a user adds a word, the backend must execute the following multi-stage extraction and linkage pipeline sequentially:

1. **Preprocessing:** Clean the input string (trim whitespace, lowercase conversion, strip special characters).
2. **Local Cache Check:** Query MongoDB to see if the word entity already exists globally. If found, skip API lookups and proceed directly to user-linkage.
3. **Vector Embedding Generation:** Pass the preprocessed word to a local or micro-service BERT model to generate a dense semantic vector embedding.
4. **Multi-Source API Enrichment:** Concurrently poll the following external APIs to extract an aggregated metadata payload:
   - *Free Dictionary API / Urban Dictionary:* Core definitions, parts of speech, phonetic transcriptions, and audio pronunciation URLs.
   - *WordNet / Wikidata / Wikipedia / Abbreviations.com:* Synonyms, antonyms, hypernyms (broader terms), hyponyms (narrower terms), and contextual abstracts.
5. **Heuristic & Semantic Relationship Mining:**
   - **Step A (Vector Search):** Query MongoDB using a vector search to find existing words whose BERT embeddings meet a strict predefined Cosine Similarity threshold (e.g., $\text{score} \ge 0.85$).
   - **Step B (Cross-Reference Validation):** Check if any of these highly similar vector words appear inside the raw text data extracted from the multi-source APIs. If they match, apply the specific verified relationship type found (e.g., `SYNONYM_OF`).
   - **Step C (Knowledge Graph Fallback):** For similar words whose exact relationship cannot be verified through text data, query the **ConceptNet** or **DBPedia** APIs. Parse their semantic paths and extract the exact connecting edge string via its `label` property.
6. **Graph Mapping Execution:** Ingest all mined relationships into Neo4j, drawing explicit edges linking the new word node to all verified pre-existing word nodes for that user's network.
---

## 6. Non-Functional Requirements (NFR)
- **NFR-1 (Performance):** The interactive graph visualization must handle up to 500 nodes on a standard mid-range mobile device smoothly, maintaining a target of 60 FPS during pans and zooms.
- **NFR-2 (Scalability):** Graph traversals (Neo4j) must run independently of profile read/writes (MongoDB) so that slow graph computation doesn't freeze routine backend responses.
- **NFR-3 (API Latency):** External dictionary API lookups must be handled asynchronously or wrapped with optimized error handling so failure of an external API does not crash the client application.

---

## 7. Constraints
- **CON-1 (Tech Stack & Delivery):** The frontend **must** be a cross-platform mobile application built using Flutter. The backend **must** use Express.js. Database storage **must** utilize MongoDB for transactional/document data and Neo4j Aura for the graph architecture.
- **CON-2 (Network Dependence):** The visual synchronization of the graph requires an active internet connection to communicate with Neo4j Aura; heavy graph calculations will not be done client-side.
- **CON-3 (Financial Constraint):** All underlying infrastructure choices must be completely free-tier compatible.