import 'posting.dart';

/// Result of applying a stock movement to a product.
typedef StockState = ({double quantity, int unitCost});

/// Inventory valuation strategy. The ledger only depends on this interface, so
/// FIFO or other methods can be added later without touching postings.
abstract interface class CostingPolicy {
  StockState apply(StockState current, StockMovement movement);
}

/// Perpetual weighted-average cost.
///
/// * Inbound goods (purchases, returned sales) are averaged in at their value.
/// * Ordinary outbound goods (sales) leave the unit cost unchanged.
/// * Outbound movements flagged [StockMovement.revaluesCost] (purchase
///   cancellation) are "un-averaged" out at their original value.
/// * When stock is zero or negative, inbound goods set the cost directly.
class WeightedAverageCosting implements CostingPolicy {
  const WeightedAverageCosting();

  @override
  StockState apply(StockState current, StockMovement m) {
    final newQuantity = _round(current.quantity + m.quantity);
    final isInbound = m.quantity > 0;

    if (isInbound) {
      if (current.quantity <= 0 || newQuantity <= 0) {
        return (quantity: newQuantity, unitCost: (m.value / m.quantity).round());
      }
      final totalValue = current.quantity * current.unitCost + m.value;
      return (quantity: newQuantity, unitCost: (totalValue / newQuantity).round());
    }

    if (m.revaluesCost && newQuantity > 0) {
      final totalValue = current.quantity * current.unitCost + m.value;
      final cost = (totalValue / newQuantity).round();
      return (quantity: newQuantity, unitCost: cost < 0 ? 0 : cost);
    }
    return (quantity: newQuantity, unitCost: current.unitCost);
  }

  /// Keeps fractional quantities clean (3 decimals) to avoid float noise.
  static double _round(double v) => (v * 1000).round() / 1000;
}
