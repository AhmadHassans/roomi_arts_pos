# Testing — Roomi Arts POS

Two layers: **automated tests** (run on every change) and a **manual checklist**
(run once before handing the app to the client).

---

## Automated tests

Run them all:

```bash
flutter test
```

| File | What it covers |
|------|----------------|
| `test/pos_flow_test.dart` | Core money logic end-to-end: discount-aware price, stock decrease on sale, stock restore on return, refund uses the price actually charged, profit/sales reports subtract returns, exchange price difference. |
| `test/data_integrity_test.dart` | **Overselling is blocked** (and nothing saved), **over-returning is blocked** across sessions, **invoice numbers are unique and increment**, empty cart can't complete, big-discount flag, discount clamps (no negative total), very large numbers don't overflow/break. |
| `test/password_hash_test.dart` | Passwords are salted, one-way, verify correctly, reject wrong guesses, and never appear in plain text. |
| `test/user_repository_test.dart` | Staff accounts: create/verify, case-insensitive **unique** usernames, roles, change password, owner counting (last-owner rule). |
| `test/auth_widget_test.dart` | Login gate renders; wrong password rejected; correct login reveals the app shell. |
| `test/overflow_test.dart` | Every screen renders with no layout overflow at the minimum window size; help dialog scrolls. |

---

## Manual test checklist

Do this on the Mac (printer preview) and later once on the Windows shop PC
(real printer). Tick each box.

### First run & login
- [ ] On first launch, the **owner setup** screen appears. Create the owner
      account (username + password). It logs you straight in.
- [ ] Open **Staff** → add a **cashier** account.
- [ ] **Log out**, then log in **as the cashier**. Confirm **Reports**,
      **Backup**, and **Staff** are NOT in the sidebar, and the **Delete**
      button is missing on the Stock screen.
- [ ] Leave the app idle → after a few minutes it **auto-locks**; unlock with
      the password. (Or press **Lock** to test immediately.)
- [ ] Log back in as the **owner** for the rest of the checklist.

### Stock
- [ ] **Add a product** (name, category, prices, stock, unit). It appears in the
      list.
- [ ] Try to save with **letters in a number field** or a **negative** number →
      it's rejected with a clear message.
- [ ] Use **Add stock** (e.g. +24) → the stock count goes up.
- [ ] **Edit** the product → changes save.

### New sale
- [ ] Search a product and add it to the cart; change quantities with +/-.
- [ ] Apply a **discount** — try both **%** and **Rs**. The total updates.
- [ ] As a **cashier**, try a **large discount** (e.g. 50%) → blocked (needs
      owner). As **owner**, it's allowed.
- [ ] Try to sell **more than the stock** → blocked with a clear message.
- [ ] **Complete the sale**. On Mac a **receipt preview** appears; on Windows it
      **prints**. Note the **invoice number**.

### Records
- [ ] Open **Records** → the sale is listed with the **correct invoice number**
      and total. Open it and **reprint / preview** the receipt.

### Return & refund
- [ ] Open **Return**, enter the **invoice number**, load it.
- [ ] Return **one** item → the refund amount is correct and **stock goes back
      up** (check on the Stock screen).
- [ ] Look the same invoice up again → it only offers the **remaining**
      returnable pieces; returning **more than was bought** is blocked.
- [ ] (Optional) Do an **exchange**: return an item and add a different one; the
      price difference (customer pays / we refund) is correct.

### Reports (owner)
- [ ] Open **Reports** → sales, profit, the daily chart, best sellers, and
      low-stock all look right for the sales you just made.

### Backup & restore (owner)
- [ ] **Backup now** → choose a folder → a `roomi_arts_backup_*.db` file is
      saved there.
- [ ] Make a small change (e.g. add a product).
- [ ] **Restore** that backup → confirm the warning dialog → the change is gone
      and the data matches the backup.
- [ ] Try restoring a **wrong/corrupt file** → it's rejected and your live data
      is untouched.

### Windows printer (on the shop PC, later)
- [ ] Install the **Speed-X SP-210UL** as a normal Windows printer (USB) and set
      it as default.
- [ ] Complete a sale → a **real 80 mm receipt prints** with the same layout as
      the Mac preview.
