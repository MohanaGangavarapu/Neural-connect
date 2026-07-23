# API Specification: VocabFlow

## 1. Global Configurations
- **Base URL:** `/api/v1`
- **Content-Type:** `application/json`
- **Authentication:** Bearer Token via HTTP Authorization Header (`Authorization: Bearer <JWT_TOKEN>`)
- **Global Error Format:**
  ```json
  {
    "success": false,
    "error": {
      "code": "STRING_ERROR_CODE",
      "message": "Human readable description of the validation or systemic failure."
    }
  }
  2. Authentication Endpoints
2.1 Register User
Endpoint: POST /auth/register

Authentication: None

Validation Rules:

username: Required, alphanumeric string, 3–15 characters, lowercase.

email: Required, valid email format.

password: Required, string, minimum 8 characters.

Request Body
JSON
{
  "username": "alexdev",
  "email": "alex@example.com",
  "password": "SecurePassword123!"
}
Response Body (21 Created)
JSON
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": "60d5ec49f83e2c1a84f3e911",
      "username": "alexdev",
      "email": "alex@example.com"
    }
  }
}
Common Error Statuses: - 400 Bad Request (Validation mismatch or username/email already taken).

2.2 Login User
Endpoint: POST /auth/login

Authentication: None

Request Body
JSON
{
  "email": "alex@example.com",
  "password": "SecurePassword123!"
}
Response Body (200 OK)
JSON
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": "60d5ec49f83e2c1a84f3e911",
      "username": "alexdev"
    }
  }
}
Common Error Statuses: - 401 Unauthorized (Invalid email or password credentials).

3. Vocabulary & Graph Endpoints
3.1 Add / Learn New Word
Endpoint: POST /words

Authentication: Required

Validation Rules:

word: Required, alphabetic characters only, auto-trimmed and downcased.

Request Body
JSON
{
  "word": "Resilient"
}
Response Body (201 Created)
Note: Returns the saved word definitions from MongoDB alongside immediate, newly formed graph connection links generated inside Neo4j via external API automation.

JSON
{
  "success": true,
  "data": {
    "wordInfo": {
      "id": "60d5ec49f83e2c1a84f3e999",
      "word": "resilient",
      "partOfSpeech": "adjective",
      "definition": "Able to withstand or recover quickly from difficult conditions.",
      "exampleSentence": "She was resilient in the face of adversity."
    },
    "graphConnections": [
      {
        "from": "resilient",
        "to": "strong",
        "type": "SYNONYM_OF"
      },
      {
        "from": "resilient",
        "to": "fragile",
        "type": "ANTONYM_OF"
      }
    ]
  }
}
Common Error Statuses:

400 Bad Request (Word already exists in user's profile graph).

404 Not Found (Word could not be resolved by public dictionary APIs).

3.2 Get Filtered Graph Canvas
Endpoint: GET /graph/canvas

Authentication: Required

Description: Pulls the logged-in user's personalized vocabulary web, filtering out unowned global items while safely fetching direct structural synonym links owned by friends.

Request Body
None (Query Parameters allowed for pagination or node limits, e.g., ?limit=100).

Response Body (200 OK)
JSON
{
  "success": true,
  "data": {
    "nodes": [
      { "id": "resilient", "label": "Word", "ownedByMe": true },
      { "id": "strong", "label": "Word", "ownedByMe": true },
      { "id": "ephemeral", "label": "Word", "ownedByMe": false, "ownedByFriend": "sam_vocab" }
    ],
    "edges": [
      { "id": "e1", "source": "resilient", "target": "strong", "type": "SYNONYM_OF" }
    ]
  }
}
4. Social & Friendship Endpoints
4.1 Send Friend Request
Endpoint: POST /social/friends/request

Authentication: Required

Validation Rules:

targetUsername: Required, exact matching handle.

Request Body
JSON
{
  "targetUsername": "sam_vocab"
}
Response Body (200 OK)
JSON
{
  "success": true,
  "message": "Friend request successfully dispatched to sam_vocab."
}
Common Error Statuses:

404 Not Found (Target user handle does not exist).

400 Bad Request (Attempting to add oneself or duplicate request pending).

4.2 Handle Pending Request
Endpoint: PUT /social/friends/respond

Authentication: Required

Validation Rules:

requesterId: Required, MongoDB string format representation.

action: Required, string strictly matching enum ["accept", "decline"].

Request Body
JSON
{
  "requesterId": "60d5ec49f83e2c1a84f3e333",
  "action": "accept"
}
Response Body (200 OK)
JSON
{
  "success": true,
  "message": "Friend connection established successfully."
}
4.3 View Friend's Shared Vocabulary List
Endpoint: GET /social/friends/:friendId/words

Authentication: Required

Description: Securely displays standard text lists of an active friend's collection, validated by relationship checkpoints inside the graph database.

Request Body
None

Response Body (200 OK)
JSON
{
  "success": true,
  "data": [
    {
      "word": "ephemeral",
      "partOfSpeech": "adjective",
      "definition": "Lasting for a very short time."
    }
  ]
}
Common Error Statuses:

403 Forbidden (Users are not mutually linked via FRIEND_OF relationships inside the graph engine).