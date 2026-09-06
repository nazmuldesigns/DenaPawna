import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ledger_transaction.dart';
import '../../models/transaction_type.dart';
import '../../providers/ledger_provider.dart';
import '../../services/backup_service.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_utils.dart';
import '../../utils/money.dart';
import '../../widgets/transaction_tile.dart';

enum ReportPeriod { daily, monthly, custom }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.monthly;
  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _customRange;
  String? _selectedPersonId; // null = all people
  final PdfService _pdfService = PdfService();
  final BackupService _backupService = BackupService();
  bool _busy = false;

  List<LedgerTransaction> _filteredTransactions(LedgerProvider provider) {
    List<LedgerTransaction> txns = _selectedPersonId == null
        ? provider.allTransactions
        : provider.transactionsForPerson(_selectedPersonId!).reversed.toList();

    switch (_period) {
      case ReportPeriod.daily:
        txns = txns
            .where((t) => AppDateUtils.isSameDay(t.date, _selectedDate))
            .toList();
        break;
      case ReportPeriod.monthly:
        txns = txns
            .where((t) => AppDateUtils.isSameMonth(t.date, _selectedDate))
            .toList();
        break;
      case ReportPeriod.custom:
        if (_customRange != null) {
          final start = AppDateUtils.startOfDay(_customRange!.start);
          final end = AppDateUtils.endOfDay(_customRange!.end);
          txns = txns
              .where((t) => !t.date.isBefore(start) && !t.date.isAfter(end))
              .toList();
        }
        break;
    }
    return txns;
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      initialDateRange: _customRange,
    );
    if (picked != null) setState(() => _customRange = picked);
  }

  Future<void> _exportPdf(
    List<LedgerTransaction> txns,
    LedgerProvider provider,
  ) async {
    setState(() => _busy = true);
    try {
      final peopleById = {for (final p in provider.allPeople) p.id: p};
      final rows = txns
          .map(
            (t) => [
              AppDateUtils.formatDate(t.date),
              '${peopleById[t.personId]?.name ?? 'অজানা'}'
                  '${t.note == null || t.note!.isEmpty ? '' : ' / ${t.note}'}',
              _paymentMethodLabel(t.paymentMethod),
              t.type.labelBn,
              Money.formatPaisa(t.amountPaisa),
            ],
          )
          .toList();
      final receivable = txns
          .where((t) => t.balanceDeltaPaisa > 0)
          .fold<int>(0, (sum, t) => sum + t.balanceDeltaPaisa);
      final payable = txns
          .where((t) => t.balanceDeltaPaisa < 0)
          .fold<int>(0, (sum, t) => sum + -t.balanceDeltaPaisa);
      final file = await _pdfService.generateReportPdf(
        rows: rows,
        totalReceivedPaisa: receivable,
        totalPaidPaisa: payable,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('PDF saved to Downloads'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => _backupService.shareFile(file),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _paymentMethodLabel(String method) {
    const labels = {
      'cash': 'Cash',
      'bkash': 'bKash',
      'nagad': 'Nagad',
      'bank': 'Bank',
    };
    return labels[method] ?? 'Cash';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LedgerProvider>();
    final txns = _filteredTransactions(provider);
    final peopleById = {for (final p in provider.allPeople) p.id: p};

    int receivable = 0;
    int payable = 0;
    for (final t in txns) {
      if (t.balanceDeltaPaisa > 0) {
        receivable += t.balanceDeltaPaisa;
      } else {
        payable += -t.balanceDeltaPaisa;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('রিপোর্ট'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _busy ? null : () => _exportPdf(txns, provider),
          ),
        ],
      ),
      body: SafeArea(
        child: _busy
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      children: [
                        SegmentedButton<ReportPeriod>(
                          segments: const [
                            ButtonSegment(
                              value: ReportPeriod.daily,
                              label: Text('দৈনিক'),
                            ),
                            ButtonSegment(
                              value: ReportPeriod.monthly,
                              label: Text('মাসিক'),
                            ),
                            ButtonSegment(
                              value: ReportPeriod.custom,
                              label: Text('কাস্টম'),
                            ),
                          ],
                          selected: {_period},
                          onSelectionChanged: (s) =>
                              setState(() => _period = s.first),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                ),
                                onPressed: _period == ReportPeriod.daily
                                    ? _pickDay
                                    : _period == ReportPeriod.monthly
                                    ? _pickMonth
                                    : _pickCustomRange,
                                label: Text(
                                  _period == ReportPeriod.daily
                                      ? AppDateUtils.formatDate(_selectedDate)
                                      : _period == ReportPeriod.monthly
                                      ? AppDateUtils.formatMonth(_selectedDate)
                                      : _customRange == null
                                      ? 'তারিখ নির্বাচন করুন'
                                      : '${AppDateUtils.formatDate(_customRange!.start)} - ${AppDateUtils.formatDate(_customRange!.end)}',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                initialValue: _selectedPersonId,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('সবাই'),
                                  ),
                                  ...provider.allPeople.map(
                                    (p) => DropdownMenuItem(
                                      value: p.id,
                                      child: Text(p.name),
                                    ),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedPersonId = v),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _summaryChip(
                            'পাবো',
                            receivable,
                            AppColors.receivableGreen,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _summaryChip(
                            'দেবো',
                            payable,
                            AppColors.payableRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: txns.isEmpty
                        ? Center(
                            child: Text(
                              'এই সময়ের কোনো লেনদেন নেই',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: txns.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final t = txns[index];
                              return TransactionTile(
                                txn: t,
                                person: peopleById[t.personId],
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _summaryChip(String label, int paisa, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          Text(
            Money.formatPaisa(paisa),
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
