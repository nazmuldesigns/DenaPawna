import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ledger_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/money.dart';
import '../../widgets/summary_card.dart';
import '../../widgets/transaction_tile.dart';
import '../../widgets/person_avatar.dart';
import '../people/person_ledger_screen.dart';
import '../people/people_screen.dart';
import '../transactions/add_transaction_screen.dart';
import '../../models/transaction_type.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LedgerProvider>();
    final summary = provider.summary;
    final recent = provider.recentTransactions;
    final outstanding = provider.outstandingPeople;
    final peopleById = {for (final p in provider.allPeople) p.id: p};

    return Scaffold(
      appBar: AppBar(
        title: const Text('দেনা পাওনা'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => provider.refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              Row(
                children: [
                  Expanded(
                    child: SummaryCard(
                      label: 'মোট পাবো',
                      amountPaisa: summary.totalReceivablePaisa,
                      icon: Icons.arrow_upward,
                      color: AppColors.receivableGreen,
                      bgColor: AppColors.receivableGreenBg,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SummaryCard(
                      label: 'মোট দেবো',
                      amountPaisa: summary.totalPayablePaisa,
                      icon: Icons.arrow_downward,
                      color: AppColors.payableRed,
                      bgColor: AppColors.payableRedBg,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.teal,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'নেট ব্যালেন্স',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      Money.formatPaisa(summary.netBalancePaisa),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (outstanding.isNotEmpty) ...[
                Text(
                  'বকেয়া আছে যাদের',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: outstanding.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final entry = outstanding[index];
                      final person = entry.key;
                      final balance = entry.value;
                      final color = balance > 0
                          ? AppColors.receivableGreen
                          : AppColors.payableRed;
                      return GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                PersonLedgerScreen(personId: person.id),
                          ),
                        ),
                        child: SizedBox(
                          width: 76,
                          child: Column(
                            children: [
                              PersonAvatar(
                                name: person.name,
                                photoPath: person.photoPath,
                                radius: 26,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                person.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              Text(
                                Money.formatPaisa(balance.abs()),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'সাম্প্রতিক লেনদেন',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PeopleScreen()),
                    ),
                    child: const Text('সবাই দেখুন'),
                  ),
                ],
              ),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'এখনো কোনো লেনদেন নেই',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    child: Column(
                      children: recent.map((t) {
                        final person = peopleById[t.personId];
                        return TransactionTile(
                          txn: t,
                          person: person,
                          onTap: person == null
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PersonLedgerScreen(
                                        personId: person.id,
                                      ),
                                    ),
                                  ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickAddSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showQuickAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'নতুন লেনদেন যুক্ত করুন',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 16),
                _quickAddOption(
                  ctx,
                  'আমি পাবো',
                  Icons.arrow_upward,
                  AppColors.receivableGreen,
                  TransactionType.lent,
                ),
                _quickAddOption(
                  ctx,
                  'আমি দেবো',
                  Icons.arrow_downward,
                  AppColors.payableRed,
                  TransactionType.borrowed,
                ),
                _quickAddOption(
                  ctx,
                  'টাকা পেলাম',
                  Icons.call_received,
                  AppColors.receivableGreen,
                  TransactionType.receivedPayment,
                ),
                _quickAddOption(
                  ctx,
                  'টাকা দিলাম',
                  Icons.call_made,
                  AppColors.payableRed,
                  TransactionType.givenPayment,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _quickAddOption(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    TransactionType type,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddTransactionScreen(initialType: type),
          ),
        );
      },
    );
  }
}
