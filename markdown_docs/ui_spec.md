# UI Architecture & Design Specification: VocabFlow

## 1. Design System & Visual Tokens
- **Theme:** Primary Dark Mode Centric (Recommended for data and graph visualizations to make nodes stand out).
- **Primary Color:** Electric Violet / Indigo (Representing knowledge flow and data nodes).
- **Secondary Color:** Clean Cyan / Teal (For secondary connections, bookmarks, and interactive action feedback).
- **Background Color:** Deep Charcoal / Obsidian (To maximize contrast on the graph canvas canvas).
- **Font Stack:** Clean, highly readable sans-serif (e.g., Inter or Roboto).

---

## 2. Core Screen Wireframes & Templates

### 2.1 Vocabulary Dashboard (List View)
Renders a clean, paginated, scrollable vertical list of all words learned by the user, featuring top bar search inputs and filtration chips.

![Vocabulary Dashboard List View](./ui_assets/dashboard_list_view.png)

### 2.2 Interactive Knowledge Graph Canvas
The central interactive interface. Renders nodes as floating tapable spheres and relationships as colored connecting lines.
- **My Words:** Colored in Primary Violet.
- **Friend's Words:** Colored in Secondary Teal.

![Knowledge Graph Canvas Screen](./ui_assets/graph_canvas_view.png)

### 2.3 Interactive Word Detail Card (Overlay Sheet)
Slid-up modal pane appearing immediately when a word node or list row is tapped. Houses full definitions, speech types, and custom memory triggers.

![Word Detail Overlay Sheet](./ui_assets/word_detail_card.png)

### 2.4 User Directory & Social Network Engine
Displays global profiles with dynamic right-aligned conditional buttons toggling between `Add Friend`, `Pending`, or `Connected`.

![User Directory Social Screen](./ui_assets/user_directory_view.png)

---

## 3. UI Navigation Tree Flow
```text
[Onboarding / Welcome Screen]
          │
          ▼
   [Login / Register]
          │
          ▼
┌───────────────────┴───────────────────┐
│                                       │
▼                                       ▼
[Home Dashboard: List View] ◄──► [Interactive Graph Canvas]
│                                       │
├──► [Word Detail Sheet]               ├──► [Word Detail Sheet]
│                                       │
▼                                       ▼
[Profile & Metrics Page]                [User Directory Search]


