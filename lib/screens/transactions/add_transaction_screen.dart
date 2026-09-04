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
  bool _submitting = false;
  final String _idempotencyKey = const Uuid().v4();

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _type = widget.existing?.type ?? widget.initialType ?? TransactionType.lent;
    _selectedPersonId = widget.existing?.personId ?? widget.personId;
    if (widget.existing != null) {
      _amountController.text = widget.existing!.amountTaka
          .toStringAsFixed(widget.existing!.amountTaka.truncateToDouble() ==
                  widget.existing!.amountTaka
              ? 0
              : 2);
      _noteController.text = widget.existing!.note ?? '';
      _date = widget.existing!.date;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('সঠিক পরিমাণ লিখুন')),
      );
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
        );
      } else {
        await provider.addTransaction(
          personId: _selectedPersonId!,
          type: _type,
          amountPaisa: amountPaisa,
          date: _date,
          note: _noteController.text,
          idempotencyKey: _idempotencyKey,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9০-৯.,]')),
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
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'তারিখ ও সময়'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_date.day}/${_date.month}/${_date.year}  '
                        '${_date.hour.toString().padLeft(2, '0')}:${_date.minute.toString().padLeft(2, '0')}',
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
    );
  }

  Widget _buildTypeSelector() {
    final types = TransactionType.values;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: types.map((t) {
        final selected = _type == t;
        final color =
            t.balanceSign > 0 ? AppColors.receivableGreen : AppColors.payableRed;
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
