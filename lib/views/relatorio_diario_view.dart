import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/relatorio_diario.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class RelatorioDiarioView extends StatefulWidget {
  final void Function(int targetIndex)? onNavigate;

  const RelatorioDiarioView({super.key, this.onNavigate});

  @override
  State<RelatorioDiarioView> createState() => _RelatorioDiarioViewState();
}

class _RelatorioDiarioViewState extends State<RelatorioDiarioView> {
  final ApiService _api = ApiService();

  RelatorioDiarioModel? _relatorio;
  List<RelatorioDiarioModel> _historico = [];
  List<Map<String, dynamic>> _militaresTI = [];

  final TextEditingController _ocorrenciasCtrl = TextEditingController();
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isSaving = false;
  bool _isLaunching = false;

  @override
  void initState() {
    super.initState();
    final cachedRel = StorageService().ultimoRelatorio;
    final cachedMil = StorageService().militares;
    if (cachedRel != null || cachedMil.isNotEmpty) {
      _relatorio = cachedRel;
      _militaresTI = cachedMil;
      if (cachedRel?.ocorrenciasMilitar != null) {
        _ocorrenciasCtrl.text = cachedRel!.ocorrenciasMilitar!;
      }
      _isLoading = false;
    }
    _carregarRelatorioHoje();
  }

  @override
  void dispose() {
    _ocorrenciasCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarRelatorioHoje({bool isManual = false}) async {
    if (_relatorio == null && _militaresTI.isEmpty) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isRefreshing = true);
    }
    try {
      final mil = await _api.listMilitaresInformatica();
      final rel = await _api.getRelatorioHoje();
      final hist = await _api.listHistoricoRelatorios();
      StorageService().persistMilitares(mil);
      StorageService().persistUltimoRelatorio(rel);
      if (mounted) {
        setState(() {
          _militaresTI = mil;
          _relatorio = rel;
          _historico = hist;
          _ocorrenciasCtrl.text = rel.ocorrenciasMilitar ?? '';
          _isLoading = false;
          _isRefreshing = false;
        });
        if (isManual) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Relatório de serviço sincronizado com sucesso!'),
              backgroundColor: AppColors.surfaceContainerHigh,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar relatório: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _carregarPorData(DateTime date) async {
    final str = DateFormat('yyyy-MM-dd').format(date);
    setState(() => _isLoading = true);
    try {
      final rel = await _api.getRelatorioPorData(str);
      if (mounted) {
        setState(() {
          _relatorio = rel;
          _ocorrenciasCtrl.text = rel.ocorrenciasMilitar ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não há relatório para esta data: $e'), backgroundColor: AppColors.warning),
        );
      }
    }
  }

  Future<void> _salvarRascunho() async {
    if (_relatorio == null || _relatorio!.isLancado) return;
    setState(() => _isSaving = true);
    try {
      final updated = await _api.salvarRascunhoRelatorio(
        _relatorio!.id,
        ocorrencias: _ocorrenciasCtrl.text.trim(),
        militarServicoId: _relatorio!.militarServicoId,
      );
      if (mounted) {
        setState(() {
          _relatorio = updated;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.surfaceContainerHigh,
            content: Text('Rascunho salvo com sucesso!', style: TextStyle(color: AppColors.tertiary)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar rascunho: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _confirmarLancamento() async {
    if (_relatorio == null || _relatorio!.isLancado) return;

    bool enviarEmail = true;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.primary),
          ),
          title: const Row(
            children: [
              Icon(Icons.verified_user, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Lançar Relatório Oficial 24h', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Deseja oficializar e lançar este relatório de serviço? Após o lançamento, ele será criptografado e bloqueado para edição.',
                  style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Destinatários Automáticos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                      SizedBox(height: 4),
                      Text('• Militar de serviço escalado (e-mail FAB cadastrado)', style: TextStyle(fontSize: 11, color: Colors.white70)),
                      Text('• 2 Militares mais antigos da Seção de Informática (DIRM-GL)', style: TextStyle(fontSize: 11, color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Disparar e-mails para os destinatários agora', style: TextStyle(fontSize: 12, color: Colors.white)),
                  value: enviarEmail,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setDialogState(() => enviarEmail = v ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.outline)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: const Color(0xFF00285D),
              ),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Confirmar e Lançar', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );

    if (confirmar != true) return;

    setState(() => _isLaunching = true);
    try {
      final lancado = await _api.lancarRelatorio(
        _relatorio!.id,
        ocorrencias: _ocorrenciasCtrl.text.trim(),
        militarServicoId: _relatorio!.militarServicoId,
        enviarEmail: enviarEmail,
      );
      if (mounted) {
        setState(() {
          _relatorio = lancado;
          _isLaunching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.surfaceContainerHigh,
            content: Text('Relatório lançado e e-mails enviados com sucesso!', style: TextStyle(color: AppColors.tertiary)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLaunching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao lançar: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rel = _relatorio;
    final isLancado = rel?.isLancado ?? false;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =========================================================================
          // 1. TACTICAL HEADER & ACTION BAR (Google Stitch #05_DailyReportView)
          // =========================================================================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outlineVariant.withOpacity(0.35)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 980;

                final headerInfo = Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.summarize_outlined, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              const Text(
                                'LIVRO DE PARTE DIÁRIO // RELATÓRIO OPERACIONAL 24H',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                  color: Colors.white,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isLancado ? AppColors.tertiary.withOpacity(0.2) : AppColors.primaryContainer.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isLancado ? AppColors.tertiary.withOpacity(0.4) : AppColors.primaryContainer.withOpacity(0.4),
                                  ),
                                ),
                                child: Text(
                                  isLancado ? 'LANÇADO OFICIALMENTE' : 'EM ANDAMENTO (TURNO ATIVO)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    color: isLancado ? AppColors.tertiary : AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'SEÇÃO DE TECNOLOGIA DA INFORMAÇÃO E COMUNICAÇÕES (C&TI) - PORTARIA Nº 142/DIRM-GL - ALA 11',
                            style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final actionButtons = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _relatorio?.dataReferencia ?? DateTime.now(),
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          _carregarPorData(picked);
                        }
                      },
                      icon: const Icon(Icons.history, size: 15, color: AppColors.secondary),
                      label: const Text('Histórico por Data', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainerHigh,
                        side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isRefreshing ? null : () => _carregarRelatorioHoje(isManual: true),
                      icon: const Icon(Icons.sync, size: 15, color: AppColors.tertiary),
                      label: const Text('Sincronizar', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainerHigh,
                        side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ],
                );

                if (isWide) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: headerInfo),
                      const SizedBox(width: 14),
                      actionButtons,
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerInfo,
                    const SizedBox(height: 12),
                    actionButtons,
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          // =========================================================================
          // 2. TURN KPIS & CRITICAL LINKS
          // =========================================================================
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final plantonistaDisplay = rel?.militarServicoGuerra != null
                  ? '${rel!.militarServicoPosto ?? ""} ${rel.militarServicoGuerra}'.trim()
                  : (rel?.militarServicoNome ?? 'Plantão TI');
              final movsTotal = (rel?.cautelasPeriodo.length ?? 0) + (rel?.devolucoesPeriodo.length ?? 0);
              final cards = [
                _buildTurnKpiCard('Plantonista Titular', plantonistaDisplay, 'SERVIÇO 24H // C&TI', Icons.badge, AppColors.tertiary),
                _buildTurnKpiCard('Materiais Movimentados', '$movsTotal', 'Cautelas & Devoluções', Icons.sync_alt, AppColors.primary),
                _buildTurnKpiCard('Equipamentos Consertados', '${rel?.itensConsertados.length ?? 0}', 'Bancada TI', Icons.build, AppColors.secondary),
                _buildTurnKpiCard('Sistemas & Enlaces', '100% ONLINE', 'CINDACTA-GL // LINK FAB', Icons.network_check, AppColors.tertiary),
              ];

              if (width >= 900) {
                return Row(
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: cards[i]),
                    ],
                  ],
                );
              }

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: cards.map((c) => SizedBox(width: (width - 10) / 2, child: c)).toList(),
              );
            },
          ),

          const SizedBox(height: 14),

          // =========================================================================
          // 3. MAIN WORKSPACE: SNAPSHOT DETAILS & EDITOR
          // =========================================================================
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : rel == null
                    ? const Center(child: Text('Nenhum relatório disponível.'))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 960;

                          final snapshotColumn = SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSnapshotBox(
                                  'Movimentações de Cautela no Turno (${rel.cautelasPeriodo.length + rel.devolucoesPeriodo.length})',
                                  Icons.sync_alt,
                                  AppColors.primary,
                                  (rel.cautelasPeriodo.isEmpty && rel.devolucoesPeriodo.isEmpty)
                                      ? 'Nenhuma movimentação de material durante o período.'
                                      : [
                                          ...rel.cautelasPeriodo.map((m) => '• [CAUTELA] ${m['item_nome'] ?? m['nome'] ?? m['item_id'] ?? ""} - ${m['militar_nome'] ?? m['responsavel_nome'] ?? ""}'),
                                          ...rel.devolucoesPeriodo.map((m) => '• [DEVOLUÇÃO] ${m['item_nome'] ?? m['nome'] ?? m['item_id'] ?? ""} - ${m['militar_nome'] ?? m['responsavel_nome'] ?? ""}'),
                                        ].join('\n'),
                                ),
                                const SizedBox(height: 10),
                                _buildSnapshotBox(
                                  'Reparos Concluídos na Bancada (${rel.itensConsertados.length})',
                                  Icons.check_circle_outline,
                                  AppColors.tertiary,
                                  rel.itensConsertados.isEmpty
                                      ? 'Nenhum equipamento finalizado na bancada neste turno.'
                                      : rel.itensConsertados.map((item) => '• ${item['nome'] ?? item['item_nome'] ?? "Item"} (BMP ${item['bmp'] ?? "S/N"}) - Laudo: ${item['laudo_reparo'] ?? item['laudo'] ?? "Ok"}').join('\n'),
                                ),
                                const SizedBox(height: 10),
                                _buildSnapshotBox(
                                  'Cautelas & Missões Ativas (${rel.missoesCautelas.length})',
                                  Icons.assignment,
                                  AppColors.secondary,
                                  rel.missoesCautelas.isEmpty
                                      ? 'Sem cautelas em carga ativa.'
                                      : rel.missoesCautelas.map((c) => '• ${c['nome'] ?? "Missão"} (${c['tipo'] ?? "MISSAO"}) - ${c['status'] ?? "ATIVA"}').join('\n'),
                                ),
                              ],
                            ),
                          );

                          final editorColumn = Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.outlineVariant.withOpacity(0.35)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Ocorrências do Militar de Serviço',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    if (isLancado)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceContainerHigh,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'BLOQUEADO / OFICIALIZADO',
                                          style: TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: AppColors.outline),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Registre falhas em links, manutenções imprevistas, missões iniciadas ou observações para o próximo turno:',
                                  style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerLowest,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
                                    ),
                                    child: TextField(
                                      controller: _ocorrenciasCtrl,
                                      enabled: !isLancado,
                                      maxLines: null,
                                      expands: true,
                                      style: const TextStyle(fontSize: 12.5, color: Colors.white),
                                      decoration: const InputDecoration(
                                        hintText: 'Digite as ocorrências do plantão...',
                                        hintStyle: TextStyle(fontSize: 11.5, color: AppColors.outline),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (!isLancado)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: _isSaving ? null : _salvarRascunho,
                                        icon: const Icon(Icons.save_outlined, size: 15),
                                        label: const Text('Salvar Rascunho', style: TextStyle(fontSize: 11, fontFamily: 'monospace')),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.4)),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: _isLaunching ? null : _confirmarLancamento,
                                        icon: const Icon(Icons.verified_user, size: 15, color: Color(0xFF00285D)),
                                        label: const Text(
                                          'Confirmar e Lançar Relatório',
                                          style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF00285D)),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primaryContainer,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          );

                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: 5, child: snapshotColumn),
                                const SizedBox(width: 14),
                                Expanded(flex: 6, child: editorColumn),
                              ],
                            );
                          }

                          return Column(
                            children: [
                              Expanded(flex: 5, child: snapshotColumn),
                              const SizedBox(height: 12),
                              Expanded(flex: 6, child: editorColumn),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  static Widget _buildTurnKpiCard(String title, String mainVal, String subVal, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.outline)),
              const SizedBox(height: 4),
              Text(mainVal, style: TextStyle(fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 2),
              Text(subVal, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.onSurfaceVariant)),
            ],
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, size: 16, color: color),
          ),
        ],
      ),
    );
  }

  static Widget _buildSnapshotBox(String title, IconData icon, Color color, String content) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              content,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.onSurfaceVariant, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
