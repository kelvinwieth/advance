import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/app_database.dart';
import '../../data/models.dart';
import '../widgets/app_dialog.dart';

class FichaFormScreen extends StatefulWidget {
  final AppDatabase database;
  final VisitForm? existing;

  const FichaFormScreen({
    super.key,
    required this.database,
    this.existing,
  });

  @override
  State<FichaFormScreen> createState() => _FichaFormScreenState();
}

class _FichaFormScreenState extends State<FichaFormScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');

  late DateTime _visitAt;
  late TextEditingController _namesController;
  late TextEditingController _addressController;
  late TextEditingController _referenceController;
  late TextEditingController _neighborhoodController;
  late TextEditingController _cityController;
  late TextEditingController _contactsController;
  late TextEditingController _literatureController;
  late TextEditingController _notesController;
  late TextEditingController _prayerController;
  late TextEditingController _teamController;

  late TextEditingController _ageChildrenController;
  late TextEditingController _ageYouthController;
  late TextEditingController _ageAdultsController;
  late TextEditingController _ageElderlyController;

  bool _religionCatolica = false;
  bool _religionEspirita = false;
  bool _religionAteu = false;
  bool _religionDesviado = false;
  bool _religionOutros = false;

  bool _resultEvangelho = false;
  bool _resultPonteSalvacao = false;
  bool _resultAceitouJesus = false;
  bool _resultReconciliacao = false;
  bool _resultPrimeiraVez = false;
  bool _resultNovaVisita = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _visitAt = existing?.visitAt ?? DateTime.now();
    _namesController = TextEditingController(text: existing?.names ?? '');
    _addressController = TextEditingController(text: existing?.address ?? '');
    _referenceController = TextEditingController(
      text: existing?.referencePoint ?? '',
    );
    _neighborhoodController = TextEditingController(
      text: existing?.neighborhood ?? '',
    );
    _cityController = TextEditingController(
      text: existing?.city ?? 'Itaporanga',
    );
    _contactsController = TextEditingController(text: existing?.contacts ?? '');
    _literatureController = TextEditingController(
      text: (existing?.literatureCount ?? 0).toString(),
    );
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _prayerController = TextEditingController(
      text: existing?.prayerRequests ?? '',
    );
    _teamController = TextEditingController(text: existing?.team ?? '');

    _ageChildrenController = TextEditingController(
      text: (existing?.ageChildren ?? 0).toString(),
    );
    _ageYouthController = TextEditingController(
      text: (existing?.ageYouth ?? 0).toString(),
    );
    _ageAdultsController = TextEditingController(
      text: (existing?.ageAdults ?? 0).toString(),
    );
    _ageElderlyController = TextEditingController(
      text: (existing?.ageElderly ?? 0).toString(),
    );

    _religionCatolica = existing?.religionCatolica ?? false;
    _religionEspirita = existing?.religionEspirita ?? false;
    _religionAteu = existing?.religionAteu ?? false;
    _religionDesviado = existing?.religionDesviado ?? false;
    _religionOutros = existing?.religionOutros ?? false;

    _resultEvangelho = existing?.resultEvangelho ?? false;
    _resultPonteSalvacao = existing?.resultPonteSalvacao ?? false;
    _resultAceitouJesus = existing?.resultAceitouJesus ?? false;
    _resultReconciliacao = existing?.resultReconciliacao ?? false;
    _resultPrimeiraVez = existing?.resultPrimeiraVez ?? false;
    _resultNovaVisita = existing?.resultNovaVisita ?? false;
  }

  @override
  void dispose() {
    _namesController.dispose();
    _addressController.dispose();
    _referenceController.dispose();
    _neighborhoodController.dispose();
    _cityController.dispose();
    _contactsController.dispose();
    _literatureController.dispose();
    _notesController.dispose();
    _prayerController.dispose();
    _teamController.dispose();
    _ageChildrenController.dispose();
    _ageYouthController.dispose();
    _ageAdultsController.dispose();
    _ageElderlyController.dispose();
    super.dispose();
  }

  int _parseInt(TextEditingController controller) {
    final value = int.tryParse(controller.text.trim());
    if (value == null || value < 0) return 0;
    return value;
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _visitAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    final ctx = context;
    if (!ctx.mounted) return;
    final time = await showTimePicker(
      context: ctx,
      initialTime: TimeOfDay.fromDateTime(_visitAt),
    );
    if (time == null) return;
    setState(() {
      _visitAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _saveForm() {
    setState(() {
      _errorMessage = null;
    });

    final ageChildren = _parseInt(_ageChildrenController);
    final ageYouth = _parseInt(_ageYouthController);
    final ageAdults = _parseInt(_ageAdultsController);
    final ageElderly = _parseInt(_ageElderlyController);
    final totalPeople = ageChildren + ageYouth + ageAdults + ageElderly;

    if (!(_resultEvangelho ||
        _resultPonteSalvacao ||
        _resultAceitouJesus ||
        _resultReconciliacao ||
        _resultPrimeiraVez ||
        _resultNovaVisita)) {
      setState(() {
        _errorMessage = 'Selecione ao menos um resultado da visita.';
      });
      return;
    }

    if (totalPeople == 0) {
      setState(() {
        _errorMessage = 'Informe ao menos uma faixa etária.';
      });
      return;
    }

    if (_teamController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Informe a equipe que realizou a visita.';
      });
      return;
    }

    try {
      if (widget.existing == null) {
        widget.database.insertVisitForm(
          visitAt: _visitAt,
          names: _namesController.text.trim(),
          address: _addressController.text.trim(),
          referencePoint: _referenceController.text.trim(),
          neighborhood: _neighborhoodController.text.trim(),
          city: _cityController.text.trim(),
          contacts: _contactsController.text.trim(),
          literatureCount: _parseInt(_literatureController),
          resultEvangelho: _resultEvangelho,
          resultPonteSalvacao: _resultPonteSalvacao,
          resultAceitouJesus: _resultAceitouJesus,
          resultReconciliacao: _resultReconciliacao,
          resultPrimeiraVez: _resultPrimeiraVez,
          resultNovaVisita: _resultNovaVisita,
          ageChildren: ageChildren,
          ageYouth: ageYouth,
          ageAdults: ageAdults,
          ageElderly: ageElderly,
          religionCatolica: _religionCatolica,
          religionEspirita: _religionEspirita,
          religionAteu: _religionAteu,
          religionDesviado: _religionDesviado,
          religionOutros: _religionOutros,
          notes: _notesController.text.trim(),
          prayerRequests: _prayerController.text.trim(),
          team: _teamController.text.trim(),
        );
      } else {
        widget.database.updateVisitForm(
          id: widget.existing!.id,
          visitAt: _visitAt,
          names: _namesController.text.trim(),
          address: _addressController.text.trim(),
          referencePoint: _referenceController.text.trim(),
          neighborhood: _neighborhoodController.text.trim(),
          city: _cityController.text.trim(),
          contacts: _contactsController.text.trim(),
          literatureCount: _parseInt(_literatureController),
          resultEvangelho: _resultEvangelho,
          resultPonteSalvacao: _resultPonteSalvacao,
          resultAceitouJesus: _resultAceitouJesus,
          resultReconciliacao: _resultReconciliacao,
          resultPrimeiraVez: _resultPrimeiraVez,
          resultNovaVisita: _resultNovaVisita,
          ageChildren: ageChildren,
          ageYouth: ageYouth,
          ageAdults: ageAdults,
          ageElderly: ageElderly,
          religionCatolica: _religionCatolica,
          religionEspirita: _religionEspirita,
          religionAteu: _religionAteu,
          religionDesviado: _religionDesviado,
          religionOutros: _religionOutros,
          notes: _notesController.text.trim(),
          prayerRequests: _prayerController.text.trim(),
          team: _teamController.text.trim(),
        );
      }
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _errorMessage = 'Falha ao salvar a ficha.';
      });
    }
  }

  Future<bool> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AppDialog(
          title: 'Excluir ficha',
          onClose: () => Navigator.of(dialogContext).pop(false),
          actions: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                style: AppDialog.outlinedStyle(),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: AppDialog.destructiveStyle(),
                child: const Text('Excluir ficha'),
              ),
            ),
          ],
          child: const Text(
            'Esta ação vai remover a ficha definitivamente. '
            'Deseja continuar?',
          ),
        );
      },
    );

    return confirmed ?? false;
  }

  Widget _buildSectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E8EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(title, subtitle: subtitle),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: hint,
        filled: true,
        fillColor: AppDialog.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildCounterField(TextEditingController controller) {
    void updateValue(int delta) {
      final current = int.tryParse(controller.text.trim()) ?? 0;
      final next = (current + delta).clamp(0, 9999);
      controller.text = next.toString();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppDialog.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => updateValue(-1),
            icon: const Icon(Icons.remove),
            tooltip: 'Diminuir',
          ),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null && parsed < 0) {
                  controller.text = '0';
                }
              },
            ),
          ),
          IconButton(
            onPressed: () => updateValue(1),
            icon: const Icon(Icons.add),
            tooltip: 'Aumentar',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/acev.png',
              height: 26,
            ),
            const SizedBox(width: 10),
            Text(isEditing ? 'Editar ficha' : 'Nova ficha'),
          ],
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE6E8EF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionCard(
                  title: 'Dados da visita',
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _namesController,
                        hint: 'Nomes (separados por vírgula)',
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _addressController,
                        hint: 'Endereço',
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _referenceController,
                        hint: 'Ponto de referência',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _neighborhoodController,
                              hint: 'Bairro',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _cityController,
                              hint: 'Cidade',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _contactsController,
                        hint: 'Contatos (separados por vírgula)',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.maxFinite,
                  child: _buildSectionCard(
                    title: 'Resultados da visita',
                    subtitle: 'Selecione tudo o que aconteceu na visita.',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _ResultChip(
                          label: 'Gráfico apresentado',
                          selected: _resultEvangelho,
                          onChanged: (value) =>
                              setState(() => _resultEvangelho = value),
                        ),
                        _ResultChip(
                          label: 'Ponte da Salvação apresentada',
                          selected: _resultPonteSalvacao,
                          onChanged: (value) => setState(
                            () => _resultPonteSalvacao = value,
                          ),
                        ),
                        _ResultChip(
                          label: 'Decisão',
                          selected: _resultAceitouJesus,
                          onChanged: (value) =>
                              setState(() => _resultAceitouJesus = value),
                        ),
                        _ResultChip(
                          label: 'Reconciliação',
                          selected: _resultReconciliacao,
                          onChanged: (value) =>
                              setState(() => _resultReconciliacao = value),
                        ),
                        _ResultChip(
                          label: 'Primeira vez que ouviu falar do Evangelho',
                          selected: _resultPrimeiraVez,
                          onChanged: (value) =>
                              setState(() => _resultPrimeiraVez = value),
                        ),
                        _ResultChip(
                          label: 'Deseja nova visita',
                          selected: _resultNovaVisita,
                          onChanged: (value) =>
                              setState(() => _resultNovaVisita = value),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildSectionCard(
                        title: 'Literaturas',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Quantidade distribuída'),
                            const SizedBox(height: 6),
                            _buildCounterField(_literatureController),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: _buildSectionCard(
                        title: 'Faixa etária',
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Crianças'),
                                  const SizedBox(height: 6),
                                  _buildCounterField(_ageChildrenController),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Jovens'),
                                  const SizedBox(height: 6),
                                  _buildCounterField(_ageYouthController),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Adultos'),
                                  const SizedBox(height: 6),
                                  _buildCounterField(_ageAdultsController),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Idosos'),
                                  const SizedBox(height: 6),
                                  _buildCounterField(_ageElderlyController),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: 'Religião',
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      _ReligionChip(
                        label: 'Católica',
                        selected: _religionCatolica,
                        onChanged: (value) =>
                            setState(() => _religionCatolica = value),
                      ),
                      _ReligionChip(
                        label: 'Espírita',
                        selected: _religionEspirita,
                        onChanged: (value) =>
                            setState(() => _religionEspirita = value),
                      ),
                      _ReligionChip(
                        label: 'Ateu',
                        selected: _religionAteu,
                        onChanged: (value) =>
                            setState(() => _religionAteu = value),
                      ),
                      _ReligionChip(
                        label: 'Desviado',
                        selected: _religionDesviado,
                        onChanged: (value) =>
                            setState(() => _religionDesviado = value),
                      ),
                      _ReligionChip(
                        label: 'Outros',
                        selected: _religionOutros,
                        onChanged: (value) =>
                            setState(() => _religionOutros = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: 'Campos livres',
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _notesController,
                        hint: 'Observações da visita',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _prayerController,
                        hint: 'Pedidos de oração',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _teamController,
                        hint: 'Equipe (nomes separados por vírgula)',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: 'Data e hora da visita',
                  child: InkWell(
                    onTap: _pickDateTime,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppDialog.inputFill,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text(_dateFormat.format(_visitAt)),
                          const Spacer(),
                          const Icon(Icons.edit_calendar_outlined, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (isEditing) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final confirm = await _confirmDelete();
                            if (!confirm) return;
                            try {
                              widget.database.deleteVisitForm(
                                widget.existing!.id,
                              );
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                            } catch (e) {
                              setState(() {
                                _errorMessage = 'Falha ao excluir a ficha.';
                              });
                            }
                          },
                          style: AppDialog.destructiveStyle(),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Excluir'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveForm,
                        style: AppDialog.primaryStyle(),
                        child: const Text('Salvar ficha'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _ResultChip({
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onChanged,
      backgroundColor: const Color(0xFFF1F2F6),
      selectedColor: const Color(0xFFE1F2F4),
      checkmarkColor: const Color(0xFF038A99),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF1D1D1D) : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? const Color(0xFF8CC9CE) : Colors.transparent,
        ),
      ),
    );
  }
}

class _ReligionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _ReligionChip({
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!selected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE1F2F4) : const Color(0xFFF1F2F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF8CC9CE) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: selected,
              onChanged: (value) => onChanged(value ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              activeColor: const Color(0xFF038A99),
            ),
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF1D1D1D) : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
