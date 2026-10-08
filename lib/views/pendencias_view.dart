import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/pendencia.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class PendenciasView extends StatefulWidget {
  final void Function(int targetIndex)? onNavigate;

  const PendenciasView({super.key, this.onNavigate});

  @override
  State<PendenciasView> createState() => _PendenciasViewState();
}

class _PendenciasViewState extends State<PendenciasView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();

  List<PendenciaModel> _ativas = [];
  List<PendenciaModel> _concluidas = [];
  bool _isLoading = true;
  String? _filtroTipo;
  String? _filtroPrioridade;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // 0ms Stale-While-Revalidate: renderiza dados locais imediatamente
    final cachedAtivas = StorageService().pendenciasAtivas;
    final cachedConcluidas = StorageService().pendenciasConcluidas;
    if (cachedAtivas.isNotEmpty || cachedConcluidas.isNotEmpty) {
      _ativas = cachedAtivas;
      _concluidas = cachedConcluidas;
      _isLoading = false;
    }
    _loadPendencias();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPendencias() async {
    if (_ativas.isEmpty && _concluidas.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final ativas = await _api.listPendenciasAtivas(
        tipo: _filtroTipo,
        prioridade: _filtroPrioridade,
      );
      final concluidas = await _api.listPendenciasConcluidas();
      StorageService().persistPendencias(ativas: ativas, concluidas: concluidas);
      if (mounted) {
        setState(() {
          _ativas = ativas;
          _concluidas = concluidas;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (_ativas.isEmpty && _concluidas.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao carregar pendências: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // --- Modal Nova Pendência / Meta ---
  void _abrirModalNovaPendencia() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String tipo = 'GERAL';
    String prioridade = 'MEDIA';
    DateTime? prazo = DateTime.now().add(const Duration(days: 3));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_task_rounded, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Nova Pendência ou Meta'),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Título da Pendência / Meta *',
                      hintText: 'Ex.: Organizar depósito de monitores',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descrição / Detalhes',
                      hintText: 'Descreva a tarefa ou escopo...',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: tipo,
                          decoration: const InputDecoration(labelText: 'Tipo'),
                          items: const [
                            DropdownMenuItem(value: 'GERAL', child: Text('Geral / Rotina')),
                            DropdownMenuItem(value: 'META', child: Text('Meta Estratégica')),
                            DropdownMenuItem(value: 'INVENTARIO', child: Text('Inventário')),
                          ],
                          onChanged: (v) => setDialogState(() => tipo = v ?? 'GERAL'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: prioridade,
                          decoration: const InputDecoration(labelText: 'Prioridade'),
                          items: const [
                            DropdownMenuItem(value: 'BAIXA', child: Text('Baixa')),
                            DropdownMenuItem(value: 'MEDIA', child: Text('Média')),
                            DropdownMenuItem(value: 'ALTA', child: Text('Alta')),
                            DropdownMenuItem(value: 'URGENTE', child: Text('Urgente')),
                          ],
                          onChanged: (v) => setDialogState(() => prioridade = v ?? 'MEDIA'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                    title: Text(prazo == null
                        ? 'Sem prazo definido'
                        : 'Prazo: ${DateFormat('dd/MM/yyyy').format(prazo!)}'),
                    trailing: TextButton(
                      child: const Text('Alterar Prazo'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: prazo ?? DateTime.now().add(const Duration(days: 3)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() => prazo = picked);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Salvar'),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Informe o título da pendência.')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await _api.createPendencia({
                    'titulo': titleCtrl.text.trim(),
                    'descricao': descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                    'tipo': tipo,
                    'prioridade': prioridade,
                    'prazo_limite': prazo?.toIso8601String(),
                  });
                  _loadPendencias();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pendência cadastrada com sucesso!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao criar: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- Modal Concluir Pendência / Manutenção ---
  void _abrirModalConcluir(PendenciaModel p) {
    final resolucaoCtrl = TextEditingController(
      text: p.isManutencao ? 'Manutenção realizada com sucesso e equipamento testado em bancada.' : '',
    );
    bool retornarEstoque = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green),
              const SizedBox(width: 10),
              Text(p.isManutencao ? 'Concluir Manutenção' : 'Concluir Pendência'),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Item / Tarefa: ${p.titulo}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: resolucaoCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: p.isManutencao ? 'Laudo do Reparo / Resolução *' : 'Resolução da Tarefa *',
                    hintText: 'Descreva a solução adotada...',
                  ),
                ),
                if (p.isManutencao) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Retornar ao estoque como DISPONÍVEL'),
                    subtitle: const Text('Libera o equipamento para uso imediato'),
                    value: retornarEstoque,
                    onChanged: (v) => setDialogState(() => retornarEstoque = v),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () async {
                if (resolucaoCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Informe a resolução / laudo.')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await _api.concluirPendencia(
                    p.id,
                    resolucao: resolucaoCtrl.text.trim(),
                    retornarEstoque: retornarEstoque,
                  );
                  _loadPendencias();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pendência concluída com sucesso!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Concluir'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Modal Dar Baixa no PC ("Deu ruim total / quebrou") ---
  void _abrirModalBaixa(PendenciaModel p) {
    final justCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text('Dar Baixa Patrimonial (Perda Total)'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Atenção: Esta ação registrará o descarte definitivo do equipamento como SUCATA/BAIXADO e encerrará a pendência de reparo.',
                        style: TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('Equipamento: ${p.itemNome ?? p.titulo}', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (p.itemBmp != null) Text('BMP: ${p.itemBmp}', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 14),
              TextField(
                controller: justCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Justificativa da Baixa / Sucata *',
                  hintText: 'Ex.: Placa-mãe queimada sem reposição viável / Danos físicos graves irreparáveis',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              if (justCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Informe a justificativa de descarte/baixa.')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await _api.baixarItemPendencia(p.id, justificativaBaixa: justCtrl.text.trim());
                _loadPendencias();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Baixa patrimonial registrada com sucesso!'), backgroundColor: Colors.orange),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Confirmar Baixa Definitiva'),
          ),
        ],
      ),
    );
  }

  Color _getPrioridadeColor(String prioridade) {
    switch (prioridade.toUpperCase()) {
      case 'URGENTE':
        return Colors.red;
      case 'ALTA':
        return Colors.orange;
      case 'MEDIA':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCardPendencia(PendenciaModel p, bool isConcluida) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final prazoFormatado = p.prazoLimite != null ? DateFormat('dd/MM/yyyy').format(p.prazoLimite!) : 'Sem prazo';

    bool isAtrasado = false;
    if (p.prazoLimite != null && !isConcluida) {
      isAtrasado = p.prazoLimite!.isBefore(DateTime.now());
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? const Color(0xFF161E2E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Ícone do Tipo
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: p.isManutencao ? Colors.amber.withOpacity(0.15) : AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    p.isManutencao ? Icons.handyman_rounded : Icons.task_alt_rounded,
                    color: p.isManutencao ? Colors.amber[800] : AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.titulo,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (p.descricao != null && p.descricao!.isNotEmpty)
                        Text(
                          p.descricao!,
                          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                        ),
                    ],
                  ),
                ),
                // Badges
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPrioridadeColor(p.prioridade).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    p.prioridade,
                    style: TextStyle(
                      color: _getPrioridadeColor(p.prioridade),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                // Prazo
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: isAtrasado ? Colors.red : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(width: 6),
                Text(
                  isConcluida
                      ? 'Concluído em: ${p.concluidoEm != null ? DateFormat('dd/MM/yyyy HH:mm').format(p.concluidoEm!) : 'N/D'}'
                      : 'Prazo: $prazoFormatado',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isAtrasado ? FontWeight.bold : FontWeight.normal,
                    color: isAtrasado ? Colors.red : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ),
                if (isAtrasado) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                    child: const Text('ATRASADO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
                const Spacer(),
                // Resolução para concluídas
                if (isConcluida && p.resolucao != null)
                  Expanded(
                    child: Text(
                      'Resolução: ${p.resolucao}',
                      style: const TextStyle(fontSize: 12, color: Colors.green, fontStyle: FontStyle.italic),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                // Ações para ativas
                if (!isConcluida) ...[
                  if (p.isManutencao) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Dar Baixa no PC'),
                      onPressed: () => _abrirModalBaixa(p),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(p.isManutencao ? 'Concluir Manutenção' : 'Concluir'),
                    onPressed: () => _abrirModalConcluir(p),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final ativasFiltradas = _ativas.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return p.titulo.toLowerCase().contains(q) ||
          (p.descricao?.toLowerCase().contains(q) ?? false) ||
          (p.itemBmp?.toLowerCase().contains(q) ?? false);
    }).toList();

    final concluidasFiltradas = _concluidas.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return p.titulo.toLowerCase().contains(q) ||
          (p.descricao?.toLowerCase().contains(q) ?? false) ||
          (p.resolucao?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E17) : const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.checklist_rtl_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pendências e Metas', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text('Gestão de atividades, prazos e manutenções patrimoniais integradas', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nova Pendência / Meta'),
                  onPressed: _abrirModalNovaPendencia,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Atualizar',
                  onPressed: _loadPendencias,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // BUSCA E ABAS
            Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabs: [
                      Tab(text: 'Pendências Ativas (${_ativas.length})'),
                      Tab(text: 'Concluídas / Histórico (${_concluidas.length})'),
                    ],
                  ),
                ),
                SizedBox(
                  width: 250,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar pendência...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF161E2E) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // CONTEÚDO DAS ABAS
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // Aba Ativas
                        ativasFiltradas.isEmpty
                            ? const Center(child: Text('Nenhuma pendência ativa no momento.', style: TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                itemCount: ativasFiltradas.length,
                                itemBuilder: (ctx, i) => _buildCardPendencia(ativasFiltradas[i], false),
                              ),
                        // Aba Concluídas
                        concluidasFiltradas.isEmpty
                            ? const Center(child: Text('Nenhuma pendência concluída encontrada.', style: TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                itemCount: concluidasFiltradas.length,
                                itemBuilder: (ctx, i) => _buildCardPendencia(concluidasFiltradas[i], true),
                              ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
