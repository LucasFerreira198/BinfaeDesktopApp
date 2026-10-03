import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/item.dart';
import '../providers/stock_provider.dart';
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
    _tabController = TabController(length: 4, vsync: this);
    _loadItemHistory();
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
                      pw.Text('BINFAE-GL - CONTROLE PATRIMONIAL', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
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

  void _showMaintenanceSubModal() {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Registrar Manutenção'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Deseja encaminhar "${_currentItem.nome}" para manutenção preventiva/corretiva?'),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Motivo / Defeito constatado',
                  hintText: 'Ex: Troca de fonte, lentidão...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.maintenance, foregroundColor: Colors.black),
            onPressed: () async {
              Navigator.pop(ctx);
              final stock = Provider.of<StockProvider>(context, listen: false);
              try {
                await stock.moveItem(
                  itemId: _currentItem.id,
                  tipoMovimentacao: 'MANUTENCAO',
                  quantidade: _currentItem.quantidade,
                  motivo: noteController.text.trim().isNotEmpty ? noteController.text.trim() : 'Encaminhado para manutenção',
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(backgroundColor: AppColors.success, content: Text('Material encaminhado para manutenção com sucesso!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: AppColors.danger, content: Text('Erro: $e')),
                  );
                }
              }
            },
            child: const Text('Confirmar Manutenção', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final qrPayload = '{"id":${_currentItem.id},"bmp":"${_currentItem.bmp ?? ''}","nome":"${_currentItem.nome}"}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: isDark ? const Color(0xFF0E1422) : Colors.white,
      child: Container(
        width: 780,
        height: 640,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header do Modal: Detalhes do Material com BMP visível
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primaryLight.withOpacity(0.4)),
                              ),
                              child: Text(
                                'BMP: ${_currentItem.bmp}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getStatusColor(_currentItem.status).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
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
                          const SizedBox(width: 8),
                          Text(
                            'ID #${_currentItem.id}',
                            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Detalhes do Material: ${_currentItem.nome}',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Fechar (Esc)',
                  icon: const Icon(Icons.close, size: 22),
                ),
              ],
            ),
            if (_currentItem.cautelaAtiva != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.assignment_ind_outlined, color: Colors.amber[800], size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MATERIAL EM CAUTELA ATIVA (${_currentItem.cautelaAtiva!.tipo == 'MISSAO' ? 'Missão Operacional' : 'Cautela Fixa'}: ${_currentItem.cautelaAtiva!.missaoNome})',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.amber[300] : Colors.amber[900]),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Responsável: ${_currentItem.cautelaAtiva!.militarPostoGraduacao} ${_currentItem.cautelaAtiva!.militarNomeGuerra} (SARAM ${_currentItem.cautelaAtiva!.militarResponsavelSaram}) • Contato: ${_currentItem.cautelaAtiva!.militarCelular ?? "Não informado"}',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Abas de Navegação Estilizadas
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryLight,
              unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.info_outline, size: 17), text: 'Especificações & Galeria'),
                Tab(icon: Icon(Icons.history, size: 17), text: 'Histórico de Cautela'),
                Tab(icon: Icon(Icons.bolt, size: 17), text: 'Ações Rápidas'),
                Tab(icon: Icon(Icons.qr_code_2, size: 17), text: 'Etiqueta & QR Code'),
              ],
            ),
            const SizedBox(height: 16),

            // Conteúdo das Abas
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Galeria de Fotos e Especificações Detalhadas
                  _buildDetailsAndGalleryTab(isDark),

                  // Tab 2: Histórico Específico de Cautela e Movimentações
                  _buildHistoryTab(isDark),

                  // Tab 3: Aba Ações Rápidas (Mini-Dashboard de Movimentações)
                  _buildQuickActionsTab(isDark),

                  // Tab 4: Etiqueta e Impressão Térmica
                  _buildLabelTab(isDark, qrPayload),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Rodapé com Botões de Ação
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
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Transferir Local', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // Tab 1: Galeria de Imagens (2 Fotos) + Especificações
  Widget _buildDetailsAndGalleryTab(bool isDark) {
    final locationPath = _currentItem.local != null
        ? (_currentItem.local!.caminhoCompleto ?? _currentItem.local!.nome).replaceAll(' > ', ' ➔ ').replaceAll(' / ', ' ➔ ').replaceAll('/', ' ➔ ')
        : 'Sem local físico cadastrado';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Galeria de Imagens do Item (2 Fotos / Hardware Preview Cards)
          Row(
            children: [
              Expanded(
                child: _buildGalleryCard(
                  title: 'Visão Frontal do Equipamento',
                  subtitle: 'Foto 1 • Registro de Patrimônio',
                  icon: Icons.computer,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGalleryCard(
                  title: 'Etiqueta & Portas Traseiras',
                  subtitle: 'Foto 2 • Conexões e Serial',
                  icon: Icons.qr_code_scanner,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Título de Especificações
          Text(
            'ESPECIFICAÇÕES TÉCNICAS E LOCALIZAÇÃO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151D2F) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildSpecRow('Local Físico (Hierarquia)', locationPath, isDark),
                _buildSpecRow('Categoria / Subgrupo', _currentItem.subgrupo?.nome ?? 'Geral', isDark),
                _buildSpecRow('Saldo Atual em Estoque', '${_currentItem.quantidade} ${_currentItem.unidadeMedida}', isDark),
                _buildSpecRow('Estoque Mínimo de Segurança', '${_currentItem.quantidadeMinima} ${_currentItem.unidadeMedida}', isDark),
                _buildSpecRow('Estado de Conservação', _currentItem.estadoConservacao.replaceAll('_', ' '), isDark),
                _buildSpecRow('Tipo de Controle', _currentItem.tipoControle, isDark),
                if (_currentItem.numeroSerie != null && _currentItem.numeroSerie!.isNotEmpty)
                  _buildSpecRow('Número de Série', _currentItem.numeroSerie!, isDark),
                if (_currentItem.codigoInterno != null && _currentItem.codigoInterno!.isNotEmpty)
                  _buildSpecRow('Código Interno', _currentItem.codigoInterno!, isDark),
                if (_currentItem.observacoes != null && _currentItem.observacoes!.isNotEmpty)
                  _buildSpecRow('Observações', _currentItem.observacoes!, isDark),
              ],
            ),
          ),

          if (_currentItem.componentes != null && _currentItem.componentes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'SUBCOMPONENTES VINCULADOS (${_currentItem.componentes!.length})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151D2F) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: _currentItem.componentes!.map((comp) {
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.link, size: 18, color: AppColors.primaryLight),
                    title: Text(comp.nome, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    subtitle: Text('Quantidade: ${comp.quantidade} • BMP: ${comp.bmp ?? "N/A"}', style: const TextStyle(fontSize: 10)),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGalleryCard({required String title, required String subtitle, required IconData icon, required bool isDark}) {
    return Container(
      height: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D2F) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF243049) : const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [Colors.white, const Color(0xFFE2E8F0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Icon(icon, size: 32, color: AppColors.primaryLight),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Anexo Ativo', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tab 2: Histórico de Cautela e Movimentações
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 48, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 10),
            const Text('Nenhuma movimentação registrada para este material.', style: TextStyle(color: Colors.grey)),
          ],
        ),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  m.tipoMovimentacao,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quantidade: ${m.quantidadeMovimentada} • $dateStr', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    if (m.motivo != null && m.motivo!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(m.motivo!, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Tab 3: Aba Ações Rápidas (Mini-Dashboard de Movimentações)
  Widget _buildQuickActionsTab(bool isDark) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mini-dashboard de métricas do item
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF151D2F) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total de Movimentações', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        '${_itemMovements.length}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF151D2F) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Status Operacional', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        _currentItem.status,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _getStatusColor(_currentItem.status)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Botões de Ação que abrem sub-modais menores
          Text(
            'OPERAÇÕES DISPONÍVEIS PARA ESTE ITEM',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),

          // 1. Transferir Local
          _buildActionButton(
            label: 'Transferir Local Físico',
            description: 'Mudar a localização do item (Depósito, Armário, Prateleira ou Bancada)',
            icon: Icons.swap_horiz,
            color: AppColors.primary,
            isDark: isDark,
            onTap: () {
              Navigator.of(context).pop();
              showDialog(
                context: context,
                builder: (ctx) => MovementDialog(item: _currentItem),
              );
            },
          ),
          const SizedBox(height: 10),

          // 2. Registrar Manutenção
          _buildActionButton(
            label: 'Registrar Manutenção Preventiva/Corretiva',
            description: 'Definir status como "EM_MANUTENCAO" e registrar diagnóstico técnico',
            icon: Icons.build_outlined,
            color: AppColors.maintenance,
            isDark: isDark,
            onTap: _showMaintenanceSubModal,
          ),
          const SizedBox(height: 10),

          // 3. Imprimir Etiqueta Térmica Directa
          _buildActionButton(
            label: 'Imprimir Etiqueta Térmica com QR Code',
            description: 'Enviar formato de etiqueta 100x60mm para impressora térmica conectada',
            icon: Icons.print_outlined,
            color: AppColors.success,
            isDark: isDark,
            onTap: _printLabel,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required String description,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151D2F) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // Tab 4: Etiqueta e Impressão Térmica
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
                      const Text('BINFAE-GL - CONTROLE PATRIMONIAL', style: TextStyle(fontSize: 8, color: Colors.black54)),
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
                label: const Text('Imprimir Etiqueta Térmica Direta (100x60mm)'),
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
            width: 190,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
        return AppColors.maintenance;
      default:
        return AppColors.info;
    }
  }
}
