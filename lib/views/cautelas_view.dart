import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/cautela.dart';
import '../providers/stock_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../widgets/cautela_detail_dialog.dart';
import '../widgets/user_avatar.dart';

class CautelasView extends StatefulWidget {
  const CautelasView({super.key});

  @override
  State<CautelasView> createState() => _CautelasViewState();
}

class _CautelasViewState extends State<CautelasView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<CautelaModel> _cautelas = [];
  bool _isLoading = true;
  String? _error;

  String _selectedStatusFilter = 'ATIVA';
  final TextEditingController _searchCtrl = TextEditingController();
  int? _observedCautelasVersion;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    // 0ms Stale-While-Revalidate: renderiza imediatamente dados salvos localmente
    final cached = StorageService().cautelas;
    if (cached.isNotEmpty) {
      _cautelas = cached;
      _isLoading = false;
    }
    _loadCautelas();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stock = Provider.of<StockProvider>(context);
    if (stock.lastCautelasVersion != null) {
      if (_observedCautelasVersion != null && stock.lastCautelasVersion != _observedCautelasVersion) {
        _observedCautelasVersion = stock.lastCautelasVersion;
        _loadCautelasSilently();
      } else if (_observedCautelasVersion == null) {
        _observedCautelasVersion = stock.lastCautelasVersion;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCautelasSilently() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final list = await api.listCautelas();
      StorageService().persistCautelas(list);
      if (mounted) {
        setState(() {
          _cautelas = list;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCautelas() async {
    if (_cautelas.isEmpty) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final list = await api.listCautelas();
      StorageService().persistCautelas(list);
      if (mounted) {
        setState(() {
          _cautelas = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Se já temos dados no cache local, não trava a tela com erro
        if (_cautelas.isNotEmpty) {
          setState(() => _isLoading = false);
        } else {
          setState(() {
            _error = e.toString().replaceAll('Exception: ', '');
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _createNewCautela({required String tipo}) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMission = tipo == 'MISSAO';
    final nameCtrl = TextEditingController();
    final obsCtrl = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151D2A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isMission ? Icons.rocket_launch_outlined : Icons.lock_clock_outlined,
              color: AppColors.cyan,
            ),
            const SizedBox(width: 10),
            Text(isMission ? 'Nova Missão Operacional' : 'Nova Cautela Fixa'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isMission
                    ? 'Informe o nome da missão. A data e hora serão registradas no horário oficial de Brasília.'
                    : 'Informe o nome/identificador da cautela fixa (ex: Posto Médico, Guarda do Quartel).',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Nome / Identificação:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: isMission ? 'Ex: Missão Escolta VIP, Exercício Operacional...' : 'Ex: Cautela Fixa do PAv...',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0E121B) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Observações (Opcional):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: obsCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Detalhes adicionais relevantes...',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0E121B) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              backgroundColor: AppColors.cyan,
              foregroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final nome = nameCtrl.text.trim();
              if (nome.isEmpty) return;

              try {
                final api = Provider.of<ApiService>(context, listen: false);
                await api.createCautela(
                  nome,
                  tipo: tipo,
                  observacoes: obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(backgroundColor: AppColors.danger, content: Text('Erro: $e')),
                  );
                }
              }
            },
            child: const Text('Criar Cautela', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (created == true) {
      await _loadCautelas();
    }
  }

  void _openQuickScanner() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scanController = TextEditingController();
    final focusNode = FocusNode();

    showDialog(
      context: context,
      builder: (ctx) {
        bool scanning = false;
        String? scanMsg;

        return StatefulBuilder(
          builder: (context, setModalState) {
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
                await _loadCautelas();

                if (context.mounted) {
                  setModalState(() {
                    scanning = false;
                    scanMsg = 'Devolução confirmada! Material "${res.item?.nome ?? trimmed}" devolvido com sucesso.';
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
              backgroundColor: isDark ? const Color(0xFF151D2A) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.qr_code_scanner, color: AppColors.cyan),
                  SizedBox(width: 10),
                  Text('Descautelar por Leitor USB / Scanner'),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Passe o leitor de código de barras ou digite o BMP para registrar a devolução imediata:',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: scanController,
                      focusNode: focusNode,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Aguardando leitura do leitor USB...',
                        prefixIcon: const Icon(Icons.qr_code, color: AppColors.cyan),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0E121B) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onSubmitted: submitCode,
                    ),
                    if (scanning) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    if (scanMsg != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scanMsg!.startsWith('Devolução')
                              ? AppColors.success.withOpacity(0.15)
                              : AppColors.danger.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          scanMsg!,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: scanMsg!.startsWith('Devolução') ? AppColors.success : AppColors.danger,
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

  void _openCautelaDetail(CautelaModel cautela) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CautelaDetailDialog(
        cautela: cautela,
        onUpdated: _loadCautelas,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeCautelas = _cautelas.where((c) => c.status == 'ATIVA').toList();
    final concludedCautelas = _cautelas.where((c) => c.status == 'CONCLUIDA').toList();

    int totalItensEmUso = 0;
    for (final c in activeCautelas) {
      totalItensEmUso += c.itensCautelados;
    }

    final query = _searchCtrl.text.trim().toLowerCase();

    List<CautelaModel> filteredList;
    if (_tabController.index == 0) {
      // Missões Ativas
      filteredList = activeCautelas.where((c) => c.tipo == 'MISSAO').toList();
    } else if (_tabController.index == 1) {
      // Cautelas Fixas
      filteredList = activeCautelas.where((c) => c.tipo == 'FIXA').toList();
    } else {
      // Concluídas
      filteredList = concludedCautelas;
    }

    if (query.isNotEmpty) {
      filteredList = filteredList.where((c) {
        final nameMatch = c.nome.toLowerCase().contains(query);
        final creatorMatch = (c.criador?.nomeGuerra.toLowerCase() ?? '').contains(query);
        return nameMatch || creatorMatch;
      }).toList();
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. HEADER LOANHUB: TÍTULO, SUBTÍTULO & 4 KPIS NO TOPO
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 900;
              final titleSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cautelas e Missões Operacionais',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Controle de cautelação, militares responsáveis e prazos de devolução',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              );

              final actionButtons = [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide(color: isDark ? const Color(0xFF232B3E) : const Color(0xFFCBD5E1)),
                  ),
                  onPressed: _openQuickScanner,
                  icon: const Icon(Icons.qr_code_scanner, size: 16, color: AppColors.cyan),
                  label: const Text('Leitor USB / Scanner Devolução', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cyan,
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _createNewCautela(tipo: _tabController.index == 1 ? 'FIXA' : 'MISSAO'),
                  icon: const Icon(Icons.add, size: 18, color: Color(0xFF0F172A)),
                  label: const Text('+ Nova Cautela / Missão', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                ),
              ];

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleSection,
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: actionButtons,
                    ),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  titleSection,
                  Row(
                    children: [
                      actionButtons[0],
                      const SizedBox(width: 10),
                      actionButtons[1],
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 18),

          // 2. LINHA DE 4 KPIS LOANHUB
          LayoutBuilder(
            builder: (context, constraints) {
              final kpiCards = [
                _LoanHubKpiCard(
                  title: 'Missões Ativas',
                  value: '${activeCautelas.length}',
                  glowColor: AppColors.cyan,
                  isDark: isDark,
                ),
                _LoanHubKpiCard(
                  title: 'Materiais em Campo',
                  value: '$totalItensEmUso',
                  glowColor: const Color(0xFF38BDF8),
                  isDark: isDark,
                ),
                _LoanHubKpiCard(
                  title: 'Devoluções Hoje',
                  value: '${(activeCautelas.length * 0.4).round()}',
                  glowColor: AppColors.warning,
                  isDark: isDark,
                  badge: 'Previsão',
                ),
                _LoanHubKpiCard(
                  title: 'Cautelas Concluídas',
                  value: '${concludedCautelas.length}',
                  glowColor: AppColors.success,
                  isDark: isDark,
                ),
              ];

              if (constraints.maxWidth >= 900) {
                return Row(
                  children: [
                    for (int i = 0; i < kpiCards.length; i++) ...[
                      if (i > 0) const SizedBox(width: 14),
                      Expanded(child: kpiCards[i]),
                    ],
                  ],
                );
              }

              final itemWidth = (constraints.maxWidth - 14) / 2;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: kpiCards.map((card) => SizedBox(width: itemWidth, child: card)).toList(),
              );
            },
          ),

          const SizedBox(height: 18),

          // 3. BARRA DE TABS E BUSCA
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 850;

              final tabsWidget = Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151D2A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTabPill('Missões Operacionais (${activeCautelas.where((c) => c.tipo == "MISSAO").length})', 0, isDark),
                      _buildTabPill('Cautelas Fixas (${activeCautelas.where((c) => c.tipo == "FIXA").length})', 1, isDark),
                      _buildTabPill('Histórico Concluídas (${concludedCautelas.length})', 2, isDark),
                    ],
                  ),
                ),
              );

              final searchWidget = SizedBox(
                width: isCompact ? double.infinity : 280,
                height: 38,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Buscar por missão ou militar...',
                    hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.cyan),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF151D2A) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    tabsWidget,
                    const SizedBox(height: 10),
                    searchWidget,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: tabsWidget),
                  const SizedBox(width: 14),
                  searchWidget,
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          // 4. TABELA ESTRUTURADA DE CAUTELAS (ESTILO LOANHUB)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const minTableWidth = 840.0;
                final tableWidth = math.max(minTableWidth, constraints.maxWidth);
                return Scrollbar(
                  thumbVisibility: constraints.maxWidth < minTableWidth,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151D2A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  // Cabeçalho da Tabela
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF101520) : const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(width: 100, child: Text('ID CAUTELA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                        Expanded(flex: 3, child: Text('MISSÃO / DESTINO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                        Expanded(flex: 3, child: Text('MILITAR RESPONSÁVEL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                        SizedBox(width: 120, child: Text('MATERIAIS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                        SizedBox(width: 130, child: Text('DATA DE SAÍDA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                        SizedBox(width: 100, child: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                        SizedBox(width: 80, child: Text('AÇÕES', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                      ],
                    ),
                  ),

                  // Lista de Linhas
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.error_outline, size: 38, color: AppColors.danger),
                                    const SizedBox(height: 8),
                                    Text('Erro ao carregar cautelas: $_error', style: const TextStyle(color: AppColors.danger)),
                                    const SizedBox(height: 8),
                                    ElevatedButton(onPressed: _loadCautelas, child: const Text('Tentar Novamente')),
                                  ],
                                ),
                              )
                            : filteredList.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.assignment_turned_in_outlined, size: 48, color: Colors.grey.withOpacity(0.4)),
                                        const SizedBox(height: 10),
                                        const Text('Nenhuma cautela encontrada.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: filteredList.length,
                                    separatorBuilder: (_, __) => Divider(
                                      height: 1,
                                      color: isDark ? const Color(0xFF1E2838) : const Color(0xFFF1F5F9),
                                    ),
                                    itemBuilder: (ctx, i) {
                                      final c = filteredList[i];
                                      return _LoanHubTableRow(
                                        cautela: c,
                                        isDark: isDark,
                                        onTap: () => _openCautelaDetail(c),
                                      );
                                    },
                                  ),
                  ),

                  // Rodapé
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF101520) : const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      border: Border(
                        top: BorderSide(
                          color: isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mostrando ${filteredList.length} missões / cautelas',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        Row(
                          children: [
                            const Text('Página 1 de 1', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.chevron_left, size: 18),
                              onPressed: null,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, size: 18),
                              onPressed: null,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabPill(String label, int index, bool isDark) {
    final active = _tabController.index == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _tabController.index = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? (isDark ? AppColors.cyan.withOpacity(0.15) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.cyan : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active
                ? AppColors.cyan
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }
}

// Card de KPI Estilo LoanHub com Glow Orb
class _LoanHubKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final Color glowColor;
  final bool isDark;
  final String? badge;

  const _LoanHubKpiCard({
    required this.title,
    required this.value,
    required this.glowColor,
    required this.isDark,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Stack(
        children: [
          // Subtle glow orb
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: glowColor.withOpacity(0.12),
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withOpacity(0.3),
                    blurRadius: 18,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Linha da Tabela de Cautela Estilo LoanHub
class _LoanHubTableRow extends StatefulWidget {
  final CautelaModel cautela;
  final bool isDark;
  final VoidCallback onTap;

  const _LoanHubTableRow({
    required this.cautela,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_LoanHubTableRow> createState() => _LoanHubTableRowState();
}

class _LoanHubTableRowState extends State<_LoanHubTableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.cautela;
    final isDark = widget.isDark;
    final isConcluded = c.status == 'CONCLUIDA';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: _isHovered
              ? (isDark ? const Color(0xFF1B2438) : const Color(0xFFF8FAFC))
              : Colors.transparent,
          child: Row(
            children: [
              // ID da Cautela
              SizedBox(
                width: 100,
                child: Text(
                  c.tipo == 'MISSAO' ? 'MIS-${202600 + c.id}' : 'FIXA-#${c.id}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cyan,
                    fontFamily: 'monospace',
                  ),
                ),
              ),

              // Missão / Destino
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.nome,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      c.tipo == 'MISSAO' ? 'Missão Operacional' : 'Cautela Fixa Contínua',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),

              // Militar Responsável (Avatar + Posto + Nome + SARAM)
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    UserAvatar(
                      fotoUrl: c.criador?.fotoUrl,
                      name: c.criador?.nomeGuerra,
                      radius: 13,
                      iconSize: 13,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${c.criador?.postoGraduacao ?? ''} ${c.criador?.nomeGuerra ?? 'Militar'}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            c.criador?.saram != null ? 'SARAM ${c.criador!.saram}' : 'BINFAE-GL',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Quantidade de Materiais
              SizedBox(
                width: 120,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0E121B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        '${c.itensCautelados} itens',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              // Data de Saída
              SizedBox(
                width: 130,
                child: Text(
                  AppDateUtils.formatDateTime(c.dataInicio),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontFamily: 'monospace',
                  ),
                ),
              ),

              // Status Badge
              SizedBox(
                width: 100,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isConcluded ? AppColors.success : AppColors.cyan).withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isConcluded ? AppColors.success : AppColors.cyan).withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      isConcluded ? 'Concluída' : 'Ativa',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isConcluded ? AppColors.success : AppColors.cyan,
                      ),
                    ),
                  ),
                ),
              ),

              // Ações
              SizedBox(
                width: 80,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.assignment_return_outlined, size: 16),
                      tooltip: 'Devolver / Descautelar',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      onPressed: widget.onTap,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      tooltip: 'Detalhes da Missão',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      onPressed: widget.onTap,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
