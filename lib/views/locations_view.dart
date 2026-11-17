import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/stock_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/item_detail_dialog.dart';
import '../widgets/location_form_dialog.dart';
import '../widgets/movement_dialog.dart';

class LocationsView extends StatefulWidget {
  final Function(int locationId)? onSelectLocation;

  const LocationsView({super.key, this.onSelectLocation});

  @override
  State<LocationsView> createState() => _LocationsViewState();
}

class _LocationsViewState extends State<LocationsView> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  final Set<int> _expandedIds = {};
  bool _initializedExpansion = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Set<int> _getDescendantIds(int rootId, List<LocationModel> allLocs) {
    final descendants = <int>{rootId};
    var added = true;
    while (added) {
      added = false;
      for (final loc in allLocs) {
        if (loc.parentId != null && descendants.contains(loc.parentId) && !descendants.contains(loc.id)) {
          descendants.add(loc.id);
          added = true;
        }
      }
    }
    return descendants;
  }

  void _expandAll(List<LocationModel> locations) {
    setState(() {
      _expandedIds.addAll(locations.map((l) => l.id));
    });
  }

  void _collapseAll() {
    setState(() {
      _expandedIds.clear();
    });
  }

  void _toggleExpand(int id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.add(id);
      }
    });
  }

  Future<void> _confirmDelete(BuildContext context, LocationModel loc, StockProvider stock, int totalItems, int childrenCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.error),
        ),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text(
              'Excluir Local Físico',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tem certeza que deseja excluir o local "${loc.nome}"?', style: const TextStyle(color: Colors.white70)),
            if (totalItems > 0 || childrenCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (totalItems > 0)
                      Text(
                        'Atenção: Existem $totalItems material(is) associados a este local e seus sublocais!',
                        style: const TextStyle(color: AppColors.error, fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    if (childrenCount > 0)
                      Padding(
                        padding: EdgeInsets.only(top: totalItems > 0 ? 4 : 0),
                        child: Text(
                          'Atenção: Existem $childrenCount sublocal(is) cadastrados dentro deste local!',
                          style: const TextStyle(color: AppColors.error, fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.outline)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: const Color(0xFF690005),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Excluir', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await stock.deleteLocation(loc.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.surfaceContainerHigh,
              content: Text('Local físico excluído com sucesso!', style: TextStyle(color: AppColors.tertiary)),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.surfaceContainerHigh,
              content: Text(e.toString().replaceAll('Exception: ', ''), style: const TextStyle(color: AppColors.error)),
            ),
          );
        }
      }
    }
  }

  void _openMaterialsDialog(BuildContext context, LocationModel loc, List<LocationModel> allLocs) {
    showDialog(
      context: context,
      builder: (ctx) => _LocationMaterialsDialog(
        targetLocation: loc,
        allLocations: allLocs,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stock = Provider.of<StockProvider>(context);
    final allLocations = stock.locations;
    final allItems = stock.allItems;

    if (!_initializedExpansion && allLocations.isNotEmpty) {
      final roots = allLocations.where((l) => l.parentId == null || !allLocations.any((parent) => parent.id == l.parentId));
      for (final r in roots) {
        _expandedIds.add(r.id);
      }
      _initializedExpansion = true;
    }

    final Map<int, List<LocationModel>> childrenMap = {};
    for (final loc in allLocations) {
      if (loc.parentId != null) {
        childrenMap.putIfAbsent(loc.parentId!, () => []).add(loc);
      }
    }

    for (final list in childrenMap.values) {
      list.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    }

    final rootLocations = allLocations.where((loc) {
      if (loc.parentId == null) return true;
      return !allLocations.any((l) => l.id == loc.parentId);
    }).toList()
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

    final Set<int> matchingLocationIds = {};
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      for (final loc in allLocations) {
        final matchName = loc.nome.toLowerCase().contains(q);
        final matchTipo = loc.tipo?.toLowerCase().contains(q) ?? false;
        final matchPath = loc.caminhoCompleto?.toLowerCase().contains(q) ?? false;
        final matchDesc = loc.descricao?.toLowerCase().contains(q) ?? false;

        final hasItemMatch = allItems.any((i) =>
            i.localId == loc.id &&
            (i.nome.toLowerCase().contains(q) ||
             (i.bmp?.toLowerCase().contains(q) ?? false) ||
             (i.codigoInterno?.toLowerCase().contains(q) ?? false)));

        if (matchName || matchTipo || matchPath || matchDesc || hasItemMatch) {
          matchingLocationIds.add(loc.id);

          var curParentId = loc.parentId;
          while (curParentId != null) {
            _expandedIds.add(curParentId);
            final parent = allLocations.firstWhere(
              (l) => l.id == curParentId,
              orElse: () => LocationModel(id: -1, nome: ''),
            );
            curParentId = parent.id != -1 ? parent.parentId : null;
          }
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =========================================================================
          // 1. TACTICAL TOP BAR & TELEMETRY CHIPS (Google Stitch #01_LocationsTreeView)
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
                final isWide = constraints.maxWidth >= 1020;

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
                      child: const Icon(Icons.account_tree_outlined, color: AppColors.primary, size: 24),
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
                                'LOCAIS FÍSICOS & INFRAESTRUTURA',
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
                                  color: AppColors.tertiary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.tertiary.withOpacity(0.4)),
                                ),
                                child: const Text(
                                  'TOPOLOGIA ATIVA',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.tertiary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
                                ),
                                child: const Text(
                                  'PORTARIA 142/DIRM-GL',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'ESTRUTURA DE NÓS FÍSICOS, BASTIDORES DE TELECOM E DISTRIBUIÇÃO GEOESPACIAL // ALA 11',
                            style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final telemetryChips = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildTelemetryChip('COMPLEXOS', '04', Icons.domain, AppColors.primary),
                    _buildTelemetryChip('PAVILHÕES', '18', Icons.corporate_fare, AppColors.secondary),
                    _buildTelemetryChip('CPDs & SALAS', '42', Icons.meeting_room, AppColors.tertiary),
                    _buildTelemetryChip('RACKS 42U', '156', Icons.dns, Colors.white),
                    _buildTelemetryChip('ATIVOS BMP', '${allItems.length}', Icons.inventory, AppColors.primary),
                  ],
                );

                if (isWide) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: headerInfo),
                      const SizedBox(width: 14),
                      telemetryChips,
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerInfo,
                    const SizedBox(height: 12),
                    telemetryChips,
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          // =========================================================================
          // 2. SEARCH & ACTION TOOLBAR (Google Stitch #01_LocationsTreeView)
          // =========================================================================
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _search = v.trim()),
                    style: const TextStyle(fontSize: 12.5, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Filtrar por nome do local, tipo, caminho ou material contido...',
                      hintStyle: const TextStyle(fontSize: 11.5, color: AppColors.outline),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.primary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 16, color: AppColors.outline),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _search = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => _expandAll(allLocations),
                icon: const Icon(Icons.unfold_more, size: 15, color: AppColors.primary),
                label: const Text('Expandir', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surfaceContainerHigh,
                  side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _collapseAll,
                icon: const Icon(Icons.unfold_less, size: 15, color: AppColors.primary),
                label: const Text('Recolher', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surfaceContainerHigh,
                  side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const LocationFormDialog(),
                  );
                },
                icon: const Icon(Icons.add_location_alt, size: 16, color: Color(0xFF00285D)),
                label: const Text(
                  '+ Nova Área / Local Raiz',
                  style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF00285D)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // =========================================================================
          // 3. TREE VIEW HIERARCHY (Google Stitch #01_LocationsTreeView)
          // =========================================================================
          Expanded(
            child: rootLocations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.place_outlined, size: 48, color: AppColors.outline.withOpacity(0.5)),
                        const SizedBox(height: 10),
                        const Text(
                          'Nenhum local físico cadastrado',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Clique em "+ Nova Área / Local Raiz" para cadastrar seu primeiro nó topológico.',
                          style: TextStyle(fontSize: 11, color: AppColors.outline),
                        ),
                      ],
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.outlineVariant.withOpacity(0.35)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        children: [
                          for (final root in rootLocations)
                            ..._buildTreeNode(
                              context: context,
                              loc: root,
                              depth: 0,
                              childrenMap: childrenMap,
                              allLocations: allLocations,
                              allItems: allItems,
                              stock: stock,
                              matchingIds: matchingLocationIds,
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static Widget _buildTelemetryChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 8.5, fontFamily: 'monospace', color: AppColors.onSurfaceVariant),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTreeNode({
    required BuildContext context,
    required LocationModel loc,
    required int depth,
    required Map<int, List<LocationModel>> childrenMap,
    required List<LocationModel> allLocations,
    required List<ItemModel> allItems,
    required StockProvider stock,
    required Set<int> matchingIds,
  }) {
    final children = childrenMap[loc.id] ?? [];
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expandedIds.contains(loc.id);

    if (_search.isNotEmpty) {
      final descIds = _getDescendantIds(loc.id, allLocations);
      final hasMatchInSubtree = descIds.any((id) => matchingIds.contains(id));
      if (!hasMatchInSubtree) {
        return [];
      }
    }

    final descIds = _getDescendantIds(loc.id, allLocations);
    final cumulativeMaterials = allItems.where((i) => descIds.contains(i.localId)).toList();
    final directMaterials = allItems.where((i) => i.localId == loc.id).toList();
    final subMaterialsCount = cumulativeMaterials.length - directMaterials.length;

    final widgets = <Widget>[
      _TreeNodeRow(
        key: ValueKey('tree_node_${loc.id}'),
        loc: loc,
        depth: depth,
        hasChildren: hasChildren,
        isExpanded: isExpanded,
        cumulativeCount: cumulativeMaterials.length,
        directCount: directMaterials.length,
        subMaterialsCount: subMaterialsCount,
        childrenCount: children.length,
        onToggleExpand: hasChildren ? () => _toggleExpand(loc.id) : null,
        onViewMaterials: () => _openMaterialsDialog(context, loc, allLocations),
        onAddSublocal: () {
          showDialog(
            context: context,
            builder: (ctx) => LocationFormDialog(initialParentId: loc.id),
          );
        },
        onEdit: () {
          showDialog(
            context: context,
            builder: (ctx) => LocationFormDialog(location: loc),
          );
        },
        onDelete: () => _confirmDelete(context, loc, stock, cumulativeMaterials.length, children.length),
      ),
    ];

    if (hasChildren && isExpanded) {
      for (final child in children) {
        widgets.addAll(
          _buildTreeNode(
            context: context,
            loc: child,
            depth: depth + 1,
            childrenMap: childrenMap,
            allLocations: allLocations,
            allItems: allItems,
            stock: stock,
            matchingIds: matchingIds,
          ),
        );
      }
    }

    return widgets;
  }
}

class _TreeNodeRow extends StatefulWidget {
  final LocationModel loc;
  final int depth;
  final bool hasChildren;
  final bool isExpanded;
  final int cumulativeCount;
  final int directCount;
  final int subMaterialsCount;
  final int childrenCount;
  final VoidCallback? onToggleExpand;
  final VoidCallback onViewMaterials;
  final VoidCallback onAddSublocal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TreeNodeRow({
    super.key,
    required this.loc,
    required this.depth,
    required this.hasChildren,
    required this.isExpanded,
    required this.cumulativeCount,
    required this.directCount,
    required this.subMaterialsCount,
    required this.childrenCount,
    required this.onToggleExpand,
    required this.onViewMaterials,
    required this.onAddSublocal,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_TreeNodeRow> createState() => _TreeNodeRowState();
}

class _TreeNodeRowState extends State<_TreeNodeRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final loc = widget.loc;
    final tipo = loc.tipo?.toUpperCase() ?? 'DEPOSITO';

    IconData icon;
    Color iconColor;

    switch (tipo) {
      case 'DEPOSITO':
        icon = Icons.warehouse_outlined;
        iconColor = AppColors.secondary;
        break;
      case 'ARMARIO':
        icon = Icons.door_sliding_outlined;
        iconColor = AppColors.warning;
        break;
      case 'PRATELEIRA':
        icon = Icons.shelves;
        iconColor = AppColors.tertiary;
        break;
      case 'GAVETA':
        icon = Icons.inventory_2_outlined;
        iconColor = AppColors.secondary;
        break;
      case 'SALA':
        icon = Icons.meeting_room_outlined;
        iconColor = AppColors.primary;
        break;
      case 'BANCADA':
        icon = Icons.handyman_outlined;
        iconColor = AppColors.tertiary;
        break;
      case 'SETOR':
        icon = Icons.domain_outlined;
        iconColor = AppColors.primary;
        break;
      default:
        icon = Icons.place_outlined;
        iconColor = AppColors.primary;
    }

    final leftPadding = 16.0 + (widget.depth * 28.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        padding: EdgeInsets.only(left: leftPadding, right: 14, top: 7, bottom: 7),
        color: _isHovered ? AppColors.surfaceContainerHigh : Colors.transparent,
        child: Row(
          children: [
            // Expand / Collapse Chevron
            if (widget.hasChildren)
              GestureDetector(
                onTap: widget.onToggleExpand,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
                  ),
                  child: Icon(
                    widget.isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
              )
            else
              const SizedBox(width: 22),
            const SizedBox(width: 8),

            // Icon with rounded bg
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 15, color: iconColor),
            ),
            const SizedBox(width: 10),

            // Name & Type badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        loc.nome,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          tipo,
                          style: TextStyle(
                            fontSize: 9,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: iconColor,
                          ),
                        ),
                      ),
                      if (widget.hasChildren) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${widget.childrenCount} nós',
                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.outline),
                        ),
                      ],
                    ],
                  ),
                  if (loc.descricao != null && loc.descricao!.isNotEmpty)
                    Text(
                      loc.descricao!,
                      style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: AppColors.outline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // Materials badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: widget.cumulativeCount > 0 ? AppColors.tertiary.withOpacity(0.15) : AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.cumulativeCount > 0 ? AppColors.tertiary.withOpacity(0.3) : AppColors.outlineVariant.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 12, color: widget.cumulativeCount > 0 ? AppColors.tertiary : AppColors.outline),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.cumulativeCount} itens',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: widget.cumulativeCount > 0 ? AppColors.tertiary : AppColors.outline,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Actions
            ElevatedButton(
              onPressed: widget.onViewMaterials,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceContainerHigh,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                elevation: 0,
              ),
              child: const Text('Materiais', style: TextStyle(fontSize: 10.5, fontFamily: 'monospace')),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 16, color: AppColors.tertiary),
              tooltip: 'Adicionar Sublocal',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: widget.onAddSublocal,
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.outline),
              tooltip: 'Editar',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: widget.onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
              tooltip: 'Excluir',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: widget.onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// Modal completo de materiais com design militar
class _LocationMaterialsDialog extends StatefulWidget {
  final LocationModel targetLocation;
  final List<LocationModel> allLocations;

  const _LocationMaterialsDialog({
    required this.targetLocation,
    required this.allLocations,
  });

  @override
  State<_LocationMaterialsDialog> createState() => _LocationMaterialsDialogState();
}

class _LocationMaterialsDialogState extends State<_LocationMaterialsDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchFilter = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Set<int> _getDescendantIds(int rootId, List<LocationModel> allLocs) {
    final descendants = <int>{rootId};
    var added = true;
    while (added) {
      added = false;
      for (final loc in allLocs) {
        if (loc.parentId != null && descendants.contains(loc.parentId) && !descendants.contains(loc.id)) {
          descendants.add(loc.id);
          added = true;
        }
      }
    }
    return descendants;
  }

  @override
  Widget build(BuildContext context) {
    final stock = Provider.of<StockProvider>(context);
    final targetLoc = widget.targetLocation;
    final allLocs = widget.allLocations;
    final allItems = stock.allItems;

    final descIds = _getDescendantIds(targetLoc.id, allLocs);
    final cumulativeItems = allItems.where((i) => descIds.contains(i.localId)).toList();

    final filteredItems = cumulativeItems.where((item) {
      if (_searchFilter.isNotEmpty) {
        final q = _searchFilter.toLowerCase();
        final matchNome = item.nome.toLowerCase().contains(q);
        final matchBmp = item.bmp?.toLowerCase().contains(q) ?? false;
        final matchCod = item.codigoInterno?.toLowerCase().contains(q) ?? false;
        final matchSerie = item.numeroSerie?.toLowerCase().contains(q) ?? false;
        return matchNome || matchBmp || matchCod || matchSerie;
      }
      return true;
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: AppColors.surfaceContainerLow,
      child: Container(
        width: 880,
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warehouse_outlined, color: AppColors.primary, size: 24),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Materiais em: ${targetLoc.nome}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          '${cumulativeItems.length} materiais alocados neste nó',
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.outline),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Search input
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchFilter = v.trim()),
                style: const TextStyle(fontSize: 12, color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Buscar materiais neste local...',
                  hintStyle: TextStyle(fontSize: 11, color: AppColors.outline),
                  prefixIcon: Icon(Icons.search, size: 16, color: AppColors.primary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Table of items
            Expanded(
              child: filteredItems.isEmpty
                  ? const Center(
                      child: Text('Nenhum material encontrado neste local.', style: TextStyle(color: AppColors.outline, fontSize: 12)),
                    )
                  : ListView.separated(
                      itemCount: filteredItems.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.outlineVariant.withOpacity(0.15)),
                      itemBuilder: (ctx, i) {
                        final item = filteredItems[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          title: Row(
                            children: [
                              Text(
                                item.bmp ?? 'BMP-${item.id}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.nome,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'S/N: ${item.numeroSerie ?? "N/A"} • Status: ${item.status}',
                            style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: AppColors.onSurfaceVariant),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => MovementDialog(item: item),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surfaceContainerHigh,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            child: const Text('Transferir', style: TextStyle(fontSize: 10.5, fontFamily: 'monospace')),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
