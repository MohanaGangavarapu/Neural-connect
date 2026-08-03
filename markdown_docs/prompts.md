# AI Agent Instructions & System Implementation Rules: VocabFlow

## 1. Pre-Implementation Guardrails
Before writing any code or modifying files, the AI assistant must analyze the context and provide a response containing:
1. **Context Summary:** A brief description of the target task's goals.
2. **Assumptions:** Any technical details assumed regarding existing variables, schemas, or dependencies.
3. **Ambiguities identified:** Any gaps or contradictions found within the instructions that require clarification before coding begins.

---

## 2. Coding & Architectural Standards

### 2.1 Pattern Adherence
- **Follow the architecture exactly:** Adhere strictly to the Feature-First layout in Flutter and the Controller-Service-Repository pattern in Express.js as outlined in `ARCHITECTURE.md`.
- **Keep controllers thin:** Controllers must only unwrap HTTP payloads, manage response status codes, and delegate execution paths.
- **Isolate business workflows:** Place all core logic and API integrations inside the service layers.
- **Isolate database interactions:** House all database operations inside specific repository files. Direct Mongoose queries or Cypher string templates must never leak into services or controllers.

### 2.2 Project Scope Management
- **Minimize file footprint:** Do not generate new files or directories unless explicitly required by the active task definition.
- **Strictly limit file modifications:** Do not edit, refactor, or touch code blocks in unrelated files.

---

## 3. Testing Mandates
No code shall be considered production-ready without accompanying automated verification suites. The AI assistant must generate:
- **Unit Tests:** Direct execution coverage testing isolated business logic units, utility helpers, and individual data transformation logic blocks in isolation.
- **Integration Tests:** End-to-end routing assertions verifying authorization middlewares, dual-database sync routines, and expected status code payloads.

---

## 4. Review Checkpoints
Prior to finalizing a code delivery, the AI assistant must conduct a rigorous multi-perspective evaluation:
- **Security Review:** Verify that inputs are sanitized, JWT access validations are explicitly applied, SQL/Cypher injection routes are avoided, and no clear-text private keys are exposed.
- **Performance Review:** Ensure indexing fields match database search queries and confirm database collection pools are properly reused to prevent socket leaks.
- **Code Quality Review:** Verify that naming conventions are consistent, dead code blocks are removed, and logical loops run efficiently.

---

## 5. Definition of Done (DoD)
A development task is officially considered complete **only** when all the following checkpoints are satisfied:
- [ ] **Acceptance Criteria:** Every requirement detailed in the corresponding `TASKS.md` block is fully functional.
- [ ] **Test Execution:** All unit and integration test specs pass successfully with zero failures.
- [ ] **Linter Alignment:** Code execution flows seamlessly without throwing compilation warnings, format errors, or syntax complaints.
- [ ] **Documentation Updates:** Any introduced parameters, altered schema keys, or new endpoints are updated across the markdown specification logs (`API_SPEC.md`, `DB_SCHEMA.md`).