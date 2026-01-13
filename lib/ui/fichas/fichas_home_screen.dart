import 'dart:io';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/app_database.dart';
import '../../data/models.dart';
import '../widgets/app_dialog.dart';
import 'ficha_analytics_screen.dart';
import 'ficha_form_screen.dart';
import 'prayer_requests_screen.dart';

// Imports necessários (provavelmente já estão no seu arquivo)
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_selector/file_selector.dart'; // Para desktop
// import 'package:open_file/open_file.dart'; // Assumindo que você tem o _openFile implementado

class FichasHomeScreen extends StatefulWidget {
  final AppDatabase database;

  const FichasHomeScreen({super.key, required this.database});

  @override
  State<FichasHomeScreen> createState() => _FichasHomeScreenState();
}

class _FichasHomeScreenState extends State<FichasHomeScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  final DateFormat _filterDateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  String? _errorMessage;
  List<VisitForm> _forms = [];
  bool _filterNovaVisita = false;
  bool _filterBible = false;
  DateTime? _filterDate;
  bool _orderAsc = false;
  Map<String, String> _lastHeaderMapping = {};
  List<VisitForm> _filteredVisits = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadHeaderMapping();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<File> _mappingFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}csv_header_mapping.json');
  }

  Future<void> _loadHeaderMapping() async {
    try {
      final file = await _mappingFile();
      if (!file.existsSync()) return;
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _lastHeaderMapping = data.map(
          (key, value) => MapEntry(key, value.toString()),
        );
      });
    } catch (_) {}
  }

  Future<void> _saveHeaderMapping(Map<String, String> mapping) async {
    try {
      final file = await _mappingFile();
      await file.writeAsString(jsonEncode(mapping));
      if (!mounted) return;
      setState(() {
        _lastHeaderMapping = Map<String, String>.from(mapping);
      });
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final forms = widget.database.fetchVisitForms();
      if (!mounted) return;
      setState(() {
        _forms = forms;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Falha ao carregar as fichas.';
        _loading = false;
      });
    }
  }

  Future<void> _openForm({VisitForm? existing}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FichaFormScreen(
          database: widget.database,
          existing: existing,
        ),
      ),
    );
    _loadData();
  }

  Future<void> _pickFilterDate() async {
    final now = DateTime.now();
    final initial = _filterDate ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    setState(() {
      _filterDate = DateTime(date.year, date.month, date.day);
    });
  }

  List<String> _parseCsvHeader(String input) {
    final buffer = StringBuffer();
    final row = <String>[];
    var inQuotes = false;
    var i = 0;

    while (i < input.length) {
      final char = input[i];
      if (char == '"') {
        final nextChar = i + 1 < input.length ? input[i + 1] : null;
        if (inQuotes && nextChar == '"') {
          buffer.write('"');
          i += 2;
          continue;
        }
        inQuotes = !inQuotes;
        i++;
        continue;
      }

      if (char == ',' && !inQuotes) {
        row.add(buffer.toString().trim());
        buffer.clear();
        i++;
        continue;
      }

      if ((char == '\n' || char == '\r') && !inQuotes) {
        row.add(buffer.toString().trim());
        return row;
      }

      buffer.write(char);
      i++;
    }

    if (buffer.isNotEmpty || row.isNotEmpty) {
      row.add(buffer.toString().trim());
    }
    return row;
  }

  String _normalizeHeader(String value) {
    var result = value.trim().toLowerCase();
    const replacements = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'é': 'e',
      'ê': 'e',
      'í': 'i',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ç': 'c',
    };
    replacements.forEach((key, replacement) {
      result = result.replaceAll(key, replacement);
    });
    return result.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Future<Map<String, String>?> _askCsvHeaderMapping([
    List<String> headers = const [],
  ]) async {
    final availableHeaders = headers.where((h) => h.isNotEmpty).toList();
    final headerLookup = <String, String>{
      for (final header in availableHeaders) _normalizeHeader(header): header,
    };

    final fields = [
      const _CsvField('carimbodedatahora', 'Carimbo de data/hora'),
      const _CsvField('literaturasdistribuidas', 'Literaturas distribuídas'),
      const _CsvField('nomes', 'Nomes'),
      const _CsvField('endereco', 'Endereço'),
      const _CsvField('pontodereferencia', 'Ponto de referência'),
      const _CsvField('bairro', 'Bairro'),
      const _CsvField('cidade', 'Cidade'),
      const _CsvField('contatos', 'Contatos'),
      const _CsvField('resultadosdavisita', 'Resultados da visita'),
      const _CsvField('crianca', 'Criança'),
      const _CsvField('jovem', 'Jovem'),
      const _CsvField('adulto', 'Adulto'),
      const _CsvField('terceiraidade', 'Terceira idade'),
      const _CsvField('religiao', 'Religião'),
      const _CsvField('observacoesdavista', 'Observações da visita'),
      const _CsvField('pedidosdeoracao', 'Pedidos de oração'),
      const _CsvField('equipe', 'Equipe'),
      const _CsvField('datadaficha', 'Data da ficha'),
      const _CsvField('horario', 'Horário'),
    ];

    final controllers = <String, TextEditingController>{};
    for (final field in fields) {
      final suggestion =
          _lastHeaderMapping[field.key] ??
          headerLookup[field.key] ??
          field.label;
      controllers[field.key] = TextEditingController(text: suggestion);
    }

    String? errorText;
    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AppDialog(
              width: 800,
              title: 'Mapear colunas do CSV',
              onClose: () => Navigator.of(dialogContext).pop(),
              actions: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: AppDialog.outlinedStyle(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final mapped = controllers.map(
                        (key, controller) =>
                            MapEntry(key, controller.text.trim()),
                      );
                      final hasLiterature =
                          mapped['literaturasdistribuidas']?.isNotEmpty ??
                          false;
                      final hasTeam = mapped['equipe']?.isNotEmpty ?? false;
                      final hasDate =
                          (mapped['datadaficha']?.isNotEmpty ?? false) ||
                          (mapped['carimbodedatahora']?.isNotEmpty ?? false);
                      if (!hasLiterature || !hasTeam || !hasDate) {
                        setDialogState(() {
                          errorText =
                              'Literaturas distribuídas, equipe e data são obrigatórios.';
                        });
                        return;
                      }
                      Navigator.of(dialogContext).pop(mapped);
                    },
                    style: AppDialog.primaryStyle(),
                    child: const Text('Confirmar'),
                  ),
                ),
              ],
              child: SizedBox(
                width: 1120,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Digite como estão os nomes das colunas do seu CSV.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE6E8EF)),
                      ),
                      child: Row(
                        children: const [
                          Expanded(
                            child: Text(
                              'Campo esperado',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Coluna do CSV',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 520,
                      child: ListView.separated(
                        itemCount: fields.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final field = fields[index];
                          final controller = controllers[field.key]!;
                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  field.label,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: controller,
                                  decoration: InputDecoration(
                                    hintText: 'Nome no CSV',
                                    filled: true,
                                    fillColor: const Color(0xFFF1F2F6),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    for (final controller in controllers.values) {
      controller.dispose();
    }

    return result;
  }

  Future<void> _importCsv() async {
    final ctx = context;
    if (!ctx.mounted) return;
    final mapping = await _askCsvHeaderMapping();
    if (mapping == null) return;
    await _saveHeaderMapping(mapping);

    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'CSV', extensions: ['csv']),
      ],
    );
    if (file == null) return;

    final confirmed = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AppDialog(
          title: 'Importar fichas',
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
              child: ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: AppDialog.primaryStyle(),
                child: const Text('Importar'),
              ),
            ),
          ],
          child: const Text(
            'As fichas do CSV serão adicionadas ao banco atual.',
          ),
        );
      },
    );
    if (confirmed != true) return;

    if (!ctx.mounted) return;
    showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final csvContent = await File(file.path).readAsString();
      if (!mounted) return;
      Navigator.of(context).pop();
      final headers = _parseCsvHeader(csvContent);
      final headerLookup = {
        for (final header in headers) _normalizeHeader(header): header,
      };
      final missing = <String>[];
      mapping.forEach((key, value) {
        if (value.trim().isEmpty) return;
        final normalized = _normalizeHeader(value);
        if (!headerLookup.containsKey(normalized)) {
          missing.add(value);
        }
      });
      if (missing.isNotEmpty) {
        await showDialog<void>(
          context: ctx,
          builder: (dialogContext) {
            return AppDialog(
              title: 'Colunas não encontradas',
              onClose: () => Navigator.of(dialogContext).pop(),
              actions: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: AppDialog.primaryStyle(),
                    child: const Text('Entendi'),
                  ),
                ),
              ],
              child: Text(
                'Estas colunas não existem no CSV selecionado:\n'
                '${missing.join(', ')}\n\n'
                'Revise o mapeamento e tente novamente.',
              ),
            );
          },
        );
        return;
      }
      showDialog<void>(
        context: ctx,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final result = await widget.database.importVisitFormsFromCsv(
        csvContent,
        headerOverrides: mapping,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Importadas ${result.inserted} fichas. '
            '${result.skipped} ignoradas.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao importar o CSV.')),
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openFile(String path) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (_) {
      // Keep silent; user still has the path in the snackbar.
    }
  }

  Future<void> _exportVisitsPdf() async {
    // 1. Validação inicial (assumindo que sua lista filtrada se chama _filteredVisits)
    // Se a variável for outra, apenas troque o nome aqui.
    if (_filteredVisits.isEmpty) {
      _showMessage('Nenhuma visita listada para exportar.');
      return;
    }

    // 2. Configuração do Tema e Fonte
    final theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    );
    final pdf = pw.Document(theme: theme);

    // 3. Cabeçalho do Relatório
    final header = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ACEV - Relatório de Visitas',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Exportação detalhada dos dados missionários',
          style: pw.TextStyle(
            fontSize: 14,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Gerado em: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 12),
        ),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 10),
      ],
    );

    // 4. Função auxiliar para formatar booleanos em texto legível
    String formatBooleans(List<MapEntry<String, bool>> items) {
      final active = items.where((e) => e.value).map((e) => e.key).toList();
      return active.isEmpty ? '-' : active.join(', ');
    }

    // 5. Construção do PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4, // Retrato é melhor para listas detalhadas
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            header,
            ..._filteredVisits.map((visit) {
              // Prepara os dados de Resultados
              final resultsStr = formatBooleans([
                MapEntry('Evangelho', visit.resultEvangelho),
                MapEntry('Ponte', visit.resultPonteSalvacao),
                MapEntry('Aceitou Jesus', visit.resultAceitouJesus),
                MapEntry('Reconciliação', visit.resultReconciliacao),
                MapEntry('1ª Vez', visit.resultPrimeiraVez),
                MapEntry('Nova Visita', visit.resultNovaVisita),
              ]);

              // Prepara os dados de Religião
              final religionStr = formatBooleans([
                MapEntry('Católica', visit.religionCatolica),
                MapEntry('Espírita', visit.religionEspirita),
                MapEntry('Ateu', visit.religionAteu),
                MapEntry('Desviado', visit.religionDesviado),
                MapEntry('Outros', visit.religionOutros),
              ]);

              // Layout de "Cartão" para cada visita
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 1),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                  color: PdfColors.grey50,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Linha 1: ID, Data e Equipe
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          '#${visit.id} - ${DateFormat('dd/MM/yyyy HH:mm').format(visit.visitAt)}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        pw.Text(
                          'Equipe: ${visit.team}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                            color: PdfColors.blue800,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),

                    // Linha 2: Nome e Endereço (Destaque)
                    pw.Text(
                      visit.names.toUpperCase(),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    pw.Text(
                      '${visit.address} - ${visit.neighborhood}, ${visit.city}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    if (visit.referencePoint.isNotEmpty)
                      pw.Text(
                        'Ref: ${visit.referencePoint}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.grey700,
                        ),
                      ),

                    pw.SizedBox(height: 6),
                    pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                    pw.SizedBox(height: 6),

                    // Linha 3: Tabela Interna de Dados (Estatísticas e Resultados)
                    pw.Table(
                      children: [
                        pw.TableRow(
                          children: [
                            _buildInfoColumn(
                              'Faixas Etárias:',
                              'Crianças: ${visit.ageChildren} · Jovens: ${visit.ageYouth} · Adultos: ${visit.ageAdults} · Idosos: ${visit.ageElderly}',
                            ),
                            _buildInfoColumn('Contatos:', visit.contacts),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(top: 4),
                              child: _buildInfoColumn(
                                'Resultados:',
                                resultsStr,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(top: 4),
                              child: _buildInfoColumn('Religião:', religionStr),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Linha 4: Notas e Pedidos (se houver)
                    if (visit.notes.isNotEmpty ||
                        visit.prayerRequests.isNotEmpty) ...[
                      pw.SizedBox(height: 8),
                      if (visit.notes.isNotEmpty)
                        pw.Text(
                          'Obs: ${visit.notes}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      if (visit.prayerRequests.isNotEmpty)
                        pw.Text(
                          'Oração: ${visit.prayerRequests}',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red900,
                          ),
                        ),
                    ],
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    // 6. Salvar Arquivo (Lógica do Windows/FileSelector)
    final bytes = await pdf.save();
    final filename =
        'visitas_acev_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

    final saveLocation = await getSaveLocation(
      suggestedName: filename,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PDF', extensions: ['pdf']),
      ],
    );

    if (saveLocation == null) {
      _showMessage('Exportação cancelada.');
      return;
    }

    final file = File(saveLocation.path);
    await file.writeAsBytes(bytes);

    // Assumindo que _openFile é o método que você já usa para abrir o PDF
    await _openFile(file.path);
    _showMessage('PDF salvo em ${file.path}');
  }

  // Pequeno helper para formatar colunas dentro do PDF de forma consistente
  pw.Widget _buildInfoColumn(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey600,
          ),
        ),
        pw.Text(
          value.isEmpty ? '-' : value,
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/acev.png',
              height: 26,
            ),
            const SizedBox(width: 10),
            const Text('Fichas'),
          ],
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE6E8EF)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Fichas registradas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PrayerRequestsScreen(
                                database: widget.database,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.favorite_border),
                          label: const Text('Pedidos de oração'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FichaAnalyticsScreen(
                                database: widget.database,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.insights_outlined),
                          label: const Text('Insights'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _importCsv,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Importar CSV'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _exportVisitsPdf,
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Salvar PDF'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => _openForm(),
                          icon: const Icon(Icons.add),
                          label: const Text('Nova ficha'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText:
                                    'Buscar por nome, bairro, endereço, referência ou equipe',
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: const Color(0xFFF1F2F6),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Tooltip(
                          message: _filterDate == null
                              ? 'Filtrar por data'
                              : 'Remover filtro de data',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _filterDate == null
                                ? _pickFilterDate
                                : () => setState(() {
                                    _filterDate = null;
                                  }),
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F2F6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.event, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    _filterDate == null
                                        ? 'Data'
                                        : _filterDateFormat.format(
                                            _filterDate!,
                                          ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    _filterDate == null
                                        ? Icons.expand_more
                                        : Icons.close,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        Tooltip(
                          message: _orderAsc
                              ? 'Ordenar por data (mais antigas primeiro)'
                              : 'Ordenar por data (mais recentes primeiro)',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                _orderAsc = !_orderAsc;
                              });
                            },
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F2F6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _orderAsc
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              _filterNovaVisita = !_filterNovaVisita;
                            });
                          },
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _filterNovaVisita
                                  ? const Color(0xFFE1F2F4)
                                  : const Color(0xFFF1F2F6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _filterNovaVisita
                                    ? const Color(0xFF8CC9CE)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                if (_filterNovaVisita) ...[
                                  const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Color(0xFF038A99),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  'Deseja nova visita',
                                  style: TextStyle(
                                    color: _filterNovaVisita
                                        ? const Color(0xFF1D1D1D)
                                        : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              _filterBible = !_filterBible;
                            });
                          },
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _filterBible
                                  ? const Color(0xFFE1F2F4)
                                  : const Color(0xFFF1F2F6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _filterBible
                                    ? const Color(0xFF8CC9CE)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                if (_filterBible) ...[
                                  const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Color(0xFF038A99),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  'Deseja Bíblia',
                                  style: TextStyle(
                                    color: _filterBible
                                        ? const Color(0xFF1D1D1D)
                                        : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Tooltip(
                          message: 'Limpar filtros',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                _filterNovaVisita = false;
                                _filterBible = false;
                                _filterDate = null;
                                _orderAsc = false;
                                _searchController.clear();
                              });
                            },
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F2F6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.filter_alt_off_outlined,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _buildFilteredList(),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilteredList() {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _forms.where((form) {
      if (_filterNovaVisita && !form.resultNovaVisita) return false;

      final notes = form.notes.toLowerCase();
      if (_filterBible &&
          !(notes.contains('biblia') || notes.contains('bíblia'))) {
        return false;
      }

      if (_filterDate != null) {
        final visitDate = DateTime(
          form.visitAt.year,
          form.visitAt.month,
          form.visitAt.day,
        );
        if (visitDate != _filterDate) return false;
      }
      if (query.isEmpty) return true;
      return form.names.toLowerCase().contains(query) ||
          form.neighborhood.toLowerCase().contains(query) ||
          form.address.toLowerCase().contains(query) ||
          form.referencePoint.toLowerCase().contains(query) ||
          form.team.toLowerCase().contains(query);
    }).toList();

    filtered.sort(
      (a, b) => _orderAsc
          ? a.visitAt.compareTo(b.visitAt)
          : b.visitAt.compareTo(a.visitAt),
    );

    _filteredVisits = filtered;

    return filtered.isEmpty
        ? const Center(child: Text('Nenhuma ficha encontrada.'))
        : ListView.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final form = filtered[index];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openForm(existing: form),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FBFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE6E8EF),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9F5F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.home_outlined,
                          color: Color(0xFF038A99),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              form.names.isEmpty
                                  ? 'Visita sem nomes'
                                  : form.names,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${form.neighborhood} · ${form.address}${form.referencePoint.isEmpty ? '' : ' · ${form.referencePoint}'}',
                              style: const TextStyle(
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_dateFormat.format(form.visitAt)} · ${form.team.isEmpty ? 'Equipe não informada' : form.team}',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              );
            },
          );
  }
}

class _CsvField {
  final String key;
  final String label;

  const _CsvField(this.key, this.label);
}
