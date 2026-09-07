/// One row of the top-selling report for a date range.
///
/// `productName` is the HISTORICAL `sale_items.product_name` snapshot —
/// never the current Products catalog name. Renamed or deactivated products
/// therefore report under the name that was actually rung up.
class TopSellingProduct {
  const TopSellingProduct({required this.productName, required this.quantitySold});

  final String productName;
  final int quantitySold;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopSellingProduct &&
          productName == other.productName &&
          quantitySold == other.quantitySold;

  @override
  int get hashCode => Object.hash(productName, quantitySold);
}
