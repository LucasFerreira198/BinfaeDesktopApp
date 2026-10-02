import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/stock_provider.dart';
import '../theme/app_theme.dart';

class MovementDialog extends StatefulWidget {
  final ItemModel item;

  const MovementDialog({super.key, required this.item});

  @override
  State<MovementDialog> createState() => _MovementDialogState();
}

class _MovementDialogState extends State<MovementDialog> {
  final TextEditingController _qtdController = TextEditingController(text: '1');
  final TextEditingController _motivoController = TextEditingController();
  int? _destinoLocalId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _destinoLocalId = widget.item.localId;
  }

  @override
  void dispose() {
    _qtdController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qty = double.tryParse(_qtdController.text.replaceAll(',', '.'));
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe uma quantidade válida.')),
      );
      return;
    }

    if (qty > widget.item.quantidade && widget.item.tipoControle == 'UNITARIO') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quantidade máxima disponível em estoque: ${widget.item.quantidade}')),
      );
      return;
    }

    if (_destinoLocalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o local físico de destino.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final stockProvider = Provider.of<StockProvider>(context, listen: false);
      final motivo = _motivoController.text.trim().isNotEmpty ? _motivoController.text.trim() : null;

      await stockProvider.moveItem(
        itemId: widget.item.id,
        tipoMovimentacao: 'TRANSFERENCIA',
        quantidade: qty,
        destinoLocalId: _destinoLocalId,
        motivo: motivo,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Material transferido com sucesso!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showLocationPicker(List<LocationModel> locations) {
    showDialog(
      context: context,
      builder: (ctx) {
        String query = '';
        String filterTipo = 'TODOS';

        return StatefulBuilder(
          builder: (context, setPickerState) {
            final filtered = locations.where((l) {
              final q = query.toLowerCase();
              final matchesQuery = query.isEmpty ||
                  l.nome.toLowerCase().contains(q) ||
                  (l.caminhoCompleto?.toLowerCase().contains(q) ?? false) ||
                  (l.tipo?.toLowerCase().contains(q) ?? false);

              final matchesType = filterTipo == 'TODOS' ||
                  (l.tipo?.toUpperCase() == filterTipo);

              return matchesQuery && matchesType;
            }).toList();

            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              backgroundColor: isDark ? const Color(0xFF0E1422) : Colors.white,
              title: Row(
                children: [
                  const Icon(Icons.place_outlined, color: AppColors.primaryLight, size: 22),
                  const SizedBox(width: 10),
                  const Text('Selecionar Local de Destino', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 520,
                height: 440,
                child: Column(
                  children: [
                    // Campo de Busca Rápida
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Pesquisar local por nome, armário ou caminho...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () => setPickerState(() => query = ''),
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF151D2F) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onChanged: (v) => setPickerState(() => query = v.trim()),
                    ),
                    const SizedBox(height: 10),

                    // Filtros por Tipo de Estrutura
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTypePickerChip('TODOS', 'Todos', filterTipo, (t) => setPickerState(() => filterTipo = t)),
                          const SizedBox(width: 6),
                          _buildTypePickerChip('DEPOSITO', 'Depósitos', filterTipo, (t) => setPickerState(() => filterTipo = t)),
                          const SizedBox(width: 6),
                          _buildTypePickerChip('ARMARIO', 'Armários', filterTipo, (t) => setPickerState(() => filterTipo = t)),
                          const SizedBox(width: 6),
                          _buildTypePickerChip('PRATELEIRA', 'Prateleiras', filterTipo, (t) => setPickerState(() => filterTipo = t)),
                          const SizedBox(width: 6),
                          _buildTypePickerChip('BANCADA', 'Bancadas', filterTipo, (t) => setPickerState(() => filterTipo = t)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Lista de Locais Filtrados
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'Nenhum local físico encontrado com "${query}".',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: isDark ? const Color(0xFF1F293D) : const Color(0xFFF1F5F9),
                              ),
                              itemBuilder: (context, idx) {
                                final loc = filtered[idx];
                                final isSelected = loc.id == _destinoLocalId;
                                final isCurrent = loc.id == widget.item.localId;

                                final pathFormatted = (loc.caminhoCompleto ?? loc.nome)
                                    .replaceAll(' > ', ' ➔ ')
                                    .replaceAll(' / ', ' ➔ ')
                                    .replaceAll('/', ' ➔ ');

                                return MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: ListTile(
                                    selected: isSelected,
                                    selectedTileColor: AppColors.primary.withOpacity(0.12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary.withOpacity(0.2)
                                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _getLocationIcon(loc.tipo),
                                        size: 18,
                                        color: isSelected ? AppColors.primaryLight : Colors.grey,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Text(loc.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        if (isCurrent) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('Atual', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Text(pathFormatted, style: const TextStyle(fontSize: 11)),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle, color: AppColors.primaryLight, size: 20)
                                        : null,
                                    onTap: () {
                                      setState(() => _destinoLocalId = loc.id);
                                      Navigator.pop(ctx);
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTypePickerChip(String type, String label, String currentType, Function(String) onSelect) {
    final active = currentType == type;
    return GestureDetector(
      onTap: () => onSelect(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? AppColors.primary : Colors.grey.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }

  IconData _getLocationIcon(String? tipo) {
    switch (tipo?.toUpperCase()) {
      case 'DEPOSITO':
        return Icons.warehouse_outlined;
      case 'ARMARIO':
        return Icons.door_sliding_outlined;
      case 'PRATELEIRA':
        return Icons.shelves;
      case 'GAVETA':
        return Icons.inventory_2_outlined;
      case 'BANCADA':
        return Icons.handyman_outlined;
      default:
        return Icons.place_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stockProvider = Provider.of<StockProvider>(context);

    final selectedLoc = stockProvider.getLocationById(_destinoLocalId ?? -1);
    final currentLoc = widget.item.local;

    final currentLocPath = currentLoc != null
        ? (currentLoc.caminhoCompleto ?? currentLoc.nome).replaceAll(' > ', ' ➔ ').replaceAll(' / ', ' ➔ ').replaceAll('/', ' ➔ ')
        : 'Sem local';

    final destLocPath = selectedLoc != null
        ? (selectedLoc.caminhoCompleto ?? selectedLoc.nome).replaceAll(' > ', ' ➔ ').replaceAll(' / ', ' ➔ ').replaceAll('/', ' ➔ ')
        : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF0E1422) : Colors.white,
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transferir Local Físico',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.item.nome,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Card Localização Atual
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151D2F) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.my_location, size: 16, color: AppColors.primaryLight),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Local Atual:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(currentLocPath, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Seletor de Local Físico de Destino (Novo Local)
            const Text('Local Físico de Destino *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _showLocationPicker(stockProvider.locations),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131A2A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF27354F) : const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 20, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        destLocPath ?? 'Clique para pesquisar e escolher o local de destino...',
                        style: TextStyle(
                          fontSize: 13,
                          color: destLocPath != null ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                          fontWeight: destLocPath != null ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Quantidade
            Text(
              'Quantidade a Transferir (${widget.item.unidadeMedida})',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _qtdController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? const Color(0xFF131A2A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF27354F) : const Color(0xFFCBD5E1)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Justificativa / Motivo (OPCIONAL)
            const Text(
              'Justificativa / Observação (Opcional)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _motivoController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Ex: Reorganização de estoque, alocação de posto de trabalho...',
                filled: true,
                fillColor: isDark ? const Color(0xFF131A2A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF27354F) : const Color(0xFFCBD5E1)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),

            // Botão Confirmar Transferência
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                icon: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check, size: 20),
                label: Text(
                  _isSubmitting ? 'Transferindo...' : 'Confirmar Transferência de Local',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
