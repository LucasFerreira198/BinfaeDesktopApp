import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/cautela.dart';
import '../models/item.dart';
import '../providers/auth_provider.dart';
import '../providers/stock_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../widgets/metric_card.dart';
import '../widgets/cautela_detail_dialog.dart';
import '../widgets/item_detail_dialog.dart';

class HomeDashboardView extends StatefulWidget {
  final Function(int tabIndex, {String? statusFilter}) onNavigate;
  final VoidCallback onNewItem;
  final VoidCallback onNewCautela;

  const HomeDashboardView({
    super.key,
    required this.onNavigate,
    required this.onNewItem,
    required this.onNewCautela,
  });

  @override
  State<HomeDashboardView> createState() => _HomeDashboardViewState();
}

class _HomeDashboardViewState extends State<HomeDashboardView> {
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  List<CautelaModel> _recentCautelas = [];
  List<ItemMovementModel> _recentMovements = [];
  bool _isLoadingActivities = true;

  @override
  void initState() {
    super.initState();
    _startClock();
    _loadDashboardActivities();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  Future<void> _loadDashboardActivities() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final results = await Future.wait([
        api.listCautelas(status: 'ATIVA').catchError((_) => <CautelaModel>[]),
        api.fetchMovements().catchError((_) => <ItemMovementModel>[]),
      ]);

      if (mounted) {
        setState(() {
          _recentCautelas = (results[0] as List<CautelaModel>).take(5).toList();
          _recentMovements = (results[1] as List<ItemMovementModel>).take(6).toList();
          _isLoadingActivities = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingActivities = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stock = Provider.of<StockProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    final metrics = stock.metrics;
    final groups = stock.groups;
    final allItems = stock.allItems;

    final formattedTime = DateFormat('HH:mm:ss').format(_currentTime);
    final formattedDate = AppDateUtils.formatDateLong(_currentTime);

    return RefreshIndicator(
      onRefresh: () async {
        await stock.syncData();
        await _loadDashboardActivities();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. BANNER MILITAR PRINCIPAL DE BOAS-VINDAS & RELÓGIO OFICIAL
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
                      : [const Color(0xFF4338CA), const Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? Colors.black : const Color(0xFF4338CA)).withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Ícone de Comando com Glow
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                    ),
                    child: const Icon(Icons.shield, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 18),

                  // Identificação do Usuário e Seção
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Centro de Operações de TI',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.85),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.25),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.6)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Text(
                                    'Vercel SP • Online',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bem-vindo(a), ${user != null ? "${user.postoGraduacao ?? ''} ${user.nomeGuerra ?? user.nomeCompleto}".trim() : "Operador"}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Gestão de Patrimônio e Logística de Informática • BINFAE-GL',
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                        ),
                      ],
                    ),
                  ),

                  // Relógio Digital em Tempo Real (Brasília UTC-3)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule, color: Color(0xFF38BDF8), size: 16),
                            const SizedBox(width: 8),
                            Text(
                              formattedTime,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                fontFamily: 'monospace',
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Horário de Brasília (UTC-3)',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF38BDF8).withOpacity(0.9),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 2. CARDS DE MÉTRICAS OPERACIONAIS (KPIS CLICÁVEIS)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  MetricCard(
                    label: 'Total de Materiais',
                    count: metrics.total,
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.primary,
                    bgColor: AppColors.primary.withOpacity(0.15),
                    isActive: false,
                    onTap: () => widget.onNavigate(1), // Vai para Estoque completo
                  ),
                  const SizedBox(width: 12),
                  MetricCard(
                    label: 'Disponíveis',
                    count: metrics.disponivel,
                    icon: Icons.check_circle_outline,
                    color: AppColors.success,
                    bgColor: AppColors.success.withOpacity(0.15),
                    isActive: false,
                    onTap: () => widget.onNavigate(1, statusFilter: 'DISPONIVEL'),
                  ),
                  const SizedBox(width: 12),
                  MetricCard(
                    label: 'Cautelados (Em Missão)',
                    count: metrics.cautelado,
                    icon: Icons.schedule,
                    color: AppColors.warning,
                    bgColor: AppColors.warning.withOpacity(0.15),
                    isActive: false,
                    onTap: () => widget.onNavigate(2), // Vai para Cautelas
                  ),
                  const SizedBox(width: 12),
                  MetricCard(
                    label: 'Em Manutenção',
                    count: metrics.manutencao,
                    icon: Icons.build_outlined,
                    color: Colors.orange,
                    bgColor: Colors.orange.withOpacity(0.15),
                    isActive: false,
                    onTap: () => widget.onNavigate(1, statusFilter: 'EM_MANUTENCAO'),
                  ),
                  const SizedBox(width: 12),
                  MetricCard(
                    label: 'Baixo Estoque',
                    count: metrics.baixoEstoque,
                    icon: Icons.warning_amber_outlined,
                    color: AppColors.danger,
                    bgColor: AppColors.danger.withOpacity(0.15),
                    isActive: false,
                    onTap: () => widget.onNavigate(1),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. BARRA DE AÇÕES RÁPIDAS (ATALHOS DE 1 CLIQUE)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151D2F) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Ações Rápidas:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.rocket_launch, size: 16),
                    label: const Text('Nova Cautela / Missão', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: widget.onNewCautela,
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 16),
                    label: const Text('Cadastrar Material', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    onPressed: widget.onNewItem,
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.inventory_2_outlined, size: 16),
                    label: const Text('Ver Estoque Completo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    onPressed: () => widget.onNavigate(1),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text('Histórico de Movimentações', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    onPressed: () => widget.onNavigate(5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 4. GRID PRINCIPAL COM DUAS COLUNAS: MISSÕES ATIVAS + ATIVIDADES RECENTES
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coluna Esquerda: Missões e Cautelas em Andamento
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151D2F) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.assignment_turned_in, size: 18, color: AppColors.primaryLight),
                                const SizedBox(width: 8),
                                const Text(
                                  'Missões e Cautelas Ativas',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_recentCautelas.length} ativas',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                                  ),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: () => widget.onNavigate(2),
                              icon: const Icon(Icons.arrow_forward, size: 14),
                              label: const Text('Ver todas', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        const Divider(height: 20),

                        if (_isLoadingActivities)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_recentCautelas.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.check_circle_outline, size: 42, color: Colors.grey.withOpacity(0.4)),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Nenhuma missão ativa no momento.',
                                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Todos os materiais estão recolhidos no depósito.',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _recentCautelas.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, i) {
                              final c = _recentCautelas[i];
                              final isMission = c.tipo == 'MISSAO';
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isMission ? AppColors.primary.withOpacity(0.15) : Colors.teal.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        isMission ? Icons.rocket_launch : Icons.lock_outline,
                                        size: 18,
                                        color: isMission ? AppColors.primaryLight : Colors.teal,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.nome,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Text(
                                                '${c.itensCautelados} material(is) pendente(s)',
                                                style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600),
                                              ),
                                              const SizedBox(width: 8),
                                              Text('•', style: TextStyle(color: isDark ? Colors.white30 : Colors.black26)),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Saída: ${AppDateUtils.formatDateTime(c.dataInicio)}',
                                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => CautelaDetailDialog(
                                            cautela: c,
                                            onUpdated: _loadDashboardActivities,
                                          ),
                                        ).then((_) => _loadDashboardActivities());
                                      },
                                      child: const Text('Detalhes', style: TextStyle(fontSize: 11)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                // Coluna Direita: Atividades Recentes do Estoque (Histórico em Tempo Real)
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151D2F) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.history, size: 18, color: Color(0xFF38BDF8)),
                                const SizedBox(width: 8),
                                const Text(
                                  'Atividades Recentes no Estoque',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: () => widget.onNavigate(5),
                              icon: const Icon(Icons.arrow_forward, size: 14),
                              label: const Text('Ver histórico', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        const Divider(height: 20),

                        if (_isLoadingActivities)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_recentMovements.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.history_toggle_off, size: 42, color: Colors.grey.withOpacity(0.4)),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Nenhuma movimentação registrada recentemente.',
                                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _recentMovements.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, i) {
                              final m = _recentMovements[i];
                              Color badgeColor;
                              switch (m.tipoMovimentacao.toUpperCase()) {
                                case 'TRANSFERENCIA':
                                  badgeColor = const Color(0xFF3B82F6);
                                  break;
                                case 'DEVOLUCAO':
                                  badgeColor = AppColors.success;
                                  break;
                                case 'SAIDA_SALDO':
                                  badgeColor = AppColors.danger;
                                  break;
                                case 'INSTALACAO':
                                  badgeColor = AppColors.primary;
                                  break;
                                default:
                                  badgeColor = Colors.grey;
                              }

                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        m.tipoMovimentacao,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: badgeColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            m.itemNome ?? 'Material #${m.itemId}',
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            m.motivo ?? (m.destino != null ? "Para: ${m.destino!.nome}" : "Operação concluída"),
                                            style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      AppDateUtils.formatDateTime(m.criadoEm),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 5. DISTRIBUIÇÃO DO ESTOQUE POR GRUPOS / CATEGORIAS
            if (groups.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151D2F) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.pie_chart_outline, size: 18, color: AppColors.primaryLight),
                            SizedBox(width: 8),
                            Text(
                              'Composição do Acervo de Informática por Grupos',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => widget.onNavigate(4), // Vai para Grupos
                          child: const Text('Gerenciar Categorias', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    Wrap(
                      spacing: 16,
                      runSpacing: 14,
                      children: groups.map((g) {
                        final count = allItems.where((it) => it.subgrupo?.grupoId == g.id).length;
                        final percent = allItems.isEmpty ? 0.0 : (count / allItems.length);

                        return Container(
                          width: 220,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      g.nome,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '$count itens',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percent,
                                  minHeight: 6,
                                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(percent * 100).toStringAsFixed(1)}% do estoque total',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
