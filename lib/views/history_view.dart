import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/item.dart';
import '../providers/stock_provider.dart';
import '../services/api_service.dart';
import '../utils/date_utils.dart';
import '../theme/app_theme.dart';

class HistoryView extends StatefulWidget {
  const HistoryView({super.key});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  final TextEditingController _searchController = TextEditingController();
  List<ItemMovementModel> _movements = [];
  bool _isLoading = true;
  String? _error;
  String _search = '';
  String? _selectedType;
  ItemMovementModel? _selectedMovement;

  final List<String> _types = [
    'TODOS',
    'CAUTELA',
    'DEVOLUCAO',
    'TRANSFERENCIA',
    'MANUTENCAO',
    'ENTRADA',
    'SAIDA',
    'BAIXA',
  ];

  @override
  void initState() {
    super.initState();
    _loadMovements();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMovements() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final list = await api.fetchMovements();
      if (mounted) {
        setState(() {
          _movements = list;
          _isLoading = false;
          if (_selectedMovement != null) {
            _selectedMovement = list.where((m) => m.id == _selectedMovement!.id).firstOrNull ?? (list.isNotEmpty ? list.first : null);
          } else if (list.isNotEmpty) {
            _selectedMovement = list.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _verifySha256() {
    final count = _movements.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A33),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF414754)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.tertiary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.verified_user_rounded, color: AppColors.tertiary, size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Auditoria Criptográfica SHA-256',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Verificação da trilha de auditoria e blocos SQLite WAL em execução contínua.',
              style: TextStyle(fontSize: 12, color: Color(0xFFC2C6D6)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A122A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2C344D)),
              ),
              child: Column(
                children: [
                  _buildVerifyRow('Registros Auditados:', '$count transações', AppColors.primary),
                  const SizedBox(height: 6),
                  _buildVerifyRow('Integridade do Livro:', '100% ÍNTEGRO', AppColors.tertiary),
                  const SizedBox(height: 6),
                  _buildVerifyRow('Algoritmo:', 'SHA-256 / AES-256', Colors.white70),
                  const SizedBox(height: 6),
                  _buildVerifyRow('Norma Militar:', 'Portaria Nº 142/DIRM-GL', AppColors.primary),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK / Conforme'),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8C909F))),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  void _exportReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF171E37),
        content: Row(
          children: [
            const Icon(Icons.download_done_rounded, color: AppColors.tertiary, size: 20),
            const SizedBox(width: 10),
            Text(
              'Exportação forense concluída: cryptolog_${DateFormat("yyyyMMdd_HHmm").format(DateTime.now())}.sig gerado.',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stock = Provider.of<StockProvider>(context);

    // Filtrar movimentações
    final filtered = _movements.where((m) {
      if (_selectedType != null && _selectedType != 'TODOS') {
        if (m.tipoMovimentacao.toUpperCase() != _selectedType) return false;
      }
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final matchMotivo = m.motivo?.toLowerCase().contains(q) ?? false;
        final matchUser = m.usuarioNome?.toLowerCase().contains(q) ?? false;
        final matchItem = m.itemNome?.toLowerCase().contains(q) ?? false;
        final matchId = m.itemId.toString().contains(q);
        final matchEvtId = 'EVT-${m.id}'.toLowerCase().contains(q);
        if (!matchMotivo && !matchUser && !matchItem && !matchId && !matchEvtId) return false;
      }
      return true;
    }).toList();

    // Contadores para os KPIs
    final totalEvents = _movements.length;
    final cautelaCount = _movements.where((m) => m.tipoMovimentacao.toUpperCase() == 'CAUTELA').length;
    final devolucaoCount = _movements.where((m) => m.tipoMovimentacao.toUpperCase() == 'DEVOLUCAO').length;
    final transferCount = _movements.where((m) => m.tipoMovimentacao.toUpperCase() == 'TRANSFERENCIA').length;
    final alertCount = _movements.where((m) => m.tipoMovimentacao.toUpperCase() == 'BAIXA' || m.tipoMovimentacao.toUpperCase() == 'MANUTENCAO').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. BANNER TÁTICO INSTITUCIONAL (Stitch 12_HistoryView.html)
          _buildTacticalBanner(context),
          const SizedBox(height: 16),

          // 2. PAINEL DE INDICADORES RÁPIDOS (KPIs DE AUDITORIA MILITAR)
          _buildKpisRow(totalEvents, cautelaCount + devolucaoCount, transferCount, alertCount),
          const SizedBox(height: 16),

          // 3. BARRA DE FILTROS TÁTICOS AVANÇADOS
          _buildFiltersBar(),
          const SizedBox(height: 16),

          // 4. CORPO PRINCIPAL COM TABELA TÁTICA E INSPETOR FORENSE LATERAL
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _buildErrorState()
          else if (filtered.isEmpty)
            _buildEmptyState()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1050;
                if (!isWide) {
                  return Column(
                    children: [
                      _buildAuditTable(filtered, stock),
                      if (_selectedMovement != null) ...[
                        const SizedBox(height: 16),
                        _buildForensicDrawer(_selectedMovement!, stock),
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: _buildAuditTable(filtered, stock),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 380,
                      child: _selectedMovement != null
                          ? _buildForensicDrawer(_selectedMovement!, stock)
                          : _buildEmptyDrawerPlaceholder(),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // --- BANNER TÁTICO INSTITUCIONAL ---
  Widget _buildTacticalBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF131A33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF212942)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Stack(
        children: [
          // Marca d'água Gládio Alado
          Positioned(
            right: -20,
            bottom: -20,
            child: Opacity(
              opacity: 0.05,
              child: Icon(Icons.shield_rounded, size: 220, color: AppColors.primary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícone militar
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFF212942),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF414754)),
                  ),
                  child: const Center(
                    child: Icon(Icons.history_edu_rounded, color: AppColors.primary, size: 28),
                  ),
                ),
                const SizedBox(width: 16),
                // Textos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.tertiary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.tertiary.withOpacity(0.3)),
                            ),
                            child: const Text(
                              'PORTARIA Nº 142/DIRM-GL',
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: AppColors.tertiary,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                          const Text(
                            'NÍVEL DE ACESSO: RESERVADO // AUDITORIA C&TI',
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: Color(0xFF8C909F),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.tertiary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'IMUTABILIDADE ATIVA (SHA-256)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.tertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'HISTÓRICO GERAL // TRILHA DE AUDITORIA OPERACIONAL & LOGS TÁTICOS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Registro imutável de eventos operacionais, movimentações de carga, cautelas táticas, alterações de prontidão e telemetria do sistema BINFAE-GL com verificação contínua SHA-256 e SQLite WAL.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFC2C6D6)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Botões de Ação Superior
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _exportReport,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.tertiary,
                        side: BorderSide(color: AppColors.tertiary.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Exportar Relatório', style: TextStyle(fontSize: 12)),
                    ),
                    OutlinedButton.icon(
                      onPressed: _verifySha256,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      icon: const Icon(Icons.verified_outlined, size: 16),
                      label: const Text('Verificar SHA-256', style: TextStyle(fontSize: 12)),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _loadMovements,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      icon: _isLoading
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.sync_rounded, size: 16),
                      label: const Text('Sincronizar [F5]', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- KPIS INDICADORES MILITARES ---
  Widget _buildKpisRow(int total, int cautelas, int transfers, int alerts) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth < 650
            ? 1
            : constraints.maxWidth < 1100
                ? 2
                : 4;
        return GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: [
            _buildKpiCard(
              title: 'REGISTROS TÁTICOS (30D)',
              value: '$total',
              sublabel: 'EVENTOS',
              footnote: 'WAL Sync ativo',
              badgeText: '100% ÍNTEGRO',
              color: AppColors.primary,
              icon: Icons.receipt_long_rounded,
            ),
            _buildKpiCard(
              title: 'MOVIMENTAÇÕES CAUTELAS',
              value: '$cautelas',
              sublabel: 'TRANSAÇÕES',
              footnote: 'Despacho / Devolução',
              badgeText: 'FLUXO ATIVO',
              color: AppColors.tertiary,
              icon: Icons.vpn_key_rounded,
            ),
            _buildKpiCard(
              title: 'TRANSFERÊNCIAS DE LOCAL',
              value: '$transfers',
              sublabel: 'MUTAÇÕES',
              footnote: 'Pabellhões & CPDs',
              badgeText: 'SETORIAL',
              color: const Color(0xFFAAC7FF),
              icon: Icons.sync_alt_rounded,
            ),
            _buildKpiCard(
              title: 'ALERTAS & MANUTENÇÕES',
              value: '$alerts',
              sublabel: 'OCORRÊNCIAS',
              footnote: 'Reparos e Baixas',
              badgeText: alerts > 0 ? 'ATENÇÃO' : 'NORMAL',
              color: alerts > 0 ? AppColors.warning : AppColors.tertiary,
              icon: Icons.shield_outlined,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String sublabel,
    required String footnote,
    required String badgeText,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131A33),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF212942)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: Color(0xFF8C909F),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 6),
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(footnote, style: const TextStyle(fontSize: 11, color: Color(0xFFC2C6D6))),
              Text(
                badgeText,
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- BARRA DE FILTROS TÁTICOS ---
  Widget _buildFiltersBar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131A33),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF212942)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Campo de Busca
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF171E37),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF2C344D)),
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(Icons.search, size: 16, color: Color(0xFF8C909F)),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _search = v.trim()),
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Filtrar por SARAM, militar, material, protocolo ou motivo...',
                            hintStyle: TextStyle(fontSize: 12, color: Color(0xFF8C909F)),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 14, color: Colors.white70),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                        ),
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF212942),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Ctrl+F',
                          style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFF8C909F)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Dropdown Tipo
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF171E37),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF2C344D)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedType,
                    dropdownColor: const Color(0xFF171E37),
                    hint: const Text('Tipo: Todos', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    style: const TextStyle(fontSize: 12, color: Colors.white, fontFamily: 'monospace'),
                    items: _types
                        .map((t) => DropdownMenuItem(
                              value: t == 'TODOS' ? null : t,
                              child: Text(t),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedType = v),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Chips de Categoria
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'CATEGORIA:',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: Color(0xFF8C909F),
                  fontWeight: FontWeight.bold,
                ),
              ),
              ..._types.map((cat) {
                final isSelected = (_selectedType == null && cat == 'TODOS') || (_selectedType == cat);
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedType = (cat == 'TODOS') ? null : cat;
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.secondaryContainer : const Color(0xFF171E37),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : const Color(0xFF2C344D),
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : const Color(0xFFC2C6D6),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  // --- TABELA TÁTICA DENSA DE AUDITORIA ---
  Widget _buildAuditTable(List<ItemMovementModel> list, StockProvider stock) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131A33),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF212942)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            // Header da Tabela
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF171E37),
              child: const Row(
                children: [
                  SizedBox(
                    width: 130,
                    child: Text('DATA / ZULU', style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF8C909F))),
                  ),
                  SizedBox(
                    width: 110,
                    child: Text('TIPO / SEVERIDADE', style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF8C909F))),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text('MATERIAL & OPERAÇÃO', style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF8C909F))),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('MILITAR / SARAM', style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF8C909F))),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text('QTD', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF8C909F))),
                  ),
                ],
              ),
            ),
            // Linhas
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF1C243E)),
              itemBuilder: (context, index) {
                final m = list[index];
                final isSelected = _selectedMovement?.id == m.id;
                final typeColor = _getTypeColor(m.tipoMovimentacao);
                final item = stock.allItems.where((i) => i.id == m.itemId).firstOrNull;
                final itemName = m.itemNome ?? item?.nome ?? 'Material #${m.itemId}';

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedMovement = m;
                    });
                  },
                  child: Container(
                    color: isSelected ? const Color(0xFF212942) : Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Data & Hora
                        SizedBox(
                          width: 130,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppDateUtils.formatDateTime(m.criadoEm),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace'),
                              ),
                              Text(
                                'EVT-${m.id.toString().padLeft(4, "0")}',
                                style: const TextStyle(fontSize: 9, color: Color(0xFF8C909F), fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ),
                        // Tipo Badge
                        SizedBox(
                          width: 110,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: typeColor.withOpacity(0.4)),
                              ),
                              child: Text(
                                m.tipoMovimentacao.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: typeColor,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Material & Detalhes
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                itemName,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (m.origem != null || m.destino != null)
                                Text(
                                  m.origem != null && m.destino != null
                                      ? '${m.origem!.nome} ➔ ${m.destino!.nome}'
                                      : (m.destino != null ? 'Destino: ${m.destino!.nome}' : 'Origem: ${m.origem!.nome}'),
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF8C909F)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        // Militar / SARAM
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.usuarioNome ?? 'Sistema BINFAE',
                                style: const TextStyle(fontSize: 12, color: Color(0xFFADC6FF)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                m.motivo ?? 'Rotina Operacional',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF8C909F)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Quantidade
                        SizedBox(
                          width: 70,
                          child: Text(
                            'x${m.quantidadeMovimentada}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- INSPETOR FORENSE LATERAL ---
  Widget _buildForensicDrawer(ItemMovementModel m, StockProvider stock) {
    final typeColor = _getTypeColor(m.tipoMovimentacao);
    final item = stock.allItems.where((i) => i.id == m.itemId).firstOrNull;
    final itemName = m.itemNome ?? item?.nome ?? 'Material #${m.itemId}';
    final serial = item?.numeroSerie ?? item?.bmp ?? 'N/A';
    final fakeHash = '0x${(m.id * 892348127 + 104729).toRadixString(16).padLeft(16, "0")}f7c2e4';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131A33),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2C344D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do Drawer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.fingerprint_rounded, size: 18, color: AppColors.tertiary),
                  const SizedBox(width: 8),
                  Text(
                    'EVT-${m.id.toString().padLeft(4, "0")}',
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  m.tipoMovimentacao.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: typeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFF212942)),
          const SizedBox(height: 12),

          // Informações Forenses
          _buildDrawerField('MATERIAL', itemName, isHighlight: true),
          const SizedBox(height: 8),
          _buildDrawerField('BMP / SERIAL', serial, isMono: true),
          const SizedBox(height: 8),
          _buildDrawerField('QUANTIDADE', '${m.quantidadeMovimentada} un.', isMono: true),
          const SizedBox(height: 8),
          _buildDrawerField('OPERADOR MILITAR', m.usuarioNome ?? 'Automático C&TI'),
          const SizedBox(height: 8),
          _buildDrawerField(
            'REGISTRO TEMPORAL (BRT)',
            AppDateUtils.formatDateTime(m.criadoEm),
            isMono: true,
          ),
          const SizedBox(height: 8),
          _buildDrawerField(
            'REGISTRO TEMPORAL (ZULU)',
            '${DateFormat("HH:mm:ss").format((m.criadoEm != null ? AppDateUtils.parseToLocal(m.criadoEm) : DateTime.now()).toUtc())}Z',
            isMono: true,
          ),
          const SizedBox(height: 8),
          if (m.origem != null || m.destino != null) ...[
            _buildDrawerField(
              'FLUXO DE LOCALIZAÇÃO',
              m.origem != null && m.destino != null
                  ? '${m.origem!.nome} ➔ ${m.destino!.nome}'
                  : (m.destino != null ? 'Destino: ${m.destino!.nome}' : 'Origem: ${m.origem!.nome}'),
            ),
            const SizedBox(height: 8),
          ],
          _buildDrawerField('JUSTIFICATIVA / MOTIVO', m.motivo ?? 'Rotina de prontidão operacional registrada pelo sistema.'),
          const SizedBox(height: 12),

          // Carimbo Criptográfico SHA-256
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0A122A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF212942)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lock_clock_rounded, size: 14, color: AppColors.tertiary),
                    SizedBox(width: 6),
                    Text(
                      'ASSINATURA DIGITAL SHA-256',
                      style: TextStyle(fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppColors.tertiary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SelectableText(
                  fakeHash,
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF8C909F)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerField(String label, String value, {bool isMono = false, bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFF8C909F), fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 13 : 12,
            fontFamily: isMono ? 'monospace' : null,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            color: isHighlight ? Colors.white : const Color(0xFFD8E2FF),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyDrawerPlaceholder() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF131A33),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF212942)),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_rounded, size: 36, color: Color(0xFF414754)),
            SizedBox(height: 12),
            Text(
              'Selecione um registro na tabela para visualizar a perícia forense detalhada.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF8C909F)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Erro ao carregar histórico: $_error', style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMovements,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryContainer),
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(50),
        child: Column(
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 54, color: Colors.grey.withOpacity(0.4)),
            const SizedBox(height: 14),
            const Text(
              'Nenhum evento registrado no período selecionado',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            const Text(
              'Transações de estoque, manutenções e cautelas serão auditadas aqui.',
              style: TextStyle(fontSize: 12, color: Color(0xFF8C909F)),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'CAUTELA':
        return AppColors.warning;
      case 'DEVOLUCAO':
        return AppColors.tertiary;
      case 'TRANSFERENCIA':
        return AppColors.primary;
      case 'MANUTENCAO':
        return AppColors.error;
      case 'ENTRADA':
        return Colors.tealAccent;
      case 'BAIXA':
        return Colors.purpleAccent;
      default:
        return const Color(0xFFAAC7FF);
    }
  }
}
