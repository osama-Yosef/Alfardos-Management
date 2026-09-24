// Security rules tests (run against the Firestore emulator):
//   firebase emulators:exec --only firestore "npm --prefix test/firestore_rules test"
//
// The write shapes mirror lib/core/ledger/ledger_service.dart exactly.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  deleteDoc,
  doc,
  getDoc,
  increment,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

let env;
const now = () => Timestamp.fromDate(new Date());

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'alfardos-rules-test',
    firestore: { rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8') },
  });
});
after(() => env.cleanup());

const users = {
  admin: ['admin'],
  sales: ['view_sales', 'create_sales', 'view_customers', 'manage_customers', 'create_payment', 'view_catalog'],
  cashier: ['view_dashboard', 'view_sales', 'create_sales', 'view_customers', 'create_payment', 'view_cashboxes',
    'create_transfer', 'view_expenses', 'create_expense', 'view_catalog'],
  viewer: ['view_sales'],
};

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'meta/bootstrap'), { adminUid: 'admin' });
    for (const [uid, permissions] of Object.entries(users)) {
      await setDoc(doc(db, `users/${uid}`), { name: uid, permissions, active: true, roleId: uid });
    }
    await setDoc(doc(db, 'users/disabled'), { name: 'x', permissions: ['admin'], active: false });
    await setDoc(doc(db, 'settings/company'), { companyName: 'T', allowNegativeCash: false });
    await setDoc(doc(db, 'cashboxes/main'), { name: 'Main', balance: 100000, lastTxId: 'seed_main', active: true });
    await setDoc(doc(db, 'cashboxes/bank'), { name: 'Bank', balance: 0, active: true });
    await setDoc(doc(db, 'customers/c1'), { name: 'C1', balance: 0, active: true, createdBy: 'admin' });
    await setDoc(doc(db, 'products/p1'), { name: 'P1', stockQty: 10, costPrice: 300, sellPrice: 500, active: true, createdBy: 'admin' });
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();

/** Writes a credit sale with partial payment exactly like the ledger. */
function saleBatch(db, uid, { id = 'sale1', paid = 400, total = 1000, cashDelta = paid, customerDelta = total - paid } = {}) {
  const b = writeBatch(db);
  const stamp = { createdAt: serverTimestamp(), createdBy: uid, createdByName: uid };
  const common = { date: now(), dayKey: '2026-09-24', type: 'sale', description: 'x', financialTxId: id,
    sourceCollection: 'sales', sourceId: id, sourceNumber: 'INV-1001', ...stamp };
  b.set(doc(db, `financial_transactions/${id}`), { type: 'sale', originalType: null, reversalOf: null, date: now(),
    dayKey: '2026-09-24', description: 'x', sourceCollection: 'sales', sourceId: id, sales: total, cashIn: paid,
    cash: [{ id: 'main', amount: paid }], customers: [{ id: 'c1', increase: total, decrease: paid }], stock: [], suppliers: [],
    ...stamp });
  b.set(doc(db, `cash_transactions/${id}_main`), { ...common, cashboxId: 'main', amount: paid, balanceAfter: 100000 + cashDelta });
  b.update(doc(db, 'cashboxes/main'), { balance: 100000 + cashDelta, lastTxId: `${id}_main`, totalIn: increment(paid),
    totalOut: increment(0), lastTxAt: serverTimestamp(), updatedAt: serverTimestamp() });
  b.set(doc(db, `customer_transactions/${id}_c1`), { ...common, customerId: 'c1', increase: total, decrease: paid,
    amount: total - paid, balanceAfter: customerDelta });
  b.update(doc(db, 'customers/c1'), { balance: customerDelta, lastTxId: `${id}_c1`, totalIncrease: increment(total),
    totalDecrease: increment(paid), invoiceCount: increment(1), lastTxAt: serverTimestamp(), updatedAt: serverTimestamp() });
  b.update(doc(db, 'products/p1'), { stockQty: 8, costPrice: 300, updatedAt: serverTimestamp() });
  b.set(doc(db, 'daily_stats/2026-09-24'), { dayKey: '2026-09-24', sales: total, txCount: 1, lastTxId: id, updatedAt: serverTimestamp() });
  b.set(doc(db, 'counters/sales'), { value: 1001, updatedAt: serverTimestamp() });
  b.set(doc(db, `sales/${id}`), { number: 'INV-1001', total, paid, status: 'active', financialTxId: id, ...stamp });
  b.set(doc(db, `sale_items/${id}_0`), { saleId: id, net: total });
  b.set(doc(db, `audit_logs/a_${id}`), { action: 'create', userId: uid, userName: uid, at: serverTimestamp() });
  return b;
}

function cancelBatch(db, uid, id = 'sale1', paid = 400, total = 1000) {
  const rev = `${id}_rev`;
  const b = writeBatch(db);
  const stamp = { createdAt: serverTimestamp(), createdBy: uid, createdByName: uid };
  const common = { date: now(), type: 'reversal', originalType: 'sale', financialTxId: rev, ...stamp };
  b.set(doc(db, `financial_transactions/${rev}`), { type: 'reversal', originalType: 'sale', reversalOf: id, date: now(),
    sales: -total, ...stamp });
  b.set(doc(db, `cash_transactions/${rev}_main`), { ...common, cashboxId: 'main', amount: -paid, balanceAfter: 100000 });
  b.update(doc(db, 'cashboxes/main'), { balance: 100000, lastTxId: `${rev}_main`, totalOut: increment(paid), updatedAt: serverTimestamp() });
  b.set(doc(db, `customer_transactions/${rev}_c1`), { ...common, customerId: 'c1', increase: paid, decrease: total,
    amount: paid - total, balanceAfter: 0 });
  b.update(doc(db, 'customers/c1'), { balance: 0, lastTxId: `${rev}_c1`, invoiceCount: increment(-1), updatedAt: serverTimestamp() });
  b.update(doc(db, 'daily_stats/2026-09-24'), { sales: increment(-total), txCount: increment(1), lastTxId: rev, updatedAt: serverTimestamp() });
  b.update(doc(db, `sales/${id}`), { status: 'cancelled', cancelReason: 'err', cancelledAt: serverTimestamp(),
    cancelledBy: uid, cancelledByName: uid, reversalTxId: rev, updatedAt: serverTimestamp(), updatedBy: uid });
  b.set(doc(db, `audit_logs/a_${rev}`), { action: 'cancel', userId: uid, userName: uid, at: serverTimestamp() });
  return b;
}

describe('access control', () => {
  test('unauthenticated users read nothing but the bootstrap flag', async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(db, 'meta/bootstrap')));
    await assertFails(getDoc(doc(db, 'cashboxes/main')));
    await assertFails(getDoc(doc(db, 'settings/company')));
  });

  test('deactivated users are locked out immediately', async () => {
    await assertFails(getDoc(doc(as('disabled'), 'cashboxes/main')));
  });

  test('users cannot escalate their own permissions', async () => {
    await assertFails(updateDoc(doc(as('sales'), 'users/sales'), { permissions: ['admin'] }));
    await assertSucceeds(updateDoc(doc(as('sales'), 'users/sales'), { name: 'new name', updatedAt: serverTimestamp() }));
  });

  test('second bootstrap is impossible', async () => {
    const db = as('attacker');
    const b = writeBatch(db);
    b.set(doc(db, 'users/attacker'), { permissions: ['admin'], active: true });
    b.set(doc(db, 'meta/bootstrap'), { adminUid: 'attacker' });
    await assertFails(b.commit());
  });

  test('audit logs are append-only and must name the real author', async () => {
    const db = as('admin');
    await assertSucceeds(setDoc(doc(db, 'audit_logs/x'), { userId: 'admin', action: 'login' }));
    await assertFails(setDoc(doc(db, 'audit_logs/y'), { userId: 'someone-else', action: 'login' }));
    await assertFails(updateDoc(doc(db, 'audit_logs/x'), { action: 'edited' }));
    await assertFails(deleteDoc(doc(db, 'audit_logs/x')));
  });
});

describe('ledger integrity', () => {
  test('a complete sale posting by an authorised user succeeds', async () => {
    // Every read the ledger performs inside its transaction must be allowed.
    const db = as('sales');
    for (const p of ['financial_transactions/new', 'settings/company', 'counters/sales', 'products/p1',
      'cashboxes/main', 'customers/c1', 'daily_stats/2026-09-24']) {
      await assertSucceeds(getDoc(doc(db, p)));
    }
    await assertSucceeds(saleBatch(db, 'sales').commit());
  });

  test('a user without create_sales cannot post a sale', async () => {
    await assertFails(saleBatch(as('viewer'), 'viewer').commit());
  });

  test('changing a cashbox balance without a ledger record is denied', async () => {
    await assertFails(updateDoc(doc(as('admin'), 'cashboxes/main'), { balance: 999999999 }));
  });

  test('balance must move by exactly the sub-ledger amount', async () => {
    await assertFails(saleBatch(as('sales'), 'sales', { cashDelta: 999 }).commit());
  });

  test('sub-ledger record without a new financial transaction is denied', async () => {
    const db = as('admin');
    const b = writeBatch(db);
    b.set(doc(db, 'cash_transactions/fake_main'), { cashboxId: 'main', amount: 5000, balanceAfter: 105000,
      financialTxId: 'fake', createdBy: 'admin' });
    b.update(doc(db, 'cashboxes/main'), { balance: 105000, lastTxId: 'fake_main' });
    await assertFails(b.commit());
  });

  test('overdraft is denied unless enabled in settings', async () => {
    await assertFails(saleBatch(as('sales'), 'sales', { paid: -200000, cashDelta: -200000, customerDelta: 1000 + 200000 }).commit());
  });

  test('posted documents cannot be edited or deleted', async () => {
    await assertSucceeds(saleBatch(as('sales'), 'sales').commit());
    const db = as('admin');
    await assertFails(updateDoc(doc(db, 'sales/sale1'), { total: 1 }));
    await assertFails(deleteDoc(doc(db, 'sales/sale1')));
    await assertFails(updateDoc(doc(db, 'financial_transactions/sale1'), { sales: 1 }));
    await assertFails(deleteDoc(doc(db, 'financial_transactions/sale1')));
    await assertFails(deleteDoc(doc(db, 'cash_transactions/sale1_main')));
    await assertFails(updateDoc(doc(db, 'customer_transactions/sale1_c1'), { amount: 0 }));
    await assertFails(deleteDoc(doc(db, 'customers/c1')));
  });

  test('cancellation requires permission and a reversal in the same write', async () => {
    await assertSucceeds(saleBatch(as('sales'), 'sales').commit());
    // Cashier lacks cancel_sales.
    await assertFails(cancelBatch(as('cashier'), 'cashier').commit());
    // Flipping status alone (no reversal) is denied even for admins.
    await assertFails(updateDoc(doc(as('admin'), 'sales/sale1'), { status: 'cancelled', cancelledBy: 'admin' }));
    await assertSucceeds(cancelBatch(as('admin'), 'admin').commit());
    // A second cancellation cannot be posted.
    await assertFails(cancelBatch(as('admin'), 'admin').commit());
  });

  test('replaying an old sub-ledger id is denied', async () => {
    await assertSucceeds(saleBatch(as('sales'), 'sales').commit());
    const db = as('admin');
    await assertFails(updateDoc(doc(db, 'cashboxes/main'), { balance: 100800, lastTxId: 'sale1_main' }));
  });

  test('document counters only increase by one', async () => {
    const db = as('sales');
    await assertSucceeds(setDoc(doc(db, 'counters/sales'), { value: 1001 }));
    await assertFails(updateDoc(doc(db, 'counters/sales'), { value: 1000 }));
    await assertSucceeds(updateDoc(doc(db, 'counters/sales'), { value: 1002 }));
  });

  test('statistics cannot be changed without a new financial transaction', async () => {
    await assertFails(setDoc(doc(as('admin'), 'daily_stats/2026-01-01'), { sales: 1e9, lastTxId: 'nope' }));
  });
});

describe('master data', () => {
  test('customers are created with zero balance unless posted through the ledger', async () => {
    const db = as('sales');
    await assertSucceeds(setDoc(doc(db, 'customers/c2'), { name: 'C2', balance: 0, active: true, createdBy: 'sales' }));
    await assertFails(setDoc(doc(db, 'customers/c3'), { name: 'C3', balance: 5000, active: true, createdBy: 'sales' }));
  });

  test('descriptive edits are allowed, balance edits are not', async () => {
    const db = as('sales');
    await assertSucceeds(updateDoc(doc(db, 'customers/c1'), { phone: '0100', updatedAt: serverTimestamp(), updatedBy: 'sales' }));
    await assertFails(updateDoc(doc(db, 'customers/c1'), { phone: '0100', balance: -1 }));
  });

  test('catalog is managed only with manage_catalog', async () => {
    await assertFails(updateDoc(doc(as('sales'), 'products/p1'), { sellPrice: 1 }));
    await assertSucceeds(updateDoc(doc(as('admin'), 'products/p1'), { sellPrice: 600, updatedAt: serverTimestamp(), updatedBy: 'admin' }));
  });
});

describe('first-run setup', () => {
  test('the first user can bootstrap the system exactly once', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const s = ctx.firestore();
      for (const p of ['meta/bootstrap', 'settings/company']) await deleteDoc(doc(s, p));
    });
    const db = as('owner');
    const b = writeBatch(db);
    b.set(doc(db, 'meta/bootstrap'), { adminUid: 'owner', createdAt: serverTimestamp() });
    b.set(doc(db, 'roles/admin2'), { name: 'Admin', permissions: ['admin'], system: true });
    b.set(doc(db, 'users/owner'), { email: 'o@x.com', name: 'Owner', roleId: 'admin', roleName: 'Admin',
      permissions: ['admin'], active: true, createdAt: serverTimestamp(), createdBy: 'owner' });
    b.set(doc(db, 'cashboxes/newbox'), { name: 'Main', kind: 'cash', balance: 0, totalIn: 0, totalOut: 0, active: true,
      createdAt: serverTimestamp(), createdBy: 'owner' });
    b.set(doc(db, 'settings/company'), { companyName: 'Co', updatedBy: 'owner' });
    b.set(doc(db, 'expense_categories/rent'), { name: 'Rent', active: true, order: 0 });
    b.set(doc(db, 'audit_logs/setup'), { action: 'create', userId: 'owner', userName: 'Owner', at: serverTimestamp() });
    await assertSucceeds(b.commit());

    // A second signup cannot become admin afterwards.
    const other = as('late');
    await assertFails(setDoc(doc(other, 'users/late'), { permissions: ['admin'], active: true }));
  });
});
