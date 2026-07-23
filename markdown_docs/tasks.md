# Comprehensive Task Backlog & Execution Graph: VocabFlow

## Phase 1: Core Environment Setup & Shared Configurations
### Task 1.1: Express.js & Database Connection Pooling Base
- **Dependencies:** None
- **Goal:** Initialize the backend codebase framework, spinning up dedicated connection pooling clients for MongoDB and Neo4j.
- **Acceptance Criteria:**
  - Express.js application runs cleanly on Node.js using ESM syntax modules.
  - Server instantiates a single persistent connection pool to MongoDB Atlas and Neo4j Aura using official connection drivers.
  - Database pool instances cleanly reuse active sockets without spawning new threads per inbound routing call.
- **Verification Criteria:**
  - Console boot logs print successful verification connections to both Mongo and Neo4j instances on server initialization.
  - Disconnecting internet connectivity manually triggers handled error connection retries without crashing the Node runtime process.

### Task 1.2: Cross-Platform Flutter Scaffolding
- **Dependencies:** None
- **Goal:** Set up the client-side responsive environment shell.
- **Acceptance Criteria:**
  - Standard multi-directory Flutter project compiled cleanly with an integrated state manager.
  - Configured centralized HTTP networking layer client (Dio) handling automated logging interceptors and authorization payload headers.
- **Verification Criteria:**
  - Application builds and renders a blank placeholder screen natively on both Android and iOS simulated virtual environments.

---

## Phase 2: User Authenticated Access Layer
### Task 2.1: Authentication & JWT Middleware Backend Service
- **Dependencies:** Task 1.1
- **Goal:** Program data schemas and verification filters to manage users.
- **Acceptance Criteria:**
  - Mongo database contains a `users` collection structured with specific matching email constraints.
  - Endpoint `/auth/register` takes parameters, encrypts strings using Bcrypt, drops a duplicate mirror token inside Neo4j as a base `User` node key, and returns an encrypted token payload string.
  - Request routes to `/auth/login` authenticate user matches and issue working signatures.
- **Verification Criteria:**
  - Triggering API calls via tools like Postman returns a valid token string, and testing duplicate registration requests throws appropriate error message configurations.

### Task 2.2: Onboarding, Login, and Registration Screens UI
- **Dependencies:** Task 1.2, Task 2.1
- **Goal:** Design the client authentication access screens.
- **Acceptance Criteria:**
  - Visual registration interfaces designed featuring dedicated string validation checkers (e.g., mail structure formats, password length bars).
  - Successful API processing handles local key token storage and smoothly navigates screens to the main layout page views.
- **Verification Criteria:**
  - Running interface flows with invalid parameter patterns flags inline custom warning indicators instantly on current user view layouts.

---

## Phase 3: The Automated Word Entry Pipeline
### Task 3.1: Dictionary Third-Party API Proxy Client
- **Dependencies:** Task 1.1
- **Goal:** Build an asynchronous backend pipeline utility fetching raw lexicography.
- **Acceptance Criteria:**
  - Programmed backend wrapper utilities fetching payload strings safely from designated public Dictionary endpoints.
  - Functions must catch invalid search terms gracefully, passing standardized payload schemas containing parsed syntax values back up stream modules.
- **Verification Criteria:**
  - Execution unit-tests targeting missing terms handle exception blocks without stalling operational processing pipelines.

### Task 3.2: Compound Atomic Multi-Database Word Engine
- **Dependencies:** Task 2.1, Task 3.1
- **Goal:** Code the backend entry router parsing logic for handling `POST /words`.
- **Acceptance Criteria:**
  - Endpoint pulls requested strings and updates global MongoDB definitions indexes safely when terms are missing.
  - Injects specific non-colliding `Word` label tokens directly into the Neo4j web mesh.
  - Establishes explicit unique ownership pointer links `(:User)-[:LEARNED]->(:Word)` identifying the creating user profile.
- **Verification Criteria:**
  - Sending word creations verifies a single document is added to Mongo while creating precisely mapped node linkages in the graph engine.

### Task 3.3: Global Linguistic Mapping Synthesis Engine
- **Dependencies:** Task 3.2
- **Goal:** Build the backend automation mapping synonyms and antonym structures.
- **Acceptance Criteria:**
  - Post-creation Cypher routines process synonym and antonym term arrays generated from dictionaries.
  - If target definitions currently reside in the master Neo4j database, the engine draws matching global relational semantic edges (`:SYNONYM_OF`, `:ANTONYM_OF`) linking them.
- **Verification Criteria:**
  - Adding words like "happy" and "joyful" consecutively maps relational associations between their nodes automatically inside graph data visualizers.

---

## Phase 4: Word Retrieval, Dashboards, and Bookmarks
### Task 4.1: Paginated Data Extraction & Search Query Engine
- **Dependencies:** Task 3.2, Task 3.3
- **Goal:** Build backend route configurations managing flexible parameter matching.
- **Acceptance Criteria:**
  - Route endpoint `GET /words/search` accepts complex input criteria arrays filtering logs accurately across parameters like timeframe, relation types, and original authors.
- **Verification Criteria:**
  - Query strings hitting search backends return properly structured JSON lists containing filtered results mapped precisely within the requested dimensions.

### Task 4.2: Vocabulary Text Dashboard & Custom List UI
- **Dependencies:** Task 2.2, Task 4.1
- **Goal:** Create user list screens rendering saved words.
- **Acceptance Criteria:**
  - Renders alphabetical paginated word text layout lists directly on clean frontend dashboard tab views.
- **Verification Criteria:**
  - Scrolling through words updates layout windows sequentially, smoothly calling background API requests to load further pages.

### Task 4.3: Interactive Word Detail Card & Overlay Panel
- **Dependencies:** Task 4.2
- **Goal:** Design the individual card detail overlay screens.
- **Acceptance Criteria:**
  - Custom display cards render clean deep word definitions, example phrases, and custom notes layouts when list entries or graph nodes are tapped.
- **Verification Criteria:**
  - Clicking targeted tokens populates interface values, raising fluid sheet menus displaying parsed dictionary entries cleanly.

### Task 4.4: Bookmark Modification Engine
- **Dependencies:** Task 4.1, Task 4.2
- **Goal:** Implement word favoriting capability.
- **Acceptance Criteria:**
  - `/words/:wordId/bookmark` safely appends targeted references within profile object arrays stored inside MongoDB.
- **Verification Criteria:**
  - Activating bookmark buttons toggles interface indicators immediately and alters state configurations uniformly across list views.

---

## Phase 5: Graph Canvas Data Integration
### Task 5.1: Sub-Neighborhood Graph Extraction Query
- **Dependencies:** Task 3.2, Task 3.3
- **Goal:** Author optimized Cypher aggregations filtering vocabulary webs.
- **Acceptance Criteria:**
  - Endpoint `GET /graph/canvas` runs queries returning vocabulary networks owned by the caller or their confirmed friends group, excluding disconnected third-party structures.
- **Verification Criteria:**
  - Database queries accurately exclude foreign vocabulary tracks from final returned canvas payload bundles.

### Task 5.2: Interactive Map Graph Paint Engine UI
- **Dependencies:** Task 4.3, Task 5.1
- **Goal:** Build the interactive visual node canvas in Flutter.
- **Acceptance Criteria:**
  - Interactive layout canvas implements pan, drag, and pinch-to-zoom capabilities seamlessly.
  - Node visuals render distinct highlight states clearly based on ownership parameters.
- **Verification Criteria:**
  - Dragging items across the screen shifts positions smoothly without UI stutter, and tapping nodes launches matching definition summaries instantly.

---

## Phase 6: Social Integration Layers
### Task 6.1: Contextual Global Directory Query Engine
- **Dependencies:** Task 2.1
- **Goal:** Build search routing filters for parsing user profile records.
- **Acceptance Criteria:**
  - Route `GET /social/users` computes relational status levels relative to the caller, flagging links cleanly as `NONE`, `PENDING_SENT`, or `FRIENDS`.
- **Verification Criteria:**
  - Profiles match real-time friendship states correctly when queried through standard backend testing suites.

### Task 6.2: User Directory & Connection Handling Interface
- **Dependencies:** Task 2.2, Task 6.1
- **Goal:** Create social directory lookup panels.
- **Acceptance Criteria:**
  - Renders user lists containing reactive action buttons changing titles from "Add Friend" to "Pending" automatically upon click interactions.
- **Verification Criteria:**
  - Pressing connection buttons hits endpoint hooks smoothly and updates UI layout states immediately.

### Task 6.3: Profile Workspace Hub Screen
- **Dependencies:** Task 4.4, Task 6.2
- **Goal:** Assemble central monitoring dashboards displaying profile tracking data.
- **Acceptance Criteria:**
  - Renders calculated count summaries showing total accumulated vocabulary arrays, active bookmark connections, and friend totals.
- **Verification Criteria:**
  - Profile tracking configurations match current backend database totals exactly on interface boots.