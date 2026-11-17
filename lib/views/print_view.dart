import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../models/escala.dart';
import '../services/api_service.dart';
import '../services/escala_pdf_service.dart';
import '../theme/app_theme.dart';

class PrintView extends StatefulWidget {
  final EscalaMensalModel? escala;
  final int? ano;
  final int? mes;

  const PrintView({
    super.key,
    this.escala,
    this.ano,
    this.mes,
  });

  @override
  State<PrintView> createState() => _PrintViewState();
}

class _PrintViewState extends State<PrintView> {
  EscalaMensalModel? _escala;
  bool _isLoading = false;
  double _zoomLevel = 0.85;
  bool _includeWatermark = true;
  bool _includeBrasao = true;
  bool _includeExpediente = true;
  bool _includeSignatures = true;
  String _selectedPrinter = 'HP LaserJet Enterprise M608 - BINFAE TI (Padrão)';

  final List<String> _printers = [
    'HP LaserJet Enterprise M608 - BINFAE TI (Padrão)',
    'Xerox VersaLink B400 - Comando Ala 11',
    'Impressora Virtual PDF (Arquivo Militar Seguro)',
  ];

  final List<String> _meses = [
    '',
    'JANEIRO',
    'FEVEREIRO',
    'MARÇO',
    'ABRIL',
    'MAIO',
    'JUNHO',
    'JULHO',
    'AGOSTO',
    'SETEMBRO',
    'OUTUBRO',
    'NOVEMBRO',
    'DEZEMBRO'
  ];

  @override
  void initState() {
    super.initState();
    _escala = widget.escala;
    if (_escala == null) {
      _loadEscala();
    }
  }

  Future<void> _loadEscala() async {
    setState(() => _isLoading = true);
    final now = DateTime.now();
    final a = widget.ano ?? now.year;
    final m = widget.mes ?? now.month;

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.getEscalaMensal(a, m);
      if (mounted) {
        setState(() {
          _escala = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _printDirect() async {
    if (_escala == null) return;
    try {
      final pdfBytes = await EscalaPdfService.generateEscalaPdf(_escala!);
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'Escala_${_meses[_escala!.mes]}_${_escala!.ano}.pdf',
        format: PdfPageFormat.a4.landscape,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao imprimir: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _exportPdf() async {
    if (_escala == null) return;
    try {
      final pdfBytes = await EscalaPdfService.generateEscalaPdf(_escala!);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Escala_Oficial_BINFAE_${_meses[_escala!.mes]}_${_escala!.ano}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final mesNome = _escala != null && _escala!.mes > 0 && _escala!.mes <= 12
        ? _meses[_escala!.mes]
        : _meses[DateTime.now().month];
    final ano = _escala?.ano ?? DateTime.now().year;

    return Scaffold(
      backgroundColor: const Color(0xFF0A122A),
      body: SafeArea(
        child: Column(
          children: [
            // 1. TOPBAR DE CONTROLES DE IMPRESSÃO (Stitch 04_PrintView.html)
            _buildTopbar(mesNome, ano),

            // 2. VIEWPORT PRINCIPAL COM FOLHA A4 E PAINEL LATERAL
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 1150;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Mesa de Visualização A4
                            Expanded(
                              child: Container(
                                color: const Color(0xFF050D25),
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                  child: Center(
                                    child: Transform.scale(
                                      scale: _zoomLevel,
                                      alignment: Alignment.topCenter,
                                      child: _buildA4Document(mesNome, ano),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Inspetor Lateral de Configuração (em telas largas)
                            if (isWide)
                              SizedBox(
                                width: 320,
                                child: _buildPrintSettingsSidebar(),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TOPBAR DE CONTROLES TÁTICOS ---
  Widget _buildTopbar(String mesNome, int ano) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF131A33),
        border: Border(bottom: BorderSide(color: Color(0xFF212942))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF212942),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.print_rounded, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Visualizador de Impressão Oficial',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'A4 PAISAGEM (297 x 210 mm)',
                          style: TextStyle(fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF212942),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PORTARIA 142/DIRM-GL',
                          style: TextStyle(fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppColors.tertiary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'BINFAE-GL // SEÇÃO DE TI E COMUNICAÇÕES — ESCALA MENSAL $mesNome / $ano',
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF8C909F)),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              // Zoom Controls
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A122A),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF2C344D)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.zoom_out, size: 16, color: Colors.white70),
                      tooltip: 'Reduzir',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () {
                        if (_zoomLevel > 0.5) setState(() => _zoomLevel -= 0.1);
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '${(_zoomLevel * 100).toInt()}%',
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.zoom_in, size: 16, color: Colors.white70),
                      tooltip: 'Aumentar',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () {
                        if (_zoomLevel < 1.3) setState(() => _zoomLevel += 0.1);
                      },
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(40, 28),
                      ),
                      onPressed: () => setState(() => _zoomLevel = 0.85),
                      child: const Text('AJUSTAR', style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _printDirect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text('Imprimir [Ctrl+P]', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _exportPdf,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: Color(0xFF2C344D)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: const Text('Salvar PDF [Ctrl+S]', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF8C909F)),
                tooltip: 'Fechar [Esc]',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- FOLHA A4 PAISAGEM RENDERIZADA ---
  Widget _buildA4Document(String mesNome, int ano) {
    final dias = _escala?.dias ?? [];

    return Container(
      width: 1100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(26),
      child: Stack(
        children: [
          // Marca d'água oficial condicional
          if (_includeWatermark)
            Positioned.fill(
              child: Center(
                child: Transform.rotate(
                  angle: -0.35,
                  child: Opacity(
                    opacity: 0.04,
                    child: Text(
                      'DOCUMENTO OFICIAL // BINFAE-GL',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: 8,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. CABEÇALHO OFICIAL FAB
              _buildOfficialFabHeader(mesNome, ano),
              const SizedBox(height: 10),

              // 2. TABELA OFICIAL DA ESCALA
              _buildOfficialTable(dias),
              const SizedBox(height: 10),

              // 3. DIRETRIZES DA PORTARIA & RESUMO DE EFETIVO
              _buildNormativeAndStats(),
              const SizedBox(height: 12),

              // 4. ASSINATURAS DIGITAIS PADRÃO COMAER
              if (_includeSignatures) _buildDigitalSignaturesRow(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialFabHeader(String mesNome, int ano) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF0F172A), width: 1.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (_includeBrasao)
                Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Icon(Icons.military_tech_rounded, color: Colors.white, size: 28),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('MINISTÉRIO DA DEFESA', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF334155), letterSpacing: 1.1)),
                  Text('COMANDO DA AERONÁUTICA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 0.5)),
                  Text('BASE AÉREA DO GALEÃO — ALA 11', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                  Text('BATALHÃO DE INFANTARIA DE AERONÁUTICA ESPECIAL DO GALEÃO (BINFAE-GL)', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
                  Text('SEÇÃO DE TECNOLOGIA DA INFORMAÇÃO E COMUNICAÇÕES (C&TI)', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF0369A1))),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$mesNome / $ano',
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 3),
              const Text('Portaria Nº 142/DIRM-GL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const Text('Boletim Interno BAGL Nº 194/2024', style: TextStyle(fontSize: 8, fontFamily: 'monospace', color: Color(0xFF64748B))),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFF059669), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text('Publicação Homologada', style: TextStyle(fontSize: 8, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialTable(List<EscalaDiaModel> dias) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF94A3B8)),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            child: Row(
              children: const [
                SizedBox(width: 55, child: Text('DIA / DATA', textAlign: TextAlign.center, style: TextStyle(fontSize: 7.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                SizedBox(width: 45, child: Text('REGIME', textAlign: TextAlign.center, style: TextStyle(fontSize: 7.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                Expanded(flex: 3, child: Text('PLANTÃO 24H (SOBREAVISO TÁTICO)', style: TextStyle(fontSize: 7.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                Expanded(flex: 3, child: Text('EXPEDIENTE ATIVO (2 MILITARES)', style: TextStyle(fontSize: 7.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                Expanded(flex: 2, child: Text('CARGA / EQUIPAMENTO', style: TextStyle(fontSize: 7.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                SizedBox(width: 45, child: Text('VISTO', textAlign: TextAlign.center, style: TextStyle(fontSize: 7.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF94A3B8)),
          // Linhas da Tabela
          if (dias.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Nenhuma escala cadastrada para o período selecionado.', style: TextStyle(fontSize: 10, color: Colors.grey)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dias.length > 31 ? 31 : dias.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
              itemBuilder: (context, idx) {
                final d = dias[idx];
                final isWeekend = d.isFimDeSemana;
                final isHoliday = d.isFeriado;
                final isToday = d.data.day == DateTime.now().day && d.data.month == DateTime.now().month && d.data.year == DateTime.now().year;

                Color rowBg = Colors.white;
                if (isToday) rowBg = const Color(0xFFFEF3C7);
                else if (isHoliday) rowBg = const Color(0xFFF0F9FF);
                else if (isWeekend) rowBg = const Color(0xFFF8FAFC);

                final svInfo = d.militarSvGuerra != null
                    ? '${d.militarSvPosto ?? ""} ${d.militarSvGuerra} (Sv. TI)'
                    : 'Sem militar escalado';

                String expdInfo = '— SEM EXPEDIENTE ADMINISTRATIVO —';
                if (!isWeekend && !isHoliday && _includeExpediente) {
                  final e1 = d.militarExpd1Guerra != null ? '${d.militarExpd1Posto ?? ""} ${d.militarExpd1Guerra}' : '';
                  final e2 = d.militarExpd2Guerra != null ? '${d.militarExpd2Posto ?? ""} ${d.militarExpd2Guerra}' : '';
                  if (e1.isNotEmpty || e2.isNotEmpty) {
                    expdInfo = '$e1 ${e2.isNotEmpty ? "/ $e2" : ""}';
                  } else {
                    expdInfo = 'Escala de expediente a definir';
                  }
                }

                return Container(
                  color: rowBg,
                  padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 55,
                        child: Text(
                          '${d.diaMes.toString().padLeft(2, "0")} ${d.diaSemana.substring(0, 3).toUpperCase()}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 8,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: isWeekend ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 45,
                        child: Text(
                          isHoliday ? 'FERIADO' : (isWeekend ? 'F.SEM' : 'ÚTIL'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 7,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: isHoliday ? const Color(0xFF0284C7) : (isWeekend ? const Color(0xFFB45309) : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          svInfo,
                          style: const TextStyle(fontSize: 8, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          expdInfo,
                          style: TextStyle(
                            fontSize: 7.5,
                            fontFamily: 'monospace',
                            color: isWeekend || isHoliday ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                            fontStyle: isWeekend || isHoliday ? FontStyle.italic : FontStyle.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'Smart Cripto / Rádio APX',
                          style: TextStyle(fontSize: 7.5, fontFamily: 'monospace', color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(
                        width: 45,
                        child: Text(
                          'OK',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 7.5, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildNormativeAndStats() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prescrições da Portaria
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'DIRETRIZES E PRESCRIÇÕES GERAIS DE SERVIÇO (PORTARIA 142/DIRM-GL):',
                  style: TextStyle(fontSize: 7.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 3),
                Text(
                  '1. Prontidão Tática: O militar de serviço permanece em escuta contínua via canal rádio CH-04 BINFAE e smartphone criptográfico ativo, com deslocamento máximo de 30 minutos até o quartel.\n2. Regime de Expediente: Cumprimento estrito de 08:00h às 16:30h nos dias úteis, assegurando suporte pleno à rede C&TI.\n3. Permutas: Devem ser solicitadas via sistema com 48h de antecedência e homologação da chefia.',
                  style: TextStyle(fontSize: 7.5, color: Color(0xFF475569), height: 1.3),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Matriz de Carga
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'MATRIZ DE CARGA E HORAS:',
                  style: TextStyle(fontSize: 7.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 3),
                Text('• Carga Horária Mensal: 744h Totais de Sobreaviso', style: TextStyle(fontSize: 7.5, color: Color(0xFF475569))),
                Text('• Folga Regulamentar: 100% Homologada Diretriz EMAER', style: TextStyle(fontSize: 7.5, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                Text('• Autenticidade: Verificação criptográfica SHA-256 ativa', style: TextStyle(fontSize: 7.5, color: Color(0xFF475569))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDigitalSignaturesRow() {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF0F172A), width: 1.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSignatureBlock('2º SGT SILVA — SARAM 6842910', 'Encarregado da Escala de TI // BINFAE-GL'),
              _buildSignatureBlock('1º TEN CAVALCANTI — SARAM 7129402', 'Chefe da Seção de TI e Comunicações'),
              _buildSignatureBlock('TEN CEL AV RODRIGUES', 'Comandante do BINFAE-GL // Ala 11'),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'DOC HASH SHA-256: 9b2d87a41ce729f8012bb9302ca74df4492a559811c039b02319efb448a03f42 • FOLHA 01/01 (A4 PAISAGEM)',
            style: TextStyle(fontSize: 6.5, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureBlock(String name, String role) {
    return Column(
      children: [
        Container(width: 220, height: 1, color: const Color(0xFF475569)),
        const SizedBox(height: 4),
        Text(name, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        Text(role, style: const TextStyle(fontSize: 7, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: const Text(
            'Assinado via ICP-Brasil',
            style: TextStyle(fontSize: 6.5, fontFamily: 'monospace', color: Color(0xFF059669), fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // --- PAINEL LATERAL DE CONFIGURAÇÕES DE IMPRESSÃO ---
  Widget _buildPrintSettingsSidebar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF131A33),
        border: Border(left: BorderSide(color: Color(0xFF212942))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Row(
                children: [
                  Icon(Icons.tune_rounded, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Configurações A4', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              Text('PERFIL COMAER', style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: AppColors.tertiary, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFF212942)),
          const SizedBox(height: 14),

          const Text('SELETOR DE IMPRESSORA', style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFF8C909F), fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0A122A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF2C344D)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPrinter,
                dropdownColor: const Color(0xFF0A122A),
                isExpanded: true,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white),
                items: _printers.map((p) => DropdownMenuItem(value: p, child: Text(p, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedPrinter = v);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text('CAMADAS DO DOCUMENTO OFICIAL', style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFF8C909F), fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          _buildLayerSwitch('Marca d\'Água Oficial', _includeWatermark, (v) => setState(() => _includeWatermark = v)),
          _buildLayerSwitch('Brasão da Força Aérea', _includeBrasao, (v) => setState(() => _includeBrasao = v)),
          _buildLayerSwitch('Matriz de Expediente', _includeExpediente, (v) => setState(() => _includeExpediente = v)),
          _buildLayerSwitch('Bloco de Assinaturas ICP', _includeSignatures, (v) => setState(() => _includeSignatures = v)),

          const Spacer(),

          // Botão Ação Grande
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: _printDirect,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text('Disparar Impressão', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: _exportPdf,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: Color(0xFF2C344D)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: const Text('Exportar PDF Direto', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayerSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          Switch(
            value: value,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
