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
          // 1. Contadores de Resumo (5 Cartões 3D com Hover Glow e Micro-interações)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                MetricCard(
                  label: 'Total',
                  count: metrics.total,
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.primary,
                  bgColor: AppColors.primary.withOpacity(0.15),
                  isActive: stock.selectedStatus == null && !stock.lowStockOnly,
                  onTap: () => stock.clearFilters(),
                ),
                const SizedBox(width: 12),
                MetricCard(
                  label: 'Disponíveis',
                  count: metrics.disponivel,
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                  bgColor: AppColors.success.withOpacity(0.15),
                  isActive: stock.selectedStatus == 'DISPONIVEL',
                  onTap: () => stock.setStatus('DISPONIVEL'),
                ),
                const SizedBox(width: 12),
                MetricCard(
                  label: 'Cautelados',
                  count: metrics.cautelado,
                  icon: Icons.schedule,
                  color: AppColors.warning,
                  bgColor: AppColors.warning.withOpacity(0.15),
                  isActive: stock.selectedStatus == 'CAUTELADO',
                  onTap: () => stock.setStatus('CAUTELADO'),
                ),
                const SizedBox(width: 12),
                MetricCard(
                  label: 'Manutenção',
                  count: metrics.manutencao,
                  icon: Icons.build_outlined,
                  color: AppColors.maintenance,
                  bgColor: AppColors.maintenance.withOpacity(0.15),
                  isActive: stock.selectedStatus == 'EM_MANUTENCAO',
                  onTap: () => stock.setStatus('EM_MANUTENCAO'),
                ),
                const SizedBox(width: 12),
                MetricCard(
                  label: 'Estoque Baixo',
                  count: metrics.baixoEstoque,
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.danger,
                  bgColor: AppColors.danger.withOpacity(0.15),
                  isActive: stock.lowStockOnly,
                  onTap: () => stock.toggleLowStockOnly(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Painel: Visão Geral da Localização com Mini-dashboards Rápidos
          _buildLocationOverviewPanel(stock, isDark),
          const SizedBox(height: 16),

          // 3. Barra de Pesquisa, Ações e Filtros
          Row(
            children: [
              // Barra de Pesquisa Clean (Ctrl+F)
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  onChanged: (val) => stock.setSearch(val),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome, BMP, código interno, serial ou observação... (Ctrl+F)',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primaryLight),
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
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Botão [+ Novo Material (Ctrl+N)] Roxo Proeminente
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                  shadowColor: AppColors.primary.withOpacity(0.4),
                ),
                icon: const Icon(Icons.add_box_outlined, size: 18),
                label: const Text('+ Novo Material (Ctrl+N)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 10),

              // Botão Sincronizar Menor (F5)
              IconButton(
                onPressed: stock.isSyncing ? null : () => stock.syncData(),
                tooltip: 'Sincronizar dados (F5)',
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

          // 4. Linha de Filtros Combinados (Chips de Status e Dropdowns)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusFilterChip('Todos', stock.selectedStatus == null && !stock.lowStockOnly, null, () => stock.clearFilters(), isDark),
                const SizedBox(width: 8),
                _buildStatusFilterChip('Disponíveis', stock.selectedStatus == 'DISPONIVEL', AppColors.success, () => stock.setStatus('DISPONIVEL'), isDark),
                const SizedBox(width: 8),
                _buildStatusFilterChip('Cautelados', stock.selectedStatus == 'CAUTELADO', AppColors.warning, () => stock.setStatus('CAUTELADO'), isDark),
                const SizedBox(width: 8),
                _buildStatusFilterChip('Manutenção', stock.selectedStatus == 'EM_MANUTENCAO', AppColors.maintenance, () => stock.setStatus('EM_MANUTENCAO'), isDark),
                const SizedBox(width: 16),

                // Filtro Grupo
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151D2F) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.category_outlined, size: 15, color: AppColors.primaryLight),
                        const SizedBox(width: 6),
                        DropdownButton<int?>(
                          value: stock.selectedGroupId,
                          isDense: true,
                          hint: const Text('Grupo: Todos', style: TextStyle(fontSize: 12)),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Grupo: Todos', style: TextStyle(fontSize: 12))),
                            ...groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.nome, style: const TextStyle(fontSize: 12)))),
                          ],
                          onChanged: (v) => stock.setGroup(v),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Filtro Subgrupo
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151D2F) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_tree_outlined, size: 15, color: AppColors.primaryLight),
                        const SizedBox(width: 6),
                        DropdownButton<int?>(
                          value: stock.selectedSubgroupId,
                          isDense: true,
                          hint: const Text('Subgrupo: Todos', style: TextStyle(fontSize: 12)),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Subgrupo: Todos', style: TextStyle(fontSize: 12))),
                            ...filteredSubgroups.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nome, style: const TextStyle(fontSize: 12)))),
                          ],
                          onChanged: (v) => stock.setSubgroup(v),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Filtro Local
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151D2F) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.place_outlined, size: 15, color: AppColors.primaryLight),
                        const SizedBox(width: 6),
                        DropdownButton<int?>(
                          value: stock.selectedLocationId,
                          isDense: true,
                          hint: const Text('Local: Todos', style: TextStyle(fontSize: 12)),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Local: Todos', style: TextStyle(fontSize: 12))),
                            ...stock.locations.map((loc) => DropdownMenuItem(
                                  value: loc.id,
                                  child: Text(_formatLocationTree(loc.caminhoCompleto ?? loc.nome), style: const TextStyle(fontSize: 12)),
                                )),
                          ],
                          onChanged: (v) => stock.setLocation(v),
                        ),
                      ],
                    ),
                  ),
                ),

                // Chip Local Ativo com Botão de Limpeza Rápida
                if (selectedLocation != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryLight),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.place, size: 14, color: AppColors.primaryLight),
                        const SizedBox(width: 6),
                        Text(
                          _formatLocationTree(selectedLocation.caminhoCompleto ?? selectedLocation.nome),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => stock.clearLocationFilter(),
                          child: const Icon(Icons.close, size: 14, color: AppColors.primaryLight),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Contador de Resultados e Limpar Filtros
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${items.length} ${items.length == 1 ? "material listado" : "materiais listados"} (pesquisa instantânea em 0ms)',
                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
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
          const SizedBox(height: 8),

          // 5. Listagem de Itens Mais Rica com Miniaturas, Árvore de Localização e Mouse Hover States
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.withOpacity(0.4)),
                        const SizedBox(height: 14),
                        Text(
                          selectedLocation != null
                              ? 'Nenhum material encontrado em ${_formatLocationTree(selectedLocation.caminhoCompleto ?? selectedLocation.nome)}'
                              : 'Nenhum material localizado',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        if (selectedLocation != null) ...[
                          const Text('Não há materiais com esses critérios nesta localização específica.', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                            label: const Text('Pesquisar em todas as localizações'),
                          ),
                        ] else ...[
                          const Text('Tente buscar por outro termo, BMP, código interno ou limpe os filtros.', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                          return _ItemTableRow(
                            key: ValueKey(item.id),
                            item: item,
                            isDark: isDark,
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Painel Visão Geral da Localização com mini-dashboards rápidos
  Widget _buildLocationOverviewPanel(StockProvider stock, bool isDark) {
    final topLocations = stock.locations.take(6).toList();
    if (topLocations.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Row(
            children: [
              const Icon(Icons.insights, size: 16, color: AppColors.primaryLight),
              const SizedBox(width: 8),
              Text(
                'Visão Geral dos Locais:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: topLocations.map((loc) {
                  final isSelected = stock.selectedLocationId == loc.id;
                  final count = stock.allItems.where((it) => it.localId == loc.id).length;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          if (isSelected) {
                            stock.clearLocationFilter();
                          } else {
                            stock.setLocation(loc.id);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : (isDark ? const Color(0xFF1B243B) : Colors.white),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                loc.nome,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.2)
                                      : (isDark ? const Color(0xFF151D2F) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : AppColors.primaryLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(String label, bool active, Color? dotColor, VoidCallback onTap, bool isDark) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? AppColors.primary : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                  color: active ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatLocationTree(String path) {
    return path.replaceAll(' > ', ' ➔ ').replaceAll(' / ', ' ➔ ').replaceAll('/', ' ➔ ');
  }
}

class _ItemTableRow extends StatefulWidget {
  final ItemModel item;
  final bool isDark;

  const _ItemTableRow({super.key, required this.item, required this.isDark});

  @override
  State<_ItemTableRow> createState() => _ItemTableRowState();
}

class _ItemTableRowState extends State<_ItemTableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDark = widget.isDark;
    final statusColor = _getStatusColor(item.status);

    final rowBg = _isHovered
        ? (isDark ? const Color(0xFF1B243B) : const Color(0xFFF8FAFC))
        : Colors.transparent;

    final locationTree = item.local != null
        ? (item.local!.caminhoCompleto ?? item.local!.nome).replaceAll(' > ', ' ➔ ').replaceAll(' / ', ' ➔ ').replaceAll('/', ' ➔ ')
        : 'Sem local físico';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) => ItemDetailDialog(item: item),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: rowBg,
            border: Border(
              left: BorderSide(
                color: _isHovered ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              // Miniatura Sutil do Item / Ícone de Hardware
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF151D2F)]
                        : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isHovered ? AppColors.primaryLight.withOpacity(0.5) : (isDark ? const Color(0xFF243049) : const Color(0xFFCBD5E1)),
                  ),
                ),
                child: Center(
                  child: Icon(
                    _getItemIcon(item.nome),
                    size: 20,
                    color: _isHovered ? AppColors.primaryLight : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Identificador BMP ou Código Interno
              Container(
                width: 90,
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

              // Nome e Representação em Árvore da Localização (ex: Depósito ➔ Armário 1)
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
                    Row(
                      children: [
                        Text(
                          item.subgrupo?.nome ?? 'Geral',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('•', style: TextStyle(fontSize: 11, color: isDark ? Colors.white30 : Colors.black26)),
                        const SizedBox(width: 6),
                        const Icon(Icons.account_tree_outlined, size: 12, color: AppColors.primaryLight),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            locationTree,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                    if (item.cautelaAtiva != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amber.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.assignment_ind, size: 11, color: Colors.amber[700]),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'CAUTELADO: ${item.cautelaAtiva!.missaoNome} • Resp: ${item.cautelaAtiva!.militarPostoGraduacao} ${item.cautelaAtiva!.militarNomeGuerra}${item.cautelaAtiva!.militarCelular != null && item.cautelaAtiva!.militarCelular!.isNotEmpty ? " (Tel: ${item.cautelaAtiva!.militarCelular})" : ""}',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.amber[300] : Colors.amber[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                width: 105,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
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

              // Ações Rápidas com Tooltip
              IconButton(
                icon: const Icon(Icons.swap_horiz, size: 20),
                tooltip: 'Transferir Local',
                color: AppColors.primaryLight,
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
        return AppColors.maintenance;
      default:
        return AppColors.info;
    }
  }

  IconData _getItemIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('optiplex') || lower.contains('computador') || lower.contains('desktop') || lower.contains('pc')) {
      return Icons.computer;
    } else if (lower.contains('notebook') || lower.contains('laptop') || lower.contains('dell')) {
      return Icons.laptop_chromebook;
    } else if (lower.contains('monitor') || lower.contains('tela')) {
      return Icons.desktop_windows_outlined;
    } else if (lower.contains('impressora') || lower.contains('laser')) {
      return Icons.print_outlined;
    } else if (lower.contains('switch') || lower.contains('roteador') || lower.contains('rede')) {
      return Icons.router_outlined;
    } else if (lower.contains('teclado') || lower.contains('mouse')) {
      return Icons.keyboard_outlined;
    } else if (lower.contains('cabo')) {
      return Icons.cable;
    }
    return Icons.devices_other;
  }
}
