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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(group == null ? 'Novo Grupo' : 'Editar Grupo'),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(labelText: 'Nome do Grupo *', hintText: 'Ex: Hardware, Redes...'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
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
                  child: const Text('Salvar'),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(subgroup == null ? 'Novo Subgrupo' : 'Editar Subgrupo'),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(labelText: 'Nome do Subgrupo *', hintText: 'Ex: Monitores, Cabos...'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedGroupId,
                      decoration: const InputDecoration(labelText: 'Grupo Pai *'),
                      items: stock.groups.map((g) {
                        return DropdownMenuItem<int>(value: g.id, child: Text(g.nome));
                      }).toList(),
                      onChanged: (val) => setModalState(() => selectedGroupId = val),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
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
                  child: const Text('Salvar'),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com Título e Botões
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 800;
              final titleSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Grupos e Subgrupos de Materiais',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Classificação e categorização de itens do patrimônio e consumo',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              );

              final actionButtons = [
                OutlinedButton.icon(
                  onPressed: () => _openSubgroupDialog(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Novo Subgrupo'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openGroupDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.category_outlined, size: 18),
                  label: const Text('Novo Grupo', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ];

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleSection,
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: actionButtons,
                    ),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  titleSection,
                  Row(
                    children: [
                      actionButtons[0],
                      const SizedBox(width: 12),
                      actionButtons[1],
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Barra de Filtro
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _search = v.trim()),
            decoration: InputDecoration(
              hintText: 'Filtrar grupos e subgrupos...',
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
          const SizedBox(height: 16),

          // Lista de Grupos com Subgrupos
          Expanded(
            child: filteredGroups.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.category_outlined, size: 54, color: Colors.grey.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        const Text('Nenhum grupo encontrado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Cadastre o primeiro grupo para organizar os materiais.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredGroups.length,
                    itemBuilder: (context, index) {
                      final group = filteredGroups[index];
                      final groupSubgroups = subgroups.where((s) => s.grupoId == group.id).toList();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF151D2F) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
                        ),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.folder_outlined, color: AppColors.primary, size: 20),
                          ),
                          title: Row(
                            children: [
                              Text(
                                group.nome,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${groupSubgroups.length} subgrupos',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: group.descricao != null && group.descricao!.isNotEmpty
                              ? Text(group.descricao!, style: const TextStyle(fontSize: 11, color: Colors.grey))
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.add, size: 18),
                                tooltip: 'Adicionar Subgrupo neste Grupo',
                                onPressed: () => _openSubgroupDialog(defaultGroupId: group.id),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Editar Grupo',
                                onPressed: () => _openGroupDialog(group),
                              ),
                            ],
                          ),
                          children: [
                            Divider(height: 1, color: isDark ? const Color(0xFF1F293D) : const Color(0xFFF1F5F9)),
                            if (groupSubgroups.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Nenhum subgrupo vinculado a este grupo.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: groupSubgroups.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  indent: 48,
                                  color: isDark ? const Color(0xFF1F293D) : const Color(0xFFF1F5F9),
                                ),
                                itemBuilder: (context, subIdx) {
                                  final sub = groupSubgroups[subIdx];
                                  final itemCount = stock.allItems.where((i) => i.subgrupoId == sub.id).length;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 24),
                                        const Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.grey),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                sub.nome,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                                                ),
                                              ),
                                              if (sub.descricao != null && sub.descricao!.isNotEmpty)
                                                Text(
                                                  sub.descricao!,
                                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '$itemCount itens',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 16),
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
}
