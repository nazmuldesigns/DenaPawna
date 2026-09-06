import 'package:flutter/material.dart';
import '../models/ledger_transaction.dart';
import '../models/person.dart';
import '../models/transaction_type.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../utils/money.dart';
import 'person_avatar.dart';

/// A single row representing a transaction, used in Home recent list,
/// Person Ledger timeline, and Reports.
class TransactionTile extends StatelessWidget {
  final LedgerTransaction txn;
  final Person? person;
  final int? runningBalancePaisa;
  final bool showPersonName;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.txn,
    this.person,
    this.runningBalancePaisa,
    this.showPersonName = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = txn.balanceDeltaPaisa >= 0;
    final color = isPositive ? AppColors.receivableGreen : AppColors.payableRed;
    final sign = isPositive ? '+' : '-';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            if (showPersonName && person != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: PersonAvatar(
                  name: person!.name,
                  photoPath: person!.photoPath,
                  radius: 20,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          showPersonName && person != null
                              ? person!.name
                              : txn.type.labelBn,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (txn.isSettlement)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'সম্পূর্ণ পরিশোধ',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.teal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      _paymentBadge(txn.paymentMethod),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    showPersonName && person != null
                        ? '${txn.type.labelBn} • ${AppDateUtils.relativeLabel(txn.date)}'
                        : AppDateUtils.formatDateTime(txn.date),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (txn.note != null && txn.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        txn.note!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$sign${Money.formatPaisa(txn.amountPaisa)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: color,
                  ),
                ),
                if (runningBalancePaisa != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'ব্যাল: ${Money.formatPaisa(runningBalancePaisa!)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentBadge(String method) {
    const labels = {
      'cash': ('Cash', Icons.payments_outlined, Colors.green),
      'bkash': ('bKash', Icons.phone_android, Colors.pink),
      'nagad': ('Nagad', Icons.account_balance_wallet_outlined, Colors.orange),
      'bank': ('Bank', Icons.account_balance_outlined, Colors.blue),
    };
    final value = labels[method] ?? labels['cash']!;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Icon(value.$2, size: 15, color: value.$3),
    );
  }
}
