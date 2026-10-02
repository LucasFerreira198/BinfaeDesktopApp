import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/item.dart';
import '../theme/app_theme.dart';
import 'movement_dialog.dart';

class ItemDetailDialog extends StatelessWidget {
  final ItemModel item;

  const ItemDetailDialog({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final qrPayload = '{"id":${item.id},"bmp":"${item.bmp ?? ''}","nome":"${item.nome}"}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 620,
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (item.bmp != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'BMP: ${item.bmp}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getStatusColor(item.status).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(item.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.nome,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Conteúdo e QR Code
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Detalhes em Grid
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildSpecRow('Local Físico', item.local?.caminhoCompleto ?? item.local?.nome ?? 'Sem local', isDark),
                      _buildSpecRow('Categoria', item.subgrupo?.nome ?? 'Geral', isDark),
                      _buildSpecRow('Saldo em Estoque', '${item.quantidade} ${item.unidadeMedida}', isDark),
                      _buildSpecRow('Estoque Mínimo', '${item.quantidadeMinima} ${item.unidadeMedida}', isDark),
                      _buildSpecRow('Estado de Conservação', item.estadoConservacao, isDark),
                      _buildSpecRow('Tipo de Controle', item.tipoControle, isDark),
                      if (item.numeroSerie != null)
                        _buildSpecRow('Número de Série', item.numeroSerie!, isDark),
                      if (item.codigoInterno != null)
                        _buildSpecRow('Código Interno', item.codigoInterno!, isDark),
                      if (item.observacoes != null)
                        _buildSpecRow('Observações', item.observacoes!, isDark),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                // QR Code
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF131A2A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: QrImageView(
                            data: qrPayload,
                            version: QrVersions.auto,
                            size: 130,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Etiqueta QR Code',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'ID #${item.id}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Rodapé com Ação
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fechar'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    showDialog(
                      context: context,
                      builder: (ctx) => MovementDialog(item: item),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Movimentar / Cautelar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'DISPONIVEL':
        return AppColors.success;
      case 'CAUTELADO':
        return AppColors.warning;
      case 'EM_MANUTENCAO':
        return AppColors.danger;
      default:
        return AppColors.info;
    }
  }
}
