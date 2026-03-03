import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/show.dart';
import '../config/app_config.dart';
import '../services/api_service.dart';

class AddExpenseScreen extends StatefulWidget {
  final Show? show; // null = general expense not tied to a show
  final Expense? existingExpense; // non-null = editing mode

  const AddExpenseScreen({super.key, this.show, this.existingExpense});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedType = AppConfig.expenseTypes.first['value']!;
  String _paymentMethod = 'cash';
  DateTime _expenseDate = DateTime.now();

  bool get _isEditing => widget.existingExpense != null;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.existingExpense!;
      _amountController.text = e.amount.toStringAsFixed(2);
      _descriptionController.text = e.description;
      _selectedType = e.type;
      _paymentMethod = e.paymentMethod;
      _expenseDate = e.expenseDate;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String get _typeLabel {
    return AppConfig.expenseTypes
        .firstWhere((t) => t['value'] == _selectedType,
            orElse: () => AppConfig.expenseTypes.first)['label']!;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await ApiService.instance.updateExpense(
          expenseId:     widget.existingExpense!.id,
          type:          _selectedType,
          description:   _descriptionController.text.trim(),
          amount:        amount,
          paymentMethod: _paymentMethod,
          notes:         _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          expenseDate:   _expenseDate,
        );
      } else {
        await ApiService.instance.addExpense(
          type:          _selectedType,
          description:   _descriptionController.text.trim(),
          amount:        amount,
          showId:        widget.show?.id,
          paymentMethod: _paymentMethod,
          notes:         _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          expenseDate:   _expenseDate,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditing ? 'Expense updated' : '\${amount.toStringAsFixed(2)} $_typeLabel logged'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to save: $e'),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _expenseDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_expenseDate),
    );
    if (picked != null) {
      setState(() {
        _expenseDate = DateTime(
          _expenseDate.year,
          _expenseDate.month,
          _expenseDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Expense' : 'Add Expense'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Show context banner
            if (widget.show != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.store, color: AppColors.accent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Logging expense for: ${widget.show!.name}',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Amount ─────────────────────────────────────────────────────
            _SectionLabel('Amount'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              autofocus: !_isEditing,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
              ),
              decoration: const InputDecoration(
                prefixText: '\$ ',
                prefixStyle: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
                hintText: '0.00',
                border: InputBorder.none,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter an amount';
                if (double.tryParse(v) == null) return 'Invalid amount';
                if (double.parse(v) <= 0) return 'Amount must be greater than 0';
                return null;
              },
            ),

            const Divider(),
            const SizedBox(height: 16),

            // ── Expense Type ───────────────────────────────────────────────
            _SectionLabel('Expense Type'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConfig.expenseTypes.map((type) {
                final selected = _selectedType == type['value'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = type['value']!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.accent.withOpacity(0.15)
                          : AppColors.darkSurfaceElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.accent
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _typeIcon(type['value']!),
                          size: 14,
                          color: selected
                              ? AppColors.accent
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          type['label']!,
                          style: TextStyle(
                            color: selected
                                ? AppColors.accent
                                : AppColors.textSecondary,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // ── Description ────────────────────────────────────────────────
            _SectionLabel('Description'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                hintText: _defaultDescription(_selectedType),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Add a description' : null,
            ),

            const SizedBox(height: 24),

            // ── Payment Method ─────────────────────────────────────────────
            _SectionLabel('Payment Method'),
            const SizedBox(height: 12),
            Row(
              children: [
                _PaymentChip('cash', 'Cash', Icons.payments_outlined),
                const SizedBox(width: 8),
                _PaymentChip('card', 'Card', Icons.credit_card),
                const SizedBox(width: 8),
                _PaymentChip('trade', 'Trade / Other', Icons.swap_horiz),
              ],
            ),

            const SizedBox(height: 24),

            // ── Date & Time ────────────────────────────────────────────────
            _SectionLabel('Date & Time'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DateTimeButton(
                    icon: Icons.calendar_today_outlined,
                    label: dateFormat.format(_expenseDate),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateTimeButton(
                    icon: Icons.access_time_outlined,
                    label: timeFormat.format(_expenseDate),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Optional Notes ─────────────────────────────────────────────
            _SectionLabel('Notes (Optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Any extra details...',
              ),
            ),

            const SizedBox(height: 40),

            // ── Save button ────────────────────────────────────────────────
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
              ),
              child: Text(
                _isEditing ? 'Update Expense' : 'Log Expense',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),

            if (_isEditing) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _confirmDelete(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                ),
                child: const Text(
                  'Delete Expense',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _PaymentChip(String value, String label, IconData icon) {
    final selected = _paymentMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withOpacity(0.15)
              : AppColors.darkSurfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accent : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color:
                    selected ? AppColors.accent : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.accent : AppColors.textSecondary,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.instance
                    .deleteExpense(widget.existingExpense!.id);
                if (!mounted) return;
                Navigator.pop(context, 'deleted');
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Failed to delete: $e'),
                  backgroundColor: AppColors.danger,
                ));
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'table_fee':
        return Icons.table_restaurant_outlined;
      case 'travel':
        return Icons.directions_car_outlined;
      case 'hotel':
        return Icons.hotel_outlined;
      case 'food':
        return Icons.restaurant_outlined;
      case 'card_purchase':
        return Icons.style_outlined;
      case 'supplies':
        return Icons.inventory_2_outlined;
      case 'grading':
        return Icons.verified_outlined;
      case 'shipping':
        return Icons.local_shipping_outlined;
      default:
        return Icons.receipt_outlined;
    }
  }

  String _defaultDescription(String type) {
    switch (type) {
      case 'table_fee':
        return 'e.g. Table B-12, corner spot...';
      case 'travel':
        return 'e.g. Gas, mileage, Uber...';
      case 'hotel':
        return 'e.g. Holiday Inn, 2 nights...';
      case 'food':
        return 'e.g. Breakfast, coffee, lunch...';
      case 'card_purchase':
        return 'e.g. Bought Charizard from vendor...';
      case 'supplies':
        return 'e.g. Top loaders, sleeves, labels...';
      case 'grading':
        return 'e.g. PSA submission, 5 cards...';
      case 'shipping':
        return 'e.g. USPS Priority to buyer...';
      default:
        return 'Describe the expense...';
    }
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.accent,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _DateTimeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DateTimeButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.darkDivider),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
