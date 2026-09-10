# دفتر المعلم — Daftar Al-Muallim

A right-to-left, Arabic-language gradebook for teachers. Students as rows, weeks as
columns, 0–4 marks, attendance, bonus columns, free-number end-of-term marks, per-cell
notes, student photos, and configurable calculation columns.

Single self-contained HTML file. No build step, no dependencies to install.

---

## الحالة الحالية / Current state

**This version stores everything in the browser it is opened in.** Accounts are created
locally, and nothing is shared between devices or teachers. It is ready to use as a
personal gradebook today; it is *not* yet a multi-teacher app. See
[Making it multi-teacher](#making-it-multi-teacher) below.

## Running it

Open `index.html` in a browser. That is the whole thing.

To put it online, see [Publishing with GitHub Pages](#publishing-with-github-pages).

## What it does

| | |
|---|---|
| **Classes** | Create, rename, delete. Each has its own students, weeks and files. |
| **Students** | Add in bulk (one name per line), drag to reorder — the whole row travels with the name. Click a name for their card: photo and rename. |
| **Weeks** | Starts at 12, add or delete freely. Drag a week header to move the whole week. |
| **Columns** | Per week: two 0–4 grade columns, one bonus column, one attendance column. Rename, reorder, add, delete, or convert between types. |
| **Project / Exam** | Two free-number columns after the last week, in the الأعمال النهائية block. Any value, not a 0–4 rubric. |
| **Calculation columns** | Three at the far end, pinned so they stay visible. Each picks its own source columns, one by one. One can sum other calculation columns. |
| **Notes** | Per cell. Right-click, or press `N`. A cell with a note shows an amber dot. |
| **Files** | Per class: PDFs and images preview inline, `.docx` renders via mammoth.js. |
| **Export** | CSV per class, or a full JSON backup of everything. |

### Keyboard

Entry runs across a student's grade columns, then down to the next student.

| Key | Effect |
|---|---|
| `0`–`4` (or `٠`–`٤`) | Set a grade, move on |
| Any digits | In free-number columns, opens an editor — `Enter` commits |
| `1` / `0` / `Space` | Attendance: present / absent / cycle |
| `Backspace` | Clear the cell |
| Arrows | Move (skipping the spacer columns between weeks) |
| `Alt` + `↑`/`↓` | Move the student up or down |
| `N` | Note on this cell |

## How the data is shaped

One document per class, so a whole class loads and saves as a unit:

```
classes/<id>   { name, sort order }
sheets/<id>    { students[], weeks[], extras[], cells{}, notes{}, totals[] }
files/<id>     { items[] }
photos/<id>    { items{} }        // only when no asset store is available
```

`cells` and `notes` are flat maps keyed `<studentId>_<columnId>`, which keeps a single
cell edit to a one-key merge instead of rewriting the class.

Column types: `n` regular 0–4 · `b` bonus 0–4 · `f` free number · `a` attendance.

`migrate()` in `index.html` upgrades older saved classes in stages, so a sheet written by
any earlier version still opens.

## Making it multi-teacher

The app talks to storage through a small interface — `doc`, `collection`, `get`, `set`,
`update`, `delete`, `onSnapshot` — implemented near the top of the script by `localDB()`.
Swapping that one function for a Supabase-backed equivalent is the whole migration; the
grid, drag-and-drop and calculations do not change.

`schema.sql` contains the Postgres tables and row-level security policies for that step.
The policies are what make the separation real: the server never sends one teacher another
teacher's rows, whatever the browser asks for.

Steps, once you have a Supabase project:

1. Run `schema.sql` in the Supabase SQL editor.
2. Create two storage buckets, `class-files` and `student-photos`, and apply the storage
   policies at the bottom of `schema.sql`.
3. Replace `localDB()` with the Supabase adapter and swap the sign-up form for
   `supabase.auth.signUp` / `signInWithPassword`.
4. Put the project URL and the **anon** key in the page. The anon key is meant to be
   public. The `service_role` key must never appear in this repo.

## Publishing with GitHub Pages

Push this repo, then in **Settings → Pages** set the source to the `main` branch, root
folder. The site appears at `https://<user>.github.io/<repo>/` within a minute or two.

On a free account the repo and site are public. That is fine — the page's code is not
secret. It becomes important only after step 4 above, because from then on the grades live
behind Supabase's login rather than in the repo. Never commit real student data.

## Note on student data

Grades, attendance and photographs of named children are personal data. Before inviting
colleagues, check what your school requires — in particular where the data is allowed to be
stored, which decides the region you pick when creating a Supabase project.

## The Claude artifact version

This app was built as a Claude artifact, which supplies its own `<!doctype>`, `<head>` and
a small CSS reset. `index.html` here is the standalone version with that wrapper included.
To publish it back as an artifact, remove the leading wrapper up to and including `<body>`
and the trailing `</body></html>`, and keep the platform capabilities `db`, `assets` and
`downloads`.
