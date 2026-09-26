import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/accounting/posting_factory.dart';
import '../../../core/accounting/recipe.dart';
import '../../../core/audit/audit_entry.dart';
import '../../../core/firebase/collections.dart';
import '../../../core/ledger/ledger_service.dart';
import '../../../core/utils/keywords.dart';
import '../../auth/domain/app_user.dart';
import '../domain/catalog_item.dart';

enum ProductFilter { all, lowStock, inactive }

class ProductInput {
  const ProductInput({
    required this.name,
    required this.sellPrice,
    this.sku = '',
    this.barcode = '',
    this.unit = 'قطعة',
    this.lowStockAlert = 0,
    this.description = '',
  });

  final String name;
  final String sku;
  final String barcode;
  final String unit;
  final int sellPrice;
  final double lowStockAlert;
  final String description;

  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'sku': sku.trim(),
        'barcode': barcode.trim(),
        'unit': unit.trim().isEmpty ? 'قطعة' : unit.trim(),
        'sellPrice': sellPrice,
        'lowStockAlert': lowStockAlert,
        'description': description.trim(),
        'keywords': Keywords.build([name, sku, barcode]),
      };
}

/// A manufactured product: a sell price and the stock products (with the
/// quantity of each) consumed from stock every time one unit is sold.
class ManufacturedInput {
  const ManufacturedInput({
    required this.name,
    required this.sellPrice,
    required this.components,
    required this.estimatedCost,
    this.sku = '',
    this.barcode = '',
    this.unit = 'قطعة',
    this.description = '',
  });

  final String name;
  final String sku;
  final String barcode;
  final String unit;
  final int sellPrice;
  final List<RecipeComponent> components;

  /// Components' cost when the recipe was saved, shown in lists. Sales use
  /// the components' actual cost at the time of sale instead.
  final int estimatedCost;
  final String description;

  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'sku': sku.trim(),
        'barcode': barcode.trim(),
        'unit': unit.trim().isEmpty ? 'قطعة' : unit.trim(),
        'sellPrice': sellPrice,
        'costPrice': estimatedCost,
        'type': 'manufactured',
        'components': [for (final c in components) c.toMap()],
        'description': description.trim(),
        'keywords': Keywords.build([name, sku, barcode]),
      };
}

class ServiceInput {
  const ServiceInput({
    required this.name,
    required this.sellPrice,
    required this.cost,
    this.description = '',
  });

  final String name;
  final int sellPrice;
  final int cost;
  final String description;

  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'sellPrice': sellPrice,
        'cost': cost,
        'description': description.trim(),
        'keywords': Keywords.build([name]),
      };
}

class CatalogRepository {
  CatalogRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _products => _db.collection(Col.products);
  CollectionReference<Map<String, dynamic>> get _services => _db.collection(Col.services);

  // ---------------------------------------------------------------- products

  Query<Map<String, dynamic>> productsQuery({String search = '', ProductFilter filter = ProductFilter.all}) {
    final term = Keywords.term(search);
    if (term != null) {
      return _products.where('keywords', arrayContains: term).orderBy('name');
    }
    return switch (filter) {
      ProductFilter.inactive => _products.where('active', isEqualTo: false).orderBy('name'),
      ProductFilter.lowStock => _products.where('active', isEqualTo: true).orderBy('stockQty'),
      ProductFilter.all => _products.orderBy('name'),
    };
  }

  Future<List<Product>> searchProducts(String text, {int limit = 20}) async {
    final term = Keywords.term(text);
    Query<Map<String, dynamic>> q = _products.where('active', isEqualTo: true);
    q = term == null ? q.orderBy('name').limit(limit) : q.where('keywords', arrayContains: term).limit(limit);
    return (await q.get()).docs.map(Product.fromDoc).toList();
  }

  /// Current state of the given products (e.g. a recipe's components).
  Future<List<Product>> productsByIds(Iterable<String> ids) async {
    final snaps = await Future.wait([for (final id in ids) _products.doc(id).get()]);
    return [for (final s in snaps) if (s.exists) Product.fromDoc(s)];
  }

  /// Exact barcode lookup (for scanner integration).
  Future<Product?> productByBarcode(String barcode) async {
    final s = await _products.where('barcode', isEqualTo: barcode.trim()).limit(1).get();
    return s.docs.isEmpty ? null : Product.fromDoc(s.docs.first);
  }

  /// Creates a product. Opening stock (if any) is posted through the ledger
  /// atomically: inventory value enters the books against opening capital.
  Future<String> createProduct(
    ProductInput input, {
    required int costPrice,
    required double openingQty,
    required AppUser user,
    required LedgerService ledger,
  }) async {
    final ref = _products.doc();
    final data = {
      ...input.toMap(),
      'costPrice': costPrice,
      'stockQty': 0.0,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': user.uid,
    };
    final audit = AuditEntry(
      action: AuditAction.create,
      entityType: Col.products,
      entityId: ref.id,
      summary: 'إضافة منتج: ${input.name.trim()}',
      after: {...input.toMap()..remove('keywords'), 'costPrice': costPrice, 'openingQty': openingQty},
    );
    if (openingQty <= 0) {
      final batch = _db.batch()
        ..set(ref, data)
        ..set(audit.newRef(_db), audit.toMap(uid: user.uid, userName: user.name));
      await batch.commit();
      return ref.id;
    }
    await ledger.post(PostingRequest(
      postingId: _db.collection(Col.financialTransactions).doc().id,
      build: (_) => PostingDraft(
        posting: PostingFactory.stockOpening(
          productId: ref.id,
          productName: input.name.trim(),
          date: DateTime.now(),
          quantity: openingQty,
          unitCost: costPrice,
        ),
        newAccounts: {ref.path: data},
        audit: audit,
      ),
    ));
    return ref.id;
  }

  /// Updates descriptive fields and price. Cost and stock are owned by the
  /// ledger; the cost can only be set manually while there is no stock.
  Future<void> updateProduct(Product before, ProductInput input, AppUser user, {int? costPrice}) async {
    final changes = {
      ...input.toMap(),
      if (costPrice != null && before.stockQty <= 0) 'costPrice': costPrice,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
    };
    final audit = AuditEntry(
      action: AuditAction.update,
      entityType: Col.products,
      entityId: before.id,
      summary: 'تعديل منتج: ${input.name.trim()}',
      before: {'name': before.name, 'sellPrice': before.sellPrice, 'costPrice': before.costPrice},
      after: {'name': input.name.trim(), 'sellPrice': input.sellPrice, 'costPrice': ?costPrice},
    );
    final batch = _db.batch()
      ..update(_products.doc(before.id), changes)
      ..set(audit.newRef(_db), audit.toMap(uid: user.uid, userName: user.name));
    await batch.commit();
  }

  /// Creates a manufactured product. It never holds stock, so nothing is
  /// posted to the ledger until it is sold.
  Future<String> createManufactured(ManufacturedInput input, AppUser user) async {
    final ref = _products.doc();
    Recipe.validate(ref.id, input.components);
    final audit = AuditEntry(
      action: AuditAction.create,
      entityType: Col.products,
      entityId: ref.id,
      summary: 'إضافة منتج تصنيعي: ${input.name.trim()}',
      after: input.toMap()..remove('keywords'),
    );
    final batch = _db.batch()
      ..set(ref, {
        ...input.toMap(),
        'stockQty': 0.0,
        'lowStockAlert': 0,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
      })
      ..set(audit.newRef(_db), audit.toMap(uid: user.uid, userName: user.name));
    await batch.commit();
    return ref.id;
  }

  Future<void> updateManufactured(Product before, ManufacturedInput input, AppUser user) async {
    Recipe.validate(before.id, input.components);
    final audit = AuditEntry(
      action: AuditAction.update,
      entityType: Col.products,
      entityId: before.id,
      summary: 'تعديل منتج تصنيعي: ${input.name.trim()}',
      before: {
        'name': before.name,
        'sellPrice': before.sellPrice,
        'components': [for (final c in before.components) c.toMap()],
      },
      after: {
        'name': input.name.trim(),
        'sellPrice': input.sellPrice,
        'components': [for (final c in input.components) c.toMap()],
      },
    );
    final batch = _db.batch()
      ..update(_products.doc(before.id), {
        ...input.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      })
      ..set(audit.newRef(_db), audit.toMap(uid: user.uid, userName: user.name));
    await batch.commit();
  }

  Future<void> setProductActive(Product p, bool active, AppUser user) =>
      _setActive(_products.doc(p.id), Col.products, 'منتج', p.name, active, user);

  // ---------------------------------------------------------------- services

  Query<Map<String, dynamic>> servicesQuery({String search = '', bool inactive = false}) {
    final term = Keywords.term(search);
    if (term != null) return _services.where('keywords', arrayContains: term).orderBy('name');
    if (inactive) return _services.where('active', isEqualTo: false).orderBy('name');
    return _services.orderBy('name');
  }

  Future<List<ServiceItem>> searchServices(String text, {int limit = 20}) async {
    final term = Keywords.term(text);
    Query<Map<String, dynamic>> q = _services.where('active', isEqualTo: true);
    q = term == null ? q.orderBy('name').limit(limit) : q.where('keywords', arrayContains: term).limit(limit);
    return (await q.get()).docs.map(ServiceItem.fromDoc).toList();
  }

  Future<void> createService(ServiceInput input, AppUser user) async {
    final ref = _services.doc();
    final audit = AuditEntry(
      action: AuditAction.create,
      entityType: Col.services,
      entityId: ref.id,
      summary: 'إضافة خدمة: ${input.name.trim()}',
      after: input.toMap()..remove('keywords'),
    );
    final batch = _db.batch()
      ..set(ref, {
        ...input.toMap(),
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
      })
      ..set(audit.newRef(_db), audit.toMap(uid: user.uid, userName: user.name));
    await batch.commit();
  }

  Future<void> updateService(ServiceItem before, ServiceInput input, AppUser user) async {
    final audit = AuditEntry(
      action: AuditAction.update,
      entityType: Col.services,
      entityId: before.id,
      summary: 'تعديل خدمة: ${input.name.trim()}',
      before: {'name': before.name, 'sellPrice': before.sellPrice, 'cost': before.cost},
      after: {'name': input.name.trim(), 'sellPrice': input.sellPrice, 'cost': input.cost},
    );
    final batch = _db.batch()
      ..update(_services.doc(before.id), {
        ...input.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      })
      ..set(audit.newRef(_db), audit.toMap(uid: user.uid, userName: user.name));
    await batch.commit();
  }

  Future<void> setServiceActive(ServiceItem s, bool active, AppUser user) =>
      _setActive(_services.doc(s.id), Col.services, 'خدمة', s.name, active, user);

  Future<void> _setActive(
    DocumentReference<Map<String, dynamic>> ref,
    String collection,
    String label,
    String name,
    bool active,
    AppUser user,
  ) async {
    final audit = AuditEntry(
      action: active ? AuditAction.activate : AuditAction.deactivate,
      entityType: collection,
      entityId: ref.id,
      summary: '${active ? 'تفعيل' : 'إيقاف'} $label: $name',
    );
    final batch = _db.batch()
      ..update(ref, {'active': active, 'updatedAt': FieldValue.serverTimestamp(), 'updatedBy': user.uid})
      ..set(audit.newRef(_db), audit.toMap(uid: user.uid, userName: user.name));
    await batch.commit();
  }
}
