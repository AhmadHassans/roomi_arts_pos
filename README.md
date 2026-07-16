# Roomi Arts POS

A simple, fully-offline **Point-of-Sale desktop app** for **Roomi Arts**, a
stationery shop. Built with **Flutter** (Windows/macOS desktop) and a single
local **SQLite** database — no internet, no cloud, no accounts on a server.

Designed for a non-technical shopkeeper: big buttons, plain words, the same
layout on every screen.

## Features

- **Login & roles** — every user logs in with a username + password.
  - **Owner**: full access (Reports, Backup/Restore, delete products, large
    discounts, manage staff).
  - **Cashier**: day-to-day billing and returns only; owner-only areas are
    hidden and blocked.
  - **Auto-lock** after a few minutes of inactivity; unlock with a password.
- **Sale** — search or scan products, build a cart, apply a whole-bill discount
  (% or Rs), take Cash/Card, complete the sale, and print/preview a receipt.
- **Stock** — add / edit / delete products, quick "add stock" when a box
  arrives, low-stock highlighting.
- **Return & exchange** — look up a past invoice, return items (refund uses the
  price actually charged), or exchange for other items.
- **Records** — searchable, filterable list of every past sale and return, with
  receipt reprint.
- **Reports** — net sales, profit, a daily bar chart, best sellers, low stock.
- **Backup & Restore** — copy the whole database to a folder/USB, or load one
  back (validated before it touches your live data).

## Security

- Passwords are **salted-hashed** (PBKDF2-HMAC-SHA256) — never stored in plain
  text.
- **Parameterised SQL** everywhere (no string-built queries).
- The local database file is restricted to the current user (not world-readable).
- Each **sale/return runs in one transaction** — all-or-nothing. Overselling and
  over-returning are blocked; invoice numbers are unique and non-editable.
- **Backup files are validated** before a restore, with an automatic rollback if
  anything goes wrong.

## Receipt printing

- **Windows (shop PC):** raw **ESC/POS** to the USB thermal printer
  (Speed-X SP-210UL, 80 mm) via the Windows print spooler.
- **Mac / other desktop (testing):** shows an **on-screen receipt preview** of
  the exact same layout — no printer needed.

## Getting started (developers)

```bash
flutter pub get
flutter run -d macos     # or: flutter run -d windows
flutter test             # run the automated tests
```

On first launch you'll be asked to **create the owner account**. After that,
the owner can add cashier accounts from the **Staff** screen.

## Tech

- Flutter + [GetX](https://pub.dev/packages/get) for state/navigation
- `sqflite_common_ffi` for desktop SQLite
- `esc_pos_utils` + `win32` for thermal printing
- `crypto` for password hashing

## Testing

See **[TESTING.md](TESTING.md)** for the automated test overview and a full
manual test checklist.
