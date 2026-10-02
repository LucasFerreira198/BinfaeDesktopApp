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
    _tipo = widget.item.status == 'CAUTELADO' ? 'DEVOLUCAO' : 'CAUTELA';
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
        SnackBar(content: Text('Quantidade máxima disponível: ${widget.item.quantidade}')),
      );
      return;
    }

    if (_motivoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o motivo ou militar responsável.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final stockProvider = Provider.of<StockProvider>(context, listen: false);
      await stockProvider.moveItem(
        itemId: widget.item.id,
        tipoMovimentacao: _tipo,
        quantidade: qty,
        destinoLocalId: _tipo == 'TRANSFERENCIA' ? _destinoLocalId : widget.item.localId,
        motivo: _motivoController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stockProvider = Provider.of<StockProvider>(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
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

            // Tipo de Movimentação
            const Text('Tipo de Operação', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildTypeChip('CAUTELA', 'Cautela', AppColors.warning),
                const SizedBox(width: 8),
                _buildTypeChip('DEVOLUCAO', 'Devolução', AppColors.success),
                const SizedBox(width: 8),
                _buildTypeChip('TRANSFERENCIA', 'Transferir', AppColors.primary),
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

            // Local Destino (se for transferência)
            if (_tipo == 'TRANSFERENCIA') ...[
              const Text('Novo Local Físico', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                value: _destinoLocalId,
                items: stockProvider.locations.map((loc) {
                  return DropdownMenuItem<int>(
                    value: loc.id,
                    child: Text(loc.caminhoCompleto ?? loc.nome),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _destinoLocalId = val),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? const Color(0xFF131A2A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Motivo
            Text(
              _tipo == 'CAUTELA' ? 'Militar Responsável / Operação' : 'Justificativa / Motivo',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _motivoController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: _tipo == 'CAUTELA' ? 'Ex: 3S Silva - Operação Ágata' : 'Ex: Revisão concluída',
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
