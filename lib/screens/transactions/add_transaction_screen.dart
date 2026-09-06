import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/ledger_transaction.dart';
import '../../models/person.dart';
import '../../models/transaction_type.dart';
import '../../providers/ledger_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/money.dart';

/// Add or edit a single transaction. Handles all four transaction types,
/// with duplicate-submission protection via a per-form idempotency key
/// and a submitting-guard flag.
class AddTransactionScreen extends StatefulWidget {
  final String? personId;
  final LedgerTransaction? existing;
  final TransactionType? initialType;

  const AddTransactionScreen({
    super.key,
    this.personId,
    this.existing,
    this.initialType,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  late TransactionType _type;
  DateTime _date = DateTime.now();
  String? _selectedPersonId;
  String _paymentMethod = 'cash';
  String _calculatorExpression = '';
  bool _keypadVisible = false;
  bool _submitting = false;
  final String _idempotencyKey = const Uuid().v4();

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _type = widget.existing?.type ?? widget.initialType ?? TransactionType.lent;
    _selectedPersonId = widget.existing?.personId ?? widget.personId;
    if (widget.existing != null) {
      _amountController.text = widget.existing!.amountTaka.toStringAsFixed(
        widget.existing!.amountTaka.truncateToDouble() ==
                widget.existing!.amountTaka
            ? 0
            : 2,
      );
      _noteController.text = widget.existing!.note ?? '';
      _date = widget.existing!.date;
      _paymentMethod = widget.existing!.paymentMethod;
      _calculatorExpression = _amountController.text;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_date),
      );
      setState(() {
        _date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time?.hour ?? _date.hour,
          time?.minute ?? _date.minute,
        );
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting) return; // Duplicate-submission guard
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPersonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('একজন ব্যক্তি নির্বাচন করুন')),
      );
      return;
    }

    final amount = Money.parseAmountInput(_amountController.text);
    if (amount == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('সঠিক পরিমাণ লিখুন')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final provider = context.read<LedgerProvider>();
      final amountPaisa = Money.takaToPaisa(amount);
      if (_isEditing) {
        await provider.updateTransaction(
          widget.existing!,
          type: _type,
          amountPaisa: amountPaisa,
          date: _date,
          note: _noteController.text,
          paymentMethod: _paymentMethod,
        );
      } else {
        await provider.addTransaction(
          personId: _selectedPersonId!,
          type: _type,
          amountPaisa: amountPaisa,
          date: _date,
          note: _noteController.text,
          idempotencyKey: _idempotencyKey,
          paymentMethod: _paymentMethod,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openKeypad() {
    setState(() {
      _calculatorExpression = _amountController.text;
      _keypadVisible = true;
    });
  }

  void _appendCalculatorInput(String value) {
    setState(() {
      if (value == '.') {
        final currentNumber = _calculatorExpression
            .split(RegExp(r'[+\-÷×xX*/%]'))
            .last;
        if (currentNumber.contains('.')) return;
        if (currentNumber.isEmpty) _calculatorExpression += '0';
      }
      _calculatorExpression += value;
      _amountController.text = _calculatorExpression;
    });
  }

  void _clearCalculator() {
    setState(() {
      _calculatorExpression = '';
      _amountController.clear();
    });
  }

  void _backspaceCalculator() {
    if (_calculatorExpression.isEmpty) return;
    setState(() {
      _calculatorExpression = _calculatorExpression.substring(
        0,
        _calculatorExpression.length - 1,
      );
      _amountController.text = _calculatorExpression;
    });
  }

  double? _evaluateCalculator() {
    final expression = _calculatorExpression.trim();
    if (expression.isEmpty) return null;
    final tokens = RegExp(
      r'\d+(?:\.\d+)?|[+\-÷×xX*/%]',
    ).allMatches(expression).map((match) => match.group(0)!).toList();
    if (tokens.isEmpty || tokens.join() != expression) return null;
    var total = double.tryParse(tokens.first);
    if (total == null) return null;
    for (var index = 1; index < tokens.length; index += 2) {
      if (index + 1 >= tokens.length) return null;
      final value = double.tryParse(tokens[index + 1]);
      if (value == null) return null;
      switch (tokens[index]) {
        case '+':
          total = total! + value;
        case '-':
          total = total! - value;
        case '×':
        case 'x':
        case 'X':
        case '*':
          total = total! * value;
        case '÷':
        case '/':
          if (value == 0) return null;
          total = total! / value;
        case '%':
          total = total! * value / 100;
        default:
          return null;
      }
    }
    return total;
  }

  void _finishCalculator() {
    final result = _evaluateCalculator();
    if (result == null || result < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('সঠিক হিসাব লিখুন')));
      return;
    }
    final formatted = result == result.truncateToDouble()
        ? result.toStringAsFixed(0)
        : result.toStringAsFixed(2);
    setState(() {
      _amountController.text = formatted;
      _calculatorExpression = formatted;
      _keypadVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LedgerProvider>();
    final people = provider.allPeople;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'লেনদেন সম্পাদনা' : 'নতুন লেনদেন'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildTypeSelector(),
                    const SizedBox(height: 20),
                    if (widget.personId == null && !_isEditing) ...[
                      _buildPersonSelector(people),
                      const SizedBox(height: 16),
                    ] else if (_selectedPersonId != null) ...[
                      _buildPersonReadonly(provider),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _amountController,
                      readOnly: true,
                      onTap: _openKeypad,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9০-৯.,]'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'পরিমাণ (৳)',
                        prefixText: '৳ ',
                      ),
                      validator: (v) {
                        if (Money.parseAmountInput(v ?? '') == null) {
                          return 'সঠিক পরিমাণ লিখুন (শূন্যের বেশি)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildPaymentMethodSelector(),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'তারিখ ও সময়',
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_date.day}/${_date.month}/${_date.year}  '
                              '${_date.hour.toString().padLeft(2, '0')}:'
                              '${_date.minute.toString().padLeft(2, '0')}',
                            ),
                            const Icon(Icons.calendar_today, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'নোট (ঐচ্ছিক)',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_isEditing ? 'আপডেট করুন' : 'সংরক্ষণ করুন'),
                    ),
                  ],
                ),
              ),
            ),
            if (_keypadVisible) _buildCalculatorKeypad(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculatorKeypad() {
    final preview = _calculatorExpression.isEmpty ? '0' : _calculatorExpression;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Container(
            height: 38,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            height: 240,
            child: Column(
              children: [
                _calculatorRow(['AC', '%', '÷', '×']),
                _calculatorRow(['7', '8', '9', '-']),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            _calculatorRow(['4', '5', '6']),
                            _calculatorRow(['1', '2', '3']),
                          ],
                        ),
                      ),
                      Expanded(child: _calculatorCell('+', accent: true)),
                    ],
                  ),
                ),
                _calculatorRow(['⌫', '0', '.', '=']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _calculatorRow(List<String> labels) {
    return SizedBox(
      height: 48,
      child: Row(
        children: labels
            .map((label) => Expanded(child: _calculatorCell(label)))
            .toList(),
      ),
    );
  }

  Widget _calculatorCell(String label, {bool accent = false}) {
    final action = switch (label) {
      'AC' => _clearCalculator,
      '⌫' => _backspaceCalculator,
      '=' => _finishCalculator,
      _ => () => _appendCalculatorInput(label),
    };
    return InkWell(
      onTap: action,
      child: Container(
        height: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent
              ? const Color(0xffffe5ed)
              : label == '='
                  ? const Color(0xffffe5ed)
                  : Colors.white,
          border: Border.all(color: Colors.grey.shade300, width: 0.6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: accent || label == '=' ? Colors.pink.shade700 : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    const methods = <String, (String, IconData, Color)>{
      'cash': ('Cash', Icons.payments_outlined, Colors.green),
      'bkash': ('bKash', Icons.phone_android, Colors.pink),
      'nagad': ('Nagad', Icons.account_balance_wallet_outlined, Colors.orange),
      'bank': ('Bank Transfer', Icons.account_balance_outlined, Colors.blue),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment method / channel',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 3.3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: methods.entries.map((entry) {
            final selected = _paymentMethod == entry.key;
            return InkWell(
              onTap: () => setState(() => _paymentMethod = entry.key),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? entry.value.$3.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? entry.value.$3 : Colors.grey.shade300,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(entry.value.$2, color: entry.value.$3, size: 20),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        entry.value.$1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? entry.value.$3 : null,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle, color: entry.value.$3, size: 17),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    final types = TransactionType.values;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: types.map((t) {
        final selected = _type == t;
        final color = t.balanceSign > 0
            ? AppColors.receivableGreen
            : AppColors.payableRed;
        return ChoiceChip(
          label: Text(t.labelBn),
          selected: selected,
          onSelected: (_) => setState(() => _type = t),
          selectedColor: color.withValues(alpha: 0.18),
          labelStyle: TextStyle(
            color: selected ? color : Colors.grey.shade700,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          side: BorderSide(color: selected ? color : Colors.grey.shade300),
          backgroundColor: Colors.transparent,
        );
      }).toList(),
    );
  }

  Widget _buildPersonSelector(List<Person> people) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedPersonId,
      decoration: const InputDecoration(labelText: 'ব্যক্তি নির্বাচন করুন'),
      items: people
          .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
          .toList(),
      onChanged: (v) => setState(() => _selectedPersonId = v),
      validator: (v) => v == null ? 'ব্যক্তি নির্বাচন করুন' : null,
    );
  }

  Widget _buildPersonReadonly(LedgerProvider provider) {
    final person = provider.getPerson(_selectedPersonId!);
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'ব্যক্তি'),
      child: Text(
        person?.name ?? '',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
