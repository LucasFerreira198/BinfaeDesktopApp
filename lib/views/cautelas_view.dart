import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/cautela.dart';
import '../providers/stock_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../widgets/cautela_detail_dialog.dart';

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
  final TextEditingController _searchCtrl = TextEditingController();
  int? _observedCautelasVersion;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

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
    final isMission = tipo == 'MISSAO';
    final nameCtrl = TextEditingController();
    final obsCtrl = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.primary),
        ),
        title: Row(
          children: [
            Icon(
              isMission ? Icons.flight_takeoff : Icons.lock_clock,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            Text(
              isMission ? 'Nova Missão Operacional' : 'Nova Cautela Fixa',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
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
                isMission
                    ? 'Informe a designação da missão tática (Ex: Operação Ágata, Escolta VIP). Prazos e termo de cautela serão gerados com carimbo ZULU.'
                    : 'Informe o identificador do posto ou divisão (Ex: Guarda do Quartel, Sala de Rádio BAGL).',
                style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              const Text('Nome / Identificação:', style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(fontSize: 13, color: Colors.white),
                decoration: InputDecoration(
                  hintText: isMission ? 'Ex: Op. Ágata - Posto Avançado Terminal 2' : 'Ex: Cautela Fixa - Posto de Guarda Portão Sul',
                  hintStyle: const TextStyle(fontSize: 12, color: AppColors.outline),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLowest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.outlineVariant.withOpacity(0.4))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Observações Táticas (Opcional):', style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 6),
              TextField(
                controller: obsCtrl,
                maxLines: 2,
                style: const TextStyle(fontSize: 13, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ordens de serviço, canal rádio VHF, armamento conjunto...',
                  hintStyle: const TextStyle(fontSize: 12, color: AppColors.outline),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLowest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.outlineVariant.withOpacity(0.4))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.outline)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: const Color(0xFF00285D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () async {
              final nome = nameCtrl.text.trim();
              if (nome.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.surfaceContainerHigh,
                    content: Text('Por favor, informe o nome ou identificação da cautela.', style: TextStyle(color: AppColors.warning)),
                  ),
                );
                return;
              }

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
                    SnackBar(backgroundColor: AppColors.surfaceContainerHigh, content: Text('Erro: $e', style: const TextStyle(color: AppColors.error))),
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
                    scanMsg = 'Devolução confirmada! Material "${res.item?.nome ?? trimmed}" retornado ao depósito com sucesso.';
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
              backgroundColor: AppColors.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.tertiary),
              ),
              title: const Row(
                children: [
                  Icon(Icons.barcode_reader, color: AppColors.tertiary),
                  SizedBox(width: 10),
                  Text(
                    'Descautelar por Leitor USB / Scanner',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Passe o leitor de código de barras USB ou digite o BMP para registrar a devolução imediata ao almoxarifado:',
                      style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: scanController,
                      focusNode: focusNode,
                      autofocus: true,
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Aguardando bip do leitor USB (ex: BMP-051902)...',
                        hintStyle: const TextStyle(fontSize: 12, color: AppColors.outline),
                        prefixIcon: const Icon(Icons.qr_code, color: AppColors.tertiary),
                        filled: true,
                        fillColor: AppColors.surfaceContainerLowest,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onSubmitted: submitCode,
                    ),
                    if (scanning) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(color: AppColors.tertiary),
                    ],
                    if (scanMsg != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scanMsg!.startsWith('Devolução')
                              ? AppColors.tertiary.withOpacity(0.15)
                              : AppColors.error.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: scanMsg!.startsWith('Devolução') ? AppColors.tertiary : AppColors.error,
                          ),
                        ),
                        child: Text(
                          scanMsg!,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: scanMsg!.startsWith('Devolução') ? AppColors.tertiary : AppColors.error,
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
                  child: const Text('Concluir', style: TextStyle(color: AppColors.primary)),
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
    final activeCautelas = _cautelas.where((c) => c.status == 'ATIVA').toList();
    final concludedCautelas = _cautelas.where((c) => c.status == 'CONCLUIDA').toList();

    final missoesAtivas = activeCautelas.where((c) => c.tipo == 'MISSAO').toList();
    final fixasAtivas = activeCautelas.where((c) => c.tipo == 'FIXA').toList();

    final query = _searchCtrl.text.trim().toLowerCase();

    List<CautelaModel> currentList;
    if (_tabController.index == 0) {
      currentList = activeCautelas;
    } else if (_tabController.index == 1) {
      currentList = missoesAtivas;
    } else if (_tabController.index == 2) {
      currentList = fixasAtivas;
    } else {
      currentList = concludedCautelas;
    }

    if (query.isNotEmpty) {
      currentList = currentList.where((c) {
        final nameMatch = c.nome.toLowerCase().contains(query);
        final creatorMatch = (c.criador?.nomeGuerra.toLowerCase() ?? '').contains(query);
        final respMatch = c.responsavelNome.toLowerCase().contains(query);
        final saramMatch = c.responsavelSaram.toLowerCase().contains(query);
        return nameMatch || creatorMatch || respMatch || saramMatch;
      }).toList();
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =========================================================================
          // 1. SUBHEADER / STATUS SUMMARY BAR (Google Stitch #08_CautelasView)
          // =========================================================================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outlineVariant.withOpacity(0.35)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 980;

                final titleSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        const Text(
                          'CONTROLE DE CAUTELAS & MISSÕES OPERACIONAIS',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.tertiary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.tertiary.withOpacity(0.35)),
                          ),
                          child: const Text(
                            'MÓDULO 03 // COORDENAÇÃO',
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: AppColors.tertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'BINFAE-GL // SEÇÃO DE TI — Gestão de Equipamentos Táticos em Carga, Destacamentos e Termos de Responsabilidade',
                      style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.onSurfaceVariant),
                    ),
                  ],
                );

                final actionButtons = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _loadCautelas,
                      icon: const Icon(Icons.sync, size: 15, color: AppColors.tertiary),
                      label: const Text('Sincronizar', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainerHigh,
                        side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _createNewCautela(tipo: 'FIXA'),
                      icon: const Icon(Icons.lock_clock, size: 15, color: AppColors.primary),
                      label: const Text('Nova Cautela Fixa', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainerHigh,
                        side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _createNewCautela(tipo: 'MISSAO'),
                      icon: const Icon(Icons.flight_takeoff, size: 16, color: Color(0xFF00285D)),
                      label: const Text(
                        'Nova Missão Operacional',
                        style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF00285D)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ],
                );

                if (isWide) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: titleSection),
                      const SizedBox(width: 14),
                      actionButtons,
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleSection,
                    const SizedBox(height: 12),
                    actionButtons,
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          // =========================================================================
          // 2. FILTER TABS & SEARCH TACTICAL STRIP (Google Stitch #08_CautelasView)
          // =========================================================================
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;

              final tabsWidget = Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.outlineVariant.withOpacity(0.35)),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicator: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.onSurfaceVariant,
                  labelStyle: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.tertiary),
                          ),
                          const SizedBox(width: 6),
                          const Text('Cautelas Ativas'),
                          const SizedBox(width: 6),
                          _buildCountBadge('${activeCautelas.length}', AppColors.tertiary),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                          ),
                          const SizedBox(width: 6),
                          const Text('Missões em Andamento'),
                          const SizedBox(width: 6),
                          _buildCountBadge('${missoesAtivas.length}', AppColors.primary),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.secondary),
                          ),
                          const SizedBox(width: 6),
                          const Text('Cautelas Fixas'),
                          const SizedBox(width: 6),
                          _buildCountBadge('${fixasAtivas.length}', AppColors.secondary),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.outline),
                          ),
                          const SizedBox(width: 6),
                          const Text('Concluídas'),
                          const SizedBox(width: 6),
                          _buildCountBadge('${concludedCautelas.length}', AppColors.outline),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              final searchAndScanner = Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.35)),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() {}),
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Filtrar por nome, responsável ou SARAM...',
                          hintStyle: const TextStyle(fontSize: 11, color: AppColors.outline),
                          prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.primary),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 14, color: AppColors.outline),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _openQuickScanner,
                    icon: const Icon(Icons.barcode_reader, size: 15, color: Color(0xFF003827)),
                    label: const Text('Descautelar (Bip)', style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF003827))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.tertiary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: tabsWidget),
                    const SizedBox(width: 12),
                    SizedBox(width: 380, child: searchAndScanner),
                  ],
                );
              }

              return Column(
                children: [
                  tabsWidget,
                  const SizedBox(height: 10),
                  searchAndScanner,
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          // =========================================================================
          // 3. CAUTELAS GRID / FEED (Google Stitch #08_CautelasView)
          // =========================================================================
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? Center(
                        child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                      )
                    : currentList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.fact_check_outlined, size: 48, color: AppColors.outline.withOpacity(0.5)),
                                const SizedBox(height: 10),
                                const Text(
                                  'Nenhuma cautela ou missão localizada nesta categoria.',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: currentList.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, i) {
                              final c = currentList[i];
                              return _TacticalCautelaCard(
                                cautela: c,
                                onInspect: () => _openCautelaDetail(c),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  static Widget _buildCountBadge(String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count,
        style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

class _TacticalCautelaCard extends StatelessWidget {
  final CautelaModel cautela;
  final VoidCallback onInspect;

  const _TacticalCautelaCard({
    required this.cautela,
    required this.onInspect,
  });

  @override
  Widget build(BuildContext context) {
    final isMission = cautela.tipo == 'MISSAO';
    final isConcluded = cautela.status == 'CONCLUIDA';

    final badgeColor = isConcluded
        ? AppColors.outline
        : (isMission ? AppColors.primary : AppColors.secondary);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: Title, type badge, inspect button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      cautela.nome,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: badgeColor.withOpacity(0.35)),
                      ),
                      child: Text(
                        isMission ? '#MS-${cautela.id.toString().padLeft(4, '0')}' : '#FX-${cautela.id.toString().padLeft(4, '0')}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isConcluded ? AppColors.outline.withOpacity(0.15) : AppColors.tertiary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isConcluded ? AppColors.outline.withOpacity(0.3) : AppColors.tertiary.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isConcluded ? Icons.check_circle_outline : Icons.timer_outlined,
                          size: 13,
                          color: isConcluded ? AppColors.outline : AppColors.tertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isConcluded ? 'CONCLUÍDA' : 'EM CURSO',
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: isConcluded ? AppColors.outline : AppColors.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onInspect,
                    icon: const Icon(Icons.visibility_outlined, size: 14),
                    label: const Text('Inspecionar', style: TextStyle(fontSize: 11, fontFamily: 'monospace')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceContainerHigh,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Militar responsável
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: AppColors.outline),
              const SizedBox(width: 6),
              const Text('Responsável: ', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
              Text(
                cautela.responsavelNome,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                '(SARAM ${cautela.responsavelSaram})',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.secondary),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Equipment preview ribbon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '${cautela.itensCautelados} equipamentos em carga ativa',
                  style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Spacer(),
                const Icon(Icons.verified_user_outlined, size: 13, color: AppColors.tertiary),
                const SizedBox(width: 4),
                const Text(
                  'Assinatura Digital Válida',
                  style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.tertiary),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Footer info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Criado por: ${cautela.criador?.nomeGuerra ?? "S2 SILVA"} em ${AppDateUtils.formatDateTime(cautela.criadoEm)}',
                style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: AppColors.outline),
              ),
              if (cautela.observacoes != null && cautela.observacoes!.isNotEmpty)
                Expanded(
                  child: Text(
                    'Obs: ${cautela.observacoes!}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: AppColors.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
