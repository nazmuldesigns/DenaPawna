import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../../models/ledger_transaction.dart';
import '../../providers/ledger_provider.dart';
import '../../services/backup_service.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/money.dart';
import '../../widgets/person_avatar.dart';
import '../../widgets/transaction_tile.dart';
import '../transactions/add_transaction_screen.dart';
import 'add_edit_person_screen.dart';

class PersonLedgerScreen extends StatefulWidget {
  final String personId;

  const PersonLedgerScreen({super.key, required this.personId});

  @override
  State<PersonLedgerScreen> createState() => _PersonLedgerScreenState();
}

class _PersonLedgerScreenState extends State<PersonLedgerScreen> {
  final PdfService _pdfService = PdfService();
  final BackupService _backupService = BackupService();
  bool _busy = false;

  Future<void> _recordPayment(int suggestedBalancePaisa) async {
    final controller = TextEditingController(
      text: (suggestedBalancePaisa.abs() / 100).toStringAsFixed(0),
    );
    var selectedMethod = 'cash';
    final result = await showDialog<(double, String)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('পরিশোধ যুক্ত করুন'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            const methods = {
              'cash': ('Cash', Icons.payments_outlined, Colors.green),
              'bkash': ('bKash', Icons.phone_android, Colors.pink),
              'nagad': (
                'Nagad',
                Icons.account_balance_wallet_outlined,
                Colors.orange,
              ),
              'bank': (
                'Bank Transfer',
                Icons.account_balance_outlined,
                Colors.blue,
              ),
            };
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'পরিমাণ (৳)',
                    prefixText: '৳ ',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment method / channel',
                  ),
                  items: methods.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Row(
                            children: [
                              Icon(entry.value.$2, color: entry.value.$3),
                              const SizedBox(width: 8),
                              Text(entry.value.$1),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedMethod = value);
                    }
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = Money.parseAmountInput(controller.text);
              if (value != null) {
                Navigator.pop(ctx, (value, selectedMethod));
              }
            },
            child: const Text('যুক্ত করুন'),
          ),
        ],
      ),
    );
    if (result == null) return;
    setState(() => _busy = true);
    try {
      await context.read<LedgerProvider>().recordPayment(
        personId: widget.personId,
        amountPaisa: Money.takaToPaisa(result.$1),
        date: DateTime.now(),
        idempotencyKey: const Uuid().v4(),
        paymentMethod: result.$2,
      );
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

  Future<void> _settleFully() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('সম্পূর্ণ পরিশোধ নিশ্চিত করুন'),
        content: const Text(
          'এই ব্যক্তির সম্পূর্ণ বকেয়া পরিশোধ হিসেবে চিহ্নিত করা হবে। '
          'পূর্বের লেনদেন ইতিহাস মুছে যাবে না।',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('নিশ্চিত করুন'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final paymentMethod = await _choosePaymentMethod();
    if (paymentMethod == null) return;
    setState(() => _busy = true);
    try {
      await context.read<LedgerProvider>().settleFully(
        personId: widget.personId,
        date: DateTime.now(),
        idempotencyKey: const Uuid().v4(),
        paymentMethod: paymentMethod,
      );
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

  Future<String?> _choosePaymentMethod() async {
    const methods = {
      'cash': ('Cash', Icons.payments_outlined, Colors.green),
      'bkash': ('bKash', Icons.phone_android, Colors.pink),
      'nagad': ('Nagad', Icons.account_balance_wallet_outlined, Colors.orange),
      'bank': ('Bank Transfer', Icons.account_balance_outlined, Colors.blue),
    };
    var selected = 'cash';
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Payment method / channel'),
          content: DropdownButtonFormField<String>(
            initialValue: selected,
            items: methods.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Row(
                      children: [
                        Icon(entry.value.$2, color: entry.value.$3),
                        const SizedBox(width: 8),
                        Text(entry.value.$1),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setDialogState(() => selected = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('বাতিল'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('নিশ্চিত করুন'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareReminder(int balancePaisa) async {
    final provider = context.read<LedgerProvider>();
    final person = provider.getPerson(widget.personId);
    if (person == null) return;
    final message = _pdfService.generateReminderMessage(
      person: person,
      balancePaisa: balancePaisa,
    );
    await SharePlus.instance.share(ShareParams(text: message));
  }

  Future<void> _sharePdf() async {
    setState(() => _busy = true);
    try {
      final provider = context.read<LedgerProvider>();
      final person = provider.getPerson(widget.personId);
      if (person == null) return;
      final txns = provider.transactionsForPerson(widget.personId);
      final balance = provider.personBalancePaisa(widget.personId);
      final file = await _pdfService.generatePersonLedgerPdf(
        person: person,
        transactions: txns,
        currentBalancePaisa: balance,
      );
      await _backupService.shareFile(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('শেয়ার করা যায়নি: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deletePerson() async {
    final provider = context.read<LedgerProvider>();
    final balance = provider.personBalancePaisa(widget.personId);
    bool force = false;
    if (balance != 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('বকেয়া আছে'),
          content: Text(
            'এই ব্যক্তির ${Money.formatPaisa(balance.abs())} টাকা বকেয়া আছে। '
            'তবুও ডিলিট করতে চান?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('বাতিল'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.payableRed,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ডিলিট করুন'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      force = true;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ডিলিট নিশ্চিত করুন'),
          content: const Text('এই ব্যক্তিকে ডিলিট করতে চান?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('বাতিল'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.payableRed,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ডিলিট করুন'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await provider.deletePerson(widget.personId, force: force);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _deleteTransaction(LedgerTransaction txn) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('লেনদেন ডিলিট করবেন?'),
        content: const Text('এই লেনদেনটি ডিলিট করা হবে। এটি বাতিল করা সম্ভব।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.payableRed,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ডিলিট করুন'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final provider = context.read<LedgerProvider>();
    await provider.deleteTransaction(txn);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('লেনদেন ডিলিট করা হয়েছে'),
          action: SnackBarAction(
            label: 'পূর্বাবস্থায় ফিরান',
            onPressed: () => provider.restoreTransaction(txn),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LedgerProvider>();
    final person = provider.getPerson(widget.personId);
    if (person == null) {
      return const Scaffold(
        body: Center(child: Text('ব্যক্তি খুঁজে পাওয়া যায়নি')),
      );
    }
    final totals = provider.personTotals(widget.personId);
    final txns = provider.transactionsForPerson(widget.personId);
    final balance = totals.currentBalancePaisa;
    final balanceColor = balance > 0
        ? AppColors.receivableGreen
        : balance < 0
        ? AppColors.payableRed
        : Colors.grey;

    // Precompute running balances for the timeline (oldest -> newest).
    int running = 0;
    final runningBalances = <String, int>{};
    for (final t in txns) {
      running += t.balanceDeltaPaisa;
      runningBalances[t.id] = running;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(person.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'edit':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AddEditPersonScreen(existing: person),
                    ),
                  );
                  break;
                case 'delete':
                  await _deletePerson();
                  break;
                case 'share_pdf':
                  await _sharePdf();
                  break;
                case 'reminder':
                  await _shareReminder(balance);
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'edit',
                child: Text('ব্যক্তি সম্পাদনা'),
              ),
              const PopupMenuItem(
                value: 'share_pdf',
                child: Text('PDF শেয়ার করুন'),
              ),
              const PopupMenuItem(
                value: 'reminder',
                child: Text('রিমাইন্ডার পাঠান'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text(
                  'ব্যক্তি ডিলিট করুন',
                  style: TextStyle(color: AppColors.payableRed),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: _busy
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                children: [
                  Center(
                    child: Column(
                      children: [
                        PersonAvatar(
                          name: person.name,
                          photoPath: person.photoPath,
                          radius: 36,
                        ),
                        const SizedBox(height: 8),
                        if (person.phone != null) Text(person.phone!),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: balanceColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Text(
                          balance > 0
                              ? 'আপনি পাবেন'
                              : balance < 0
                              ? 'আপনাকে দিতে হবে'
                              : 'হিসাব সমান',
                          style: TextStyle(
                            color: balanceColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Money.formatPaisa(balance.abs()),
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: balanceColor,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _statBox(
                                'মোট পাওনা তৈরি',
                                totals.totalLentPaisa,
                                Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _statBox(
                                'মোট পরিশোধ',
                                totals.totalPaidPaisa,
                                Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (balance != 0)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _recordPayment(balance),
                            child: const Text('আংশিক পরিশোধ'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _settleFully,
                            child: const Text('সম্পূর্ণ পরিশোধ'),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'লেনদেনের ইতিহাস',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${txns.length} টি',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (txns.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'কোনো লেনদেন নেই',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  else
                    ...txns.reversed.map((t) {
                      return Dismissible(
                        key: ValueKey(t.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          color: AppColors.payableRed.withValues(alpha: 0.15),
                          child: const Icon(
                            Icons.delete,
                            color: AppColors.payableRed,
                          ),
                        ),
                        confirmDismiss: (_) async {
                          await _deleteTransaction(t);
                          return false; // list rebuilds via provider
                        },
                        child: TransactionTile(
                          txn: t,
                          showPersonName: false,
                          runningBalancePaisa: runningBalances[t.id],
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AddTransactionScreen(
                                personId: widget.personId,
                                existing: t,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddTransactionScreen(personId: widget.personId),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _statBox(String label, int paisa, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            Money.formatPaisa(paisa),
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
