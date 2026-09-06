import 'package:uuid/uuid.dart';
import '../models/person.dart';
import '../models/ledger_transaction.dart';
import '../models/transaction_type.dart';
import 'database_service.dart';

/// Result summary for the whole ledger (dashboard-level numbers).
class LedgerSummary {
  final int totalReceivablePaisa; // মোট পাবো
  final int totalPayablePaisa; // মোট দেবো
  int get netBalancePaisa => totalReceivablePaisa - totalPayablePaisa;

  LedgerSummary({
    required this.totalReceivablePaisa,
    required this.totalPayablePaisa,
  });
}

/// Per-person ledger totals used on the Person Ledger screen.
class PersonLedgerTotals {
  final int
  totalLentPaisa; // মোট পাওনা তৈরি হয়েছে (lent + borrowed-repay base)
  final int totalPaidPaisa; // মোট পরিশোধ হয়েছে
  final int currentBalancePaisa; // বর্তমান ব্যালেন্স (+ receivable / - payable)

  PersonLedgerTotals({
    required this.totalLentPaisa,
    required this.totalPaidPaisa,
    required this.currentBalancePaisa,
  });
}

/// Exception thrown when an operation would violate accounting integrity.
class LedgerException implements Exception {
  final String message;
  LedgerException(this.message);
  @override
  String toString() => message;
}

/// LedgerService is the SINGLE SOURCE OF TRUTH for all financial
/// calculations in the app. Transactions are the ground truth records;
/// balances are ALWAYS derived by summing transactions, never hard-coded.
///
/// Every mutation (create/edit/delete/payment/settlement) triggers a
/// recalculation of the affected person's cached balance so list screens
/// can render quickly without re-summing every time, but the cache is
/// always rebuilt from transactions -- it is never treated as authoritative
/// on its own.
class LedgerService {
  final DatabaseService _db = DatabaseService.instance;
  static const Uuid _uuid = Uuid();

  // ---------------------------------------------------------------------
  // Core read operations
  // ---------------------------------------------------------------------

  List<Person> getAllPeople({bool includeDeleted = false}) {
    final people = _db.peopleBox.values
        .where((p) => includeDeleted || !p.isDeleted)
        .toList();
    people.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return people;
  }

  Person? getPerson(String id) {
    try {
      return _db.peopleBox.values.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  List<LedgerTransaction> getTransactionsForPerson(
    String personId, {
    bool includeDeleted = false,
  }) {
    final txns = _db.transactionsBox.values
        .where(
          (t) => t.personId == personId && (includeDeleted || !t.isDeleted),
        )
        .toList();
    txns.sort((a, b) => a.date.compareTo(b.date));
    return txns;
  }

  List<LedgerTransaction> getAllTransactions({bool includeDeleted = false}) {
    final txns = _db.transactionsBox.values
        .where((t) => includeDeleted || !t.isDeleted)
        .toList();
    txns.sort((a, b) => b.date.compareTo(a.date));
    return txns;
  }

  // ---------------------------------------------------------------------
  // Balance calculation - ALWAYS derived from transactions
  // ---------------------------------------------------------------------

  /// Recomputes a person's balance strictly from their non-deleted
  /// transactions. Positive => person owes user (receivable).
  /// Negative => user owes person (payable).
  int calculatePersonBalancePaisa(String personId) {
    final txns = getTransactionsForPerson(personId);
    int balance = 0;
    for (final t in txns) {
      balance += t.balanceDeltaPaisa;
    }
    return balance;
  }

  PersonLedgerTotals calculatePersonTotals(String personId) {
    final txns = getTransactionsForPerson(personId);
    int lent = 0;
    int paid = 0;
    int balance = 0;
    for (final t in txns) {
      balance += t.balanceDeltaPaisa;
      if (t.type.isDebtEntry) {
        lent += t.amountPaisa;
      } else {
        paid += t.amountPaisa;
      }
    }
    return PersonLedgerTotals(
      totalLentPaisa: lent,
      totalPaidPaisa: paid,
      currentBalancePaisa: balance,
    );
  }

  /// Recalculates and persists the cached balance on the Person record.
  /// Called after every transaction mutation for that person.
  Future<void> refreshPersonCache(String personId) async {
    final person = getPerson(personId);
    if (person == null) return;
    person.cachedBalancePaisa = calculatePersonBalancePaisa(personId);
    await person.save();
  }

  /// Full ledger summary across all (non-deleted) people, always derived
  /// fresh from transactions to guarantee correctness -- no stale caches
  /// are relied upon for these headline dashboard numbers.
  LedgerSummary calculateSummary() {
    int totalReceivable = 0;
    int totalPayable = 0;
    for (final person in getAllPeople()) {
      final balance = calculatePersonBalancePaisa(person.id);
      if (balance > 0) {
        totalReceivable += balance;
      } else if (balance < 0) {
        totalPayable += -balance;
      }
    }
    return LedgerSummary(
      totalReceivablePaisa: totalReceivable,
      totalPayablePaisa: totalPayable,
    );
  }

  /// List of people who currently have a non-zero outstanding balance,
  /// sorted by absolute amount descending (biggest first).
  List<MapEntry<Person, int>> getOutstandingPeople() {
    final result = <MapEntry<Person, int>>[];
    for (final person in getAllPeople()) {
      final balance = calculatePersonBalancePaisa(person.id);
      if (balance != 0) {
        result.add(MapEntry(person, balance));
      }
    }
    result.sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    return result;
  }

  // ---------------------------------------------------------------------
  // Person CRUD
  // ---------------------------------------------------------------------

  Future<Person> addPerson({
    required String name,
    String? phone,
    String? note,
    String? photoPath,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw LedgerException('নাম আবশ্যক (Name is required)');
    }
    final person = Person(
      id: _uuid.v4(),
      name: trimmedName,
      phone: phone?.trim().isEmpty == true ? null : phone?.trim(),
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      photoPath: photoPath,
    );
    await _db.peopleBox.add(person);
    return person;
  }

  Future<void> updatePerson(
    Person person, {
    required String name,
    String? phone,
    String? note,
    String? photoPath,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw LedgerException('নাম আবশ্যক (Name is required)');
    }
    person.name = trimmedName;
    person.phone = phone?.trim().isEmpty == true ? null : phone?.trim();
    person.note = note?.trim().isEmpty == true ? null : note?.trim();
    if (photoPath != null) person.photoPath = photoPath;
    await person.save();
  }

  /// Soft-deletes a person. By default this is blocked if the person has
  /// a non-zero outstanding balance, to protect financial data integrity
  /// (the user must settle or explicitly force-delete).
  Future<void> deletePerson(String personId, {bool force = false}) async {
    final person = getPerson(personId);
    if (person == null) return;
    final balance = calculatePersonBalancePaisa(personId);
    if (balance != 0 && !force) {
      throw LedgerException(
        'বকেয়া থাকা অবস্থায় ডিলিট করা যাবে না (Cannot delete while balance is outstanding)',
      );
    }
    person.isDeleted = true;
    await person.save();
    // Soft-delete their transactions too so summary calculations stay
    // consistent and history can be restored if un-deleted later.
    for (final t in getTransactionsForPerson(personId)) {
      t.isDeleted = true;
      await t.save();
    }
  }

  // ---------------------------------------------------------------------
  // Transaction CRUD (source of truth mutations)
  // ---------------------------------------------------------------------

  /// Adds a transaction with duplicate-submission protection via
  /// idempotencyKey: if a non-deleted transaction with the same key
  /// already exists, the existing one is returned instead of creating
  /// a duplicate.
  Future<LedgerTransaction> addTransaction({
    required String personId,
    required TransactionType type,
    required int amountPaisa,
    required DateTime date,
    String? note,
    String? idempotencyKey,
    String paymentMethod = 'cash',
    bool isSettlement = false,
  }) async {
    if (amountPaisa <= 0) {
      throw LedgerException('পরিমাণ শূন্যের বেশি হতে হবে (Amount must be > 0)');
    }
    if (getPerson(personId) == null) {
      throw LedgerException('ব্যক্তি খুঁজে পাওয়া যায়নি (Person not found)');
    }

    if (idempotencyKey != null) {
      final existing = _db.transactionsBox.values.where(
        (t) => t.idempotencyKey == idempotencyKey && !t.isDeleted,
      );
      if (existing.isNotEmpty) {
        return existing.first;
      }
    }

    final txn = LedgerTransaction(
      id: _uuid.v4(),
      personId: personId,
      type: type,
      amountPaisa: amountPaisa,
      date: date,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      idempotencyKey: idempotencyKey ?? _uuid.v4(),
      isSettlement: isSettlement,
      paymentMethod: paymentMethod,
    );
    await _db.transactionsBox.add(txn);
    await refreshPersonCache(personId);
    return txn;
  }

  Future<void> updateTransaction(
    LedgerTransaction txn, {
    TransactionType? type,
    int? amountPaisa,
    DateTime? date,
    String? note,
    String? paymentMethod,
  }) async {
    if (amountPaisa != null && amountPaisa <= 0) {
      throw LedgerException('পরিমাণ শূন্যের বেশি হতে হবে (Amount must be > 0)');
    }
    if (type != null) txn.type = type;
    if (amountPaisa != null) txn.amountPaisa = amountPaisa;
    if (date != null) txn.date = date;
    if (note != null) txn.note = note.trim().isEmpty ? null : note.trim();
    if (paymentMethod != null) txn.paymentMethod = paymentMethod;
    txn.updatedAt = DateTime.now();
    await txn.save();
    await refreshPersonCache(txn.personId);
  }

  Future<void> deleteTransaction(LedgerTransaction txn) async {
    txn.isDeleted = true;
    txn.updatedAt = DateTime.now();
    await txn.save();
    await refreshPersonCache(txn.personId);
  }

  Future<void> restoreTransaction(LedgerTransaction txn) async {
    txn.isDeleted = false;
    txn.updatedAt = DateTime.now();
    await txn.save();
    await refreshPersonCache(txn.personId);
  }

  /// Records a partial or full payment against a person's current
  /// balance. Automatically infers the correct payment TransactionType
  /// based on the sign of the outstanding balance:
  ///   balance > 0 (they owe user)  -> receivedPayment (টাকা পেলাম)
  ///   balance < 0 (user owes them) -> givenPayment    (টাকা দিলাম)
  Future<LedgerTransaction> recordPayment({
    required String personId,
    required int amountPaisa,
    required DateTime date,
    String? note,
    String? idempotencyKey,
  }) async {
    final balance = calculatePersonBalancePaisa(personId);
    if (balance == 0) {
      throw LedgerException('কোনো বকেয়া নেই (No outstanding balance)');
    }
    final type = balance > 0
        ? TransactionType.receivedPayment
        : TransactionType.givenPayment;
    return addTransaction(
      personId: personId,
      type: type,
      amountPaisa: amountPaisa,
      date: date,
      note: note,
      idempotencyKey: idempotencyKey,
    );
  }

  /// Fully settles a person's outstanding balance in one transaction,
  /// WITHOUT deleting any prior history. Marked with isSettlement=true
  /// so the UI can display a "সম্পূর্ণ পরিশোধ" badge.
  Future<LedgerTransaction?> settleFully({
    required String personId,
    required DateTime date,
    String? note,
    String? idempotencyKey,
  }) async {
    final balance = calculatePersonBalancePaisa(personId);
    if (balance == 0) {
      return null; // already settled, nothing to do
    }
    final type = balance > 0
        ? TransactionType.receivedPayment
        : TransactionType.givenPayment;
    return addTransaction(
      personId: personId,
      type: type,
      amountPaisa: balance.abs(),
      date: date,
      note: note ?? 'সম্পূর্ণ পরিশোধ',
      idempotencyKey: idempotencyKey,
      isSettlement: true,
    );
  }
}
