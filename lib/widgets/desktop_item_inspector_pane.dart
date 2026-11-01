import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/item.dart';
import '../theme/app_theme.dart';
import 'item_form_dialog.dart';
import 'movement_dialog.dart';

class DesktopItemInspectorPane extends StatelessWidget {
  final ItemModel item;
  final bool isDark;
  final VoidCallback onClose;
  final VoidCallback onOpenFullDialog;
  final void Function(int targetIndex)? onNavigate;

  const DesktopItemInspectorPane({
    super.key,
    required this.item,
    required this.isDark,
    required this.onClose,
    required this.onOpenFullDialog,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    final upperStatus = item.status.toUpperCase();
    if (upperStatus == 'DISPONIVEL') {
      if (item.estaEmSetor) {
        statusColor = const Color(0xFF8B5CF6);
        statusText = 'No Setor';
      } else {
        statusColor = AppColors.success;
        statusText = 'Disponível';
      }
    } else if (upperStatus == 'EM_USO') {
      statusColor = const Color(0xFF8B5CF6);
      statusText = 'Em Uso';
    } else if (upperStatus == 'CAUTELADO') {
      statusColor = AppColors.cyan;
      statusText = (item.cautelaAtiva != null &&
              (item.cautelaAtiva!['tipo'] == 'FIXA' || item.cautelaAtiva!['cautela_tipo'] == 'FIXA'))
          ? 'Setor (Fixa)'
          : 'Cautelado';
    } else if (upperStatus == 'EM_MANUTENCAO') {
      statusColor = AppColors.warning;
      statusText = 'Manutenção';
    } else if (upperStatus == 'BAIXADO') {
      statusColor = Colors.grey;
      statusText = 'Baixado';
    } else {
      statusColor = AppColors.danger;
      statusText = item.status;
    }

    final double ratio = item.quantidadeMinima > 0
        ? (item.quantidade / (item.quantidadeMinima * 3)).clamp(0.05, 1.0)
        : (item.quantidade > 0 ? 0.95 : 0.0);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header da Barra de Inspeção
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'PAINEL DE INSPEÇÃO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.cyan,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                Tooltip(
                  message: 'Expandir Modal Completo com QR Code e Histórico',
                  child: IconButton(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: onOpenFullDialog,
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Fechar Painel (Esc)',
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: onClose,
                  ),
                ),
              ],
            ),
          ),

          // Conteúdo com Rolagem
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card Principal: Foto/Ícone + Nome + BMP + Status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            _getItemIcon(item.nome),
                            size: 24,
                            color: AppColors.cyan,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.nome,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    final textToCopy = item.bmp ?? item.codigoInterno ?? item.nome;
                                    Clipboard.setData(ClipboardData(text: textToCopy));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: AppColors.cyanDark,
                                        content: Text('Copiado: $textToCopy'),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          item.bmp != null ? 'BMP-${item.bmp}' : (item.codigoInterno ?? 'S/ BMP'),
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.cyan,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.copy, size: 10, color: AppColors.cyan),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: statusColor.withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Nível de Estoque
                  _buildPropertyRow(
                    label: 'Quantidade em Estoque',
                    value: '${item.quantidade} ${item.unidadeMedida.toLowerCase()}',
                    isDark: isDark,
                    trailing: item.quantidade <= item.quantidadeMinima
                        ? const Text(
                            'Estoque Baixo',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.warning),
                          )
                        : null,
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        item.quantidade <= item.quantidadeMinima ? AppColors.warning : AppColors.cyan,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Localização Atual com Botão de Ação Rápida
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161F31) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF23304B) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.estaEmSetor
                              ? Icons.domain_outlined
                              : (item.cautelaAtiva != null ? Icons.shield_outlined : Icons.warehouse_outlined),
                          size: 20,
                          color: item.estaEmSetor
                              ? const Color(0xFF8B5CF6)
                              : (item.cautelaAtiva != null ? AppColors.warning : AppColors.cyan),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Localização Atual',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.localizacaoAtual,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.swap_horiz, size: 18),
                          tooltip: 'Transferir Local',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => MovementDialog(item: item),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Detalhes Específicos
                  _buildPropertyRow(label: 'Categoria / Subgrupo', value: item.subgrupo?.nome ?? 'Geral', isDark: isDark),
                  const SizedBox(height: 8),
                  _buildPropertyRow(label: 'Número de Série', value: item.numeroSerie ?? 'Não cadastrado', isDark: isDark),
                  const SizedBox(height: 8),
                  _buildPropertyRow(label: 'Código Interno', value: item.codigoInterno ?? '-', isDark: isDark),
                  if (item.observacoes != null && item.observacoes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildPropertyRow(label: 'Observações', value: item.observacoes!, isDark: isDark),
                  ],

                  // Se estiver Cautelado
                  if (item.cautelaAtiva != null || upperStatus == 'CAUTELADO') ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shield_outlined, size: 16, color: AppColors.cyan),
                              const SizedBox(width: 6),
                              const Text(
                                'Material Sob Cautela Ativa',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.cyan),
                              ),
                              const Spacer(),
                              if (onNavigate != null)
                                TextButton(
                                  onPressed: () => onNavigate!(2),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Ver Cautelas', style: TextStyle(fontSize: 10.5)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Responsável: ${item.cautelaAtiva?['militar_nome'] ?? item.cautelaAtiva?['militar']?['nome'] ?? 'Militar Registrado'}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          if (item.cautelaAtiva?['data_cautela'] != null)
                            Text(
                              'Retirado em: ${item.cautelaAtiva!['data_cautela']}',
                              style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white60 : Colors.black54),
                            ),
                        ],
                      ),
                    ),
                  ],

                  // Se estiver em Manutenção
                  if (upperStatus == 'EM_MANUTENCAO') ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.handyman_outlined, size: 16, color: AppColors.warning),
                              const SizedBox(width: 6),
                              const Text(
                                'Em Manutenção Técnica',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.warning),
                              ),
                              const Spacer(),
                              if (onNavigate != null)
                                TextButton(
                                  onPressed: () => onNavigate!(3),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Ir à Bancada', style: TextStyle(fontSize: 10.5, color: AppColors.warning)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Defeito: ${item.defeitoManutencao ?? "Falha relatada na bancada"}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Barra de Ações Rápidas no Rodapé do Painel
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: BorderSide(color: isDark ? const Color(0xFF2E3D5B) : const Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Editar', style: TextStyle(fontSize: 11.5)),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => ItemFormDialog(item: item),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cyan,
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 1,
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 15, color: Color(0xFF0F172A)),
                    label: const Text('Histórico', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    onPressed: onOpenFullDialog,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyRow({
    required String label,
    required String value,
    required bool isDark,
    Widget? trailing,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        if (trailing != null)
          trailing
        else
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  IconData _getItemIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('optiplex') || lower.contains('computador') || lower.contains('desktop') || lower.contains('pc')) {
      return Icons.computer;
    } else if (lower.contains('notebook') || lower.contains('laptop') || lower.contains('dell')) {
      return Icons.laptop_chromebook;
    } else if (lower.contains('monitor') || lower.contains('tela')) {
      return Icons.desktop_windows_outlined;
    } else if (lower.contains('switch') || lower.contains('roteador') || lower.contains('cisco')) {
      return Icons.router_outlined;
    } else if (lower.contains('nobreak') || lower.contains('apc') || lower.contains('ups')) {
      return Icons.battery_charging_full_outlined;
    } else if (lower.contains('rádio') || lower.contains('ht') || lower.contains('motorola')) {
      return Icons.settings_remote_outlined;
    }
    return Icons.devices_other;
  }
}
