# Afterword

A personal iPhone app for reading notes. Log a reflection after each chapter, and keep a
structured reference section (characters, plot threads, predictions) you can search later.

Local only. No account, no server, no recurring cost. Your notes live in a SQLite database
on your phone.

Stack: Expo (React Native) + expo-router + TypeScript + expo-sqlite + Drizzle ORM.

---

## First-time setup

Run these once, in order. The `db:generate` step matters: the app imports the generated
migration file on launch, so it will not start until you have run it at least once.

```bash
# 1. Install dependencies
npm install

# 2. Align native module versions with your installed Expo SDK
npx expo install --fix

# 3. Generate the initial database migration from the schema
npm run db:generate

# 4. Start the dev server
npx expo start
```

Then open the **Expo Go** app on your iPhone (free from the App Store) and scan the QR code
in the terminal. The app loads on your phone in seconds. Edit code, save, and it hot-reloads.

## Whenever you change the database schema

Edit `src/db/schema.ts`, then:

```bash
npm run db:generate
```

This writes a new migration into `src/db/migrations/`. The app applies it on next launch.
Never hand-edit files in that folder.

## Where things live

See `PLAN.md` for the full architecture, roadmap, and backlog. Short version:

- `app/` — screens (expo-router; the file path is the route)
- `src/db/` — schema, client, generated migrations
- `src/features/` — data access grouped by feature (books, chapters, reference)
- `src/components/ui/` — shared building blocks (Button, Card, TextField, etc.)
- `src/theme/` — colors, spacing, type. Change a value here, it changes everywhere.
