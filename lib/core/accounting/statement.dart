/// One row of a customer / supplier / cashbox statement.
class StatementEntry {
  const StatementEntry({
    required this.id,
    required this.date,
    required this.description,
    required this.increase,
    required this.decrease,
    this.reference,
    this.typeLabel,
  });

  final String id;
  final DateTime date;
  final String description;
  final int increase;
  final int decrease;
  final String? reference;
  final String? typeLabel;

  int get net => increase - decrease;
}

class StatementRow {
  const StatementRow(this.entry, this.balance);
  final StatementEntry entry;
  final int balance;
}

class Statement {
  const Statement({
    required this.opening,
    required this.rows,
  });

  final int opening;
  final List<StatementRow> rows;

  int get closing => rows.isEmpty ? opening : rows.last.balance;
  int get totalIncrease => rows.fold(0, (s, r) => s + r.entry.increase);
  int get totalDecrease => rows.fold(0, (s, r) => s + r.entry.decrease);

  /// Builds a running-balance statement. Balances are always *derived* from
  /// the entries (never read from a stored field), so a statement is
  /// self-verifying: opening + Σincrease − Σdecrease == closing.
  factory Statement.build({
    required int opening,
    required List<StatementEntry> entries,
  }) {
    final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));
    var balance = opening;
    final rows = <StatementRow>[];
    for (final e in sorted) {
      balance += e.net;
      rows.add(StatementRow(e, balance));
    }
    return Statement(opening: opening, rows: rows);
  }
}
