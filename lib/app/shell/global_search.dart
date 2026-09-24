import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/firebase/collections.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/permissions/permissions.dart';
import '../../core/utils/keywords.dart';
import '../../core/widgets/fields.dart';
import '../../features/auth/application/auth_providers.dart';

class _Hit {
  const _Hit(this.title, this.subtitle, this.icon, this.route);
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
}

/// Searches customers, suppliers, products, services and invoices by
/// keyword prefix, respecting the user's view permissions.
class GlobalSearch extends ConsumerStatefulWidget {
  const GlobalSearch({super.key});

  static Future<void> open(BuildContext context) => showDialog(
        context: context,
        builder: (_) => const Dialog(
          alignment: Alignment.topCenter,
          insetPadding: EdgeInsets.fromLTRB(24, 72, 24, 24),
          child: SizedBox(width: 620, height: 520, child: GlobalSearch()),
        ),
      );

  @override
  ConsumerState<GlobalSearch> createState() => _GlobalSearchState();
}

class _GlobalSearchState extends ConsumerState<GlobalSearch> {
  List<_Hit> _hits = const [];
  bool _loading = false;
  String _query = '';

  Future<void> _search(String text) async {
    _query = text;
    final term = Keywords.term(text);
    if (term == null) {
      setState(() => _hits = const []);
      return;
    }
    setState(() => _loading = true);
    final db = ref.read(firestoreProvider);
    final user = ref.read(currentUserProvider)!;

    Future<List<_Hit>> run(
      Permission p,
      String col,
      _Hit Function(DocumentSnapshot<Map<String, dynamic>>) map, {
      bool byDate = false,
    }) async {
      if (!user.can(p)) return const [];
      Query<Map<String, dynamic>> q = db.collection(col).where('keywords', arrayContains: term);
      if (byDate) q = q.orderBy('date', descending: true);
      final s = await q.limit(5).get();
      return s.docs.map(map).toList();
    }

    try {
      final results = await Future.wait([
        run(Permission.viewCustomers, Col.customers,
            (d) => _Hit(d['name'] as String, 'عميل', Symbols.person, '/customers/${d.id}')),
        run(Permission.viewSuppliers, Col.suppliers,
            (d) => _Hit(d['name'] as String, 'مورد', Symbols.local_shipping, '/suppliers/${d.id}')),
        run(Permission.viewSales, Col.sales,
            (d) => _Hit('${d['number']}', 'فاتورة بيع - ${d['partyName']}', Symbols.receipt_long, '/sales/${d.id}'),
            byDate: true),
        run(Permission.viewPurchases, Col.purchases,
            (d) => _Hit('${d['number']}', 'فاتورة شراء - ${d['partyName']}', Symbols.shopping_cart, '/purchases/${d.id}'),
            byDate: true),
        run(Permission.viewCatalog, Col.products,
            (d) => _Hit(d['name'] as String, 'منتج', Symbols.inventory_2, '/products?q=${Uri.encodeComponent(d['name'] as String)}')),
        run(Permission.viewCatalog, Col.services,
            (d) => _Hit(d['name'] as String, 'خدمة', Symbols.home_repair_service, '/services')),
      ]);
      if (mounted && _query == text) {
        setState(() => _hits = [for (final r in results) ...r]);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SearchField(onChanged: _search, autofocus: true, hint: 'اكتب اسماً أو رقم فاتورة...'),
          const SizedBox(height: 8),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _hits.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty ? 'ابدأ الكتابة للبحث' : (_loading ? '' : 'لا توجد نتائج'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.separated(
                    itemCount: _hits.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, i) {
                      final h = _hits[i];
                      return ListTile(
                        leading: Icon(h.icon),
                        title: Text(h.title),
                        subtitle: Text(h.subtitle),
                        onTap: () {
                          Navigator.pop(context);
                          context.push(h.route);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
