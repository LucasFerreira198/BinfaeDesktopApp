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

  // Previne dependência circular e busca todos os IDs de descendentes
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151D2F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
            SizedBox(width: 10),
            Text('Excluir Local Físico', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tem certeza que deseja excluir o local "${loc.nome}"?'),
            if (totalItems > 0 || childrenCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (totalItems > 0)
                      Text(
                        '⚠️ Atenção: Existem $totalItems material(is) associados a este local e seus sublocais!',
                        style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    if (childrenCount > 0)
                      Padding(
                        padding: EdgeInsets.only(top: totalItems > 0 ? 6 : 0),
                        child: Text(
                          '⚠️ Atenção: Existem $childrenCount sublocal(is) cadastrados dentro deste local!',
                          style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold),
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
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Excluir'),
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
              backgroundColor: AppColors.success,
              content: Text('Local físico excluído com sucesso!'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.danger,
              content: Text(e.toString().replaceAll('Exception: ', '')),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stock = Provider.of<StockProvider>(context);

    final allLocations = stock.locations;
    final allItems = stock.allItems;

    // Inicializa expansão dos locais raiz por padrão na primeira carga
    if (!_initializedExpansion && allLocations.isNotEmpty) {
      final roots = allLocations.where((l) => l.parentId == null || !allLocations.any((parent) => parent.id == l.parentId));
      for (final r in roots) {
        _expandedIds.add(r.id);
      }
      _initializedExpansion = true;
    }

    // Agrupa sublocais por parent_id
    final Map<int, List<LocationModel>> childrenMap = {};
    for (final loc in allLocations) {
      if (loc.parentId != null) {
        childrenMap.putIfAbsent(loc.parentId!, () => []).add(loc);
      }
    }

    // Ordena os filhos por nome
    for (final list in childrenMap.values) {
      list.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    }

    // Raízes (parentId nulo ou cujo parentId não existe na base)
    final rootLocations = allLocations.where((loc) {
      if (loc.parentId == null) return true;
      return !allLocations.any((l) => l.id == loc.parentId);
    }).toList()
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

    // Filtro de busca com propagação para pais
    final Set<int> matchingLocationIds = {};
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      for (final loc in allLocations) {
        final matchName = loc.nome.toLowerCase().contains(q);
        final matchTipo = loc.tipo?.toLowerCase().contains(q) ?? false;
        final matchPath = loc.caminhoCompleto?.toLowerCase().contains(q) ?? false;
        final matchDesc = loc.descricao?.toLowerCase().contains(q) ?? false;

        // Também pesquisa se possui material que bate com a busca
        final hasItemMatch = allItems.any((i) =>
            i.localId == loc.id &&
            (i.nome.toLowerCase().contains(q) ||
             (i.bmp?.toLowerCase().contains(q) ?? false) ||
             (i.codigoInterno?.toLowerCase().contains(q) ?? false)));

        if (matchName || matchTipo || matchPath || matchDesc || hasItemMatch) {
          matchingLocationIds.add(loc.id);

          // Expande todos os ancestrais para que o nó fique visível
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com Título, Estatísticas e Botão de Ação
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Locais Físicos e Áreas de Estoque',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${allLocations.length} locais',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Estrutura hierárquica em árvore: Depósitos ➔ Armários ➔ Prateleiras com materiais acumulados',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _expandAll(allLocations),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : const Color(0xFF475569),
                      side: BorderSide(color: isDark ? const Color(0xFF243049) : const Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.unfold_more, size: 16),
                    label: const Text('Expandir Tudo', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _collapseAll,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : const Color(0xFF475569),
                      side: BorderSide(color: isDark ? const Color(0xFF243049) : const Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.unfold_less, size: 16),
                    label: const Text('Recolher Tudo', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => const LocationFormDialog(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                    label: const Text('Nova Área / Local Raiz', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Barra de Pesquisa Rápida
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Filtrar por nome do local, tipo, caminho ou material contido...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _search = '');
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
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151D2F) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_tree_outlined, size: 16, color: AppColors.primaryLight),
                    const SizedBox(width: 8),
                    Text(
                      '${rootLocations.length} áreas principais',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Árvore de Locais Físicos
          Expanded(
            child: rootLocations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.place_outlined, size: 54, color: Colors.grey.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        const Text('Nenhum local físico cadastrado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Clique em "+ Nova Área / Local Raiz" para cadastrar seu primeiro local.', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
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
                              isDark: isDark,
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

  // Gera nós recursivos da árvore com recuo
  List<Widget> _buildTreeNode({
    required BuildContext context,
    required LocationModel loc,
    required int depth,
    required Map<int, List<LocationModel>> childrenMap,
    required List<LocationModel> allLocations,
    required List<ItemModel> allItems,
    required StockProvider stock,
    required bool isDark,
    required Set<int> matchingIds,
  }) {
    final children = childrenMap[loc.id] ?? [];
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expandedIds.contains(loc.id);

    // Se estiver filtrando e este nó e seus filhos não derem match, oculta
    if (_search.isNotEmpty) {
      final descIds = _getDescendantIds(loc.id, allLocations);
      final hasMatchInSubtree = descIds.any((id) => matchingIds.contains(id));
      if (!hasMatchInSubtree) {
        return [];
      }
    }

    // Contagem CUMULATIVA de materiais (diretos + todos os sublocais recursivos)
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
        isDark: isDark,
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

    // Se expandido, renderiza os filhos recursivamente
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
            isDark: isDark,
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
  final bool isDark;
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
    required this.isDark,
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
    final isDark = widget.isDark;
    final tipo = loc.tipo?.toUpperCase() ?? 'DEPOSITO';

    IconData icon;
    Color iconColor;

    switch (tipo) {
      case 'DEPOSITO':
        icon = Icons.warehouse_outlined;
        iconColor = const Color(0xFF8B5CF6);
        break;
      case 'ARMARIO':
        icon = Icons.door_sliding_outlined;
        iconColor = Colors.orange;
        break;
      case 'PRATELEIRA':
        icon = Icons.shelves;
        iconColor = Colors.teal;
        break;
      case 'GAVETA':
        icon = Icons.inventory_2_outlined;
        iconColor = Colors.amber.shade700;
        break;
      case 'SALA':
        icon = Icons.meeting_room_outlined;
        iconColor = Colors.indigoAccent;
        break;
      case 'BANCADA':
        icon = Icons.handyman_outlined;
        iconColor = Colors.cyan;
        break;
      case 'SETOR':
        icon = Icons.domain_outlined;
        iconColor = Colors.blue;
        break;
      default:
        icon = Icons.place_outlined;
        iconColor = AppColors.primary;
    }

    final rowBg = _isHovered
        ? (isDark ? const Color(0xFF1E283F) : const Color(0xFFF1F5F9))
        : Colors.transparent;

    final leftPadding = 16.0 + (widget.depth * 32.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.only(left: leftPadding, right: 16, top: 8, bottom: 8),
        decoration: BoxDecoration(
          color: rowBg,
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF1F5F9),
              width: 1,
            ),
            left: BorderSide(
              color: _isHovered ? iconColor : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            // Botão Expandir / Recolher ou Conector
            if (widget.hasChildren)
              InkWell(
                onTap: widget.onToggleExpand,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    widget.isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                    size: 16,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
              )
            else
              Container(
                width: 24,
                alignment: Alignment.center,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
              ),
            const SizedBox(width: 8),

            // Ícone do Tipo de Estrutura
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isHovered ? iconColor.withOpacity(0.4) : Colors.transparent,
                ),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),

            // Nome do Local e Hierarquia / Descrição
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          loc.nome,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tipo,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      if (widget.hasChildren) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${widget.childrenCount} sublocais',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: iconColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (loc.descricao != null && loc.descricao!.isNotEmpty)
                    Text(
                      loc.descricao!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    )
                  else if (loc.caminhoCompleto != null)
                    Text(
                      loc.caminhoCompleto!.replaceAll(' > ', ' ➔ ').replaceAll(' / ', ' ➔ '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                      ),
                    ),
                ],
              ),
            ),

            // Badge Cumulativa de Materiais (com detalhamento diretos vs sublocais)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.cumulativeCount > 0
                        ? AppColors.primary.withOpacity(0.14)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.cumulativeCount > 0
                          ? AppColors.primary.withOpacity(0.3)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 13,
                        color: widget.cumulativeCount > 0 ? AppColors.primaryLight : Colors.grey,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.cumulativeCount == 1 ? '1 material' : '${widget.cumulativeCount} materiais',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: widget.cumulativeCount > 0 ? AppColors.primaryLight : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.hasChildren && widget.cumulativeCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 4),
                    child: Text(
                      '${widget.directCount} diretos • ${widget.subMaterialsCount} em sublocais',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),

            // Botão "Ver Materiais"
            ElevatedButton.icon(
              onPressed: widget.onViewMaterials,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0),
                foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.search, size: 14, color: AppColors.primaryLight),
              label: const Text('Ver Materiais', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),

            // Botão "+ Sublocal"
            Tooltip(
              message: 'Adicionar sublocal dentro de "${loc.nome}"',
              child: IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 18),
                color: Colors.tealAccent.shade700,
                onPressed: widget.onAddSublocal,
              ),
            ),

            // Botão Editar
            Tooltip(
              message: 'Editar Local',
              child: IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: widget.onEdit,
              ),
            ),

            // Botão Excluir
            Tooltip(
              message: 'Excluir Local',
              child: IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppColors.danger.withOpacity(0.8),
                onPressed: widget.onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Modal completo para visualização e busca de materiais no local e seus sublocais
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
  int? _selectedSubFilter; // null: todos, -1: apenas diretos, id: sublocal específico

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stock = Provider.of<StockProvider>(context);

    final targetLoc = widget.targetLocation;
    final allLocs = widget.allLocations;
    final allItems = stock.allItems;

    // Descendentes acumulados do local atual
    final descIds = _getDescendantIds(targetLoc.id, allLocs);
    final cumulativeItems = allItems.where((i) => descIds.contains(i.localId)).toList();
    final directItems = allItems.where((i) => i.localId == targetLoc.id).toList();

    // Filhos diretos do local atual
    final directChildren = allLocs.where((l) => l.parentId == targetLoc.id).toList()
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

    // Filtra materiais por chip selecionado e texto de busca
    final filteredItems = cumulativeItems.where((item) {
      // Filtro de local / sublocal
      if (_selectedSubFilter == -1) {
        // Apenas diretos
        if (item.localId != targetLoc.id) return false;
      } else if (_selectedSubFilter != null) {
        // Sublocal específico e seus descendentes
        final subDescIds = _getDescendantIds(_selectedSubFilter!, allLocs);
        if (!subDescIds.contains(item.localId)) return false;
      }

      // Filtro de busca textual
      if (_searchFilter.isNotEmpty) {
        final q = _searchFilter.toLowerCase();
        final matchNome = item.nome.toLowerCase().contains(q);
        final matchBmp = item.bmp?.toLowerCase().contains(q) ?? false;
        final matchCod = item.codigoInterno?.toLowerCase().contains(q) ?? false;
        final matchSerie = item.numeroSerie?.toLowerCase().contains(q) ?? false;
        final matchSub = item.subgrupo?.nome.toLowerCase().contains(q) ?? false;
        final matchLocal = item.local?.nome.toLowerCase().contains(q) ?? false;
        return matchNome || matchBmp || matchCod || matchSerie || matchSub || matchLocal;
      }

      return true;
    }).toList();

    final pathFormatted = (targetLoc.caminhoCompleto ?? targetLoc.nome)
        .replaceAll(' > ', ' ➔ ')
        .replaceAll(' / ', ' ➔ ');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF0E1422) : Colors.white,
      child: Container(
        width: 960,
        height: 680,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header do Modal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.warehouse_outlined, color: AppColors.primaryLight, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Materiais em: ${targetLoc.nome}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${cumulativeItems.length} materiais no total',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pathFormatted,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Barra de Busca Interna no Local
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchFilter = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Pesquisar por BMP, nome, série ou código interno neste local...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchFilter = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF151D2F) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF151D2F) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    '${filteredItems.length} exibidos',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Chips de Filtro por Sublocal (Todos, Apenas Diretos, e cada sublocal)
            if (directChildren.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSubFilterChip(
                      label: 'Todos acumulados (${cumulativeItems.length})',
                      isSelected: _selectedSubFilter == null,
                      onTap: () => setState(() => _selectedSubFilter = null),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildSubFilterChip(
                      label: 'Diretos em ${targetLoc.nome} (${directItems.length})',
                      isSelected: _selectedSubFilter == -1,
                      onTap: () => setState(() => _selectedSubFilter = -1),
                      isDark: isDark,
                    ),
                    for (final child in directChildren) ...[
                      const SizedBox(width: 8),
                      _buildChildFilterChip(
                        child: child,
                        allLocs: allLocs,
                        allItems: allItems,
                        isSelected: _selectedSubFilter == child.id,
                        onTap: () => setState(() => _selectedSubFilter = child.id),
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // Lista de Materiais do Local
            Expanded(
              child: filteredItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.withOpacity(0.4)),
                          const SizedBox(height: 12),
                          const Text('Nenhum material encontrado neste local ou sublocal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          const Text('Refine a busca ou transfira materiais para cá.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF151D2F) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ListView.separated(
                          itemCount: filteredItems.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          ),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final isDirect = item.localId == targetLoc.id;

                            return _MaterialDialogRow(
                              item: item,
                              targetLoc: targetLoc,
                              isDirect: isDirect,
                              isDark: isDark,
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? const Color(0xFF151D2F) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildChildFilterChip({
    required LocationModel child,
    required List<LocationModel> allLocs,
    required List<ItemModel> allItems,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final subDescIds = _getDescendantIds(child.id, allLocs);
    final count = allItems.where((i) => subDescIds.contains(i.localId)).length;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? const Color(0xFF151D2F) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getChildIcon(child.tipo),
              size: 13,
              color: isSelected ? Colors.white : AppColors.primaryLight,
            ),
            const SizedBox(width: 6),
            Text(
              '${child.nome} ($count)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getChildIcon(String? tipo) {
    switch (tipo?.toUpperCase()) {
      case 'ARMARIO':
        return Icons.door_sliding_outlined;
      case 'PRATELEIRA':
        return Icons.shelves;
      case 'GAVETA':
        return Icons.inventory_2_outlined;
      case 'SALA':
        return Icons.meeting_room_outlined;
      case 'BANCADA':
        return Icons.handyman_outlined;
      default:
        return Icons.place_outlined;
    }
  }
}

class _MaterialDialogRow extends StatefulWidget {
  final ItemModel item;
  final LocationModel targetLoc;
  final bool isDirect;
  final bool isDark;

  const _MaterialDialogRow({
    required this.item,
    required this.targetLoc,
    required this.isDirect,
    required this.isDark,
  });

  @override
  State<_MaterialDialogRow> createState() => _MaterialDialogRowState();
}

class _MaterialDialogRowState extends State<_MaterialDialogRow> {
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
        ? (item.local!.caminhoCompleto ?? item.local!.nome).replaceAll(' > ', ' ➔ ').replaceAll(' / ', ' ➔ ')
        : 'Sem Local';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
            // BMP Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: item.bmp != null
                    ? AppColors.primary.withOpacity(0.15)
                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.bmp ?? 'S/ BMP',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: item.bmp != null ? AppColors.primaryLight : Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Nome e Localização Exata
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nome,
                    style: TextStyle(
                      fontSize: 13,
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
                      Text('•', style: TextStyle(fontSize: 10, color: isDark ? Colors.white30 : Colors.black26)),
                      const SizedBox(width: 6),
                      Icon(
                        widget.isDirect ? Icons.place_outlined : Icons.account_tree_outlined,
                        size: 12,
                        color: widget.isDirect ? Colors.green : AppColors.primaryLight,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          locationTree,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: widget.isDirect ? FontWeight.w600 : FontWeight.normal,
                            color: widget.isDirect
                                ? (isDark ? Colors.greenAccent : Colors.green.shade700)
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor.withOpacity(0.4)),
              ),
              child: Text(
                item.status.replaceAll('_', ' '),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Quantidade
            SizedBox(
              width: 80,
              child: Text(
                '${item.quantidade} ${item.unidadeMedida.toLowerCase()}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Ações: Transferir e Detalhes
            IconButton(
              icon: const Icon(Icons.swap_horiz, size: 18),
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
              icon: const Icon(Icons.chevron_right, size: 18),
              tooltip: 'Ver Detalhes',
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
        return AppColors.maintenance;
      default:
        return AppColors.info;
    }
  }
}
