import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/stock_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/metric_card.dart';
import '../widgets/item_detail_dialog.dart';
import '../widgets/movement_dialog.dart';

class StockView extends StatefulWidget {
  const StockView({super.key});

  @override
  State<StockView> createState() => _StockViewState();
}

class _StockViewState extends State<StockView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stock = Provider.of<StockProvider>(context);

    final metrics = stock.metrics;
    final items = stock.filteredItems;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Faixa Compacta de Métricas (0ms de resposta)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                MetricCard(
                  label: 'Total',
                  count: metrics.total,
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.primary,
                  bgColor: AppColors.primary.withOpacity(0.12),
                  isActive: stock.selectedStatus == null && !stock.lowStockOnly,
                  onTap: () => stock.clearFilters(),
                ),
                const SizedBox(width: 12),
                MetricCard(
                  label: 'Disponíveis',
                  count: metrics.disponivel,
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                  bgColor: AppColors.success.withOpacity(0.12),
                  isActive: stock.selectedStatus == 'DISPONIVEL',
                  onTap: () => stock.setStatus('DISPONIVEL'),
                ),
                const SizedBox(width: 12),
                MetricCard(
                  label: 'Cautelados',
                  count: metrics.cautelado,
                  icon: Icons.schedule,
                  color: AppColors.warning,
                  bgColor: AppColors.warning.withOpacity(0.12),
                  isActive: stock.selectedStatus == 'CAUTELADO',
                  onTap: () => stock.setStatus('CAUTELADO'),
                ),
                const SizedBox(width: 12),
                MetricCard(
                  label: 'Manutenção',
                  count: metrics.manutencao,
                  icon: Icons.build_outlined,
                  color: AppColors.danger,
                  bgColor: AppColors.danger.withOpacity(0.12),
                  isActive: stock.selectedStatus == 'EM_MANUTENCAO',
                  onTap: () => stock.setStatus('EM_MANUTENCAO'),
                ),
                const SizedBox(width: 12),
                MetricCard(
                  label: 'Estoque Baixo',
                  count: metrics.baixoEstoque,
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFEC4899),
                  bgColor: const Color(0xFFEC4899).withOpacity(0.12),
                  isActive: stock.lowStockOnly,
                  onTap: () => stock.toggleLowStockOnly(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Barra de Busca e Filtros Instantâneos em 0ms
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => stock.setSearch(val),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome do material, BMP, código interno, serial...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              stock.setSearch('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF151D2F) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => stock.syncData(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: stock.isSyncing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 18),
                label: Text(stock.isSyncing ? 'Sincronizando...' : 'Atualizar'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Chips de Filtro
          Row(
            children: [
              _buildFilterChip(context, 'Todos', stock.selectedStatus == null && !stock.lowStockOnly, () => stock.clearFilters()),
              const SizedBox(width: 8),
              _buildFilterChip(context, 'Disponíveis', stock.selectedStatus == 'DISPONIVEL', () => stock.setStatus('DISPONIVEL')),
              const SizedBox(width: 8),
              _buildFilterChip(context, 'Cautelados', stock.selectedStatus == 'CAUTELADO', () => stock.setStatus('CAUTELADO')),
              const SizedBox(width: 8),
              _buildFilterChip(context, 'Manutenção', stock.selectedStatus == 'EM_MANUTENCAO', () => stock.setStatus('EM_MANUTENCAO')),
              const Spacer(),
              Text(
                '${items.length} ${items.length == 1 ? "material encontrado" : "materiais encontrados"} (0ms)',
                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Tabela de Materiais Virtualizada de Alta Performance
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        const Text('Nenhum material encontrado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Tente buscar por outro termo ou limpar os filtros.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151D2F) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFF1F5F9),
                        ),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _buildItemRow(context, item, isDark);
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, bool active, VoidCallback onTap) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : (isDark ? const Color(0xFF1F293D) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, ItemModel item, bool isDark) {
    final statusColor = _getStatusColor(item.status);

    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => ItemDetailDialog(item: item),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Identificador BMP ou Código
            Container(
              width: 80,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: item.bmp != null
                    ? AppColors.primary.withOpacity(0.12)
                    : (isDark ? const Color(0xFF1F293D) : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.bmp != null ? 'BMP ${item.bmp}' : (item.codigoInterno ?? 'ID #${item.id}'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: item.bmp != null ? AppColors.primaryLight : Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Nome e Subgrupo
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nome,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.subgrupo?.nome ?? "Geral"} • ${item.local?.caminhoCompleto ?? item.local?.nome ?? "Sem local"}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(width: 20),

            // Quantidade
            SizedBox(
              width: 100,
              child: Text(
                '${item.quantidade} ${item.unidadeMedida.toLowerCase()}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),

            // Ações Rápidas
            IconButton(
              icon: const Icon(Icons.swap_horiz, size: 20),
              tooltip: 'Movimentar / Cautelar',
              color: AppColors.primary,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => MovementDialog(item: item),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              tooltip: 'Detalhes',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => ItemDetailDialog(item: item),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'DISPONIVEL':
        return AppColors.success;
      case 'CAUTELADO':
        return AppColors.warning;
      case 'EM_MANUTENCAO':
        return AppColors.danger;
      default:
        return AppColors.info;
    }
  }
}
