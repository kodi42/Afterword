# Afterword — SwiftUI Migration Plan

Concrete plan to re-implement Afterword as a native SwiftUI app, **iOS-only**, with an
emphasis on design and smoothness. The existing Expo/React Native app stays intact for
reference and revert (see §2). `PLAN.md` remains the product spec — this file is the *how* of
the port. Nothing here changes the RN code; it describes new work under `apple/`.

---

## 0. Why native, and what carries over

The RN app is a **validated, working prototype**. The expensive part — deciding what to build,
the data model, the UX, the marker-parsing algorithm, the Open Library cover approach — is done
and is 100% portable. This is a re-implementation against a finished spec, not a redesign.

| Carries over as-is | Rebuilt in Swift (mechanical) |
|---|---|
| Product design + every decision in `PLAN.md` | Every screen → SwiftUI views |
| Data model (5 tables, relationships, cascade) | Persistence → SwiftData |
| Marker parser **algorithm** (pure logic, ~1:1) | Navigation → `NavigationStack` |
| Open Library cover flow | Networking → `URLSession` + `Codable` |
| Design tokens (colors/spacing/radius/type) | Tests → Swift Testing |
| Search semantics (case-insensitive contains) | Local file storage → `FileManager` |

**Reality check (unchanged by this rewrite):** standalone iOS install still needs Apple signing
— $99/yr Apple Developer for TestFlight, or free-provisioning with a 7-day reinstall. The rewrite
does not change deployment; it's chosen for native quality, not to escape Apple's gate.

---

## 1. Target stack

| Concern | Choice | Why |
|---|---|---|
| Min iOS | **iOS 17** (target latest 18/26) | Unlocks SwiftData, `ContentUnavailableView`, `@Query`, `.scrollPosition`. Personal app — no need to support old OSes. |
| Language | Swift 6, strict concurrency | Modern, safe. |
| UI | **SwiftUI** | The point. Declarative, matches the RN mental model (state → view). |
| Persistence | **SwiftData** | Native, `@Query` gives reactive reads (the direct analog of `useLiveQuery`), `@Model` relationships with `.cascade` mirror the current schema, and it unlocks **CloudKit sync for near-free** (solves the backup backlog). |
| Search | SwiftData `#Predicate` + `localizedStandardContains` | Case/diacritic-insensitive substring — an upgrade over SQL `LIKE`. FTS5 (ranked) deferred; would need GRDB (see §11). |
| Networking | `URLSession` async/await + `Codable` | Open Library cover search. |
| Images | `AsyncImage` (remote thumbs) + `Image` (local file) | Native caching, no dependency. |
| Nav | `NavigationStack` + `.sheet` | Library → detail; sheets for add/edit; search screen. |
| Testing | **Swift Testing** (`import Testing`) | Mirrors the vitest harness; parser + model logic are unit-testable in-process. |

**Rejected:** GRDB (more boilerplate, no free CloudKit) unless/until FTS5 ranked search is
needed. Core Data directly (SwiftData wraps it more ergonomically).

---

## 2. Coexistence & safety (keep the RN app intact)

Both projects live in one repo, side by side, so you can reference the RN implementation while
porting. The RN app at the repo root is **never modified** by this work.

```
Afterword/                     ← repo root: Expo/RN app stays here, untouched
├── PLAN.md                    ← product spec (shared source of truth)
├── SWIFTUI_PLAN.md            ← this file
├── app/  src/  tests/  ...    ← existing RN code (reference/revert)
└── apple/                     ← NEW: the SwiftUI Xcode project
    ├── Afterword.xcodeproj
    ├── Afterword/             ← Swift sources (structure in §4)
    └── AfterwordTests/
```

**Safety steps before starting (do once):**
1. Commit the current RN app clean.
2. Tag it: `git tag expo-v1` (a permanent, named revert point).
3. Optional branch for the port: `git switch -c swiftui-migration`. Merge to `main` when at
   parity. `git checkout expo-v1` always restores the working RN app.

The RN test harness (`npm test`) keeps working throughout — it's how we confirm the *reference*
behavior we're porting to (e.g., diff the Swift parser against the vitest cases).

---

## 3. Design system & "smoothness" (the emphasis)

Native is where the design gets to feel *right*. This section is a first-class deliverable, not
an afterthought. The look stays the warm "paper and ink" identity; the *feel* becomes native.

### 3.1 Design tokens (port exactly, then elevate)

Ship the current palette verbatim as a `Theme`, so parity is pixel-honest, then layer native
niceties (Dark Mode, Dynamic Type) on top.

```swift
enum Theme {
    enum Color {
        static let bg         = SwiftUI.Color(hex: 0xF6F1E7) // warm paper
        static let surface    = SwiftUI.Color(hex: 0xFFFFFF)
        static let surfaceAlt  = SwiftUI.Color(hex: 0xEFE7D6)
        static let ink         = SwiftUI.Color(hex: 0x26221C)
        static let inkSoft     = SwiftUI.Color(hex: 0x6B6357)
        static let inkFaint    = SwiftUI.Color(hex: 0xA79E8C)
        static let accent      = SwiftUI.Color(hex: 0xB4562B) // terracotta
        static let accentSoft  = SwiftUI.Color(hex: 0xF0DDCF)
        static let border      = SwiftUI.Color(hex: 0xE3DACA)
        static let success     = SwiftUI.Color(hex: 0x3F7A55)
        static let danger      = SwiftUI.Color(hex: 0xB23A38)
    }
    enum Space { static let xs=4.0, sm=8.0, md=16.0, lg=24.0, xl=32.0, xxl=48.0 }
    enum Radius { static let sm=8.0, md=12.0, lg=20.0, pill=999.0 }
}
```

- **Colors → Asset Catalog** with light/dark variants, so Dark Mode is a design decision, not a
  rewrite. (RN app is light-only; native makes dark cheap — a backlog item becomes trivial.)
- **Typography:** map the current scale to a SwiftUI `Font` set with **Dynamic Type** support
  (`.font(.system(...))` with relative sizing). Design opportunity: a refined **serif for display
  titles** to lean into the reading identity (e.g., New York), sans for body. Decide in §Phase D.

### 3.2 Component mapping (RN → native)

| RN component | SwiftUI replacement | Smoothness win |
|---|---|---|
| `Screen` | `NavigationStack` + safe-area | Native large-title, scroll-edge effects |
| `Card` | `.cardStyle()` ViewModifier | Consistent, cheap |
| `Button` | `Button` + custom `ButtonStyle` | Press states, haptics baked in |
| `TextField` | `TextField` / `TextEditor` | Native focus, toolbars |
| `SegmentedControl` | `Picker(.segmented)` | System control, animated |
| `EmptyState` | **`ContentUnavailableView`** (native) | First-class empty states |
| `SwipeableRow` (custom) | `.swipeActions` | Native swipe, no custom gesture code |
| `KeyboardDoneBar` | `.toolbar { ToolbarItemGroup(placement:.keyboard) }` | The known keyboard bug disappears |
| `BookCover` | `AsyncImage` + `Image` | Built-in async load/cache |
| `useLiveQuery` | `@Query` | Reactive reads, less wiring |
| `Alert.alert` | `.alert` / `.confirmationDialog` | Native action sheets |
| scroll-to-note hack | **`ScrollViewReader` + `.scrollTo(id:)`** | The jump bug is a non-issue natively |

Note two bugs we fought in RN vanish for free: the **keyboard Done-bar** issue and the
**scroll-to-note timing** hack (`ScrollViewReader.scrollTo(id, anchor:)` is deterministic).

### 3.3 Motion, feedback, interaction (the "smooth" checklist)

Applied throughout, and hardened in a dedicated polish phase (Phase D):

- **Springs everywhere:** `withAnimation(.snappy)` / `.spring` for tab switches, list
  insert/remove, form reveal, cover selection. No abrupt state changes.
- **Haptics:** `.sensoryFeedback` — `.success` on mark-finished, `.impact` on note save / cover
  pick, `.selection` on segmented change.
- **Matched geometry:** `matchedGeometryEffect` for cover/card → detail transitions.
- **Native list polish:** `.listRowSeparator`, swipe actions, `.refreshable` where sensible.
- **Sheets with detents:** add/edit book as `.sheet` with `.presentationDetents`.
- **SF Symbols** for all iconography; **materials/blur** for overlays.
- **Dynamic Type + accessibility labels** on every interactive element; VoiceOver pass.
- **Dark Mode** via the asset catalog.
- **8pt grid**, generous whitespace, consistent corner radii.

---

## 4. Project structure

Mirrors the RN convention: **views stay thin, logic lives in feature types.**

```
apple/Afterword/
├── App/
│   ├── AfterwordApp.swift         // @main, ModelContainer, root nav
│   └── RootView.swift
├── Models/                        // SwiftData @Model types (§6)
│   ├── Book.swift
│   ├── ChapterNote.swift
│   ├── Character.swift
│   ├── Prediction.swift
│   └── CharacterAlias.swift
├── DesignSystem/
│   ├── Theme.swift                // tokens (§3.1)
│   ├── Components/                // Card, PrimaryButton, FormField, EmptyState wrappers,
│   │                             //   BookCover, ChapterTag, StatusBadge, SegmentedTabs
│   └── Modifiers/                 // cardStyle, screenPadding, etc.
├── Features/
│   ├── Library/                   // LibraryView, BookRow, add FAB, search entry
│   ├── BookForm/                  // Add + Edit sheet (shared), cover search UI
│   ├── BookDetail/                // header, actions menu, tab container
│   ├── Chapters/                  // ChaptersView, NoteForm, scroll-to-note
│   ├── Reference/                 // sub-sections shell + Characters/Highlights/Predictions
│   ├── Surface/                   // MarkerParser (pure) + surfaced views + merge
│   ├── Search/                    // SearchView + query
│   └── Covers/                    // CoverSearch (Open Library) + CoverStore (files)
└── Services/                      // shared helpers (Date formatting, etc.)

apple/AfterwordTests/              // Swift Testing: MarkerParser, CoverSearch, model logic
```

---

## 5. Feature parity matrix

Everything the RN app does today, and the native approach. Nothing is dropped.

| Feature (RN) | SwiftUI approach |
|---|---|
| Library: reading/finished shelves, empty state, FAB, search button | `@Query` split by status; `ContentUnavailableView`; toolbar `+` and search |
| Book row: cover + progress | `BookRow` with `BookCover`, progress text |
| Add / Edit book (modal) | Shared `BookFormView` in a `.sheet` (add + edit) |
| Cover search (Open Library) | `CoverSearch` service; grid of `AsyncImage`; download on save |
| Book detail header + actions (edit / finish↔reading / delete) | Header view + toolbar `Menu`; `.confirmationDialog` for delete |
| Segmented Chapters / Reference | `Picker(.segmented)` bound to `@State` |
| Chapters: add for next chapter, auto-advance (forward-only), list newest-first | `@Query` sorted desc; `addNote` advances `currentChapter` if greater |
| Chapter note edit/delete (swipe) | `.swipeActions` |
| Scroll-to-note + highlight (jump) | `ScrollViewReader.scrollTo(id, anchor:.top)` + brief highlight |
| Reference sub-sections + search box | Inner segmented + `.searchable` |
| Characters: manual add/edit (name, desc, first-seen, active/gone) | `CharacterFormView` + `@Query` |
| Characters: surfaced from `- Name:` markers (timeline, chapter tags, merge) | `MarkerParser` over notes; alias merge via `CharacterAlias` |
| Highlights: surfaced from `* ...` | parser output, newest-first |
| Predictions: manual + surfaced `? ...`; mark right/wrong + outcome; reopen | manual `@Query` + parser; materialize-on-answer + dedup by normalized prompt |
| Global search across notes/characters/predictions | `#Predicate` contains queries, grouped results, deep-link |
| Deep-link to book + tab + chapter jump | `NavigationStack` path value carrying tab + target chapter |
| Delete cascade + cover file cleanup | SwiftData `.cascade` + `CoverStore.delete` |

---

## 6. Data model (Drizzle → SwiftData)

Direct mapping. Timestamps auto-set; relationships use `.cascade` to match the current
`onDelete: 'cascade'`. Example (the rest follow the same shape as `src/db/schema.ts`):

```swift
enum BookStatus: String, Codable { case reading, finished }

@Model final class Book {
    var title: String
    var author: String?
    var status: BookStatus = .reading
    var coverLocalPath: String?          // was coverUri (local file path)
    var totalChapters: Int?
    var currentChapter: Int?
    var startedAt: Date?
    var finishedAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \ChapterNote.book)
    var chapterNotes: [ChapterNote] = []
    @Relationship(deleteRule: .cascade, inverse: \Character.book)
    var characters: [Character] = []
    @Relationship(deleteRule: .cascade, inverse: \Prediction.book)
    var predictions: [Prediction] = []
    @Relationship(deleteRule: .cascade, inverse: \CharacterAlias.book)
    var aliases: [CharacterAlias] = []

    init(title: String) { self.title = title }
}
```

- **Enums for status** (`reading|finished`, `active|gone`, `open|answered`) — safer than the
  RN string columns.
- **No `plot_threads`** — already dropped to backlog in `PLAN.md`; omit.
- **Relationships** replace manual `bookId` filtering; `@Query` filters by relationship.

---

## 7. Key logic ports

### 7.1 Marker parser (the crown jewel — ports ~1:1)
`src/features/surface/parser.ts` is pure string logic. Port to a `MarkerParser` enum with the
same rules and outputs; validate against the vitest cases in `tests/parser.test.ts`.

```swift
enum MarkerParser {
    static func normalizeKey(_ s: String) -> String { /* trim, collapse spaces, lowercase */ }
    static func parse(_ notes: [ChapterNote],
                      aliases: [String: String] = [:]) -> ParsedMarkers { /* ... */ }
}
```
Same regexes: line must start (after trim) with `- Name:` / `*` / `?`. Same grouping
(case-insensitive, earliest-chapter headline, chapter timeline), same newest-first ordering,
same alias folding + chain-flatten. **Every `tests/parser.test.ts` case becomes a Swift test.**

### 7.2 Cover search (Open Library)
Port `coverSearch.ts`: build the same URL, `URLSession` fetch, decode with `Codable`, keep only
docs with `cover_i`, map to `https://covers.openlibrary.org/b/id/{id}-M.jpg`, de-dupe. Download
chosen cover to Documents via `FileManager` (port `cover.ts`).

### 7.3 Predictions materialize-on-answer + dedup
Keep the exact rule: answering a surfaced `?` inserts a `Prediction`, and the surfaced list hides
any `?` whose normalized text already exists in stored predictions.

### 7.4 Auto-advance (forward-only)
`addNote` sets `book.currentChapter = max(current ?? 0, chapter)` — never rewinds.

---

## 8. Phased roadmap (test after each phase)

Build in dependency order; each phase is demoable on the simulator/device.

- **Phase 0 — Setup & safety**
  - [ ] Tag `expo-v1`; create `apple/` Xcode project (iOS 17, SwiftData, Swift Testing).
  - [ ] `ModelContainer` wired in `AfterwordApp`; empty `RootView` runs.
- **Phase A — Data model**
  - [ ] All `@Model` types + relationships + enums (§6).
  - [ ] Swift Testing: create/read, cascade delete, forward-only advance, resolve/reopen.
- **Phase B — Design system**
  - [ ] `Theme` tokens (asset-catalog colors w/ dark variants), typography w/ Dynamic Type.
  - [ ] Core components: Card, PrimaryButton, FormField, EmptyState, BookCover, ChapterTag,
        StatusBadge, SegmentedTabs. Component gallery preview.
- **Phase C — Library + Book form + Covers**
  - [ ] Library shelves, FAB, empty state, rows with cover/progress.
  - [ ] Add/Edit sheet; Open Library cover search + download; parser tests for cover search.
- **Phase D — Chapter log**
  - [ ] Chapters view, add-for-next-chapter, forward-only advance, newest-first list.
  - [ ] Edit/delete via `.swipeActions`; `ScrollViewReader` jump + highlight.
- **Phase E — Reference (manual baseline)**
  - [ ] Sub-section shell; Characters manual CRUD; Predictions manual + mark right/wrong + reopen.
- **Phase F — Surface (markers)**
  - [ ] Port `MarkerParser` + all parser tests green.
  - [ ] Surfaced Characters (timeline, chapter-tag jump), Highlights, surfaced Predictions
        (materialize-on-answer + dedup); alias **Merge** UI.
- **Phase G — Search**
  - [ ] Global `#Predicate` search across notes/characters/predictions; grouped results;
        deep-link to book + tab + chapter jump.
- **Phase H — Polish & smoothness pass** *(the design capstone)*
  - [ ] Motion/haptics/transitions (§3.3), matched-geometry cover→detail, sheet detents.
  - [ ] Dark Mode, Dynamic Type, VoiceOver, empty-state copy, icon + launch screen.
- **Phase I — Native payoffs (optional, post-parity)**
  - [ ] `ShareLink` **markdown export** (backlog item, one-liner natively).
  - [ ] **CloudKit sync** (SwiftData `.automatic`) for cross-device backup.
  - [ ] Home-screen **widget** (current book + last note); Shortcuts/Spotlight.

**Definition of done:** every row in §5 works on device, all §7 logic ports have passing Swift
tests matching the RN suite, and the Phase H checklist is complete.

---

## 9. Testing strategy

- **Swift Testing** target mirrors the vitest harness. Port, one-to-one:
  - `parser.test.ts` → `MarkerParserTests` (same fixtures, same assertions).
  - `queries.test.ts` → model tests on an in-memory `ModelContainer`
    (`ModelConfiguration(isStoredInMemoryOnly: true)`) — cascade, advance, resolve/reopen, merge.
  - `search.test.ts` → predicate-search tests.
  - `coverSearch.test.ts` → `parse` tests against sample Open Library JSON.
- Keep `npm test` alive as the **reference oracle**: when a Swift test's expectation is unclear,
  the RN test defines correct behavior.

---

## 10. Data migration (RN → native)

Different stores (expo-sqlite vs SwiftData) — no automatic transfer.

- **Recommended:** start fresh. Current data is mostly test content.
- **If you want to keep real notes:** build the RN **markdown export** first (it's small), then a
  one-time importer in the native app that parses that export. Lowest-effort bridge; also
  doubles as the export feature you wanted. (Optional, only if you've logged real notes.)

---

## 11. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Swift learning curve (coming from JS) | Phased build; port pure logic first (parser) where JS→Swift is nearly mechanical; lean on the RN app as a living reference |
| SwiftData edge cases (young framework) | Keep models simple; in-memory container for tests; GRDB is a fallback if a wall is hit |
| No FTS5 in SwiftData | `localizedStandardContains` covers current search; adopt GRDB only if ranked search is needed |
| Scope creep during "polish" | Phase H has an explicit checklist; parity (Phases A–G) lands before polish |
| Deployment expectations | Unchanged by rewrite — $99 TestFlight or 7-day free reinstall; decided separately |

---

## 12. What we deliberately keep from the RN app

- **`PLAN.md`** as the shared product spec (both apps point to it).
- The **RN codebase** at repo root as reference + revert (`expo-v1` tag).
- The **design tokens**, **marker rules**, **Open Library approach**, and **test cases** as
  ground truth the Swift port is validated against.

---

## 13. First move

Phase 0: tag `expo-v1`, scaffold `apple/Afterword.xcodeproj` (iOS 17, SwiftData, Swift Testing),
get an empty themed `RootView` running, then Phase A (models + tests). Say go and I'll start —
though note Xcode project scaffolding may need a step or two run on your Mac (I'll give exact
commands and file contents).
```
