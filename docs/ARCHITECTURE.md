# Alfardos Management — Architecture

Arabic (RTL) accounting & business management app. Flutter (Android + Windows),
Firebase (Auth, Firestore, Storage, App Check, Crashlytics, Analytics).
Firebase project: **alfardos-mgmt** (runs fully on the free Spark plan; Storage needs Blaze).

## 1. Layers

```
presentation (screens, widgets)      features/*/presentation
      ↓
application (Riverpod providers,     features/*/application
controllers)
      ↓
domain (models, pure accounting)     core/accounting, features/*/domain
      ↓
data (repositories)                  features/*/data
      ↓
central ledger engine                core/ledger/ledger_service.dart
      ↓
Firebase                             Firestore transactions + security rules
```

The business logic lives outside the widgets:

* `core/accounting/` is **pure Dart** (no Flutter, no Firebase): invoice math, the
  posting factory, costing, statements. It is fully unit-tested.
* `core/ledger/ledger_service.dart` is the **only** code that changes balances.

## 2. Accounting engine

Every financial operation becomes a `Posting` (built by `PostingFactory`):

| Operation            | Cash            | Customer (AR)      | Supplier (AP)      | Stock        | P&L metrics                         |
|----------------------|-----------------|--------------------|--------------------|--------------|-------------------------------------|
| Cash sale 10,000     | +10,000         | +10,000 / −10,000* | –                  | −qty @ cost  | sales, COGS, service cost           |
| Credit sale 10,000   | –               | +10,000            | –                  | −qty @ cost  | sales, COGS, service cost           |
| Customer payment     | +x              | −x                 | –                  | –            | cash in                             |
| Purchase             | −paid           | –                  | +remaining         | +qty @ net   | purchases (not an expense)          |
| Supplier payment     | −x              | –                  | −x                 | –            | cash out                            |
| Expense              | −x              | –                  | –                  | –            | expenses                            |
| Transfer A→B         | A −x, B +x      | –                  | –                  | –            | **none** (not revenue/expense/profit) |
| Opening balances     | ±               | ±                  | ±                  | +            | capital only                        |
| Cancellation         | exact negation of the original posting, dated today                              |

\* A registered customer's statement shows the total as debit and the amount paid as credit.

**Double-entry check:** every posting must satisfy `Posting.isBalanced`, otherwise it is rejected:
`Δcash + Δreceivables + Δinventory − Δpayables − service cost = net profit + capital`

**Profit:** `revenue − cost of goods sold (actual weighted-average cost at sale time)
− service cost − operating expenses`. Purchases never reduce profit directly.
Costing is behind the `CostingPolicy` interface (weighted average today), so FIFO can be added later.

**Money:** all amounts are `int` minor units (1/100); quantities are `double`, and
every amount derived from a quantity is rounded immediately. An invoice discount is
allocated to its lines using the largest-remainder method, so no minor units are lost.

### Ledger transaction (one atomic Firestore transaction)

1. Idempotency: `financial_transactions/{postingId}` must not exist. The id is generated
   when the form opens and reused on retry, so a double-tap or a network retry never posts twice.
2. Reads: settings, counter, products (current average cost), every affected account.
3. Build and validate the posting; enforce overdraft, over-payment, stock and inactive-account rules.
4. Writes:
   * `financial_transactions`: immutable, includes every movement and metric
   * one sub-ledger record per account (`cash_transactions`, `customer_transactions`, `supplier_transactions`),
     with id `{postingId}_{accountId}` and `balanceAfter`
   * the account balances, each with `lastTxId` pointing to its sub-ledger record
   * product `stockQty` / `costPrice`
   * `daily_stats/{yyyy-MM-dd}` (dashboard and profit report)
   * the business document (invoice, receipt, ...) and `sale_items`
   * `counters/*` (INV-1001, ...), `notifications`, `audit_logs`

Transactions need the server, so **financial operations never create pending offline
balances**. Reads work offline from the persistent cache, and the top bar shows an offline badge.

## 3. Firestore schema

| Collection | Purpose / key fields |
|---|---|
| `meta/bootstrap` | `adminUid`, set once by the first-run setup |
| `users/{uid}` | name, email, roleId, roleName, `permissions[]` (copied from the role), active |
| `roles/{id}` | name, `permissions[]` |
| `settings/company` | company info, currency, prefixes, business rules, alert thresholds |
| `counters/{sales,purchases,...}` | `value` (security rules only allow +1) |
| `customers`, `suppliers` | name, phone, keywords[], **balance**, lastTxId, totals, invoiceCount, active |
| `cashboxes` | name, kind, **balance**, lastTxId, totalIn, totalOut, active |
| `products` | name, sku, barcode, unit, sellPrice, **costPrice (avg)**, **stockQty**, lowStockAlert |
| `services` | name, sellPrice, cost, active |
| `expense_categories` | name, order, active |
| `sales`, `purchases` | number, date, party, lines[], totals, paid, remaining, cost, profit, status |
| `sale_items` | per-line analytics (reversal lines are negative) |
| `customer_payments`, `supplier_payments`, `expenses`, `transfers` | business documents with a status |
| `financial_transactions` | the journal (immutable) |
| `cash_/customer_/supplier_transactions` | sub-ledgers with balanceAfter |
| `daily_stats/{day}` | summed metrics per day |
| `audit_logs` | who / what / when / where (platform) / before / after |
| `notifications` | low cash, large expense |

All documents carry `createdAt/createdBy` (server timestamps) and, where editable, `updatedAt/updatedBy`.

## 4. Security (`firestore.rules`, tested in `test/firestore_rules`)

* Access requires an **active member** (`users/{uid}.active`). Permissions are checked server-side.
* **No deletes** anywhere. Posted documents cannot be edited; the only allowed change is
  `active → cancelled`, and only together with the reversal transaction in the same write.
* **Balance integrity:** a balance may change only when the same write creates a new
  sub-ledger record for that account and the balance moves by exactly that record's amount.
  That record in turn requires a new financial transaction by a user permitted to post its type.
  Replaying an old record, tampering with amounts or editing balances directly is rejected.
* Counters increase only by one. Statistics change only with a new transaction.
  Audit logs are append-only and must name their real author.
* First-run setup works exactly once (`meta/bootstrap`).
* Storage: logo (manage_settings, images < 2 MB); receipts are write-once (create_expense, images/PDF < 5 MB).
* No secrets in the client. App Check runs on Android (Play Integrity in release, debug provider in debug).

### Roles (`core/permissions/permissions.dart`)

| Role | Summary |
|---|---|
| مدير النظام (admin) | everything |
| محاسب (accountant) | all operations, cancellations, reports, cost visibility |
| أمين صندوق (cashier) | sales, receipts, supplier payments, expenses, transfers, dashboard |
| مندوب مبيعات (sales) | sales, customers, receipts |

Admins can create custom roles. Permissions are granular (`view_sales`, `create_sales`,
`cancel_sales`, `view_cost`, `manage_users`, ...).

## 5. Navigation

Desktop: right-side sidebar (RTL) and a top bar (global search, offline badge, quick sale,
notifications, user menu). Tablet: compact icon sidebar. Phone: bottom bar
(Home, Sales, Customers, Cashboxes, More).

Order: Dashboard → Sales / Customers / Receipts → Purchases / Suppliers / Supplier payments →
Cashboxes / Transfers / Expenses → Services / Products → Reports → Users / Settings / Audit log.

## 6. Tests

```bash
flutter test                                    # accounting core + ledger service (40 tests)
firebase emulators:exec --only firestore --project demo-alfardos "npm --prefix test/firestore_rules test"
```

## 7. Deploy

```bash
firebase deploy --only firestore,auth --project alfardos-mgmt
firebase deploy --only storage --project alfardos-mgmt   # after enabling Storage in the console
```

## 8. Extension points

* Barcode scanner: the item search already resolves exact barcodes (USB scanners work).
  A camera scanner can call `CatalogRepository.productByBarcode`.
* Tax: the settings are stored (`taxEnabled`, `taxRatePercent`); add a tax line in `InvoiceCalculator`.
* Push notifications (debt reminders): need Cloud Functions + FCM (Blaze plan).
  The in-app notifications and dashboard alerts cover this today.
