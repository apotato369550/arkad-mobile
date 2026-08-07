enum TransactionType { income, expense }

class LedgerTransaction {
  LedgerTransaction({
    required this.id,
    required this.merchant,
    required this.category,
    required this.date,
    required this.amount,
    required this.type,
  });

  final int id;
  final String merchant;
  final String category;
  final DateTime date;
  final double amount;
  final TransactionType type;

  LedgerTransaction copyWith({
    String? merchant,
    String? category,
    DateTime? date,
    double? amount,
    TransactionType? type,
  }) {
    return LedgerTransaction(
      id: id,
      merchant: merchant ?? this.merchant,
      category: category ?? this.category,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      type: type ?? this.type,
    );
  }

  factory LedgerTransaction.fromJson(Map<String, dynamic> json) {
    return LedgerTransaction(
      id: json['id'] as int,
      merchant: json['merchant'] as String,
      category: json['category'] as String,
      date: DateTime.parse(json['date'] as String),
      amount: (json['amount'] as num).toDouble(),
      type: TransactionType.values.byName(json['type'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'merchant': merchant,
        'category': category,
        'date': date.toIso8601String(),
        'amount': amount,
        'type': type.name,
      };
}
