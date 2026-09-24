import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accounting/accounting_exception.dart';
import '../../../core/accounting/invoice_calculator.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/firebase/collections.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/ledger/ledger_service.dart';
import '../../../core/utils/dates.dart';
import '../../cashboxes/domain/cashbox.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../parties/domain/party.dart';
import '../../parties/domain/payment.dart';
import '../data/invoice_repository.dart';
import '../domain/invoice.dart';
import 'invoice_providers.dart';

enum PaymentMode {
  full('نقدي (مدفوع بالكامل)'),
  partial('دفع جزئي'),
  credit('آجل');

  const PaymentMode(this.label);
  final String label;
}

class DraftLine {
  const DraftLine({required this.key, required this.item, required this.quantity, required this.unitPrice});

  /// Stable key so line widgets keep their text controllers.
  final int key;
  final Sellable item;
  final double quantity;
  final int unitPrice;

  DraftLine copyWith({double? quantity, int? unitPrice}) => DraftLine(
        key: key,
        item: item,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
      );

  InvoiceLineInput toInput() => InvoiceLineInput(
        kind: item.kind,
        itemId: item.id,
        name: item.name,
        quantity: quantity,
        unitPrice: unitPrice,
        unitCost: item.cost,
      );
}

class InvoiceFormState {
  const InvoiceFormState({
    required this.postingId,
    required this.date,
    this.party,
    this.lines = const [],
    this.discount = 0,
    this.mode = PaymentMode.full,
    this.partialPaid = 0,
    this.cashbox,
    this.method = PaymentMethod.cash,
    this.notes = '',
    this.saving = false,
  });

  final String postingId;
  final DateTime date;
  final Party? party;
  final List<DraftLine> lines;
  final int discount;
  final PaymentMode mode;
  final int partialPaid;
  final Cashbox? cashbox;
  final PaymentMethod method;
  final String notes;
  final bool saving;

  int get subtotal => lines.fold(0, (s, l) => s + l.toInput().grossTotal);
  int get total => subtotal - discount;

  int get paid => switch (mode) {
        PaymentMode.full => total,
        PaymentMode.credit => 0,
        PaymentMode.partial => partialPaid,
      };

  int get remaining => total - paid;

  /// Live preview totals. For sales, product cost shown here is an estimate
  /// (current average cost); the exact cost is read again when posting.
  InvoiceTotals? get preview {
    try {
      return InvoiceCalculator.calculate(
        lines: [for (final l in lines) l.toInput()],
        discount: discount,
        paid: paid.clamp(0, total < 0 ? 0 : total),
      );
    } on AccountingException {
      return null;
    }
  }

  InvoiceFormState copyWith({
    DateTime? date,
    Party? party,
    bool clearParty = false,
    List<DraftLine>? lines,
    int? discount,
    PaymentMode? mode,
    int? partialPaid,
    Cashbox? cashbox,
    PaymentMethod? method,
    String? notes,
    bool? saving,
  }) =>
      InvoiceFormState(
        postingId: postingId,
        date: date ?? this.date,
        party: clearParty ? null : (party ?? this.party),
        lines: lines ?? this.lines,
        discount: discount ?? this.discount,
        mode: mode ?? this.mode,
        partialPaid: partialPaid ?? this.partialPaid,
        cashbox: cashbox ?? this.cashbox,
        method: method ?? this.method,
        notes: notes ?? this.notes,
        saving: saving ?? this.saving,
      );
}

/// Holds the invoice being edited and submits it through the repository.
class InvoiceFormController extends Notifier<InvoiceFormState> {
  InvoiceFormController(this.kind);

  final InvoiceKind kind;
  int _nextKey = 0;

  @override
  InvoiceFormState build() => InvoiceFormState(
        postingId: ref.read(firestoreProvider).collection(Col.financialTransactions).doc().id,
        date: DateTime.now(),
      );

  InvoiceRepository get _repo => ref.read(invoiceRepositoryProvider(kind));

  void setParty(Party? party) {
    state = state.copyWith(
      party: party,
      clearParty: party == null,
      // A walk-in customer/supplier can only pay in full.
      mode: party == null ? PaymentMode.full : null,
    );
  }

  /// Adds an item; adding the same item again increases its quantity.
  void addItem(Sellable item) {
    final existing = state.lines.indexWhere((l) => l.item.id == item.id && l.item.kind == item.kind);
    if (existing >= 0) {
      final lines = [...state.lines];
      lines[existing] = lines[existing].copyWith(quantity: lines[existing].quantity + 1);
      state = state.copyWith(lines: lines);
      return;
    }
    final price = kind.isSale ? item.price : item.cost;
    state = state.copyWith(lines: [
      ...state.lines,
      DraftLine(key: _nextKey++, item: item, quantity: 1, unitPrice: price),
    ]);
  }

  /// Pre-fills the form from an existing invoice ("copy to new invoice").
  /// This is how a posted invoice is corrected: cancel it (reversal), then
  /// issue a corrected copy — history is never overwritten.
  void loadFrom(Invoice source, Party? party) {
    state = state.copyWith(
      party: party,
      clearParty: party == null,
      discount: source.discount,
      mode: party == null ? PaymentMode.full : PaymentMode.credit,
      notes: source.notes,
      lines: [
        for (final l in source.lines)
          DraftLine(
            key: _nextKey++,
            item: Sellable(kind: l.kind, id: l.itemId, name: l.name, price: l.unitPrice, cost: l.unitCost),
            quantity: l.quantity,
            unitPrice: l.unitPrice,
          ),
      ],
    );
  }

  void updateLine(int key, {double? quantity, int? unitPrice}) {
    state = state.copyWith(lines: [
      for (final l in state.lines) l.key == key ? l.copyWith(quantity: quantity, unitPrice: unitPrice) : l,
    ]);
  }

  void removeLine(int key) {
    state = state.copyWith(lines: state.lines.where((l) => l.key != key).toList());
  }

  void setDiscount(int v) => state = state.copyWith(discount: v);
  void setMode(PaymentMode m) => state = state.copyWith(mode: m);
  void setPartialPaid(int v) => state = state.copyWith(partialPaid: v);
  void setCashbox(Cashbox? c) => state = state.copyWith(cashbox: c);
  void setMethod(PaymentMethod m) => state = state.copyWith(method: m);
  void setDate(DateTime d) => state = state.copyWith(date: d);
  void setNotes(String n) => state = state.copyWith(notes: n);

  /// Validates and posts. Throws [AppException]/[AccountingException] with
  /// Arabic messages; returns the generated invoice number.
  Future<PostingOutcome> submit() async {
    final s = state;
    if (s.lines.isEmpty) throw const AccountingException(AccountingError.emptyInvoice);
    if (s.discount < 0 || s.discount > s.subtotal) {
      throw const AccountingException(AccountingError.discountExceedsTotal);
    }
    if (s.mode == PaymentMode.partial && (s.partialPaid <= 0 || s.partialPaid >= s.total)) {
      throw const AppException('في الدفع الجزئي يجب أن يكون المبلغ المدفوع أكبر من صفر وأقل من الصافي.');
    }
    if (s.remaining > 0 && s.party == null) {
      throw const AccountingException(AccountingError.creditRequiresParty);
    }
    if (s.paid > 0 && s.cashbox == null) {
      throw const AccountingException(AccountingError.cashboxRequired);
    }
    state = s.copyWith(saving: true);
    try {
      return await _repo.create(
        InvoiceSubmission(
          kind: kind,
          postingId: s.postingId,
          date: Dates.withCurrentTime(s.date),
          lines: [for (final l in s.lines) l.toInput()],
          discount: s.discount,
          paid: s.paid,
          method: s.method,
          notes: s.notes,
          party: s.party,
          cashboxId: s.cashbox?.id,
          cashboxName: s.cashbox?.name,
        ),
        ref.read(ledgerProvider),
      );
    } finally {
      if (ref.mounted) state = state.copyWith(saving: false);
    }
  }
}

final invoiceFormProvider =
    NotifierProvider.autoDispose.family<InvoiceFormController, InvoiceFormState, InvoiceKind>(
  InvoiceFormController.new,
);
