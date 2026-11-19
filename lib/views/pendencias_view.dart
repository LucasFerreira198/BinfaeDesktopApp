import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/pendencia.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class PendenciasView extends StatefulWidget {
  final void Function(int targetIndex)? onNavigate;

  const PendenciasView({super.key, this.onNavigate});

  @override
  State<PendenciasView> createState() => _PendenciasViewState();
}

class _PendenciasViewState extends State<PendenciasView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();

  List<PendenciaModel> _ativas = [];
  List<PendenciaModel> _concluidas = [];
  bool _isLoading = true;
  String? _filtroTipo;
  String? _filtroPrioridade;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });

    final cachedAtivas = StorageService().pendenciasAtivas;
    final cachedConcluidas = StorageService().pendenciasConcluidas;
    if (cachedAtivas.isNotEmpty || cachedConcluidas.isNotEmpty) {
      _ativas = cachedAtivas;
      _concluidas = cachedConcluidas;
      _isLoading = false;
    }
    _loadPendencias();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPendencias() async {
    if (_ativas.isEmpty && _concluidas.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final ativas = await _api.listPendenciasAtivas(
        tipo: _filtroTipo,
        prioridade: _filtroPrioridade,
      );
      final concluidas = await _api.listPendenciasConcluidas();
      StorageService().persistPendencias(ativas: ativas, concluidas: concluidas);
      if (mounted) {
        setState(() {
          _ativas = ativas;
          _concluidas = concluidas;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _abrirModalNovaPendencia({String tipoInicial = 'GERAL'}) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String tipo = tipoInicial;
    String prioridade = 'MEDIA';
    DateTime? prazo = DateTime.now().add(const Duration(days: 3));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.primary),
          ),
          title: Row(
            children: [
              Icon(tipo == 'META' ? Icons.flag : Icons.add_task, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                tipo == 'META' ? 'Nova Meta Estratégica' : 'Nova Pendência Operacional',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Título da Tarefa / Meta *', style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: tipo == 'META' ? 'Ex: Auditar 100% dos rádios APX 8000 da Guarda' : 'Ex: Substituir cabeamento estruturado Rack TI-02',
                      hintStyle: const TextStyle(fontSize: 11.5, color: AppColors.outline),
                      filled: true,
                      fillColor: AppColors.surfaceContainerLowest,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Descrição / Detalhes Táticos', style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Instruções de execução, militares encarregados, ferramentas necessárias...',
                      hintStyle: const TextStyle(fontSize: 11.5, color: AppColors.outline),
                      filled: true,
                      fillColor: AppColors.surfaceContainerLowest,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tipo:', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.outline)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: tipo,
                                  isExpanded: true,
                                  dropdownColor: AppColors.surfaceContainerHigh,
                                  items: const [
                                    DropdownMenuItem(value: 'GERAL', child: Text('Geral / Rotina', style: TextStyle(fontSize: 12, color: Colors.white))),
                                    DropdownMenuItem(value: 'META', child: Text('Meta Estratégica', style: TextStyle(fontSize: 12, color: Colors.white))),
                                    DropdownMenuItem(value: 'INVENTARIO', child: Text('Inventário', style: TextStyle(fontSize: 12, color: Colors.white))),
                                  ],
                                  onChanged: (v) => setDialogState(() => tipo = v ?? 'GERAL'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Prioridade:', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.outline)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: prioridade,
                                  isExpanded: true,
                                  dropdownColor: AppColors.surfaceContainerHigh,
                                  items: const [
                                    DropdownMenuItem(value: 'BAIXA', child: Text('Baixa', style: TextStyle(fontSize: 12, color: Colors.white))),
                                    DropdownMenuItem(value: 'MEDIA', child: Text('Média', style: TextStyle(fontSize: 12, color: Colors.white))),
                                    DropdownMenuItem(value: 'ALTA', child: Text('Alta', style: TextStyle(fontSize: 12, color: Colors.white))),
                                    DropdownMenuItem(value: 'URGENTE', child: Text('Urgente', style: TextStyle(fontSize: 12, color: AppColors.error))),
                                  ],
                                  onChanged: (v) => setDialogState(() => prioridade = v ?? 'MEDIA'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.outline)),
            ),
            ElevatedButton(
              onPressed: () async {
                final t = titleCtrl.text.trim();
                if (t.isEmpty) return;
                Navigator.of(ctx).pop();
                try {
                  await _api.createPendencia({
                    'titulo': t,
                    if (descCtrl.text.trim().isNotEmpty) 'descricao': descCtrl.text.trim(),
                    'tipo': tipo,
                    'prioridade': prioridade,
                    if (prazo != null) 'prazo_limite': prazo!.toIso8601String(),
                  });
                  _loadPendencias();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: const Color(0xFF00285D),
              ),
              child: const Text('Salvar Registro', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _concluirPendencia(PendenciaModel p) async {
    try {
      await _api.concluirPendencia(p.id, resolucao: 'Concluída via painel tático');
      await _loadPendencias();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceContainerHigh,
            content: Text('Tarefa "${p.titulo}" concluída!', style: const TextStyle(color: AppColors.tertiary)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _tabController.index == 0 ? _ativas : _concluidas;
    final filtered = list.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return p.titulo.toLowerCase().contains(q) || (p.descricao?.toLowerCase().contains(q) ?? false);
    }).toList();

    final urgentesCount = _ativas.where((p) => p.prioridade == 'URGENTE').length;
    final metasCount = _ativas.where((p) => p.tipo == 'META').length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =========================================================================
          // 1. TOP COMMAND & ACTION BAR (Google Stitch #07_PendenciasView)
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
                      child: const Icon(Icons.task_alt, color: AppColors.primary, size: 24),
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
                                'Quadro Tático de Pendências & Metas da Seção',
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
                                  color: AppColors.primaryContainer.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'MOD-05 // GESTÃO OPERACIONAL TI',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'BASE AÉREA DO GALEÃO // ALA 11 • PROTOCOLO MIL-STD-810H • SLA GLOBAL: 94.8% NO PRAZO',
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
                      onPressed: _loadPendencias,
                      icon: const Icon(Icons.sync, size: 15, color: AppColors.secondary),
                      label: const Text('Sincronizar', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainerHigh,
                        side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _abrirModalNovaPendencia(tipoInicial: 'META'),
                      icon: const Icon(Icons.flag, size: 15, color: AppColors.tertiary),
                      label: const Text('Nova Meta', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainerHigh,
                        side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _abrirModalNovaPendencia(tipoInicial: 'GERAL'),
                      icon: const Icon(Icons.add_task, size: 16, color: Color(0xFF00285D)),
                      label: const Text(
                        '+ Nova Pendência',
                        style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF00285D)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          // 2. METRIC / TELEMETRY KPI ROW (Google Stitch #07_PendenciasView)
          // =========================================================================
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final totalPendencias = _ativas.length + _concluidas.length;
              final taxaResolucao = totalPendencias > 0
                  ? ((_concluidas.length / totalPendencias) * 100).toStringAsFixed(0)
                  : '100';

              final kpis = [
                _buildKpiCard('Pendências em Aberto', '${_ativas.length}', '$urgentesCount Críticas', Icons.priority_high, AppColors.error),
                _buildKpiCard('Metas Estratégicas', '$metasCount', 'OKRs Ativos', Icons.track_changes, AppColors.tertiary),
                _buildKpiCard('Concluídas no Total', '${_concluidas.length}', '100% Auditadas', Icons.check_circle, AppColors.primary),
                _buildKpiCard('Taxa de Resolução', '$taxaResolucao%', '${_concluidas.length} de $totalPendencias resolvidas', Icons.insights, AppColors.secondary),
              ];

              if (width >= 900) {
                return Row(
                  children: [
                    for (int i = 0; i < kpis.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: kpis[i]),
                    ],
                  ],
                );
              }

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: kpis.map((c) => SizedBox(width: (width - 10) / 2, child: c)).toList(),
              );
            },
          ),

          const SizedBox(height: 14),

          // =========================================================================
          // 3. TABS & SEARCH BAR (Google Stitch #07_PendenciasView)
          // =========================================================================
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 880;

              final searchInput = Container(
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.outlineVariant.withOpacity(0.35)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Buscar por tarefa, pendência, meta ou escopo...',
                    hintStyle: const TextStyle(fontSize: 11, color: AppColors.outline),
                    prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.primary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 14, color: AppColors.outline),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              );

              final tabsBar = Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.outlineVariant.withOpacity(0.35)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.onSurfaceVariant,
                  labelStyle: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.tertiary),
                          ),
                          const SizedBox(width: 6),
                          const Text('Pendências Ativas'),
                          const SizedBox(width: 6),
                          _buildCountBadge('${_ativas.length}', AppColors.tertiary),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.outline),
                          ),
                          const SizedBox(width: 6),
                          const Text('Concluídas'),
                          const SizedBox(width: 6),
                          _buildCountBadge('${_concluidas.length}', AppColors.outline),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(flex: 5, child: searchInput),
                    const SizedBox(width: 12),
                    Expanded(flex: 5, child: tabsBar),
                  ],
                );
              }

              return Column(
                children: [
                  searchInput,
                  const SizedBox(height: 10),
                  tabsBar,
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          // =========================================================================
          // 4. TASK CARDS LIST
          // =========================================================================
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.task_alt, size: 48, color: AppColors.outline.withOpacity(0.5)),
                            const SizedBox(height: 10),
                            const Text(
                              'Nenhum item nesta lista!',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final item = filtered[i];
                          return _TacticalPendenciaCard(
                            pendencia: item,
                            isConcluded: _tabController.index == 1,
                            onConclude: () => _concluirPendencia(item),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  static Widget _buildKpiCard(String title, String count, String subtext, IconData icon, Color color) {
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
              Text(
                count,
                style: TextStyle(fontSize: 22, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 2),
              Text(subtext, style: TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: color.withOpacity(0.85))),
            ],
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
        ],
      ),
    );
  }

  static Widget _buildCountBadge(String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count,
        style: TextStyle(fontSize: 9.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

class _TacticalPendenciaCard extends StatelessWidget {
  final PendenciaModel pendencia;
  final bool isConcluded;
  final VoidCallback onConclude;

  const _TacticalPendenciaCard({
    required this.pendencia,
    required this.isConcluded,
    required this.onConclude,
  });

  @override
  Widget build(BuildContext context) {
    Color prioridadeColor;
    switch (pendencia.prioridade) {
      case 'URGENTE':
        prioridadeColor = AppColors.error;
        break;
      case 'ALTA':
        prioridadeColor = AppColors.warning;
        break;
      case 'MEDIA':
        prioridadeColor = AppColors.primary;
        break;
      default:
        prioridadeColor = AppColors.outline;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Conclude action button / Checkbox
          if (!isConcluded)
            IconButton(
              icon: const Icon(Icons.radio_button_unchecked, color: AppColors.primary, size: 20),
              tooltip: 'Marcar como Concluída',
              onPressed: onConclude,
            )
          else
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.check_circle, color: AppColors.tertiary, size: 20),
            ),
          const SizedBox(width: 8),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: prioridadeColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: prioridadeColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        pendencia.prioridade,
                        style: TextStyle(
                          fontSize: 9,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: prioridadeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        pendencia.tipo,
                        style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: AppColors.secondary),
                      ),
                    ),
                    const Spacer(),
                    if (pendencia.prazoLimite != null)
                      Text(
                        'Prazo: ${DateFormat('dd/MM/yyyy').format(pendencia.prazoLimite!)}',
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.outline),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  pendencia.titulo,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isConcluded ? AppColors.outline : Colors.white,
                    decoration: isConcluded ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (pendencia.descricao != null && pendencia.descricao!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    pendencia.descricao!,
                    style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Responsável: ${pendencia.militarResponsavelNome ?? pendencia.criadoPorNome ?? "C&TI"} • Criado: ${pendencia.criadoEm != null ? DateFormat('dd/MM HH:mm').format(pendencia.criadoEm!) : "Recente"}',
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
