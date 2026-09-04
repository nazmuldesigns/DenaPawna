import 'package:flutter/foundation.dart';
import '../models/person.dart';
import '../models/ledger_transaction.dart';
import '../models/transaction_type.dart';
import '../services/ledger_service.dart';

/// App-wide state management for the ledger domain. Wraps LedgerService
/// (which owns the actual business logic / accounting rules) and exposes
/// reactive getters for the UI layer via Provider/ChangeNotifier.
///
/// IMPORTANT: This class NEVER stores balances independently -- every
/// getter here calls back into LedgerService, which always derives
/// numbers fresh from the Transaction records.
class LedgerProvider extends ChangeNotifier {
  final LedgerService _service = LedgerService();

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // People
  // ---------------------------------------------------------------------

  List<Person> get allPeople => _service.getAllPeople();

  List<Person> get filteredPeople {
    final all = allPeople;
    if (_searchQuery.trim().isEmpty) return all;
    final q = _searchQuery.trim().toLowerCase();
    return all
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            (p.phone?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  Person? getPerson(String id) => _service.getPerson(id);

  Future<Person> addPerson({
    required String name,
    String? phone,
    String? note,
    String? photoPath,
  }) async {
    final person = await _service.addPerson(
      name: name,
      phone: phone,
      note: note,
      photoPath: photoPath,
    );
    notifyListeners();
    return person;
  }

  Future<void> updatePerson(
    Person person, {
    required String name,
    String? phone,
    String? note,
    String? photoPath,
  }) async {
    await _service.updatePerson(
      person,
      name: name,
      phone: phone,
      note: note,
      photoPath: photoPath,
    );
    notifyListeners();
  }

  Future<void> deletePerson(String personId, {bool force = false}) async {
    await _service.deletePerson(personId, force: force);
    notifyListeners();
  }

  int personBalancePaisa(String personId) =>
      _service.calculatePersonBalancePaisa(personId);

  PersonLedgerTotals personTotals(String personId) =>
      _service.calculatePersonTotals(personId);

  List<MapEntry<Person, int>> get outstandingPeople =>
      _service.getOutstandingPeople();

  // ---------------------------------------------------------------------
  // Transactions
  // ---------------------------------------------------------------------

  List<LedgerTransaction> transactionsForPerson(String personId) =>
      _service.getTransactionsForPerson(personId);

  List<LedgerTransaction> get allTransactions => _service.getAllTransactions();

  Future<LedgerTransaction> addTransaction({
    required String personId,
    required TransactionType type,
    required int amountPaisa,
    required DateTime date,
    String? note,
    String? idempotencyKey,
  }) async {
    final txn = await _service.addTransaction(
      personId: personId,
      type: type,
      amountPaisa: amountPaisa,
      date: date,
      note: note,
      idempotencyKey: idempotencyKey,
    );
    notifyListeners();
    return txn;
  }

  Future<void> updateTransaction(
    LedgerTransaction txn, {
    TransactionType? type,
    int? amountPaisa,
    DateTime? date,
    String? note,
  }) async {
    await _service.updateTransaction(
      txn,
      type: type,
      amountPaisa: amountPaisa,
      date: date,
      note: note,
    );
    notifyListeners();
  }

  Future<void> deleteTransaction(LedgerTransaction txn) async {
    await _service.deleteTransaction(txn);
    notifyListeners();
  }

  Future<void> restoreTransaction(LedgerTransaction txn) async {
    await _service.restoreTransaction(txn);
    notifyListeners();
  }

  Future<LedgerTransaction> recordPayment({
    required String personId,
    required int amountPaisa,
    required DateTime date,
    String? note,
    String? idempotencyKey,
  }) async {
    final txn = await _service.recordPayment(
      personId: personId,
      amountPaisa: amountPaisa,
      date: date,
      note: note,
      idempotencyKey: idempotencyKey,
    );
    notifyListeners();
    return txn;
  }

  Future<LedgerTransaction?> settleFully({
    required String personId,
    required DateTime date,
    String? note,
    String? idempotencyKey,
  }) async {
    final txn = await _service.settleFully(
      personId: personId,
      date: date,
      note: note,
      idempotencyKey: idempotencyKey,
    );
    notifyListeners();
    return txn;
  }

  // ---------------------------------------------------------------------
  // Summary
  // ---------------------------------------------------------------------

  LedgerSummary get summary => _service.calculateSummary();

  /// Recent transactions across all people, most recent first.
  List<LedgerTransaction> get recentTransactions {
    final all = allTransactions;
    return all.take(10).toList();
  }

  void refresh() => notifyListeners();
}
