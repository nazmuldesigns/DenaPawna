import 'package:hive/hive.dart';

part 'person.g.dart';

/// A person the user has a lending/borrowing relationship with.
/// Balance is NEVER stored here as an authoritative value long-term;
/// it is always recalculated from the Transaction records by LedgerService.
/// The [cachedBalance] field is only a cache for fast list rendering and
/// is refreshed every time transactions change.
@HiveType(typeId: 0)
class Person extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? phone;

  @HiveField(3)
  String? note;

  @HiveField(4)
  String? photoPath;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  bool isDeleted;

  /// Cached running balance in paisa (integer, avoids float errors).
  /// Positive = তারা আমাকে দেবে (receivable, ও আমার কাছে পাবে... wait clarify)
  /// Convention: positive => person owes user (আমি পাবো / receivable)
  ///             negative => user owes person (আমি দেবো / payable)
  @HiveField(7)
  int cachedBalancePaisa;

  Person({
    required this.id,
    required this.name,
    this.phone,
    this.note,
    this.photoPath,
    DateTime? createdAt,
    this.isDeleted = false,
    this.cachedBalancePaisa = 0,
  }) : createdAt = createdAt ?? DateTime.now();
}
