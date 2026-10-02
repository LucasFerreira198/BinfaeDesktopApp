import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/stock_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/location_form_dialog.dart';

class LocationsView extends StatefulWidget {
  final Function(int locationId)? onSelectLocation;

  const LocationsView({super.key, this.onSelectLocation});

  @override
  State<LocationsView> createState() => _LocationsViewState();
}

class _LocationsViewState extends State<LocationsView> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

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

    final allLocations = stock.locations;
    final filteredLocations = allLocations.where((loc) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      final matchName = loc.nome.toLowerCase().contains(q);
      final matchPath = loc.caminhoCompleto?.toLowerCase().contains(q) ?? false;
      final matchTipo = loc.tipo?.toLowerCase().contains(q) ?? false;
      return matchName || matchPath || matchTipo;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com Título e Botão de Ação
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Locais Físicos e Estrutura de Estoque',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Organização hierárquica de depósitos, armários, prateleiras e setores',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
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
                label: const Text('Novo Local Físico', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Barra de Pesquisa e Contador
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Filtrar por nome do local ou caminho na hierarquia...',
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
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151D2F) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '${filteredLocations.length} locais cadastrados',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Lista de Locais em Cards de Alta Densidade
          Expanded(
            child: filteredLocations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.place_outlined, size: 54, color: Colors.grey.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        const Text('Nenhum local físico encontrado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Cadastre o primeiro local ou refine a busca.', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                        itemCount: filteredLocations.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFF1F5F9),
                        ),
                        itemBuilder: (context, index) {
                          final loc = filteredLocations[index];
                          final itemCount = stock.allItems.where((i) => i.localId == loc.id).length;

                          return _LocationRowItem(
                            key: ValueKey(loc.id),
                            loc: loc,
                            itemCount: itemCount,
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
}

class _LocationRowItem extends StatefulWidget {
  final LocationModel loc;
  final int itemCount;
  final bool isDark;

  const _LocationRowItem({
    super.key,
    required this.loc,
    required this.itemCount,
    required this.isDark,
  });

  @override
  State<_LocationRowItem> createState() => _LocationRowItemState();
}

class _LocationRowItemState extends State<_LocationRowItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final loc = widget.loc;
    final itemCount = widget.itemCount;
    final isDark = widget.isDark;

    IconData icon;
    Color iconColor;
    final tipo = loc.tipo?.toUpperCase() ?? 'DEPOSITO';

    switch (tipo) {
      case 'DEPOSITO':
        icon = Icons.warehouse_outlined;
        iconColor = AppColors.primary;
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
        icon = Icons.inventory;
        iconColor = Colors.amber.shade700;
        break;
      case 'SALA':
        icon = Icons.meeting_room_outlined;
        iconColor = Colors.indigo;
        break;
      case 'BANCADA':
        icon = Icons.handyman_outlined;
        iconColor = Colors.cyan;
        break;
      default:
        icon = Icons.place_outlined;
        iconColor = AppColors.primary;
    }

    final pathFormatted = (loc.caminhoCompleto ?? loc.nome)
        .replaceAll(' > ', ' ➔ ')
        .replaceAll(' / ', ' ➔ ')
        .replaceAll('/', ' ➔ ');

    final rowBg = _isHovered
        ? (isDark ? const Color(0xFF1B243B) : const Color(0xFFF8FAFC))
        : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
            // Ícone do Tipo de Estrutura
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isHovered ? iconColor.withOpacity(0.4) : Colors.transparent,
                ),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),

            // Nome do Local e Caminho Completo em Árvore
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        loc.nome,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    pathFormatted,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                    ),
                  ),
                  if (loc.descricao != null && loc.descricao!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      loc.descricao!,
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Badge de Quantidade de Materiais Vinculados
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: itemCount > 0
                    ? AppColors.primary.withOpacity(0.12)
                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                itemCount == 1 ? '1 material' : '$itemCount materiais',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: itemCount > 0 ? AppColors.primaryLight : Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Botão Editar
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Editar Local',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => LocationFormDialog(location: loc),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
