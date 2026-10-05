import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/stock_provider.dart';
import '../theme/app_theme.dart';
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

    final items = stock.filteredItems;
    final groups = stock.groups;
    final filteredSubgroups = stock.selectedGroupId != null
        ? stock.subgroups.where((s) => s.grupoId == stock.selectedGroupId).toList()
        : stock.subgroups;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. HEADER LOGISTICS PRO: TÍTULO, SUBTÍTULO & AÇÕES RÁPIDAS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Materiais e Gestão de Estoque',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${stock.allItems.length} itens registrados no acervo de informática',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),

              // Botões de Ação (+ Novo Material & Importar/Exportar)
              Row(
                children: [
                  // Busca Rápida no Topo
                  SizedBox(
                    width: 280,
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      onChanged: (val) => stock.setSearch(val),
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nome, BMP, serial...',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                        prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.cyan),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  stock.setSearch('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF151D2A) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.cyan, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Botão Ciano "+ Novo Material"
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => const ItemFormDialog(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cyan,
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.add, size: 18, color: Color(0xFF0F172A)),
                    label: const Text(
                      'Novo Material',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Botão Outline "Sincronizar"
                  OutlinedButton.icon(
                    onPressed: stock.isSyncing ? null : () => stock.syncData(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: isDark ? const Color(0xFF232B3E) : const Color(0xFFCBD5E1)),
                    ),
                    icon: stock.isSyncing
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sync, size: 16),
                    label: const Text('Sincronizar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 2. FILTROS RÁPIDOS EM CHIPS (Todos, Disponíveis, Cautelados, Manutenção + Grupos)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildPillChip('Todos', stock.selectedStatus == null && !stock.lowStockOnly, () => stock.clearFilters(), isDark),
                  const SizedBox(width: 8),
                  _buildPillChip('Disponíveis', stock.selectedStatus == 'DISPONIVEL', () => stock.setStatus('DISPONIVEL'), isDark),
                  const SizedBox(width: 8),
                  _buildPillChip('Cautelados', stock.selectedStatus == 'CAUTELADO', () => stock.setStatus('CAUTELADO'), isDark),
                  const SizedBox(width: 8),
                  _buildPillChip('Manutenção', stock.selectedStatus == 'EM_MANUTENCAO', () => stock.setStatus('EM_MANUTENCAO'), isDark),
                  const SizedBox(width: 8),
                  _buildPillChip('Baixo Estoque', stock.lowStockOnly, () => stock.toggleLowStockOnly(), isDark),
                ],
              ),

              // Dropdowns de Grupo e Subgrupo
              Row(
                children: [
                  // Dropdown Grupo
                  DropdownButtonHideUnderline(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF151D2A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButton<int?>(
                        value: stock.selectedGroupId,
                        isDense: true,
                        hint: const Text('Grupo: Todos', style: TextStyle(fontSize: 11)),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Grupo: Todos', style: TextStyle(fontSize: 11))),
                          ...groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.nome, style: const TextStyle(fontSize: 11)))),
                        ],
                        onChanged: (v) => stock.setGroup(v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Dropdown Subgrupo
                  DropdownButtonHideUnderline(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF151D2A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButton<int?>(
                        value: stock.selectedSubgroupId,
                        isDense: true,
                        hint: const Text('Subgrupo: Todos', style: TextStyle(fontSize: 11)),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Subgrupo: Todos', style: TextStyle(fontSize: 11))),
                          ...filteredSubgroups.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nome, style: const TextStyle(fontSize: 11)))),
                        ],
                        onChanged: (v) => stock.setSubgroup(v),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 3. TABELA DE ESTOQUE MODERNA (ESTILO LOGISTICS PRO)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151D2A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  // Cabeçalho da Tabela
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF101520) : const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 48, child: Text('FOTO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                        const SizedBox(width: 14),
                        const Expanded(flex: 4, child: Text('NOME DO MATERIAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                        const SizedBox(width: 110, child: Text('BMP / PATRIMÔNIO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                        const SizedBox(width: 120, child: Text('CATEGORIA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                        const SizedBox(width: 130, child: Text('QUANTIDADE / NÍVEL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                        const Expanded(flex: 3, child: Text('LOCALIZAÇÃO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                        const SizedBox(width: 110, child: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                        const SizedBox(width: 90, child: Text('AÇÕES', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                      ],
                    ),
                  ),

                  // Lista de Linhas
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.withOpacity(0.4)),
                                const SizedBox(height: 12),
                                const Text('Nenhum material localizado no acervo.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 4),
                                const Text('Tente buscar por outro termo ou limpe os filtros.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: isDark ? const Color(0xFF1E2838) : const Color(0xFFF1F5F9),
                            ),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return _LogisticsProRow(
                                item: item,
                                isDark: isDark,
                              );
                            },
                          ),
                  ),

                  // Rodapé de Paginação
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF101520) : const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      border: Border(
                        top: BorderSide(
                          color: isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mostrando ${items.length} de ${stock.allItems.length} materiais cadastrados',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        Row(
                          children: [
                            const Text('Página 1 de 1', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.chevron_left, size: 18),
                              onPressed: null,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, size: 18),
                              onPressed: null,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillChip(String label, bool active, VoidCallback onTap, bool isDark) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? (isDark ? AppColors.cyan.withOpacity(0.15) : const Color(0xFFE6FFFA))
                : (isDark ? const Color(0xFF151D2A) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? AppColors.cyan : (isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
              color: active ? AppColors.cyan : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }
}

// Linha da Tabela de Estoque Estilo Logistics Pro
class _LogisticsProRow extends StatefulWidget {
  final ItemModel item;
  final bool isDark;

  const _LogisticsProRow({required this.item, required this.isDark});

  @override
  State<_LogisticsProRow> createState() => _LogisticsProRowState();
}

class _LogisticsProRowState extends State<_LogisticsProRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDark = widget.isDark;

    Color statusColor;
    String statusText;
    switch (item.status.toUpperCase()) {
      case 'DISPONIVEL':
        statusColor = AppColors.success;
        statusText = 'Disponível';
        break;
      case 'CAUTELADO':
        statusColor = AppColors.cyan;
        statusText = 'Cautelado';
        break;
      case 'EM_MANUTENCAO':
        statusColor = AppColors.warning;
        statusText = 'Manutenção';
        break;
      default:
        statusColor = AppColors.danger;
        statusText = item.status;
    }

    final double ratio = item.quantidadeEstoqueMinimo != null && item.quantidadeEstoqueMinimo! > 0
        ? (item.quantidade / (item.quantidadeEstoqueMinimo! * 3)).clamp(0.05, 1.0)
        : (item.quantidade > 0 ? 0.95 : 0.0);

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
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: _isHovered
              ? (isDark ? const Color(0xFF1B2438) : const Color(0xFFF8FAFC))
              : Colors.transparent,
          child: Row(
            children: [
              // Miniatura do Material
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0E121B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Center(
                  child: Icon(
                    _getItemIcon(item.nome),
                    size: 18,
                    color: _isHovered ? AppColors.cyan : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Nome do Material
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nome,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.observacoes != null && item.observacoes!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.observacoes!,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // BMP / Patrimônio Militar
              SizedBox(
                width: 110,
                child: Text(
                  item.bmp != null ? 'BMP-${item.bmp}' : (item.codigoInterno ?? '-'),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cyan,
                    fontFamily: 'monospace',
                  ),
                ),
              ),

              // Categoria / Subgrupo
              SizedBox(
                width: 120,
                child: Text(
                  item.subgrupo?.nome ?? 'Geral',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Nível de Estoque com Mini Barra de Progresso
              SizedBox(
                width: 130,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${item.quantidade} ${item.unidadeMedida.toLowerCase()}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 5,
                        backgroundColor: isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          item.quantidade <= (item.quantidadeEstoqueMinimo ?? 0)
                              ? AppColors.warning
                              : AppColors.cyan,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Localização Física
              Expanded(
                flex: 3,
                child: Text(
                  item.local?.nome ?? 'Depósito Geral',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Status Badge
              SizedBox(
                width: 110,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
              ),

              // Ações Rápidas
              SizedBox(
                width: 90,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      tooltip: 'Transferir / Movimentar',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => MovementDialog(item: item),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      tooltip: 'Editar',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => ItemFormDialog(item: item),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      tooltip: 'Detalhes & QR Code',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
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
            ],
          ),
        ),
      ),
    );
  }

  IconData _getItemIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('optiplex') || lower.contains('computador') || lower.contains('desktop') || lower.contains('pc')) {
      return Icons.computer;
    } else if (lower.contains('notebook') || lower.contains('laptop') || lower.contains('dell')) {
      return Icons.laptop_chromebook;
    } else if (lower.contains('monitor') || lower.contains('tela')) {
      return Icons.desktop_windows_outlined;
    } else if (lower.contains('switch') || lower.contains('roteador') || lower.contains('cisco')) {
      return Icons.router_outlined;
    } else if (lower.contains('nobreak') || lower.contains('apc') || lower.contains('ups')) {
      return Icons.battery_charging_full_outlined;
    } else if (lower.contains('rádio') || lower.contains('ht') || lower.contains('motorola')) {
      return Icons.settings_remote_outlined;
    }
    return Icons.devices_other;
  }
}
