import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/item.dart';
import '../providers/stock_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class HistoryView extends StatefulWidget {
  const HistoryView({super.key});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  final TextEditingController _searchController = TextEditingController();
  List<ItemMovementModel> _movements = [];
  bool _isLoading = true;
  String? _error;
  String _search = '';
  String? _selectedType;

  final List<String> _types = [
    'CAUTELA',
    'DEVOLUCAO',
    'TRANSFERENCIA',
    'MANUTENCAO',
    'ENTRADA',
    'SAIDA',
    'BAIXA',
  ];

  @override
  void initState() {
    super.initState();
    _loadMovements();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMovements() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final list = await api.fetchMovements();
      if (mounted) {
        setState(() {
          _movements = list;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stock = Provider.of<StockProvider>(context);

    // Filtrar movimentações
    final filtered = _movements.where((m) {
      if (_selectedType != null && m.tipoMovimentacao.toUpperCase() != _selectedType) {
        return false;
      }
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final matchMotivo = m.motivo?.toLowerCase().contains(q) ?? false;
        final matchUser = m.usuarioNome?.toLowerCase().contains(q) ?? false;
        final matchItem = m.itemNome?.toLowerCase().contains(q) ?? false;
        final matchId = m.itemId.toString().contains(q);
        if (!matchMotivo && !matchUser && !matchItem && !matchId) return false;
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com Título e Botão de Atualizar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Histórico Geral de Movimentações',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Registro auditável de transferências, cautelas, manutenções e ajustes',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _loadMovements,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 18),
                label: const Text('Atualizar Histórico'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filtros
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Filtrar por material, motivo, militar ou ID...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _search = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF151D2F) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Dropdown tipo
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151D2F) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedType,
                    hint: const Text('Tipo: Todos'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tipo: Todos')),
                      ..._types.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                    ],
                    onChanged: (v) => setState(() => _selectedType = v),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Conteúdo
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                            const SizedBox(height: 12),
                            Text('Erro ao carregar histórico: $_error'),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadMovements, child: const Text('Tentar Novamente')),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history_toggle_off, size: 54, color: Colors.grey.withOpacity(0.5)),
                                const SizedBox(height: 12),
                                const Text('Nenhuma movimentação registrada', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                const Text('Movimentações como transferências e cautelas aparecerão aqui.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF151D2F) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: isDark ? const Color(0xFF1F293D) : const Color(0xFFF1F5F9),
                                ),
                                itemBuilder: (context, index) {
                                  final m = filtered[index];
                                  final item = stock.allItems.where((i) => i.id == m.itemId).firstOrNull;
                                  final itemName = m.itemNome ?? item?.nome ?? 'Material #${m.itemId}';

                                  return _buildMovementRow(context, m, itemName, isDark);
                                },
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementRow(BuildContext context, ItemMovementModel m, String itemName, bool isDark) {
    final typeColor = _getTypeColor(m.tipoMovimentacao);

    String formattedDate = '';
    if (m.criadoEm != null) {
      try {
        final parsed = DateTime.parse(m.criadoEm!);
        formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(parsed.toLocal());
      } catch (_) {
        formattedDate = m.criadoEm!;
      }
    }

    String localInfo = '';
    if (m.origem != null && m.destino != null) {
      localInfo = '${m.origem!.nome} ➔ ${m.destino!.nome}';
    } else if (m.destino != null) {
      localInfo = 'Destino: ${m.destino!.nome}';
    } else if (m.origem != null) {
      localInfo = 'Origem: ${m.origem!.nome}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Data e Hora
          SizedBox(
            width: 130,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
                Text(
                  'ID #${m.id}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Badge Tipo
          Container(
            width: 120,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              m.tipoMovimentacao.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: typeColor,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Nome do Material e Locais
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                if (localInfo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 13, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        localInfo,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Quantidade
          SizedBox(
            width: 80,
            child: Text(
              'Qtd: ${m.quantidadeMovimentada}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),

          // Justificativa / Motivo
          Expanded(
            flex: 2,
            child: Text(
              m.motivo ?? 'Sem justificativa informada',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontStyle: m.motivo == null ? FontStyle.italic : FontStyle.normal,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'CAUTELA':
        return AppColors.warning;
      case 'DEVOLUCAO':
        return AppColors.success;
      case 'TRANSFERENCIA':
        return AppColors.primary;
      case 'MANUTENCAO':
        return AppColors.danger;
      case 'ENTRADA':
        return Colors.teal;
      case 'BAIXA':
        return Colors.purple;
      default:
        return AppColors.info;
    }
  }
}
