import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../models/inventory_item.dart';
import '../config/app_config.dart';
import '../config/card_variants.dart';
import 'card_recognition_screen.dart';
import 'card_scan_screen.dart'; // ScanResult + ScannedCardData types

class AddEditCardScreen extends StatefulWidget {
  final InventoryItem? existingItem;

  const AddEditCardScreen({super.key, this.existingItem});

  bool get isEditing => existingItem != null;

  @override
  State<AddEditCardScreen> createState() => _AddEditCardScreenState();
}

class _AddEditCardScreenState extends State<AddEditCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  final _cardNameController    = TextEditingController();
  final _setNameController     = TextEditingController();
  final _cardNumberController  = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _marketPriceController = TextEditingController();
  final _askingPriceController = TextEditingController();
  final _notesController       = TextEditingController();
  final _gradeController       = TextEditingController();

  String _selectedGame    = AppConfig.allGames.first;
  String _condition       = 'NM';
  String _finish          = 'normal';
  String _language        = 'English';
  int    _quantity        = 1;
  bool   _isGraded        = false;
  String _gradingCompany  = 'PSA';
  DateTime _acquiredDate  = DateTime.now();

  static const _conditions = ['NM', 'LP', 'MP', 'HP', 'DMG'];
  static const _languages  = [
    'English', 'Japanese', 'Korean', 'Chinese', 'French',
    'German', 'Italian', 'Spanish', 'Portuguese',
  ];
  static const _gradingCompanies = ['PSA', 'BGS', 'SGC', 'CGC', 'CSG', 'HGA'];

  /// Variants update whenever the game changes
  List<CardVariant> get _variants => CardVariants.forGame(_selectedGame);

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) _populateFromExisting();
  }

  void _populateFromExisting() {
    final item = widget.existingItem!;
    _cardNameController.text   = item.cardName;
    _setNameController.text    = item.setName;
    _cardNumberController.text = item.cardNumber;
    _selectedGame  = item.game;
    _condition     = item.condition;
    _finish        = item.finish;
    _language      = item.language;
    _quantity      = item.quantity;
    _isGraded      = item.isGraded;
    _acquiredDate  = item.acquiredDate;

    if (item.purchasePrice != null)
      _purchasePriceController.text = item.purchasePrice!.toStringAsFixed(2);
    if (item.marketPrice != null)
      _marketPriceController.text = item.marketPrice!.toStringAsFixed(2);
    if (item.askingPrice != null)
      _askingPriceController.text = item.askingPrice!.toStringAsFixed(2);
    if (item.notes != null)
      _notesController.text = item.notes!;
    if (item.gradingCompany != null) _gradingCompany = item.gradingCompany!;
    if (item.grade != null) _gradeController.text = item.grade!;
  }

  /// When game changes, reset finish to 'normal' if current value
  /// isn't valid for the new game.
  void _onGameChanged(String game) {
    final newVariants = CardVariants.forGame(game);
    final stillValid  = newVariants.any((v) => v.value == _finish);
    setState(() {
      _selectedGame = game;
      if (!stillValid) _finish = newVariants.first.value;
    });
  }

  @override
  void dispose() {
    _cardNameController.dispose();
    _setNameController.dispose();
    _cardNumberController.dispose();
    _purchasePriceController.dispose();
    _marketPriceController.dispose();
    _askingPriceController.dispose();
    _notesController.dispose();
    _gradeController.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final now  = DateTime.now();
    final item = InventoryItem(
      id:             widget.existingItem?.id ?? _uuid.v4(),
      cardId:         widget.existingItem?.cardId ?? _uuid.v4(),
      cardName:       _cardNameController.text.trim(),
      game:           _selectedGame,
      setName:        _setNameController.text.trim(),
      cardNumber:     _cardNumberController.text.trim(),
      finish:         _finish,
      condition:      _condition,
      language:       _language,
      isGraded:       _isGraded,
      gradingCompany: _isGraded ? _gradingCompany : null,
      grade:          _isGraded && _gradeController.text.isNotEmpty
                        ? _gradeController.text.trim()
                        : null,
      quantity:       _quantity,
      purchasePrice:  double.tryParse(_purchasePriceController.text),
      marketPrice:    double.tryParse(_marketPriceController.text),
      askingPrice:    double.tryParse(_askingPriceController.text),
      notes:          _notesController.text.trim().isEmpty
                        ? null
                        : _notesController.text.trim(),
      acquiredDate:   _acquiredDate,
      createdAt:      widget.existingItem?.createdAt ?? now,
    );

    Navigator.pop(context, item);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(widget.isEditing
          ? '${item.cardName} updated'
          : '${item.cardName} added to inventory'),
      backgroundColor: AppColors.success,
    ));
  }

  Future<void> _openScanner() async {
    final result = await Navigator.push<ScanResult>(
      context,
      MaterialPageRoute(builder: (_) => const CardRecognitionScreen()),
    );

    if (result == null || result.isManualEntry) return;

    if (result.hasCardData) {
      final card = result.cardData!;

      // Validate finish is legal for the identified game before setting
      final gameForCard = card.game.isNotEmpty ? card.game : _selectedGame;
      final validFinishes = CardVariants.forGame(gameForCard);
      final finishValid = card.finish != null &&
          validFinishes.any((v) => v.value == card.finish);

      setState(() {
        // Identity
        _cardNameController.text   = card.cardName;
        _setNameController.text    = card.setName;
        _cardNumberController.text = card.cardNumber;
        if (card.game.isNotEmpty) _selectedGame = card.game;
        if (finishValid) _finish = card.finish!;

        // Condition — AI estimates this from the card surface image
        if (card.condition != null &&
            _conditions.contains(card.condition)) {
          _condition = card.condition!;
        }

        // Grading — if it's a slab the AI reads the label
        if (card.isGraded == true) {
          _isGraded = true;
          if (card.gradingCompany != null)
            _gradingCompany = card.gradingCompany!;
          if (card.grade != null)
            _gradeController.text = card.grade!;
        }

        // Pricing
        if (card.marketPrice != null)
          _marketPriceController.text =
              card.marketPrice!.toStringAsFixed(2);
      });

      // Show confidence level so vendor knows how much to trust the result
      final pct = card.confidence != null
          ? ' (${(card.confidence! * 100).toStringAsFixed(0)}% confident)'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${card.cardName} identified$pct — review details below'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 4),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Card not recognised — fill in the details manually'),
        backgroundColor: AppColors.warning,
      ));
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _acquiredDate,
      firstDate:   DateTime(2000),
      lastDate:    DateTime.now(),
    );
    if (picked != null) setState(() => _acquiredDate = picked);
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title:   const Text('Remove Card'),
        content: Text('Remove ${widget.existingItem!.cardName} from inventory? '
            'This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, 'deleted');
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _suggestAskingPrice() {
    final market = double.tryParse(_marketPriceController.text);
    if (market != null && market > 0) {
      _askingPriceController.text = (market * 1.05).toStringAsFixed(2);
      setState(() {});
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final variants   = _variants;

    // Make sure current finish value is valid for this game
    final finishValid = variants.any((v) => v.value == _finish);
    if (!finishValid) _finish = variants.first.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Card' : 'Add Card'),
        actions: [
          // Scan button — only shown in Add mode
          if (!widget.isEditing)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scan card to auto-fill',
              onPressed: _openScanner,
            ),
          TextButton(
            onPressed: _save,
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

            // Scan CTA — shown in Add mode at top of form
            if (!widget.isEditing) ...[
              _ScanBanner(onTap: _openScanner),
              const SizedBox(height: 24),
            ],

            // ── Card Identity ─────────────────────────────────────────────
            const _SectionLabel('Card Identity'),
            const SizedBox(height: 12),

            _FieldLabel('Game'),
            const SizedBox(height: 6),
            _GameSelector(
              selected:  _selectedGame,
              onChanged: _onGameChanged,
            ),

            const SizedBox(height: 16),

            _FieldLabel('Card Name'),
            const SizedBox(height: 6),
            TextFormField(
              controller:            _cardNameController,
              autofocus:             !widget.isEditing,
              textCapitalization:    TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Charizard, Black Lotus, Connor McDavid...',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Card name is required'
                  : null,
            ),

            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel('Set / Series'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller:         _setNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Base Set, Alpha...',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel('Card #'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _cardNumberController,
                        decoration:
                            const InputDecoration(hintText: 'e.g. 4/102'),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── Condition & Attributes ────────────────────────────────────
            const _SectionLabel('Condition & Attributes'),
            const SizedBox(height: 12),

            _FieldLabel('Condition'),
            const SizedBox(height: 8),
            _SegmentedPicker(
              options:   _conditions,
              selected:  _condition,
              onChanged: (v) => setState(() => _condition = v),
              colorForOption: (opt) {
                switch (opt) {
                  case 'NM':  return AppColors.success;
                  case 'LP':  return AppColors.accent;
                  case 'MP':  return AppColors.warning;
                  case 'HP':  return Colors.orange;
                  case 'DMG': return AppColors.danger;
                  default:    return AppColors.textSecondary;
                }
              },
            ),

            const SizedBox(height: 20),

            // Finish — game-specific, with label showing current game
            Row(
              children: [
                _FieldLabel('Finish / Variant'),
                const Spacer(),
                Text(
                  _selectedGame,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: variants.map((v) {
                final selected = _finish == v.value;
                return _ChoiceChip(
                  label:    v.label,
                  selected: selected,
                  onTap:    () => setState(() => _finish = v.value),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            _FieldLabel('Language'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value:       _language,
              decoration:  const InputDecoration(),
              items: _languages
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (v) => setState(() => _language = v!),
            ),

            const SizedBox(height: 28),

            // ── Grading ───────────────────────────────────────────────────
            const _SectionLabel('Grading'),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color:        AppColors.darkSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title:    const Text('This card is graded',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('PSA, BGS, SGC, etc.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                value:       _isGraded,
                activeColor: AppColors.accent,
                onChanged:   (v) => setState(() => _isGraded = v),
              ),
            ),

            if (_isGraded) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel('Grading Company'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value:      _gradingCompany,
                          decoration: const InputDecoration(),
                          items: _gradingCompanies
                              .map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _gradingCompany = v!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel('Grade'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _gradeController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: const InputDecoration(
                              hintText: 'e.g. 9, 9.5'),
                          validator: (v) =>
                              (_isGraded && (v == null || v.trim().isEmpty))
                                  ? 'Required'
                                  : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 28),

            // ── Quantity ──────────────────────────────────────────────────
            const _SectionLabel('Quantity'),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color:        AppColors.darkSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text('Copies in inventory',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon:  const Icon(Icons.remove_circle_outline),
                    color: _quantity > 1
                        ? AppColors.accent
                        : AppColors.textSecondary,
                    onPressed:
                        _quantity > 1 ? () => setState(() => _quantity--) : null,
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '$_quantity',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon:      const Icon(Icons.add_circle_outline),
                    color:     AppColors.accent,
                    onPressed: () => setState(() => _quantity++),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Pricing ───────────────────────────────────────────────────
            const _SectionLabel('Pricing'),
            const SizedBox(height: 12),

            _FieldLabel('Purchase Price  (what you paid)'),
            const SizedBox(height: 6),
            TextFormField(
              controller:    _purchasePriceController,
              keyboardType:  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
              ],
              decoration:    const InputDecoration(prefixText: '\$ '),
              onChanged:     (_) => setState(() {}),
            ),

            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel('Market Price'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller:  _marketPriceController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'))
                        ],
                        decoration:  const InputDecoration(prefixText: '\$ '),
                        onChanged:   (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _FieldLabel('Asking Price'),
                          const Spacer(),
                          if (_marketPriceController.text.isNotEmpty)
                            GestureDetector(
                              onTap: _suggestAskingPrice,
                              child: const Text(
                                'Suggest',
                                style: TextStyle(
                                  color:      AppColors.accent,
                                  fontSize:   11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller:  _askingPriceController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'))
                        ],
                        decoration:  const InputDecoration(prefixText: '\$ '),
                        onChanged:   (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (_purchasePriceController.text.isNotEmpty &&
                _askingPriceController.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ProfitPreview(
                purchase: double.tryParse(_purchasePriceController.text),
                asking:   double.tryParse(_askingPriceController.text),
                market:   double.tryParse(_marketPriceController.text),
              ),
            ],

            const SizedBox(height: 28),

            // ── Acquisition ───────────────────────────────────────────────
            const _SectionLabel('Acquisition'),
            const SizedBox(height: 12),

            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:        AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(color: AppColors.darkDivider),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Date Acquired',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                        Text(
                          dateFormat.format(_acquiredDate),
                          style:
                              const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Notes ─────────────────────────────────────────────────────
            const _SectionLabel('Notes  (Optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines:   3,
              decoration: const InputDecoration(
                hintText: 'Centering, surface marks, where you got it...',
              ),
            ),

            const SizedBox(height: 40),

            // ── Save ──────────────────────────────────────────────────────
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                padding:         const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
              ),
              child: Text(
                widget.isEditing ? 'Save Changes' : 'Add to Inventory',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),

            if (widget.isEditing) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _confirmDelete,
                style: OutlinedButton.styleFrom(
                  padding:         const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: AppColors.danger,
                  side:            const BorderSide(color: AppColors.danger),
                ),
                child: const Text(
                  'Remove from Inventory',
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
}

// ── Scan Banner ───────────────────────────────────────────────────────────────

class _ScanBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        AppColors.accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: AppColors.accent.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:        AppColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.qr_code_scanner,
                  color: AppColors.accent, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Scan Card to Auto-Fill',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize:   15,
                      color:      AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Point at the barcode or set number — '
                    'name, set, and market price fill automatically.',
                    style: TextStyle(
                      color:    AppColors.accent.withOpacity(0.7),
                      fontSize: 12,
                      height:   1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

// ── Game Selector ─────────────────────────────────────────────────────────────

class _GameSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _GameSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: AppColors.darkDivider),
      ),
      child: ListTile(
        dense: true,
        title: Text(selected,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing:
            const Icon(Icons.expand_more, color: AppColors.textSecondary),
        onTap: () => _showGamePicker(context),
      ),
    );
  }

  void _showGamePicker(BuildContext context) {
    showModalBottomSheet(
      context:           context,
      isScrollControlled: true,
      backgroundColor:   Colors.transparent,
      builder: (_) => _GamePickerSheet(
        selected:   selected,
        onSelected: (g) {
          onChanged(g);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _GamePickerSheet extends StatefulWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _GamePickerSheet(
      {required this.selected, required this.onSelected});

  @override
  State<_GamePickerSheet> createState() => _GamePickerSheetState();
}

class _GamePickerSheetState extends State<_GamePickerSheet> {
  String _search = '';
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize:     0.95,
      minChildSize:     0.5,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color:        Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color:        AppColors.darkDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                onChanged:  (v) => setState(() => _search = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText:   'Search games...',
                  prefixIcon: const Icon(Icons.search,
                      color: AppColors.textSecondary, size: 20),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon:      const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _search = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                children:
                    AppConfig.supportedCategories.entries.expand((entry) {
                  final games = entry.value
                      .where((g) =>
                          g.isNotEmpty &&
                          (_search.isEmpty ||
                              g.toLowerCase().contains(_search)))
                      .toList();
                  if (games.isEmpty) return <Widget>[];
                  return [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        entry.key.toUpperCase(),
                        style: const TextStyle(
                          fontSize:   10,
                          fontWeight: FontWeight.w800,
                          color:      AppColors.accent,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    ...games.map((game) => ListTile(
                          dense: true,
                          title: Text(game),
                          trailing: game == widget.selected
                              ? const Icon(Icons.check,
                                  color: AppColors.accent)
                              : null,
                          tileColor: game == widget.selected
                              ? AppColors.accent.withOpacity(0.08)
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          onTap: () => widget.onSelected(game),
                        )),
                  ];
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profit Preview ────────────────────────────────────────────────────────────

class _ProfitPreview extends StatelessWidget {
  final double? purchase;
  final double? asking;
  final double? market;

  const _ProfitPreview({this.purchase, this.asking, this.market});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    if (purchase == null || asking == null) return const SizedBox.shrink();

    final margin    = asking! - purchase!;
    final marginPct = purchase! > 0 ? (margin / purchase!) * 100 : 0.0;
    final vsMarket  = (market != null && market! > 0)
        ? ((asking! - market!) / market!) * 100
        : null;
    final color     = margin >= 0 ? AppColors.success : AppColors.danger;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(
            margin >= 0 ? Icons.trending_up : Icons.trending_down,
            color: color, size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  margin >= 0
                      ? 'Profit: ${currency.format(margin)} '
                        '(${marginPct.toStringAsFixed(1)}% ROI)'
                      : 'Loss: ${currency.format(margin.abs())}',
                  style: TextStyle(
                    color:      color,
                    fontWeight: FontWeight.w700,
                    fontSize:   13,
                  ),
                ),
                if (vsMarket != null)
                  Text(
                    vsMarket >= 0
                        ? '${vsMarket.toStringAsFixed(1)}% above market'
                        : '${vsMarket.abs().toStringAsFixed(1)}% below market',
                    style: const TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize:      11,
            fontWeight:    FontWeight.w700,
            color:         AppColors.accent,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize:   13,
        fontWeight: FontWeight.w600,
        color:      AppColors.textSecondary,
      ),
    );
  }
}

class _SegmentedPicker extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  final Color Function(String) colorForOption;

  const _SegmentedPicker({
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.colorForOption,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((opt) {
        final sel   = selected == opt;
        final color = colorForOption(opt);
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(opt),
            child: Container(
              margin: EdgeInsets.only(
                  right: opt == options.last ? 0 : 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color:        sel ? color.withOpacity(0.15) : AppColors.darkSurfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border:       Border.all(color: sel ? color : Colors.transparent),
              ),
              child: Text(
                opt,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:      sel ? color : AppColors.textSecondary,
                  fontWeight: sel ? FontWeight.w800 : FontWeight.normal,
                  fontSize:   13,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:        selected
              ? AppColors.accent.withOpacity(0.15)
              : AppColors.darkSurfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(
            color: selected ? AppColors.accent : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:      selected ? AppColors.accent : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            fontSize:   13,
          ),
        ),
      ),
    );
  }
}
