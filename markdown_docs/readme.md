# VocabFlow 🚀

VocabFlow is a cutting-edge, cross-platform mobile application built with Flutter that transforms traditional vocabulary learning. Instead of treating words as isolated units for rote memorization, VocabFlow utilizes a hybrid document-graph database architecture (Express.js, MongoDB, and Neo4j Aura) to construct a dynamic, personalized **Knowledge Graph** of your language journey. 

Every time you enter a word, VocabFlow leverages a sophisticated NLP and semantic mining pipeline to fetch rich metadata, generate dense vector embeddings, and automatically wire relationships to words you already know—mapping language in the exact way the human brain retains it.

---

## 🛠️ Tech Stack & Infrastructure

- **Frontend:** Flutter (Cross-platform iOS/Android) using a feature-first layered architecture.
- **Backend:** Node.js + Express.js (Controller-Service-Repository pattern).
- **Primary Database (System of Record):** MongoDB Atlas (Free Tier) — stores static word data, text definitions, user credentials, and session metadata.
- **Graph Database (Relation Engine):** Neo4j Aura (Free Tier) — tracks social links (`:FRIEND_OF`) and vocabulary ownership (`:LEARNED`), and forms the global semantic web.
- **AI / NLP Stack:** Transformer-based BERT model for dense semantic word embeddings.

---

## 🧠 Automated Word Ingestion Pipeline

When a word is submitted, the backend triggers an advanced atomic pipeline:
1. **Preprocessing:** Inputs are trimmed, sanitized, and normalized to lowercase.
2. **Cache Check:** MongoDB skips lookups if the word is already globally cached.
3. **Embedding Generation:** A local/microservice BERT wrapper generates a semantic vector embedding.
4. **Multi-Source Fetch:** Concurrently pulls data from 6 public APIs: *WordNet, Free Dictionary, Urban Dictionary, Wikipedia, Abbreviations.com, and Wikidata*.
5. **Semantic Triage:** - Runs a **Cosine Similarity** vector search against your existing lexicon in MongoDB.
   - Cross-references vector neighbors against the pulled API payloads to deduce core linguistic links (`:SYNONYM_OF`, `:ANTONYM_OF`).
   - Falls back to **ConceptNet** and **DBPedia** API pathing via `label` scanning for deep contextual ties.
6. **Graph Commit:** Batch-writes the resulting nodes and semantic links into Neo4j scoped tightly to your user node.

---

## 📂 Project Repository Blueprint

```text
vocabflow/
├── docs/                     # Comprehensive Architecture & System Specifications
│   ├── ui_assets/            # App wireframe templates and image buffers
│   ├── 1.project_spec.md     # Executive rules, functional & non-functional bounds
│   ├── 2.architecture.md     # Layer segmentation and database boundary routing
│   ├── 3.dbschema.md         # Polyglot schema structures & index configuration
│   ├── 4.api_spec.md         # Production RESTful endpoint contracts & JWT guards
│   ├── 5.tasks.md            # Dependency-ordered execution backlog
│   ├── 6.prompt_rules.md     # Strict AI coding assistant execution guidelines
│   ├── 7.decisions.md        # Architectural Decision Records (ADRs)
│   └── 9.ui_spec.md          # Visual tokens, page wireframes, and design states
├── backend/                  # Express.js Source Code
└── frontend/                 # Flutter Mobile Application Source Code