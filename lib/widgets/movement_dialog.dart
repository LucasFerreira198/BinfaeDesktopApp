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
  late String _tipo;
  final TextEditingController _qtdController = TextEditingController(text: '1');
  final TextEditingController _motivoController = TextEditingController();
  int? _destinoLocalId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tipo = widget.item.status == 'CAUTELADO' ? 'DEVOLUCAO' : 'TRANSFERENCIA';
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

    if (qty > widget.item.quantidade && widget.item.tipoControle == 'UNITARIO' && _tipo != 'DEVOLUCAO') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quantidade máxima disponível em estoque: ${widget.item.quantidade}')),
      );
      return;
    }

    if (_tipo == 'TRANSFERENCIA' && _destinoLocalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o local de destino para a transferência.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final stockProvider = Provider.of<StockProvider>(context, listen: false);
      final motivo = _motivoController.text.trim().isNotEmpty ? _motivoController.text.trim() : null;

      await stockProvider.moveItem(
        itemId: widget.item.id,
        tipoMovimentacao: _tipo,
        quantidade: qty,
        destinoLocalId: _tipo == 'TRANSFERENCIA' ? _destinoLocalId : widget.item.localId,
        motivo: motivo,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Movimentação registrada com sucesso!'),
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
        return StatefulBuilder(
          builder: (context, setPickerState) {
            final filtered = locations.where((l) {
              if (query.isEmpty) return true;
              final q = query.toLowerCase();
              return l.nome.toLowerCase().contains(q) || (l.caminhoCompleto?.toLowerCase().contains(q) ?? false);
            }).toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Selecionar Local de Destino'),
              content: SizedBox(
                width: 460,
                height: 380,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Pesquisar local por nome ou caminho...',
                        prefixIcon: Icon(Icons.search, size: 20),
                      ),
                      onChanged: (v) => setPickerState(() => query = v.trim()),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('Nenhum local encontrado.'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, idx) {
                                final loc = filtered[idx];
                                final isSelected = loc.id == _destinoLocalId;

                                return ListTile(
                                  selected: isSelected,
                                  leading: Icon(
                                    Icons.place_outlined,
                                    color: isSelected ? AppColors.primary : Colors.grey,
                                  ),
                                  title: Text(loc.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  subtitle: loc.caminhoCompleto != null ? Text(loc.caminhoCompleto!, style: const TextStyle(fontSize: 11)) : null,
                                  trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
                                  onTap: () {
                                    setState(() => _destinoLocalId = loc.id);
                                    Navigator.pop(ctx);
                                  },
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stockProvider = Provider.of<StockProvider>(context);

    final selectedLoc = stockProvider.getLocationById(_destinoLocalId ?? -1);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registrar Movimentação',
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
            const SizedBox(height: 20),

            // Tipo de Operação
            const Text('Tipo de Operação', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildTypeChip('TRANSFERENCIA', 'Transferir', AppColors.primary),
                const SizedBox(width: 8),
                _buildTypeChip('CAUTELA', 'Cautela', AppColors.warning),
                const SizedBox(width: 8),
                _buildTypeChip('DEVOLUCAO', 'Devolução', AppColors.success),
                const SizedBox(width: 8),
                _buildTypeChip('MANUTENCAO', 'Manutenção', AppColors.danger),
              ],
            ),
            const SizedBox(height: 16),

            // Quantidade
            Text(
              'Quantidade (${widget.item.unidadeMedida})',
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

            // Seletor Hierárquico de Local Destino para Transferência
            if (_tipo == 'TRANSFERENCIA') ...[
              const Text('Novo Local Físico (Destino) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                          selectedLoc != null
                              ? (selectedLoc.caminhoCompleto ?? selectedLoc.nome)
                              : 'Clique para escolher o local de destino...',
                          style: TextStyle(
                            fontSize: 13,
                            color: selectedLoc != null ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                            fontWeight: selectedLoc != null ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Justificativa / Motivo (OPCIONAL)
            Text(
              _tipo == 'CAUTELA'
                  ? 'Militar Responsável / Operação (Opcional)'
                  : 'Justificativa / Motivo (Opcional)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _motivoController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: _tipo == 'CAUTELA' ? 'Ex: 3S Silva - Operação Ágata' : 'Ex: Transferência de almoxarifado',
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

            // Botão Confirmar
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check, size: 20),
                label: Text(
                  _isSubmitting ? 'Registrando...' : 'Confirmar Operação',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type, String label, Color color) {
    final active = _tipo == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tipo = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? color : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? color : Colors.transparent),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
              color: active ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}
