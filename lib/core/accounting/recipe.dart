import '../money/money.dart';
import 'accounting_exception.dart';

/// One component of a manufactured product: [quantity] units of the stock
/// product [productId] go into every unit of the manufactured product.
class RecipeComponent {
  const RecipeComponent({
    required this.productId,
    required this.name,
    required this.quantity,
  });

  final String productId;
  final String name;
  final double quantity;

  Map<String, dynamic> toMap() => {'id': productId, 'name': name, 'qty': quantity};

  factory RecipeComponent.fromMap(Map<String, dynamic> m) => RecipeComponent(
        productId: m['id'] as String,
        name: m['name'] as String? ?? '',
        quantity: (m['qty'] as num).toDouble(),
      );

  static List<RecipeComponent> listFrom(Object? value) => [
        for (final m in (value as List?) ?? const [])
          RecipeComponent.fromMap(Map<String, dynamic>.from(m as Map)),
      ];
}

/// A component with the actual unit cost of its product, read when posting.
class CostedComponent {
  const CostedComponent({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitCost,
  });

  final String productId;
  final String name;

  /// Quantity per unit of the manufactured product.
  final double quantity;
  final int unitCost;

  /// Cost of this component in one unit of the manufactured product.
  int get costPerUnit => Money.multiply(quantity, unitCost);
}

/// Pure rules for manufactured (assembled-on-sale) products.
///
/// A manufactured product has no stock of its own: selling it consumes its
/// components from stock, and its cost is the actual cost of those
/// components at the moment of the sale.
abstract final class Recipe {
  /// Cost of one unit: the sum of every component's cost.
  static int unitCost(List<CostedComponent> components) =>
      components.fold(0, (sum, c) => sum + c.costPerUnit);

  /// Validates a recipe before it is saved.
  static void validate(String productId, List<RecipeComponent> components) {
    if (components.isEmpty) {
      throw const AccountingException(AccountingError.emptyRecipe);
    }
    final ids = <String>{};
    for (final c in components) {
      if (!(c.quantity > 0)) {
        throw const AccountingException(AccountingError.invalidQuantity);
      }
      if (c.productId == productId || !ids.add(c.productId)) {
        throw AccountingException(AccountingError.invalidRecipe, c.name);
      }
    }
  }

  /// Quantity of a component consumed by selling [soldQuantity] units.
  /// Rounded to 3 decimals like every stock quantity.
  static double consumed(double soldQuantity, double componentQuantity) =>
      (soldQuantity * componentQuantity * 1000).round() / 1000;
}
