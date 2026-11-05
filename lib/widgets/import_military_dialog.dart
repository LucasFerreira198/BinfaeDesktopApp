import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/excel_picker_helper.dart';

class ImportMilitaryDialog extends StatefulWidget {
  final ExcelPickResult file;
  final VoidCallback onImportSuccess;

  const ImportMilitaryDialog({
    super.key,
    required this.file,
    required this.onImportSuccess,
  });

  @override
  State<ImportMilitaryDialog> createState() => _ImportMilitaryDialogState();
}

class _ImportMilitaryDialogState extends State<ImportMilitaryDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingPreview = true;
  bool _isImporting = false;
  String? _errorMessage;

  Map<String, dynamic>? _resultData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPreview();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _isLoadingPreview = true;
      _errorMessage = null;
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.importMilitaryExcel(
        bytes: widget.file.bytes,
        fileName: widget.file.fileName,
        dryRun: true,
      );

      if (mounted) {
        setState(() {
          _resultData = res;
          _isLoadingPreview = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoadingPreview = false;
        });
      }
    }
  }

  Future<void> _executeImport() async {
    setState(() {
      _isImporting = true;
      _errorMessage = null;
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.importMilitaryExcel(
        bytes: widget.file.bytes,
        fileName: widget.file.fileName,
        dryRun: false,
      );

      if (mounted) {
        widget.onImportSuccess();
        Navigator.of(context).pop();

        final importedCount = res['imported_count'] ?? 0;
        final skippedCount = res['skipped_count'] ?? 0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            content: Text(
              'Sucesso! $importedCount novos militares cadastrados. '
              '$skippedCount já cadastrados foram identificados e não repetidos.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isImporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final importedList = (_resultData?['imported'] as List?) ?? [];
    final skippedList = (_resultData?['skipped'] as List?) ?? [];
    final errorList = (_resultData?['errors'] as List?) ?? [];

    final importedCount = _resultData?['imported_count'] ?? importedList.length;
    final skippedCount = _resultData?['skipped_count'] ?? skippedList.length;
    final errorCount = _resultData?['error_count'] ?? errorList.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 900,
          maxHeight: 700,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.table_chart_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Importação de Militares via Planilha',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            widget.file.fileName,
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Conteúdo: Loading, Erro ou Resultado da Análise
              if (_isLoadingPreview) ...[
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text(
                          'Analisando planilha e verificando duplicidades com o efetivo...',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Identificando militares já cadastrados para evitar registros duplicados.',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (_errorMessage != null) ...[
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 40),
                          const SizedBox(height: 12),
                          const Text(
                            'Falha ao Processar Planilha',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.danger),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadPreview,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Tentar Novamente'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Resumo em Cartões / KPIs
                Row(
                  children: [
                    _buildKpiCard(
                      label: 'Novos Militares',
                      count: importedCount,
                      icon: Icons.person_add_rounded,
                      color: AppColors.success,
                      subtitle: 'Serão incluídos no sistema',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 12),
                    _buildKpiCard(
                      label: 'Já Cadastrados',
                      count: skippedCount,
                      icon: Icons.shield_outlined,
                      color: AppColors.warning,
                      subtitle: 'Ignorados (não duplicar)',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 12),
                    _buildKpiCard(
                      label: 'Inconsistências',
                      count: errorCount,
                      icon: Icons.warning_amber_rounded,
                      color: errorCount > 0 ? AppColors.danger : Colors.grey,
                      subtitle: errorCount > 0 ? 'Linhas inválidas' : 'Nenhum erro',
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Abas de Detalhes
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 16),
                          const SizedBox(width: 6),
                          Text('Novos a Cadastrar ($importedCount)'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.info_outline, size: 16),
                          const SizedBox(width: 6),
                          Text('Já no Sistema / Não Repetir ($skippedCount)'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 16),
                          const SizedBox(width: 6),
                          Text('Erros / Inválidos ($errorCount)'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Lista de Itens por Aba
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildImportedList(importedList, isDark),
                      _buildSkippedList(skippedList, isDark),
                      _buildErrorList(errorList, isDark),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              // Footer com Ações
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _resultData != null
                        ? 'Total processado: ${importedCount + skippedCount + errorCount} registros'
                        : '',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: (_isLoadingPreview || _isImporting || importedCount == 0)
                            ? null
                            : _executeImport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isImporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.download_done_rounded, size: 18),
                        label: Text(
                          _isImporting
                              ? 'Importando...'
                              : 'Confirmar e Cadastrar ($importedCount Militares)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required String subtitle,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportedList(List items, bool isDark) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Nenhum militar novo a ser cadastrado.',
          style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
      itemBuilder: (context, index) {
        final item = items[index];
        final saram = item['saram'];
        final posto = item['posto_graduacao'] ?? '';
        final guerra = item['nome_guerra'] ?? '';
        final nome = item['nome_completo'] ?? '';
        final secao = item['secao'];
        final email = item['email'];

        return ListTile(
          dense: true,
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$saram',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
          title: Text(
            '$posto $guerra',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          subtitle: Text(
            '$nome${secao != null ? ' • $secao' : ''}${email != null ? ' • $email' : ''}',
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
          ),
          trailing: const Icon(Icons.add_circle_outline, color: AppColors.success, size: 18),
        );
      },
    );
  }

  Widget _buildSkippedList(List items, bool isDark) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Nenhum militar duplicado ou já existente detectado.',
          style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
      itemBuilder: (context, index) {
        final item = items[index];
        final saram = item['saram'];
        final posto = item['posto_graduacao'] ?? '';
        final guerra = item['nome_guerra'] ?? '';
        final reason = item['reason'] ?? 'Militar já cadastrado no sistema.';

        return ListTile(
          dense: true,
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$saram',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.warning),
            ),
          ),
          title: Text(
            '$posto $guerra (Linha ${item['row']})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          subtitle: Text(
            reason,
            style: TextStyle(fontSize: 11, color: isDark ? Colors.orange[200] : Colors.orange[800]),
          ),
          trailing: const Icon(Icons.block_flipped, color: AppColors.warning, size: 18),
        );
      },
    );
  }

  Widget _buildErrorList(List items, bool isDark) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Nenhuma linha com erro na planilha.',
          style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
      itemBuilder: (context, index) {
        final item = items[index];
        final row = item['row'];
        final reason = item['reason'] ?? 'Inconsistência nos dados.';

        return ListTile(
          dense: true,
          leading: const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          title: Text(
            'Linha $row',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.danger),
          ),
          subtitle: Text(
            reason,
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
          ),
        );
      },
    );
  }
}
