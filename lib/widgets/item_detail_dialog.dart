import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/item.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'movement_dialog.dart';
import 'item_form_dialog.dart';

class ItemDetailDialog extends StatefulWidget {
  final ItemModel item;

  const ItemDetailDialog({super.key, required this.item});

  @override
  State<ItemDetailDialog> createState() => _ItemDetailDialogState();
}

class _ItemDetailDialogState extends State<ItemDetailDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ItemModel _currentItem;

  List<ItemMovementModel> _itemMovements = [];
  bool _isLoadingHistory = false;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _itemMovements.isEmpty && !_isLoadingHistory) {
        _loadItemHistory();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadItemHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final list = await api.fetchMovements(itemId: _currentItem.id);
      if (mounted) {
        setState(() {
          _itemMovements = list;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historyError = e.toString().replaceAll('Exception: ', '');
          _isLoadingHistory = false;
        });
      }
    }
  }

  Future<void> _printLabel() async {
    final pdf = pw.Document();
    final qrData = '{"id":${_currentItem.id},"bmp":"${_currentItem.bmp ?? ''}","nome":"${_currentItem.nome}"}';

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(100 * PdfPageFormat.mm, 60 * PdfPageFormat.mm, marginAll: 3 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(5),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1.2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('FORÇA AÉREA BRASILEIRA', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.Text('BINFAE - CONTROLE PATRIMONIAL', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                      pw.Divider(thickness: 0.5),
                      pw.Text('BMP: ${_currentItem.bmp ?? "S/ BMP"}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      pw.Text(_currentItem.nome, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold), maxLines: 2),
                      pw.Text('Local: ${_currentItem.local?.nome ?? "Depósito"}', style: const pw.TextStyle(fontSize: 7)),
                      pw.Text('ID #${_currentItem.id} • ${DateFormat("dd/MM/yyyy").format(DateTime.now())}', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Container(
                  width: 75,
                  height: 75,
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrData,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Etiqueta_${_currentItem.bmp ?? _currentItem.id}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final qrPayload = '{"id":${_currentItem.id},"bmp":"${_currentItem.bmp ?? ''}","nome":"${_currentItem.nome}"}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 720,
        height: 600,
        padding: const EdgeInsets.all(26),
        child: Column(
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
                          if (_currentItem.bmp != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'BMP: ${_currentItem.bmp}',
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
                              color: _getStatusColor(_currentItem.status).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _currentItem.status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(_currentItem.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _currentItem.nome,
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
            const SizedBox(height: 12),

            // Abas de Navegação
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.info_outline, size: 18), text: 'Detalhes'),
                Tab(icon: Icon(Icons.history, size: 18), text: 'Histórico do Item'),
                Tab(icon: Icon(Icons.qr_code_2, size: 18), text: 'Etiqueta & QR Code'),
              ],
            ),
            const SizedBox(height: 16),

            // Conteúdo das Abas
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Detalhes
                  _buildDetailsTab(isDark),

                  // Tab 2: Histórico Específico
                  _buildHistoryTab(isDark),

                  // Tab 3: Etiqueta e Impressão
                  _buildLabelTab(isDark, qrPayload),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Rodapé com Ações
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final res = await showDialog(
                      context: context,
                      builder: (ctx) => ItemFormDialog(item: _currentItem),
                    );
                    if (res == true && mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Editar Material'),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Fechar'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        showDialog(
                          context: context,
                          builder: (ctx) => MovementDialog(item: _currentItem),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Movimentar / Transferir'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab(bool isDark) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildSpecRow('Local Físico', _currentItem.local?.caminhoCompleto ?? _currentItem.local?.nome ?? 'Sem local', isDark),
          _buildSpecRow('Categoria / Subgrupo', _currentItem.subgrupo?.nome ?? 'Geral', isDark),
          _buildSpecRow('Saldo em Estoque', '${_currentItem.quantidade} ${_currentItem.unidadeMedida}', isDark),
          _buildSpecRow('Estoque Mínimo de Segurança', '${_currentItem.quantidadeMinima} ${_currentItem.unidadeMedida}', isDark),
          _buildSpecRow('Estado de Conservação', _currentItem.estadoConservacao.replaceAll('_', ' '), isDark),
          _buildSpecRow('Tipo de Controle', _currentItem.tipoControle, isDark),
          if (_currentItem.numeroSerie != null)
            _buildSpecRow('Número de Série', _currentItem.numeroSerie!, isDark),
          if (_currentItem.codigoInterno != null)
            _buildSpecRow('Código Interno', _currentItem.codigoInterno!, isDark),
          if (_currentItem.observacoes != null)
            _buildSpecRow('Observações', _currentItem.observacoes!, isDark),
          if (_currentItem.componentes != null && _currentItem.componentes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Subcomponentes Vinculados (${_currentItem.componentes!.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(height: 6),
            ..._currentItem.componentes!.map((comp) {
              return ListTile(
                dense: true,
                leading: const Icon(Icons.link, size: 16),
                title: Text(comp.nome, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                subtitle: Text('Qtd: ${comp.quantidade} • BMP: ${comp.bmp ?? "N/A"}', style: const TextStyle(fontSize: 10)),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryTab(bool isDark) {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_historyError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Erro ao obter histórico: $_historyError'),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _loadItemHistory, child: const Text('Recarregar')),
          ],
        ),
      );
    }

    if (_itemMovements.isEmpty) {
      return const Center(
        child: Text('Nenhuma movimentação registrada para este material.', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.separated(
      itemCount: _itemMovements.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF1F293D) : const Color(0xFFF1F5F9)),
      itemBuilder: (context, index) {
        final m = _itemMovements[index];
        final typeColor = _getStatusColor(m.tipoMovimentacao);

        String dateStr = m.criadoEm ?? '';
        try {
          dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(m.criadoEm!).toLocal());
        } catch (_) {}

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  m.tipoMovimentacao,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Qtd: ${m.quantidadeMovimentada} • $dateStr', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    if (m.motivo != null && m.motivo!.isNotEmpty)
                      Text(m.motivo!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLabelTab(bool isDark, String qrPayload) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Preview da Etiqueta Térmica
          Container(
            width: 440,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black45, width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('FORÇA AÉREA BRASILEIRA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black)),
                      const Text('BINFAE - CONTROLE PATRIMONIAL', style: TextStyle(fontSize: 8, color: Colors.black54)),
                      const Divider(thickness: 1, color: Colors.black26),
                      Text(
                        'BMP: ${_currentItem.bmp ?? "SEM BMP"}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentItem.nome,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text('Local: ${_currentItem.local?.nome ?? "Depósito"}', style: const TextStyle(fontSize: 9, color: Colors.black54)),
                      Text('ID #${_currentItem.id}', style: const TextStyle(fontSize: 8, color: Colors.black38)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: QrImageView(
                    data: qrPayload,
                    version: QrVersions.auto,
                    size: 96,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Botões de Ação para Impressão
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _printLabel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Imprimir Etiqueta Térmica Directa (100x60mm)'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _printLabel,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('Exportar PDF'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
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
                fontSize: 13,
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
    switch (status.toUpperCase()) {
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
