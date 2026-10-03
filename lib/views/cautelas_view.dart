import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/cautela.dart';
import '../providers/stock_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
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

  // Sub-filtro de status: 'ATIVA' ou 'CONCLUIDA'
  String _selectedStatusFilter = 'ATIVA';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadCautelas();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCautelas() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final list = await api.listCautelas();
      if (mounted) {
        setState(() {
          _cautelas = list;
          _isLoading = false;
        });
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

  Future<void> _createNewCautela({required String tipo}) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMission = tipo == 'MISSAO';
    final nameCtrl = TextEditingController();
    final obsCtrl = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151D2F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isMission ? Icons.rocket_launch_outlined : Icons.lock_clock_outlined,
              color: isMission ? AppColors.primary : Colors.orange,
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
                    ? 'Informe o nome da missão. A data de início será registrada automaticamente no momento da criação.'
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
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
              backgroundColor: isMission ? AppColors.primary : Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final nome = nameCtrl.text.trim();
              if (nome.isEmpty) return;

              try {
                final api = Provider.of<ApiService>(context, listen: false);
                await api.createCautela(nome, tipo: tipo, observacoes: obsCtrl.text);
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(backgroundColor: AppColors.danger, content: Text('Erro: $e')),
                  );
                }
              }
            },
            child: const Text('Criar e Iniciar'),
          ),
        ],
      ),
    );

    if (created == true) {
      await _loadCautelas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(isMission ? 'Missão criada com sucesso!' : 'Cautela fixa criada com sucesso!'),
          ),
        );
      }
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
        WidgetsBinding.instance.addPostFrameCallback((_) => focusNode.requestFocus());
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool scanning = false;
            String? scanMsg;
            CautelaItemModel? returnedItem;

            Future<void> submitCode(String code) async {
              final trimmed = code.trim();
              if (trimmed.isEmpty) return;
              setModalState(() {
                scanning = true;
                scanMsg = null;
                returnedItem = null;
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
                    returnedItem = res;
                    scanMsg = 'Devolução confirmada! Material "${res.item?.nome ?? trimmed}" devolvido.';
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
                  const Text('Descautelar Material por QR Code / Scanner'),
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
                        prefixIcon: const Icon(Icons.qr_code, color: AppColors.primaryLight),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
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

    final currentTipo = _tabController.index == 0 ? 'MISSAO' : 'FIXA';

    final filteredList = _cautelas.where((c) {
      if (c.tipo != currentTipo) return false;
      if (c.status != _selectedStatusFilter) return false;

      final query = _searchCtrl.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final nameMatch = c.nome.toLowerCase().contains(query);
        final creatorMatch = (c.criador?.nomeGuerra.toLowerCase() ?? '').contains(query);
        return nameMatch || creatorMatch;
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Superior
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cautela de Materiais',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gestão de missões operacionais e cautelas fixas com leitor de código de barras e QR Code.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryLight,
                      side: const BorderSide(color: AppColors.primaryLight),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onPressed: _openQuickScanner,
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text('Descautelar via Scanner'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _tabController.index == 0 ? AppColors.primary : Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () => _createNewCautela(tipo: currentTipo),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      _tabController.index == 0 ? '+ Nova Missão' : '+ Nova Cautela Fixa',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Tabs Principais: "Missões Operacionais" & "Cautelas Fixas"
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.primaryLight,
              unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              tabs: const [
                Tab(
                  child: Row(
                    children: [
                      Icon(Icons.rocket_launch_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Missões Operacionais', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      Icon(Icons.lock_clock_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Cautelas Fixas', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Barra de Filtros e Busca
          Row(
            children: [
              // Alternador de Status: "Ativas" e "Concluídas"
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151D2F) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    _buildStatusChip('Ativas', 'ATIVA', isDark),
                    _buildStatusChip('Concluídas', 'CONCLUIDA', isDark),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Barra de Busca
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome da missão ou militar...',
                    hintStyle: const TextStyle(fontSize: 12.5),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF151D2F) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Atualizar Lista',
                onPressed: _loadCautelas,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Lista de Missões / Cautelas
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 40, color: AppColors.danger),
                            const SizedBox(height: 10),
                            Text('Erro ao carregar: $_error', style: const TextStyle(color: AppColors.danger)),
                            const SizedBox(height: 10),
                            ElevatedButton(onPressed: _loadCautelas, child: const Text('Tentar Novamente')),
                          ],
                        ),
                      )
                    : filteredList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _tabController.index == 0 ? Icons.rocket_outlined : Icons.lock_clock_outlined,
                                  size: 48,
                                  color: Colors.grey.withOpacity(0.4),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedStatusFilter == 'ATIVA'
                                      ? 'Nenhuma cautela ativa encontrada.'
                                      : 'Nenhuma cautela concluída registrada.',
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.45,
                            ),
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              final cautela = filteredList[index];
                              return _CautelaCard(
                                cautela: cautela,
                                isDark: isDark,
                                onTap: () => _openCautelaDetail(cautela),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, String value, bool isDark) {
    final selected = _selectedStatusFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatusFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? (value == 'ATIVA' ? AppColors.primary : Colors.grey[700])
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }
}

class _CautelaCard extends StatelessWidget {
  final CautelaModel cautela;
  final bool isDark;
  final VoidCallback onTap;

  const _CautelaCard({
    required this.cautela,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMission = cautela.tipo == 'MISSAO';
    final isConcluded = cautela.status == 'CONCLUIDA';
    final total = cautela.totalItens;
    final devolvidos = cautela.itensDevolvidos;
    final pendentes = cautela.itensPendentes;
    final progresso = total > 0 ? (devolvidos / total) : 0.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151D2F) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Topo do card
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    cautela.nome,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isConcluded
                        ? Colors.grey.withOpacity(0.15)
                        : AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isConcluded ? 'CONCLUÍDA' : 'ATIVA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isConcluded ? Colors.grey : AppColors.success,
                    ),
                  ),
                ),
              ],
            ),

            // Informações de Criador e Datas
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Responsável: ${cautela.criador?.postoGraduacao ?? ''} ${cautela.criador?.nomeGuerra ?? ''}',
                  style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Início: ${DateFormat('dd/MM/yyyy HH:mm').format(cautela.dataInicio)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                if (cautela.dataFim != null)
                  Text(
                    'Fim: ${DateFormat('dd/MM/yyyy HH:mm').format(cautela.dataFim!)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600),
                  ),
              ],
            ),

            // Barra de Progresso e Itens
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$total materiais • $pendentes pendentes',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${(progresso * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 11,
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
                    minHeight: 5,
                    backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isConcluded ? AppColors.success : AppColors.primary,
                    ),
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
