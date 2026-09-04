import 'package:hive_flutter/hive_flutter.dart';
import '../models/person.dart';
import '../models/ledger_transaction.dart';
import '../models/transaction_type.dart';

/// Thin wrapper around Hive boxes. Owns box lifecycle & registration of
/// type adapters. All other services/providers go through this class
/// instead of touching Hive directly, so storage engine could be swapped
/// later without breaking business logic.
class DatabaseService {
  static const String peopleBoxName = 'people_box';
  static const String transactionsBoxName = 'transactions_box';
  static const String settingsBoxName = 'settings_box';

  late Box<Person> peopleBox;
  late Box<LedgerTransaction> transactionsBox;
  late Box settingsBox;

  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PersonAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TransactionTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(LedgerTransactionAdapter());
    }

    peopleBox = await Hive.openBox<Person>(peopleBoxName);
    transactionsBox = await Hive.openBox<LedgerTransaction>(
      transactionsBoxName,
    );
    settingsBox = await Hive.openBox(settingsBoxName);

    _initialized = true;
  }

  Future<void> clearAllData() async {
    await peopleBox.clear();
    await transactionsBox.clear();
  }
}
