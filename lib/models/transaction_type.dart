import 'package:hive/hive.dart';

part 'transaction_type.g.dart';

/// Four core transaction types in the Bangla ledger domain.
///
/// Balance convention: positive balance = person owes user (receivable).
///   lent            (আমি পাবো)   -> balance += amount
///   receivedPayment (টাকা পেলাম) -> balance -= amount
///   borrowed        (আমি দেবো)   -> balance -= amount
///   givenPayment    (টাকা দিলাম) -> balance += amount
@HiveType(typeId: 1)
enum TransactionType {
  @HiveField(0)
  lent, // আমি পাবো - user gave money/goods, person now owes user

  @HiveField(1)
  borrowed, // আমি দেবো - user took money/goods, user now owes person

  @HiveField(2)
  receivedPayment, // টাকা পেলাম - person paid user back (reduces receivable)

  @HiveField(3)
  givenPayment, // টাকা দিলাম - user paid person back (reduces payable)
}

extension TransactionTypeX on TransactionType {
  String get labelBn {
    switch (this) {
      case TransactionType.lent:
        return 'আমি পাবো';
      case TransactionType.borrowed:
        return 'আমি দেবো';
      case TransactionType.receivedPayment:
        return 'টাকা পেলাম';
      case TransactionType.givenPayment:
        return 'টাকা দিলাম';
    }
  }

  /// Multiplier applied to signed amount to get balance delta.
  /// balance is from the perspective of: positive = they owe user.
  int get balanceSign {
    switch (this) {
      case TransactionType.lent:
        return 1;
      case TransactionType.borrowed:
        return -1;
      case TransactionType.receivedPayment:
        return -1;
      case TransactionType.givenPayment:
        return 1;
    }
  }

  /// Whether this transaction type is a "payment" (settlement-related)
  /// as opposed to a new debt/credit entry.
  bool get isPayment =>
      this == TransactionType.receivedPayment ||
      this == TransactionType.givenPayment;

  /// Whether this transaction increases the receivable (they owe more)
  bool get isDebtEntry =>
      this == TransactionType.lent || this == TransactionType.borrowed;
}
