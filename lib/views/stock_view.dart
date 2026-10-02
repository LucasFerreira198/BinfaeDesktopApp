import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/stock_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/metric_card.dart';
import '../widgets/item_detail_dialog.dart';
import '../widgets/movement_dialog.dart';
import '../widgets/item_form_dialog.dart';

class StockView extends StatefulWidget {
  final FocusNode? searchFocusNode;

  const StockView({super.key, this.searchFocusNode});

  @override
  State<StockView> createState() => _StockViewState();
}

class _StockViewState extends State<StockView> {
  final TextEditingController _searchController = TextEditingController();
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.searchFocusNode ?? FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (widget.searchFocusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stock = Provider.of<StockProvider>(context);

    final metrics = stock.metrics;
    final items = stock.filteredItems;

    final selectedLocation = stock.selectedLocationId != null
        ? stock.getLocationById(stock.selectedLocationId!)
        : null;

    final groups = stock.groups;
    final filteredSubgroups = stock.selectedGroupId != null
        ? stock.subgroups.where((s) => s.grupoId == stock.selectedGroupId).toList()
        : stock.subgroups;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Faixa de Métricas Instantâneas (0ms de resposta da RAM)
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
          const SizedBox(height: 18),

          // 2. Barra de Busca, Ações e Cascata de Filtros
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  onChanged: (val) => stock.setSearch(val),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome, BMP, código interno, serial ou observação... (Ctrl+F)',
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

              // Botão [+ Novo Material]
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const ItemFormDialog(),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_box_outlined, size: 18),
                label: const Text('Novo Material (Ctrl+N)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),

              // Botão Sincronizar
              IconButton(
                onPressed: stock.isSyncing ? null : () => stock.syncData(),
                tooltip: 'Sincronizar dados com o servidor (F5)',
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: stock.isSyncing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Linha de Filtros Combinados (Status, Grupo, Subgrupo, Local)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Todos', stock.selectedStatus == null && !stock.lowStockOnly, () => stock.clearFilters(), isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Disponíveis', stock.selectedStatus == 'DISPONIVEL', () => stock.setStatus('DISPONIVEL'), isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Cautelados', stock.selectedStatus == 'CAUTELADO', () => stock.setStatus('CAUTELADO'), isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Manutenção', stock.selectedStatus == 'EM_MANUTENCAO', () => stock.setStatus('EM_MANUTENCAO'), isDark),
                const SizedBox(width: 16),

                // Filtro Grupo
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButton<int?>(
                      value: stock.selectedGroupId,
                      hint: const Text('Grupo: Todos', style: TextStyle(fontSize: 12)),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Grupo: Todos', style: TextStyle(fontSize: 12))),
                        ...groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.nome, style: const TextStyle(fontSize: 12)))),
                      ],
                      onChanged: (v) => stock.setGroup(v),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Filtro Subgrupo
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButton<int?>(
                      value: stock.selectedSubgroupId,
                      hint: const Text('Subgrupo: Todos', style: TextStyle(fontSize: 12)),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Subgrupo: Todos', style: TextStyle(fontSize: 12))),
                        ...filteredSubgroups.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nome, style: const TextStyle(fontSize: 12)))),
                      ],
                      onChanged: (v) => stock.setSubgroup(v),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Filtro Local
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButton<int?>(
                      value: stock.selectedLocationId,
                      hint: const Text('Local: Todos', style: TextStyle(fontSize: 12)),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Local: Todos', style: TextStyle(fontSize: 12))),
                        ...stock.locations.map((loc) => DropdownMenuItem(
                              value: loc.id,
                              child: Text(loc.caminhoCompleto ?? loc.nome, style: const TextStyle(fontSize: 12)),
                            )),
                      ],
                      onChanged: (v) => stock.setLocation(v),
                    ),
                  ),
                ),

                // Chip Local Ativo com limpeza
                if (selectedLocation != null) ...[
                  const SizedBox(width: 8),
                  InputChip(
                    label: Text(selectedLocation.nome, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    avatar: const Icon(Icons.place, size: 14, color: AppColors.primary),
                    onDeleted: () => stock.clearLocationFilter(),
                    deleteIconColor: Colors.grey,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Contador de Resultados
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${items.length} ${items.length == 1 ? "material listado" : "materiais listados"} (consulta em 0ms)',
                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B)),
              ),
              if (stock.searchQuery.isNotEmpty || stock.selectedStatus != null || stock.selectedGroupId != null || stock.selectedLocationId != null || stock.lowStockOnly)
                TextButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    stock.clearFilters();
                  },
                  icon: const Icon(Icons.filter_alt_off, size: 14),
                  label: const Text('Limpar Filtros', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // 3. Tabela de Materiais Avançada com Comportamento Contextual de Busca Vazia
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.withOpacity(0.5)),
                        const SizedBox(height: 14),
                        Text(
                          selectedLocation != null
                              ? 'Nenhum material encontrado no(a) ${selectedLocation.caminhoCompleto ?? selectedLocation.nome}'
                              : 'Nenhum material encontrado',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        if (selectedLocation != null) ...[
                          const Text('Não há materiais com esses critérios armazenados nesta localização específica.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => stock.clearLocationFilter(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.search, size: 16),
                            label: const Text('Sair deste local e pesquisar em todos os estoques'),
                          ),
                        ] else ...[
                          const Text('Tente buscar por outro termo, código interno ou limpe os filtros ativos.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ],
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151D2F) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
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

  Widget _buildFilterChip(String label, bool active, VoidCallback onTap, bool isDark) {
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
              width: 86,
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

            // Nome e Hierarquia (Local + Subgrupo)
            Expanded(
              flex: 4,
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
                    '${item.subgrupo?.nome ?? "Geral"} • 📍 ${item.local?.caminhoCompleto ?? item.local?.nome ?? "Sem local físico"}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            // Estado de Conservação
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.estadoConservacao.replaceAll('_', ' '),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Status Badge
            Container(
              width: 100,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              alignment: Alignment.center,
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

            // Saldo Atual
            SizedBox(
              width: 90,
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
              tooltip: 'Movimentar / Transferir',
              color: AppColors.primary,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => MovementDialog(item: item),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Editar Material',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => ItemFormDialog(item: item),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              tooltip: 'Detalhes e QR Code',
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
    switch (status.toUpperCase()) {
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
