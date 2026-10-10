import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/cautela.dart';
import '../models/item.dart';
import '../models/user.dart';
import '../providers/stock_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class CautelaDetailDialog extends StatefulWidget {
  final CautelaModel cautela;
  final VoidCallback onUpdated;

  const CautelaDetailDialog({
    super.key,
    required this.cautela,
    required this.onUpdated,
  });

  @override
  State<CautelaDetailDialog> createState() => _CautelaDetailDialogState();
}

class _CautelaDetailDialogState extends State<CautelaDetailDialog> {
  late CautelaModel _cautela;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cautela = widget.cautela;
    _refreshDetails();
  }

  Future<void> _refreshDetails() async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final fresh = await api.getCautela(_cautela.id);
      if (mounted) {
        setState(() {
          _cautela = fresh;
          _isLoading = false;
        });
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteCautela() async {
    final itensAtivos = _cautela.itens.where((i) => i.status == 'CAUTELADO' || i.status == 'EM_USO').toList();
    if (itensAtivos.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Exclusão Bloqueada'),
            ],
          ),
          content: Text(
            'Esta ${_cautela.isMissao ? "missão" : "cautela"} possui ${itensAtivos.length} material(is) ainda cautelado(s). Devolva todos os materiais antes de excluir.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Excluir Cautela / Missão'),
          ],
        ),
        content: Text(
          'Deseja excluir permanentemente "${_cautela.nome}"?\nEsta ação não poderá ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir Permanentemente'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.deleteCautela(_cautela.id);
      widget.onUpdated();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Missão/Cautela excluída com sucesso.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _abrirModalEditarCautela() async {
    final nomeCtrl = TextEditingController(text: _cautela.nome);
    final obsCtrl = TextEditingController(text: _cautela.observacoes ?? '');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final salvar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151D2F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Editar ${_cautela.isMissao ? "Missão" : "Cautela"}'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome / Identificação *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: obsCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observações (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              if (nomeCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('O nome não pode ser vazio.'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (salvar != true) return;

    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final updated = await api.updateCautela(
        _cautela.id,
        nome: nomeCtrl.text.trim(),
        observacoes: obsCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _cautela = updated;
          _isLoading = false;
        });
        widget.onUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cautela atualizada com sucesso!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _confirmDevolverItem(CautelaItemModel item) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final condicaoController = TextEditingController(text: item.condicaoSaida);
    final obsController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151D2F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.assignment_return_outlined, color: AppColors.primary),
            const SizedBox(width: 10),
            const Text('Confirmar Devolução'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deseja registrar o retorno do seguinte material?',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E3D5B) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.item?.nome ?? 'Material #${item.itemId}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    if (item.item?.bmp != null)
                      Text(
                        'BMP: ${item.item!.bmp}',
                        style: const TextStyle(fontSize: 12, color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Responsável: ${item.militar?.postoGraduacao ?? ''} ${item.militar?.nomeGuerra ?? ''} (SARAM ${item.militarSaram})',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                    if (item.telefoneContato != null && item.telefoneContato!.isNotEmpty)
                      Text(
                        'Telefone: ${item.telefoneContato}',
                        style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Condição no Retorno:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: condicaoController.text,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'BOM', child: Text('BOM (Sem alterações)')),
                  DropdownMenuItem(value: 'REGULAR', child: Text('REGULAR (Desgaste natural)')),
                  DropdownMenuItem(value: 'DANIFICADO', child: Text('DANIFICADO (Necessita reparo)')),
                  DropdownMenuItem(value: 'EXTRAVIADO', child: Text('EXTRAVIADO / INOPERANTE')),
                ],
                onChanged: (val) {
                  if (val != null) condicaoController.text = val;
                },
              ),
              const SizedBox(height: 12),
              const Text('Observações (Opcional):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: obsController,
                decoration: InputDecoration(
                  hintText: 'Ex: Entregue limpo e com acessórios...',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar Devolução'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final stock = Provider.of<StockProvider>(context, listen: false);
      await api.devolverItemCautela(
        _cautela.id,
        item.itemId,
        condicaoRetorno: condicaoController.text,
        observacoes: obsController.text,
      );
      await stock.syncData();
      await StorageService().invalidateUltimoRelatorio();
      await _refreshDetails();

      if (mounted) {
        final isConcluded = _cautela.status == 'CONCLUIDA';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              isConcluded
                  ? 'Material devolvido com sucesso! Todos os materiais retornaram e a missão foi CONCLUÍDA automaticamente.'
                  : 'Material devolvido com sucesso!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Erro ao devolver material: $e'),
          ),
        );
      }
    }
  }

  void _showItemOptionsModal(CautelaItemModel item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151D2F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.item?.nome ?? 'Material #${item.itemId}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BMP: ${item.item?.bmp ?? 'Não informado'} | Responsável: ${item.militar?.postoGraduacao ?? ''} ${item.militar?.nomeGuerra ?? ''}',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: isDark ? const Color(0xFF2E3D5B) : const Color(0xFFE2E8F0)),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                ),
                title: const Text('Escanear QR Code deste Material', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('Apenas o código deste material será aceito na leitura', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openTargetedScanDialog(item);
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: isDark ? const Color(0xFF2E3D5B) : const Color(0xFFE2E8F0)),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.assignment_turned_in, color: AppColors.success),
                ),
                title: const Text('Descautelar Manualmente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('Confirmar devolução e estado do material sem scanner', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmDevolverItem(item);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _openTargetedScanDialog(CautelaItemModel item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scanController = TextEditingController();
    final focusNode = FocusNode();

    showDialog(
      context: context,
      builder: (ctx) {
        WidgetsBinding.instance.addPostFrameCallback((_) => focusNode.requestFocus());
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool scanning = false;
            String? scanMsg;
            bool isError = false;

            Future<void> submitCode(String code) async {
              final trimmed = code.trim();
              if (trimmed.isEmpty) return;

              final validCodes = <String>{
                if (item.item?.bmp != null && item.item!.bmp!.isNotEmpty) item.item!.bmp!.trim().toLowerCase(),
                if (item.item?.codigoInterno != null && item.item!.codigoInterno!.isNotEmpty) item.item!.codigoInterno!.trim().toLowerCase(),
                if (item.item?.numeroSerie != null && item.item!.numeroSerie!.isNotEmpty) item.item!.numeroSerie!.trim().toLowerCase(),
                item.itemId.toString().trim().toLowerCase(),
              };

              if (!validCodes.contains(trimmed.toLowerCase())) {
                setModalState(() {
                  scanning = false;
                  isError = true;
                  scanMsg = 'Código Inválido! O código "$trimmed" não pertence ao material selecionado (${item.item?.nome ?? 'ID ${item.itemId}'}).';
                });
                scanController.clear();
                focusNode.requestFocus();
                return;
              }

              setModalState(() {
                scanning = true;
                scanMsg = null;
                isError = false;
              });

              try {
                final api = Provider.of<ApiService>(context, listen: false);
                final stock = Provider.of<StockProvider>(context, listen: false);
                final res = await api.scanDevolverItem(trimmed);
                await stock.syncData();
                await _refreshDetails();

                if (context.mounted) {
                  setModalState(() {
                    scanning = false;
                    isError = false;
                    scanMsg = 'Sucesso! Material "${res.item?.nome ?? trimmed}" devolvido.';
                  });
                  Future.delayed(const Duration(milliseconds: 1400), () {
                    if (context.mounted) Navigator.of(ctx).pop();
                  });
                }
              } catch (e) {
                if (context.mounted) {
                  setModalState(() {
                    scanning = false;
                    isError = true;
                    scanMsg = 'Erro: ${e.toString().replaceAll('Exception: ', '')}';
                  });
                  scanController.clear();
                  focusNode.requestFocus();
                }
              }
            }

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF151D2F) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Escanear Material Específico'),
                  ),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.item?.nome ?? 'Material #${item.itemId}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'BMP Esperado: ${item.item?.bmp ?? 'Nenhum'} | Responsável: ${item.militar?.nomeGuerra ?? '-'}',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Passe o leitor USB ou digite o código deste material específico:',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: scanController,
                      focusNode: focusNode,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Aguardando leitura do leitor ou digitação...',
                        prefixIcon: const Icon(Icons.qr_code, color: AppColors.primaryLight),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onSubmitted: (code) => submitCode(code),
                    ),
                    if (scanning) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    if (scanMsg != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isError
                              ? AppColors.danger.withOpacity(0.15)
                              : AppColors.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isError ? AppColors.danger.withOpacity(0.3) : AppColors.success.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isError ? Icons.error_outline : Icons.check_circle_outline,
                              color: isError ? AppColors.danger : AppColors.success,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                scanMsg!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isError ? AppColors.danger : AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openAddMaterialsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddCautelaMaterialModal(
        cautela: _cautela,
        onAdded: () async {
          final stock = Provider.of<StockProvider>(context, listen: false);
          await stock.syncData();
          await _refreshDetails();
        },
      ),
    );
  }

  void _openQuickScanDevolucaoDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scanController = TextEditingController();
    final focusNode = FocusNode();

    showDialog(
      context: context,
      builder: (ctx) {
        WidgetsBinding.instance.addPostFrameCallback((_) => focusNode.requestFocus());
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool scanning = false;
            String? scanMsg;

            Future<void> submitCode(String code) async {
              final trimmed = code.trim();
              if (trimmed.isEmpty) return;
              setModalState(() {
                scanning = true;
                scanMsg = null;
              });

              try {
                final api = Provider.of<ApiService>(context, listen: false);
                final stock = Provider.of<StockProvider>(context, listen: false);
                final res = await api.scanDevolverItem(trimmed);
                await stock.syncData();
                await _refreshDetails();

                if (context.mounted) {
                  setModalState(() {
                    scanning = false;
                    scanMsg = 'Sucesso! Material "${res.item?.nome ?? trimmed}" devolvido.';
                  });
                  scanController.clear();
                  focusNode.requestFocus();
                }
              } catch (e) {
                if (context.mounted) {
                  setModalState(() {
                    scanning = false;
                    scanMsg = 'Erro: ${e.toString().replaceAll('Exception: ', '')}';
                  });
                  scanController.clear();
                  focusNode.requestFocus();
                }
              }
            }

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF151D2F) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                  const SizedBox(width: 10),
                  const Text('Descautelar por Scanner / QR Code'),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Passe o leitor de código de barras ou digite o BMP/Serial para descautelar imediatamente:',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: scanController,
                      focusNode: focusNode,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Aguardando leitura do leitor USB ou digitação...',
                        prefixIcon: const Icon(Icons.qr_code, color: AppColors.primaryLight),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onSubmitted: (code) => submitCode(code),
                    ),
                    if (scanning) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    if (scanMsg != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scanMsg!.startsWith('Sucesso')
                              ? AppColors.success.withOpacity(0.15)
                              : AppColors.danger.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          scanMsg!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: scanMsg!.startsWith('Sucesso') ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Concluir'),
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
    final isMission = _cautela.tipo == 'MISSAO';
    final isConcluded = _cautela.status == 'CONCLUIDA';
    final total = _cautela.totalItens;
    final devolvidos = _cautela.itensDevolvidos;
    final pendentes = _cautela.itensPendentes;
    final progresso = total > 0 ? (devolvidos / total) : 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Container(
        width: 950,
        height: 680,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Topo do Header: Tipo, Título e Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMission
                        ? AppColors.primary.withOpacity(0.15)
                        : Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isMission ? Icons.rocket_launch_outlined : Icons.lock_clock_outlined,
                    color: isMission ? AppColors.primary : Colors.orange,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isMission
                                  ? AppColors.primary.withOpacity(0.15)
                                  : Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isMission ? 'MISSÃO OPERACIONAL' : 'CAUTELA FIXA',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isMission ? AppColors.primaryLight : Colors.orange,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isConcluded
                                  ? Colors.grey.withOpacity(0.15)
                                  : AppColors.success.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isConcluded ? Icons.check_circle : Icons.radio_button_checked,
                                  size: 12,
                                  color: isConcluded ? Colors.grey : AppColors.success,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isConcluded ? 'CONCLUÍDA' : 'ATIVA',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isConcluded ? Colors.grey : AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _cautela.nome,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Criado por: ${_cautela.criador?.postoGraduacao ?? ''} ${_cautela.criador?.nomeGuerra ?? ''}',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                          ),
                          const SizedBox(width: 12),
                          Text('•', style: TextStyle(color: isDark ? Colors.white30 : Colors.black26)),
                          const SizedBox(width: 12),
                          Text(
                            'Início: ${DateFormat('dd/MM/yyyy HH:mm').format(_cautela.dataInicio.toLocal())}',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                          ),
                          if (_cautela.dataFim != null) ...[
                            const SizedBox(width: 12),
                            Text('•', style: TextStyle(color: isDark ? Colors.white30 : Colors.black26)),
                            const SizedBox(width: 12),
                            Text(
                              'Conclusão: ${DateFormat('dd/MM/yyyy HH:mm').format(_cautela.dataFim!.toLocal())}',
                              style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                      tooltip: 'Editar Identificação / Observações',
                      onPressed: _abrirModalEditarCautela,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                      tooltip: 'Excluir Cautela / Missão',
                      onPressed: _confirmDeleteCautela,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Barra de Progresso e Ações
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151D2F) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Devolução de Materiais: $devolvidos de $total concluídos',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${(progresso * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isConcluded ? AppColors.success : AppColors.primaryLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progresso,
                            minHeight: 6,
                            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isConcluded ? AppColors.success : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isConcluded) ...[
                    const SizedBox(width: 24),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryLight,
                        side: const BorderSide(color: AppColors.primaryLight),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onPressed: _openQuickScanDevolucaoDialog,
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: const Text('Escanear Retorno'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: _openAddMaterialsDialog,
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text('Cautelar Materiais'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Título da Lista
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Materiais Cautelados (${_cautela.itens.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Atualizar Lista',
                  onPressed: _refreshDetails,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Tabela com Itens
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _cautela.itens.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.withOpacity(0.5)),
                              const SizedBox(height: 12),
                              const Text(
                                'Nenhum material adicionado a esta cautela ainda.',
                                style: TextStyle(color: Colors.grey),
                              ),
                              if (!isConcluded) ...[
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _openAddMaterialsDialog,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Adicionar Primeiro Material'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF151D2F) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ListView.separated(
                              itemCount: _cautela.itens.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              ),
                              itemBuilder: (context, index) {
                                final item = _cautela.itens[index];
                                final isEmUso = item.status == 'CAUTELADO' || item.status == 'EM_USO';

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  onTap: isEmUso ? () => _showItemOptionsModal(item) : null,
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isEmUso
                                          ? Colors.amber.withOpacity(0.15)
                                          : AppColors.success.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      isEmUso ? Icons.outbox : Icons.move_to_inbox,
                                      color: isEmUso ? Colors.amber[700] : AppColors.success,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.item?.nome ?? 'Material #${item.itemId}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ),
                                      if (item.item?.bmp != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'BMP ${item.item!.bmp}',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primaryLight,
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isEmUso
                                              ? Colors.amber.withOpacity(0.15)
                                              : AppColors.success.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isEmUso ? 'EM USO' : 'DEVOLVIDO',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isEmUso ? Colors.amber[700] : AppColors.success,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.person_pin, size: 14, color: AppColors.primaryLight),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${item.militar?.postoGraduacao ?? ''} ${item.militar?.nomeGuerra ?? ''} (SARAM ${item.militarSaram})',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        const Icon(Icons.phone_outlined, size: 13, color: AppColors.success),
                                        const SizedBox(width: 4),
                                        Text(
                                          (item.telefoneContato != null && item.telefoneContato!.isNotEmpty)
                                              ? item.telefoneContato!
                                              : 'Sem telefone',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: (item.telefoneContato != null && item.telefoneContato!.isNotEmpty)
                                                ? AppColors.success
                                                : Colors.grey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        const Icon(Icons.access_time, size: 13, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Saída: ${DateFormat('dd/MM HH:mm').format(item.dataCautela.toLocal())}',
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                        if (item.dataDevolucao != null) ...[
                                          const SizedBox(width: 10),
                                          Text(
                                            '• Retorno: ${DateFormat('dd/MM HH:mm').format(item.dataDevolucao!.toLocal())}',
                                            style: const TextStyle(fontSize: 11, color: AppColors.success),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  trailing: isEmUso
                                      ? ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.success,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          onPressed: () => _showItemOptionsModal(item),
                                          icon: const Icon(Icons.assignment_turned_in, size: 15),
                                          label: const Text('Devolver', style: TextStyle(fontSize: 11.5)),
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.success.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Devolvido',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.success,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                );
                              },
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// Modal para adicionar materiais (Fluxo: Seleciona Militar Primeiro -> Confirma/Edita Telefone no canto -> Seleciona/Escaneia Material)
class _AddCautelaMaterialModal extends StatefulWidget {
  final CautelaModel cautela;
  final VoidCallback onAdded;

  const _AddCautelaMaterialModal({
    required this.cautela,
    required this.onAdded,
  });

  @override
  State<_AddCautelaMaterialModal> createState() => _AddCautelaMaterialModalState();
}

class _AddCautelaMaterialModalState extends State<_AddCautelaMaterialModal> {
  // Lista de militares
  List<MilitaryModel> _militaries = [];
  bool _loadingMilitaries = true;
  MilitaryModel? _selectedMilitary;
  final TextEditingController _militarySearchCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  // Seleção e scanner de materiais
  final TextEditingController _itemScannerCtrl = TextEditingController();
  final FocusNode _scannerFocusNode = FocusNode();
  ItemModel? _selectedItem;

  // Lote / Múltiplos itens
  final List<ItemModel> _batchItems = [];
  bool _isBatchMode = false;

  bool _isSubmitting = false;
  String? _modalError;

  @override
  void initState() {
    super.initState();
    _loadMilitaries();
  }

  @override
  void dispose() {
    _militarySearchCtrl.dispose();
    _phoneCtrl.dispose();
    _itemScannerCtrl.dispose();
    _scannerFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMilitaries() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final list = await api.listMilitaries();
      if (mounted) {
        setState(() {
          _militaries = list;
          _loadingMilitaries = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingMilitaries = false);
      }
    }
  }

  void _onMilitarySelected(MilitaryModel mil) {
    setState(() {
      _selectedMilitary = mil;
      _phoneCtrl.text = mil.celular ?? '';
      _modalError = null;
    });
    // Foca imediatamente no leitor de materiais
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scannerFocusNode.requestFocus();
    });
  }

  void _handleItemScanOrInput(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return;

    final stock = Provider.of<StockProvider>(context, listen: false);
    // Busca nos itens disponíveis
    ItemModel? match;
    for (final it in stock.allItems) {
      if (it.status == 'CAUTELADO') continue; // Já está cautelado
      final bmpMatch = it.bmp?.toLowerCase() == clean;
      final codeMatch = it.codigoInterno?.toLowerCase() == clean;
      final idMatch = it.id.toString() == clean;
      final serialMatch = it.numeroSerie?.toLowerCase() == clean;
      final nameExact = it.nome.toLowerCase() == clean;

      if (bmpMatch || codeMatch || idMatch || serialMatch || nameExact) {
        match = it;
        break;
      }
    }

    // Se não encontrou por código exato, busca por contenção no nome
    if (match == null) {
      final partial = stock.allItems.where((it) => it.status != 'CAUTELADO' && it.nome.toLowerCase().contains(clean)).toList();
      if (partial.isNotEmpty) {
        match = partial.first;
      }
    }

    if (match != null) {
      if (_isBatchMode) {
        if (!_batchItems.any((i) => i.id == match!.id)) {
          setState(() {
            _batchItems.add(match!);
            _modalError = null;
          });
        }
        _itemScannerCtrl.clear();
        _scannerFocusNode.requestFocus();
      } else {
        setState(() {
          _selectedItem = match;
          _modalError = null;
        });
        _itemScannerCtrl.clear();
      }
    } else {
      setState(() {
        _modalError = 'Material com identificação "$query" não encontrado ou já está cautelado.';
      });
      _itemScannerCtrl.clear();
      _scannerFocusNode.requestFocus();
    }
  }

  Future<void> _submitCautela() async {
    if (_selectedMilitary == null) {
      setState(() => _modalError = 'Selecione o militar responsável pelo material.');
      return;
    }

    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _modalError = 'Informe o telefone de contato do militar no canto direito.');
      return;
    }

    if (!_isBatchMode && _selectedItem == null) {
      setState(() => _modalError = 'Escolha ou escaneie um material para cautelar.');
      return;
    }

    if (_isBatchMode && _batchItems.isEmpty) {
      setState(() => _modalError = 'Adicione ao menos um material para cautelar em lote.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _modalError = null;
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);

      if (_isBatchMode) {
        final ids = _batchItems.map((i) => i.id).toList();
        await api.addBatchItemsToCautela(
          widget.cautela.id,
          militarSaram: _selectedMilitary!.saram,
          telefoneContato: phone,
          itensIds: ids,
        );
      } else {
        await api.addItemToCautela(
          widget.cautela.id,
          itemId: _selectedItem!.id,
          militarSaram: _selectedMilitary!.saram,
          telefoneContato: phone,
        );
      }

      await StorageService().invalidateUltimoRelatorio();
      widget.onAdded();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              _isBatchMode
                  ? '${_batchItems.length} materiais cautelados para ${_selectedMilitary!.postoGraduacao} ${_selectedMilitary!.nomeGuerra}!'
                  : 'Material cautelado com sucesso para ${_selectedMilitary!.postoGraduacao} ${_selectedMilitary!.nomeGuerra}!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _modalError = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stock = Provider.of<StockProvider>(context);

    final filteredMilitaries = _militaries.where((m) {
      final q = _militarySearchCtrl.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      return m.nomeGuerra.toLowerCase().contains(q) ||
          m.nomeCompleto.toLowerCase().contains(q) ||
          m.saram.toString().contains(q);
    }).take(6).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Container(
        width: 820,
        height: 640,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header do Modal
            Row(
              children: [
                const Icon(Icons.assignment_ind_outlined, color: AppColors.primary, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cautelar Materiais na Missão',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Missão: ${widget.cautela.nome}',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                    ],
                  ),
                ),
                // Alternador de Modo: Individual vs Conjunto / Lote
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Individual / Unitário', style: TextStyle(fontSize: 11)),
                        selected: !_isBatchMode,
                        onSelected: (val) {
                          if (val) setState(() => _isBatchMode = false);
                        },
                      ),
                      const SizedBox(width: 4),
                      ChoiceChip(
                        label: const Text('Conjunto / Lote', style: TextStyle(fontSize: 11)),
                        selected: _isBatchMode,
                        onSelected: (val) {
                          if (val) setState(() => _isBatchMode = true);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

            if (_modalError != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _modalError!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Coluna 1: SELECIONAR MILITAR RESPONSÁVEL
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF151D2F) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedMilitary != null
                              ? AppColors.primary
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '1. Militar Responsável',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              if (_selectedMilitary != null)
                                TextButton(
                                  onPressed: () => setState(() => _selectedMilitary = null),
                                  child: const Text('Trocar', style: TextStyle(fontSize: 11)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (_selectedMilitary == null) ...[
                            // Barra de pesquisa do militar
                            TextField(
                              controller: _militarySearchCtrl,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Pesquisar militar por guerra, SARAM...',
                                hintStyle: const TextStyle(fontSize: 12),
                                prefixIcon: const Icon(Icons.search, size: 18),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Lista de sugestões
                            Expanded(
                              child: _loadingMilitaries
                                  ? const Center(child: CircularProgressIndicator())
                                  : ListView.separated(
                                      itemCount: filteredMilitaries.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                                      itemBuilder: (context, idx) {
                                        final mil = filteredMilitaries[idx];
                                        return InkWell(
                                          onTap: () => _onMilitarySelected(mil),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isDark ? const Color(0xFF2E3D5B) : const Color(0xFFE2E8F0),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.person, size: 18, color: AppColors.primaryLight),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        '${mil.postoGraduacao} ${mil.nomeGuerra}',
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                      ),
                                                      Text(
                                                        'SARAM: ${mil.saram} • ${mil.nomeCompleto}',
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ] else ...[
                            // Militar Selecionado com destaque do telefone no canto!
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const CircleAvatar(
                                        radius: 16,
                                        backgroundColor: AppColors.primary,
                                        child: Icon(Icons.check, color: Colors.white, size: 16),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${_selectedMilitary!.postoGraduacao} ${_selectedMilitary!.nomeGuerra}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            Text(
                                              'SARAM: ${_selectedMilitary!.saram} • ${_selectedMilitary!.nomeCompleto}',
                                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 18),

                                  // DESTAQUE DO TELEFONE NO CANTO / FORMULÁRIO OBRIGATÓRIO
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.phone_android, size: 18, color: AppColors.success),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Telefone de Contato:',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _phoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      hintText: 'Ex: (21) 98765-4321 (Obrigatório)',
                                      hintStyle: const TextStyle(fontSize: 11),
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'O telefone informado será atualizado no registro do militar caso seja alterado.',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Coluna 2: SELECIONAR OU ESCANEAR MATERIAL (UNITÁRIO OU EM LOTE)
                  Expanded(
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF151D2F) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _isBatchMode ? '2. Adicionar Materiais ao Lote' : '2. Material a Cautelar',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const Icon(Icons.qr_code_scanner, size: 18, color: AppColors.primaryLight),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Campo do scanner USB / Leitor de código de barras
                          TextField(
                            controller: _itemScannerCtrl,
                            focusNode: _scannerFocusNode,
                            enabled: _selectedMilitary != null,
                            decoration: InputDecoration(
                              hintText: _selectedMilitary != null
                                  ? 'Escaneie o código com leitor USB ou digite o BMP...'
                                  : 'Selecione o militar primeiro para liberar a leitura',
                              hintStyle: const TextStyle(fontSize: 12),
                              prefixIcon: const Icon(Icons.qr_code, size: 18, color: AppColors.primaryLight),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.arrow_forward, size: 18),
                                onPressed: () => _handleItemScanOrInput(_itemScannerCtrl.text),
                              ),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onSubmitted: _handleItemScanOrInput,
                          ),
                          const SizedBox(height: 12),

                          if (!_isBatchMode) ...[
                            // Modo Unitário: mostra material selecionado
                            if (_selectedItem != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.inventory_2, color: AppColors.primary, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _selectedItem!.nome,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.clear, size: 16),
                                          onPressed: () => setState(() => _selectedItem = null),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('BMP: ${_selectedItem!.bmp ?? "Sem BMP"} • Código: ${_selectedItem!.codigoInterno ?? "ID #${_selectedItem!.id}"}', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                                    Text('Local Atual: ${_selectedItem!.localizacaoAtual}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Expanded(
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.barcode_reader, size: 36, color: Colors.grey.withOpacity(0.4)),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Use o leitor USB de código de barras ou\ndigite o BMP / Serial acima.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ] else ...[
                            // Modo Conjunto / Lote: Lista de materiais adicionados
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Materiais no Lote: ${_batchItems.length}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                if (_batchItems.isNotEmpty)
                                  TextButton(
                                    onPressed: () => setState(() => _batchItems.clear()),
                                    child: const Text('Limpar Lote', style: TextStyle(fontSize: 11, color: AppColors.danger)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: _batchItems.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.playlist_add, size: 36, color: Colors.grey.withOpacity(0.4)),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Escaneie materiais consecutivamente.\nEles serão adicionados a esta lista para cautela conjunta.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 11.5, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: _batchItems.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                                      itemBuilder: (context, idx) {
                                        final it = _batchItems[idx];
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF2E3D5B) : const Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${it.nome} (BMP ${it.bmp ?? "S/N"})',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.remove_circle_outline, size: 16, color: AppColors.danger),
                                                onPressed: () => setState(() => _batchItems.removeAt(idx)),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Rodapé do Modal
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: _isSubmitting ? null : _submitCautela,
                  icon: _isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check, size: 18),
                  label: Text(
                    _isBatchMode ? 'Confirmar Cautela do Lote' : 'Confirmar Cautela',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
