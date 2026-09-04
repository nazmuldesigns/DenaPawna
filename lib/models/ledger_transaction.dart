import 'package:hive/hive.dart';
import 'transaction_type.dart';

part 'ledger_transaction.g.dart';

/// A single immutable-ish ledger entry. Transactions are the single source
/// of truth for all balance calculations. Never hard-code balances anywhere
/// else in the app -- always derive them from the full list of transactions
/// belonging to a person via LedgerService.
@HiveType(typeId: 2)
class LedgerTransaction extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String personId;

  @HiveField(2)
  TransactionType type;

  /// Amount stored in paisa (1 taka = 100 paisa) as an integer to avoid
  /// floating point rounding errors in financial calculations.
  @HiveField(3)
  int amountPaisa;

  @HiveField(4)
  DateTime date;

  @HiveField(5)
  String? note;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime? updatedAt;

  @HiveField(8)
  bool isDeleted;

  /// Idempotency key to prevent duplicate submissions (e.g. double-tap on
  /// submit button creating two identical transactions).
  @HiveField(9)
  String? idempotencyKey;

  /// Marks this entry as a full settlement action (for display purposes:
  /// "সম্পূর্ণ পরিশোধ" badge) even though it is stored as a normal payment.
  @HiveField(10)
  bool isSettlement;

  LedgerTransaction({
    required this.id,
    required this.personId,
    required this.type,
    required this.amountPaisa,
    required this.date,
    this.note,
    DateTime? createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.idempotencyKey,
    this.isSettlement = false,
  }) : createdAt = createdAt ?? DateTime.now();

  double get amountTaka => amountPaisa / 100.0;

  /// Signed delta this transaction contributes to the person's balance,
  /// in paisa. Positive = increases what they owe user.
  int get balanceDeltaPaisa => amountPaisa * type.balanceSign;
}
