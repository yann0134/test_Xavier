class SellerSummary {
  final int totalOrders;
  final double totalSales;
  final int totalClients;
  final String peakHour;
  final String topProductByQuantity;
  final String topProductByRevenue;
  final double averageBasket;
  final double variationSinceYesterday;
  final List<String> suggestions;
  final List<String> stockAlerts;
  final String motivationalMessage;

  SellerSummary({
    required this.totalOrders,
    required this.totalSales,
    required this.totalClients,
    required this.peakHour,
    required this.topProductByQuantity,
    required this.topProductByRevenue,
    required this.averageBasket,
    required this.variationSinceYesterday,
    required this.suggestions,
    required this.stockAlerts,
    required this.motivationalMessage,
  });
}
