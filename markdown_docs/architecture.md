# System Architecture: VocabFlow

## 1. Executive High-Level Architecture
VocabFlow implements a hybrid database backend coupled with a highly responsive, cross-platform client layer. To decouple structured document transactions from complex relational graph traversals, the system separates concerns across an Express.js application layer serving a single Flutter mobile client, backed by both MongoDB and Neo4j Aura.
+--------------------------+
                     |      Flutter Client      |
                     +------------+-------------+
                                  |
                                  | HTTP / JSON (REST)
                                  v
                     +------------+-------------+
                     |    Express.js Backend    |
                     +-----+--------------+-----+
                           |              |
       ODM (Mongoose)      |              | Driver (Neo4j-Driver)
                           v              v
              +------------+----+   +-----+------------+
              |  MongoDB Atlas  |   |    Neo4j Aura    |
              |  (User Profiles,|   |  (Word Graphs &  |
              |   Social Meta)  |   |   Friendships)   |
              +-----------------+   +------------------+

---

## 2. Frontend Architecture (Flutter)
The Flutter mobile application leverages a layered feature-first architecture to maximize modularity and code reuse. State management is handled cleanly via standard reactive blocks to isolate the UI layer from underlying business logic.

### Architectural Core Layers
1. **Presentation Layer:** Contains Flutter widgets, page layouts, visual interactive canvas widgets, and design tokens. This layer relies entirely on state values and UI events; it contains no business logic.
2. **Business Logic Layer (Controllers/Blocs):** Manages local state mutations, event streams, validation rules, and page routing. It coordinates data hydration between the presentation layer and data repositories.
3. **Repository Layer:** Acts as an abstraction bridge over data sources. For instance, the `WordRepository` determines if an entry should be fetched from local offline cache or the network API, safeguarding the application from data layer disruptions.
4. **Data Source Layer:** Low-level clients handling raw network operations (HTTP/Dio client mapping REST responses) and local storage drivers (e.g., Hive or SQLite for offline definitions cache).

---

## 3. Backend Architecture (Express.js)
The backend is a lightweight, stateless RESTful API engine structured around the **Controller-Service-Repository** pattern. This structure prevents database lock-in and isolates business workflows from the transport framework.

### Layer Segmentation
- **Routing & Middleware Layer:** Intercepts incoming HTTP requests, decodes/verifies JSON Web Tokens (JWT) for authentication, sanitizes payload inputs, and enforces global rate limiting.
- **Controller Layer:** Unwraps request payloads, maps parameters to appropriate service handlers, and governs HTTP response payloads (status codes, response bodies, and system exceptions).
- **Service Layer (Core Business Domain):** Contains the actual business workflows of VocabFlow. It orchestrates transactions across multiple repositories—such as ensuring a word entry is successfully executed in both the document store and graph store concurrently.
- **Data Access Objects / Repository Layer:** Encapsulates database-specific syntax. The MongoDB repository utilizes Mongoose schemas, while the Neo4j repository handles Cypher query templates via the official neo4j-driver instance.

---

## 4. Service Boundaries & Database Separation
To optimize the free tier resource constraints, the application divides records cleanly based on operational properties:

+---------------------------------------+   +---------------------------------------+
|             MongoDB Boundary          |   |             Neo4j Boundary            |
+---------------------------------------+   +---------------------------------------+
| * User Credentials & Hashes           |   | * Word Nodes                          |
| * Session Metadata & JWT Secrets      |   | * Semantic Edges (synonym_of, etc.)   |
| * System Activity Timestamps          |   | * Friend Nodes                        |
| * Static Content / App Parameters     |   | * Social Edges (FRIEND_OF, REQUESTED) |
+---------------------------------------+   +---------------------------------------+


---

## 5. Folder Structure

### Frontend Structure (Flutter)
```text
lib/
├── core/
│   ├── constants/        # API Endpoints, colors, assets paths
│   ├── network/          # Base HTTP client configurations & interceptors
│   ├── theme/            # Global UI styling sheets
│   └── utils/            # Shared string helpers, date formatters
├── features/
│   ├── auth/             # Login, Signup modules
│   ├── dashboard/        # Home profile and list dictionary tabs
│   ├── graph_canvas/     # Interactive node view engine
│   ├── notifications/    # Message receiver configurations
│   └── social/           # Friend search, profile viewer
│       ├── data/         # Models, Remote Data Sources
│       ├── domain/       # Repositories interface, State Controllers
│       └── presentation/ # Screen widgets, Custom Painters
└── main.dart             # Application initialization entrypoint
Backend Structure (Node.js/Express)
Plaintext
src/
├── config/               # Database pool configurations (Mongo/Neo4j)
├── middleware/           # Auth guards, request loggers, error catchers
├── services/             # Third-party utilities (External Dictionary API integrations)
├── features/             # Feature modules combining Routes, Controllers, and Services
│   ├── auth/             # User onboarding routes & token issuing
│   ├── graph/            # Node configurations, relationships, map generation
│   ├── social/           # Friends request queues and approval handlers
│   └── words/            # Manual adjustments, definitions retrieval
├── models/               # Shared Mongoose Schemas & Cypher query abstractions
├── app.js                # Core Express application definition
└── server.js             # Cluster worker cluster orchestration & entrypoint
6. Data Flow
6.1 User Adds a Word Node (Successful Pipeline)
Initiation: The user enters a string (e.g., "Meticulous") on the Flutter interface and submits.

API Handshake: The frontend dispatches an authorized HTTP POST request to /api/v1/words containing the target string.

External Fetch: The Express backend intercepts the token via middleware, processes the payload, and asynchronously queries the external public Free Dictionary API to pull definitions, synonyms, and antonyms.

Dual Database Sync (Transaction Flow):

The system executes a write to MongoDB to update user usage statistics and log historical transactions.

The system maps the target word into Neo4j as a node linked to the unique User node. It simultaneously checks the user's existing vocabulary dictionary for any matching synonym/antonym records fetched from the external API, drawing connecting relationship edges matching those values instantly.

UI Update: The backend streams the compiled node metadata and newly inferred relationships back to Flutter as an aggregate JSON structure, refreshing the interactive canvas.

7. Scalability & Free-Tier Optimization Considerations
7.1 Distributed Write Safeguards
Because VocabFlow interacts with dual databases over network boundaries, standard database transactions are split. To prevent desynchronization (e.g., writing to MongoDB but failing on Neo4j due to free-tier rate timeouts), the service layer enforces an Application-Level Rollback Policy: if a critical Neo4j query fails, the matching MongoDB record is purged, and a graceful retry warning returns to the client application.

7.2 Connection Pool Management
Free tiers on cloud infrastructure (MongoDB Atlas Shared Tier and Neo4j Aura Free) restrict active concurrent socket counts.

The backend establishes a persistent, reused client pool instance instead of instantiating new database handles per incoming request.

Unused idle collection drivers terminate systematically using timeouts, staying well under shared environment limitations.

7.3 Graph Caching & Serialization Overhead
Rendering interactive nodes on a mobile screen presents a substantial layout calculations bottleneck. The Flutter client prevents thread blocking by utilizing an isolate worker group to parse heavy backend graph matrices asynchronously. Additionally, the backend strictly implements graph pagination boundaries; requesting data maps limits responses to a user's nearest local neighborhood clusters (e.g., adjacent degree hops) rather than attempting to return an entire vocabulary dataset in a single call payload.