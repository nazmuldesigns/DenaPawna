import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/person.dart';
import '../models/ledger_transaction.dart';
import '../models/transaction_type.dart';
import 'database_service.dart';
import 'ledger_service.dart';

/// Handles full data backup/restore as JSON, and CSV export, with
/// duplicate-prevention on restore (matched by stable `id` fields).
class BackupService {
  final DatabaseService _db = DatabaseService.instance;
  final LedgerService _ledger = LedgerService();

  /// Serializes all people + transactions into a single JSON backup
  /// document (schema-versioned for forward compatibility).
  Map<String, dynamic> exportToJsonMap() {
    final people = _db.peopleBox.values
        .map(
          (p) => {
            'id': p.id,
            'name': p.name,
            'phone': p.phone,
            'note': p.note,
            'photoPath': p.photoPath,
            'createdAt': p.createdAt.toIso8601String(),
            'isDeleted': p.isDeleted,
          },
        )
        .toList();

    final txns = _db.transactionsBox.values
        .map(
          (t) => {
            'id': t.id,
            'personId': t.personId,
            'type': t.type.name,
            'amountPaisa': t.amountPaisa,
            'date': t.date.toIso8601String(),
            'note': t.note,
            'createdAt': t.createdAt.toIso8601String(),
            'updatedAt': t.updatedAt?.toIso8601String(),
            'isDeleted': t.isDeleted,
            'idempotencyKey': t.idempotencyKey,
            'isSettlement': t.isSettlement,
            'paymentMethod': t.paymentMethod,
          },
        )
        .toList();

    return {
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'appName': 'Khata Bondhu',
      'people': people,
      'transactions': txns,
    };
  }

  Future<File> exportToJsonFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/khata_bondhu_backup_$timestamp.json');
    final jsonStr = const JsonEncoder.withIndent(
      '  ',
    ).convert(exportToJsonMap());
    await file.writeAsString(jsonStr);
    return file;
  }

  /// Restores from a JSON backup map. Uses `id` fields to prevent
  /// duplicate records: existing people/transactions with the same id
  /// are updated in place, new ones are inserted.
  Future<void> restoreFromJsonMap(Map<String, dynamic> data) async {
    final peopleList = (data['people'] as List?) ?? [];
    final txnList = (data['transactions'] as List?) ?? [];

    final existingPeopleById = <String, Person>{};
    for (final p in _db.peopleBox.values) {
      existingPeopleById[p.id] = p;
    }

    for (final raw in peopleList) {
      final map = raw as Map<String, dynamic>;
      final id = map['id'] as String;
      final existing = existingPeopleById[id];
      if (existing != null) {
        existing.name = map['name'] as String;
        existing.phone = map['phone'] as String?;
        existing.note = map['note'] as String?;
        existing.photoPath = map['photoPath'] as String?;
        existing.isDeleted = map['isDeleted'] as bool? ?? false;
        await existing.save();
      } else {
        final person = Person(
          id: id,
          name: map['name'] as String,
          phone: map['phone'] as String?,
          note: map['note'] as String?,
          photoPath: map['photoPath'] as String?,
          createdAt:
              DateTime.tryParse(map['createdAt'] as String? ?? '') ??
              DateTime.now(),
          isDeleted: map['isDeleted'] as bool? ?? false,
        );
        await _db.peopleBox.add(person);
      }
    }

    final existingTxnById = <String, LedgerTransaction>{};
    for (final t in _db.transactionsBox.values) {
      existingTxnById[t.id] = t;
    }

    final affectedPersonIds = <String>{};

    for (final raw in txnList) {
      final map = raw as Map<String, dynamic>;
      final id = map['id'] as String;
      final personId = map['personId'] as String;
      affectedPersonIds.add(personId);
      final existing = existingTxnById[id];
      final type = TransactionType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => TransactionType.lent,
      );
      if (existing != null) {
        existing.type = type;
        existing.amountPaisa = map['amountPaisa'] as int;
        existing.date = DateTime.parse(map['date'] as String);
        existing.note = map['note'] as String?;
        existing.isDeleted = map['isDeleted'] as bool? ?? false;
        existing.isSettlement = map['isSettlement'] as bool? ?? false;
        existing.paymentMethod = map['paymentMethod'] as String? ?? 'cash';
        await existing.save();
      } else {
        final txn = LedgerTransaction(
          id: id,
          personId: personId,
          type: type,
          amountPaisa: map['amountPaisa'] as int,
          date: DateTime.parse(map['date'] as String),
          note: map['note'] as String?,
          createdAt:
              DateTime.tryParse(map['createdAt'] as String? ?? '') ??
              DateTime.now(),
          updatedAt: map['updatedAt'] != null
              ? DateTime.tryParse(map['updatedAt'] as String)
              : null,
          isDeleted: map['isDeleted'] as bool? ?? false,
          idempotencyKey: map['idempotencyKey'] as String?,
          isSettlement: map['isSettlement'] as bool? ?? false,
          paymentMethod: map['paymentMethod'] as String? ?? 'cash',
        );
        await _db.transactionsBox.add(txn);
      }
    }

    for (final personId in affectedPersonIds) {
      await _ledger.refreshPersonCache(personId);
    }
  }

  /// Exports all transactions (with person names) as a CSV file.
  Future<File> exportToCsvFile() async {
    final rows = <List<dynamic>>[
      ['তারিখ', 'ব্যক্তি', 'ধরন', 'পরিমাণ (৳)', 'নোট'],
    ];
    final peopleById = <String, Person>{};
    for (final p in _db.peopleBox.values) {
      peopleById[p.id] = p;
    }
    final txns = _ledger.getAllTransactions();
    for (final t in txns) {
      final person = peopleById[t.personId];
      rows.add([
        t.date.toIso8601String(),
        person?.name ?? 'অজানা',
        t.type.labelBn,
        t.amountTaka.toStringAsFixed(2),
        t.note ?? '',
      ]);
    }
    final csvStr = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/khata_bondhu_export_$timestamp.csv');
    await file.writeAsString(csvStr);
    return file;
  }

  Future<void> shareFile(File file, {String? text}) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: text),
    );
  }
}
