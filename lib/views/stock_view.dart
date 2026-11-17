import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/stock_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/item_detail_dialog.dart';
import '../widgets/movement_dialog.dart';
import '../widgets/item_form_dialog.dart';
import '../widgets/desktop_item_inspector_pane.dart';

class StockView extends StatefulWidget {
  final FocusNode? searchFocusNode;
  final void Function(int targetIndex)? onNavigate;

  const StockView({super.key, this.searchFocusNode, this.onNavigate});

  @override
  State<StockView> createState() => _StockViewState();
}

class _StockViewState extends State<StockView> {
  final TextEditingController _searchController = TextEditingController();
  late FocusNode _focusNode;
  final FocusNode _keyboardFocusNode = FocusNode();
  ItemModel? _selectedItem;
  bool _isInspectorOpen = false;

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
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleTableKey(KeyEvent event, List<ItemModel> items, double screenWidth) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (items.isEmpty) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      int currentIndex = _selectedItem == null ? -1 : items.indexWhere((i) => i.id == _selectedItem!.id);
      int nextIndex = (currentIndex + 1).clamp(0, items.length - 1);
      setState(() {
        _selectedItem = items[nextIndex];
        if (screenWidth >= 1150) {
          _isInspectorOpen = true;
        }
      });
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      int currentIndex = _selectedItem == null ? 0 : items.indexWhere((i) => i.id == _selectedItem!.id);
      int prevIndex = (currentIndex - 1).clamp(0, items.length - 1);
      setState(() {
        _selectedItem = items[prevIndex];
        if (screenWidth >= 1150) {
          _isInspectorOpen = true;
        }
      });
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_isInspectorOpen) {
        setState(() {
          _isInspectorOpen = false;
        });
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_selectedItem != null) {
        if (screenWidth < 1150) {
          showDialog(
            context: context,
            builder: (ctx) => ItemDetailDialog(
              item: _selectedItem!,
              onNavigateView: widget.onNavigate,
            ),
          );
        } else {
          setState(() {
            _isInspectorOpen = true;
          });
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final stock = Provider.of<StockProvider>(context);
    final items = stock.filteredItems;
    final filteredSubgroups = stock.selectedGroupId != null
        ? stock.subgroups.where((s) => s.grupoId == stock.selectedGroupId).toList()
        : stock.subgroups;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =========================================================================
          // 1. TOP COMMAND & ACTION BAR (Google Stitch #09_StockView)
          // =========================================================================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outlineVariant.withOpacity(0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 980;

                final titleSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        const Icon(Icons.inventory_2, color: AppColors.primary, size: 22),
                        const Text(
                          'Catálogo de Materiais & Gestão de Estoque',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.tertiary.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.tertiary.withOpacity(0.3)),
                          ),
                          child: const Text(
                            'STOCKVIEW PRO',
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: AppColors.tertiary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Acervo Geral de TI, Comunicações Militares & Equipamentos Táticos — BINFAE-GL / FAB',
                      style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                );

                final actionButtons = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.end,
                  children: [
                    // Telemetry pills
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.tertiary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${stock.allItems.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: AppColors.tertiary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'ITENS ATIVOS',
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Sincronizar F5
                    OutlinedButton.icon(
                      onPressed: stock.isSyncing ? null : () => stock.syncData(),
                      icon: stock.isSyncing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          : const Icon(Icons.sync, size: 16, color: AppColors.primary),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Sincronizar',
                            style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text('F5', style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.outline)),
                          ),
                        ],
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainerHigh,
                        side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    // Novo Material
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => const ItemFormDialog(),
                        );
                      },
                      icon: const Icon(Icons.add_box, size: 16, color: Color(0xFF00285D)),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '+ Novo Material',
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF00285D),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'Ctrl+N',
                              style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF00285D)),
                            ),
                          ),
                        ],
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        elevation: 2,
                      ),
                    ),
                  ],
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleSection,
                      const SizedBox(height: 12),
                      actionButtons,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleSection),
                    const SizedBox(width: 16),
                    actionButtons,
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          // =========================================================================
          // 2. SEARCH & METRIC BAR (Google Stitch #09_StockView)
          // =========================================================================
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 980;

              final searchAndChips = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tactical search input
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      onChanged: (val) => stock.setSearch(val),
                      style: const TextStyle(fontSize: 12.5, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Buscar por descrição, BMP, Nº de Série, MAC Address ou Código de Barras... (Ctrl+F)',
                        hintStyle: const TextStyle(fontSize: 11.5, color: AppColors.outline),
                        prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.primary),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close, size: 16, color: AppColors.outline),
                                onPressed: () {
                                  _searchController.clear();
                                  stock.setSearch('');
                                },
                              ),
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Ctrl+F',
                                style: TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: AppColors.outline),
                              ),
                            ),
                          ],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Quick Status Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTacticalChip('Todos', '${stock.allItems.length}', stock.selectedStatus == null && !stock.lowStockOnly, AppColors.primary, () => stock.clearFilters()),
                        const SizedBox(width: 8),
                        _buildTacticalChip('No Depósito', '${stock.metrics.disponivel}', stock.selectedStatus == 'NO_DEPOSITO', AppColors.tertiary, () => stock.setStatus('NO_DEPOSITO')),
                        const SizedBox(width: 8),
                        _buildTacticalChip('No Setor', '${stock.metrics.noSetor}', stock.selectedStatus == 'NO_SETOR', AppColors.secondary, () => stock.setStatus('NO_SETOR')),
                        const SizedBox(width: 8),
                        _buildTacticalChip('Cautelado Missão', '${stock.metrics.cautelado}', stock.selectedStatus == 'CAUTELADO', AppColors.primary, () => stock.setStatus('CAUTELADO')),
                        const SizedBox(width: 8),
                        _buildTacticalChip('Em Manutenção', '${stock.metrics.manutencao}', stock.selectedStatus == 'EM_MANUTENCAO', AppColors.error, () => stock.setStatus('EM_MANUTENCAO')),
                        const SizedBox(width: 8),
                        _buildTacticalChip('Baixo Estoque', '', stock.lowStockOnly, AppColors.warning, () => stock.toggleLowStockOnly()),
                      ],
                    ),
                  ),
                ],
              );

              final dropdownFilters = Row(
                children: [
                  // Dropdown Grupo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GRUPO DE MATERIAL',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: AppColors.outline,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              value: stock.selectedGroupId,
                              isExpanded: true,
                              dropdownColor: AppColors.surfaceContainerHigh,
                              hint: const Text('Todos os Grupos', style: TextStyle(fontSize: 11.5, color: Colors.white70)),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Todos os Grupos', style: TextStyle(fontSize: 11.5, color: Colors.white))),
                                ...stock.groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.nome, style: const TextStyle(fontSize: 11.5, color: Colors.white)))),
                              ],
                              onChanged: (v) => stock.setGroup(v),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Dropdown Subgrupo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SUBGRUPO TÁTICO',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: AppColors.outline,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              value: stock.selectedSubgroupId,
                              isExpanded: true,
                              dropdownColor: AppColors.surfaceContainerHigh,
                              hint: const Text('Todos os Subgrupos', style: TextStyle(fontSize: 11.5, color: Colors.white70)),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Todos os Subgrupos', style: TextStyle(fontSize: 11.5, color: Colors.white))),
                                ...filteredSubgroups.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nome, style: const TextStyle(fontSize: 11.5, color: Colors.white)))),
                              ],
                              onChanged: (v) => stock.setSubgroup(v),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: searchAndChips),
                    const SizedBox(width: 14),
                    Expanded(flex: 4, child: dropdownFilters),
                  ],
                );
              }

              return Column(
                children: [
                  searchAndChips,
                  const SizedBox(height: 10),
                  dropdownFilters,
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          // =========================================================================
          // 3. MAIN WORKSPACE: MILITARY INVENTORY GRID & INSPECTOR SPLIT
          // =========================================================================
          Expanded(
            child: Focus(
              focusNode: _keyboardFocusNode,
              onKeyEvent: (node, event) => _handleTableKey(event, items, MediaQuery.of(context).size.width),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool showSplitPane = constraints.maxWidth >= 1100 && _isInspectorOpen && _selectedItem != null;

                  if (showSplitPane) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _buildTableCard(items, stock, true),
                        ),
                        const SizedBox(width: 14),
                        SizedBox(
                          width: 380,
                          child: DesktopItemInspectorPane(
                            item: _selectedItem!,
                            isDark: true,
                            onClose: () {
                              setState(() {
                                _isInspectorOpen = false;
                              });
                            },
                            onOpenFullDialog: () async {
                              final res = await showDialog(
                                context: context,
                                builder: (ctx) => ItemDetailDialog(
                                  item: _selectedItem!,
                                  onNavigateView: widget.onNavigate,
                                ),
                              );
                              if (res == 'NAVIGATE_TO_MAINTENANCE') {
                                widget.onNavigate?.call(3);
                              }
                            },
                            onNavigate: widget.onNavigate,
                          ),
                        ),
                      ],
                    );
                  }

                  return _buildTableCard(items, stock, false);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard(List<ItemModel> items, StockProvider stock, bool isSplit) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minTableWidth = isSplit ? 680.0 : 920.0;
        final tableWidth = math.max(minTableWidth, constraints.maxWidth);

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.outlineVariant.withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Tactical Header Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                  border: Border(
                    bottom: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.table_rows_outlined, size: 16, color: AppColors.secondary),
                        SizedBox(width: 8),
                        Text(
                          'GRID TÁTICO DE PATRIMÔNIO // BINFAE-GL',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.tertiary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Auto-Sync Ativo',
                          style: TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: AppColors.tertiary),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${items.length} de ${stock.allItems.length} listados',
                          style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: AppColors.outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Table Body with Horiz Scroll
              Expanded(
                child: Scrollbar(
                  thumbVisibility: constraints.maxWidth < minTableWidth,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Column(
                        children: [
                          // Column Headers
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              border: Border(
                                bottom: BorderSide(color: AppColors.outlineVariant.withOpacity(0.2)),
                              ),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 110,
                                  child: Text(
                                    'BMP / CÓDIGO',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    'DESCRIÇÃO & ESPECIFICAÇÃO',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                SizedBox(
                                  width: 120,
                                  child: Text(
                                    'S/N - SÉRIE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                SizedBox(
                                  width: 130,
                                  child: Text(
                                    'LOCALIZAÇÃO',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                SizedBox(
                                  width: 120,
                                  child: Text(
                                    'STATUS',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                SizedBox(
                                  width: 110,
                                  child: Text(
                                    'AÇÕES',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Rows
                          Expanded(
                            child: items.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.inventory_2_outlined, size: 42, color: AppColors.outline.withOpacity(0.5)),
                                        const SizedBox(height: 10),
                                        const Text(
                                          'Nenhum material localizado no acervo.',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Tente buscar por outro termo ou limpe os filtros.',
                                          style: TextStyle(color: AppColors.outline, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: items.length,
                                    separatorBuilder: (_, __) => Divider(
                                      height: 1,
                                      color: AppColors.outlineVariant.withOpacity(0.15),
                                    ),
                                    itemBuilder: (context, index) {
                                      final item = items[index];
                                      final isSelected = _selectedItem?.id == item.id;
                                      return _TacticalStockRow(
                                        item: item,
                                        isSelected: isSelected,
                                        onTap: () {
                                          _keyboardFocusNode.requestFocus();
                                          final screenW = MediaQuery.of(context).size.width;
                                          if (screenW >= 1100) {
                                            setState(() {
                                              _selectedItem = item;
                                              _isInspectorOpen = true;
                                            });
                                          } else {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => ItemDetailDialog(
                                                item: item,
                                                onNavigateView: widget.onNavigate,
                                              ),
                                            );
                                          }
                                        },
                                        onInspect: () {
                                          setState(() {
                                            _selectedItem = item;
                                            _isInspectorOpen = true;
                                          });
                                        },
                                        onNavigate: widget.onNavigate,
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Table Footer / Pagination
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                  border: Border(
                    top: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Exibindo ${items.length} de ${stock.allItems.length} registros',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.onSurfaceVariant),
                    ),
                    const Text(
                      'SQLite 3.42 • 100% Sincronizado',
                      style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.outline),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTacticalChip(String label, String count, bool active, Color color, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? color : AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? color : AppColors.outlineVariant.withOpacity(0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!active) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: active ? (color == AppColors.tertiary ? const Color(0xFF003827) : const Color(0xFF001B3E)) : Colors.white,
                ),
              ),
              if (count.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: active ? Colors.black.withOpacity(0.15) : AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: active ? Colors.white : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TacticalStockRow extends StatefulWidget {
  final ItemModel item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onInspect;
  final void Function(int targetIndex)? onNavigate;

  const _TacticalStockRow({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onInspect,
    this.onNavigate,
  });

  @override
  State<_TacticalStockRow> createState() => _TacticalStockRowState();
}

class _TacticalStockRowState extends State<_TacticalStockRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    Color badgeColor;
    String badgeText;
    final upperStatus = item.status.toUpperCase();
    if (upperStatus == 'DISPONIVEL') {
      if (item.estaEmSetor) {
        badgeColor = AppColors.secondary;
        badgeText = 'No Setor';
      } else {
        badgeColor = AppColors.tertiary;
        badgeText = 'No Depósito';
      }
    } else if (upperStatus == 'EM_USO') {
      badgeColor = AppColors.secondary;
      badgeText = 'No Setor';
    } else if (upperStatus == 'CAUTELADO') {
      badgeColor = AppColors.primary;
      badgeText = 'Cautelado';
    } else if (upperStatus == 'EM_MANUTENCAO') {
      badgeColor = AppColors.error;
      badgeText = 'Manutenção';
    } else {
      badgeColor = AppColors.outline;
      badgeText = item.status;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: widget.isSelected
              ? AppColors.surfaceContainerHighest.withOpacity(0.8)
              : (_isHovered ? AppColors.surfaceContainerHigh : Colors.transparent),
          child: Row(
            children: [
              // BMP / Código
              SizedBox(
                width: 110,
                child: Row(
                  children: [
                    Text(
                      item.bmp ?? 'BMP-${item.id.toString().padLeft(6, '0')}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 12, color: AppColors.outline),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Copiar BMP',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: item.bmp ?? '${item.id}'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('BMP copiado para a área de transferência'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Descrição
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nome,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      item.especificacao ?? item.grupoNome ?? 'Material Geral',
                      style: const TextStyle(fontSize: 10.5, color: AppColors.outline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // S/N
              SizedBox(
                width: 120,
                child: Text(
                  item.numeroSerie ?? 'N/A',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Localização
              SizedBox(
                width: 130,
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: AppColors.tertiary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.localizacaoFisica ?? 'Almoxarifado',
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status Badge
              SizedBox(
                width: 120,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: badgeColor.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: badgeColor),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Ações
              SizedBox(
                width: 110,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.swap_horiz, size: 16, color: AppColors.primary),
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
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 16, color: AppColors.tertiary),
                      tooltip: 'Inspecionar',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      onPressed: widget.onInspect,
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.outline),
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
