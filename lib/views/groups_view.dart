import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/stock_provider.dart';
import '../theme/app_theme.dart';

class GroupsView extends StatefulWidget {
  const GroupsView({super.key});

  @override
  State<GroupsView> createState() => _GroupsViewState();
}

class _GroupsViewState extends State<GroupsView> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openGroupDialog([GroupModel? group]) {
    final nomeController = TextEditingController(text: group?.nome ?? '');
    final descController = TextEditingController(text: group?.descricao ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.primary),
              ),
              title: Text(
                group == null ? 'Novo Grupo de Material' : 'Editar Grupo',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nome do Grupo *', style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nomeController,
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ex: Comunicações & Rádios Táticos',
                        hintStyle: const TextStyle(fontSize: 11.5, color: AppColors.outline),
                        filled: true,
                        fillColor: AppColors.surfaceContainerLowest,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Descrição / Especificação', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Normas de cautela, uso militar, sensibilidade...',
                        hintStyle: const TextStyle(fontSize: 11.5, color: AppColors.outline),
                        filled: true,
                        fillColor: AppColors.surfaceContainerLowest,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar', style: TextStyle(color: AppColors.outline)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final nome = nomeController.text.trim();
                          if (nome.isEmpty) return;
                          setModalState(() => isSubmitting = true);
                          try {
                            final stock = Provider.of<StockProvider>(context, listen: false);
                            if (group == null) {
                              await stock.createGroup(nome, descController.text.trim());
                            } else {
                              await stock.updateGroup(group.id, nome, descController.text.trim());
                            }
                            if (mounted) Navigator.pop(ctx);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                              );
                            }
                          } finally {
                            setModalState(() => isSubmitting = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: const Color(0xFF00285D),
                  ),
                  child: const Text('Salvar Grupo', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openSubgroupDialog({SubgroupModel? subgroup, int? defaultGroupId}) {
    final stock = Provider.of<StockProvider>(context, listen: false);
    final nomeController = TextEditingController(text: subgroup?.nome ?? '');
    final descController = TextEditingController(text: subgroup?.descricao ?? '');
    int? selectedGroupId = subgroup?.grupoId ?? defaultGroupId ?? (stock.groups.isNotEmpty ? stock.groups.first.id : null);

    showDialog(
      context: context,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.secondary),
              ),
              title: Text(
                subgroup == null ? 'Novo Subgrupo Operacional' : 'Editar Subgrupo',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nome do Subgrupo *', style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nomeController,
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ex: Rádios APX 8000, Toughbooks...',
                        hintStyle: const TextStyle(fontSize: 11.5, color: AppColors.outline),
                        filled: true,
                        fillColor: AppColors.surfaceContainerLowest,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Grupo Primário Vinculado *', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedGroupId,
                          isExpanded: true,
                          dropdownColor: AppColors.surfaceContainerHigh,
                          items: stock.groups.map((g) {
                            return DropdownMenuItem<int>(
                              value: g.id,
                              child: Text(g.nome, style: const TextStyle(fontSize: 12, color: Colors.white)),
                            );
                          }).toList(),
                          onChanged: (val) => setModalState(() => selectedGroupId = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Descrição / Norma', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Detalhes adicionais...',
                        hintStyle: const TextStyle(fontSize: 11.5, color: AppColors.outline),
                        filled: true,
                        fillColor: AppColors.surfaceContainerLowest,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar', style: TextStyle(color: AppColors.outline)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final nome = nomeController.text.trim();
                          if (nome.isEmpty || selectedGroupId == null) return;
                          setModalState(() => isSubmitting = true);
                          try {
                            if (subgroup == null) {
                              await stock.createSubgroup(nome, selectedGroupId!, descController.text.trim());
                            } else {
                              await stock.updateSubgroup(subgroup.id, nome, selectedGroupId!, descController.text.trim());
                            }
                            if (mounted) Navigator.pop(ctx);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                              );
                            }
                          } finally {
                            setModalState(() => isSubmitting = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: const Color(0xFF001B3E),
                  ),
                  child: const Text('Salvar Subgrupo', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final stock = Provider.of<StockProvider>(context);
    final groups = stock.groups;
    final subgroups = stock.subgroups;

    final filteredGroups = groups.where((g) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      final matchGroup = g.nome.toLowerCase().contains(q);
      final hasMatchingSubgroup = subgroups.any((s) => s.grupoId == g.id && s.nome.toLowerCase().contains(q));
      return matchGroup || hasMatchingSubgroup;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =========================================================================
          // 1. TOP COMMAND BAR (Google Stitch #11_GroupsView)
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
                      child: const Icon(Icons.category_outlined, color: AppColors.primary, size: 24),
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
                                'CATÁLOGO DE GRUPOS E SUBGRUPOS TÁTICOS',
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
                                  'NORMAS DE CAUTELA',
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
                            'CLASSIFICAÇÃO PATRIMONIAL, LOGÍSTICA DE C&TI E NORMAS DE CAUTELA // PORTARIA 142/DIRM-GL // ALA 11',
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
                      onPressed: () => _openSubgroupDialog(),
                      icon: const Icon(Icons.create_new_folder, size: 15, color: AppColors.secondary),
                      label: const Text('+ Novo Subgrupo', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainerHigh,
                        side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openGroupDialog(),
                      icon: const Icon(Icons.add_box, size: 16, color: Color(0xFF00285D)),
                      label: const Text(
                        '+ Novo Grupo',
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
          // 2. KPI METRICS ROW (Google Stitch #11_GroupsView)
          // =========================================================================
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final kpis = [
                _buildGroupKpiCard('GRUPOS PRIMÁRIOS', '${groups.length}', '100% HOMOLOGADOS', Icons.folder_special, AppColors.primary),
                _buildGroupKpiCard('SUBGRUPOS OPERACIONAIS', '${subgroups.length}', 'CLASSES ATIVAS', Icons.account_tree, AppColors.secondary),
                _buildGroupKpiCard('ATIVOS CLASSIFICADOS', '${stock.allItems.length}', 'AUDITADO 24H', Icons.devices, AppColors.tertiary),
                _buildGroupKpiCard('TAXA DE ROTATIVIDADE', '42%', 'CAMPO OK', Icons.sync_alt, AppColors.primaryContainer),
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
          // 3. SEARCH BAR
          // =========================================================================
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.outlineVariant.withOpacity(0.35)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _search = v.trim()),
              style: const TextStyle(fontSize: 12, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar grupo, subgrupo ou código...',
                hintStyle: const TextStyle(fontSize: 11, color: AppColors.outline),
                prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.primary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 14, color: AppColors.outline),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // =========================================================================
          // 4. GROUPS LIST WITH SUBGROUPS
          // =========================================================================
          Expanded(
            child: filteredGroups.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.category_outlined, size: 48, color: AppColors.outline.withOpacity(0.5)),
                        const SizedBox(height: 10),
                        const Text(
                          'Nenhum grupo encontrado!',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredGroups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final group = filteredGroups[index];
                      final groupSubgroups = subgroups.where((s) => s.grupoId == group.id).toList();

                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
                        ),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.folder_outlined, color: AppColors.primary, size: 18),
                          ),
                          title: Row(
                            children: [
                              Text(
                                group.nome,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${groupSubgroups.length} subgrupos',
                                  style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: AppColors.secondary),
                                ),
                              ),
                            ],
                          ),
                          subtitle: group.descricao != null && group.descricao!.isNotEmpty
                              ? Text(group.descricao!, style: const TextStyle(fontSize: 10.5, color: AppColors.outline))
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 16, color: AppColors.tertiary),
                                tooltip: 'Adicionar Subgrupo neste Grupo',
                                onPressed: () => _openSubgroupDialog(defaultGroupId: group.id),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.outline),
                                tooltip: 'Editar Grupo',
                                onPressed: () => _openGroupDialog(group),
                              ),
                            ],
                          ),
                          children: [
                            Divider(height: 1, color: AppColors.outlineVariant.withOpacity(0.2)),
                            if (groupSubgroups.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('Nenhum subgrupo vinculado a este grupo.', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: groupSubgroups.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  indent: 48,
                                  color: AppColors.outlineVariant.withOpacity(0.1),
                                ),
                                itemBuilder: (context, subIdx) {
                                  final sub = groupSubgroups[subIdx];
                                  final itemCount = stock.allItems.where((i) => i.subgrupoId == sub.id).length;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 24),
                                        const Icon(Icons.subdirectory_arrow_right, size: 14, color: AppColors.outline),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                sub.nome,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                              if (sub.descricao != null && sub.descricao!.isNotEmpty)
                                                Text(
                                                  sub.descricao!,
                                                  style: const TextStyle(fontSize: 10, color: AppColors.outline),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceContainerLowest,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '$itemCount itens',
                                            style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: AppColors.onSurfaceVariant),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 14, color: AppColors.outline),
                                          tooltip: 'Editar Subgrupo',
                                          onPressed: () => _openSubgroupDialog(subgroup: sub),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static Widget _buildGroupKpiCard(String title, String count, String sub, IconData icon, Color color) {
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
              Text(title, style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: AppColors.outline)),
              const SizedBox(height: 4),
              Text(count, style: TextStyle(fontSize: 20, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: color.withOpacity(0.8))),
            ],
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, size: 16, color: color),
          ),
        ],
      ),
    );
  }
}
