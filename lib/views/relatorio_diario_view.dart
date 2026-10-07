import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/relatorio_diario.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class RelatorioDiarioView extends StatefulWidget {
  final void Function(int targetIndex)? onNavigate;

  const RelatorioDiarioView({super.key, this.onNavigate});

  @override
  State<RelatorioDiarioView> createState() => _RelatorioDiarioViewState();
}

class _RelatorioDiarioViewState extends State<RelatorioDiarioView> {
  final ApiService _api = ApiService();

  RelatorioDiarioModel? _relatorio;
  List<RelatorioDiarioModel> _historico = [];
  List<Map<String, dynamic>> _militaresTI = [];

  final TextEditingController _ocorrenciasCtrl = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLaunching = false;

  @override
  void initState() {
    super.initState();
    _carregarRelatorioHoje();
  }

  @override
  void dispose() {
    _ocorrenciasCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarRelatorioHoje() async {
    setState(() => _isLoading = true);
    try {
      final mil = await _api.listMilitaresInformatica();
      final rel = await _api.getRelatorioHoje();
      final hist = await _api.listHistoricoRelatorios();
      if (mounted) {
        setState(() {
          _militaresTI = mil;
          _relatorio = rel;
          _historico = hist;
          _ocorrenciasCtrl.text = rel.ocorrenciasMilitar ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar relatório: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _carregarPorData(DateTime date) async {
    final str = DateFormat('yyyy-MM-dd').format(date);
    setState(() => _isLoading = true);
    try {
      final rel = await _api.getRelatorioPorData(str);
      if (mounted) {
        setState(() {
          _relatorio = rel;
          _ocorrenciasCtrl.text = rel.ocorrenciasMilitar ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não há relatório para esta data: $e'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _salvarRascunho() async {
    if (_relatorio == null || _relatorio!.isLancado) return;
    setState(() => _isSaving = true);
    try {
      final updated = await _api.salvarRascunhoRelatorio(
        _relatorio!.id,
        ocorrencias: _ocorrenciasCtrl.text.trim(),
        militarServicoId: _relatorio!.militarServicoId,
      );
      if (mounted) {
        setState(() {
          _relatorio = updated;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rascunho salvo com sucesso!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar rascunho: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmarLancamento() async {
    if (_relatorio == null || _relatorio!.isLancado) return;

    bool enviarEmail = true;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.send_rounded, color: Colors.blue),
              SizedBox(width: 10),
              Text('Lançar Relatório Oficial'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Deseja oficializar e lançar este relatório de serviço? Após o lançamento, ele será bloqueado para edição.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Destinatários Automáticos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                      SizedBox(height: 4),
                      Text('• Militar de serviço escalado (todos os e-mails cadastrados)', style: TextStyle(fontSize: 12)),
                      Text('• 2 Militares mais antigos da Seção de Informática (cadastrados no Admin)', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Disparar e-mails para os destinatários agora'),
                  value: enviarEmail,
                  onChanged: (v) => setDialogState(() => enviarEmail = v ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Confirmar e Lançar'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );

    if (confirmar != true) return;

    setState(() => _isLaunching = true);
    try {
      final lancado = await _api.lancarRelatorio(
        _relatorio!.id,
        ocorrencias: _ocorrenciasCtrl.text.trim(),
        militarServicoId: _relatorio!.militarServicoId,
        enviarEmail: enviarEmail,
      );
      if (mounted) {
        setState(() {
          _relatorio = lancado;
          _isLaunching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Relatório lançado e e-mails enviados com sucesso!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLaunching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao lançar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E17) : const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER COM AÇÕES
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF0369A1)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.assignment_turned_in_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Relatório Diário de Serviço (24 Horas)',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                    ),
                    Text(
                      'Passagem de plantão (07:30 às 07:30) com compilação automática',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ],
                ),
                const Spacer(),
                // Seletor de Data Histórica
                OutlinedButton.icon(
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: const Text('Histórico por Data'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _relatorio?.dataReferencia ?? DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      _carregarPorData(picked);
                    }
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Atualizar',
                  onPressed: _carregarRelatorioHoje,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // CONTEÚDO PRINCIPAL
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _relatorio == null
                      ? const Center(child: Text('Nenhum relatório disponível.'))
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // COLUNA ESQUERDA: CARDS DO SNAPSHOT 24H (55%)
                            Expanded(
                              flex: 55,
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    _buildCardInfoGeral(isDark),
                                    const SizedBox(height: 12),
                                    _buildCardManutencao(isDark),
                                    const SizedBox(height: 12),
                                    _buildCardCautelas(isDark),
                                    const SizedBox(height: 12),
                                    _buildCardPendencias(isDark),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // COLUNA DIREITA: EDITOR DE OCORRÊNCIAS & BOTÃO LANÇAR (45%)
                            Expanded(
                              flex: 45,
                              child: _buildColunaOcorrencias(isDark),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardInfoGeral(bool isDark) {
    final r = _relatorio!;
    final inicioStr = DateFormat('dd/MM HH:mm').format(r.periodoInicio);
    final fimStr = DateFormat('dd/MM HH:mm').format(r.periodoFim);
    final isLancado = r.isLancado;

    return Card(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Período: $inicioStr até $fimStr',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'Data de Referência: ${DateFormat('dd/MM/yyyy').format(r.dataReferencia)}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLancado ? Colors.green.withOpacity(0.15) : Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isLancado ? Colors.green : Colors.amber),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isLancado ? Icons.check_circle_rounded : Icons.edit_note_rounded,
                          size: 14, color: isLancado ? Colors.green : Colors.amber[800]),
                      const SizedBox(width: 4),
                      Text(
                        isLancado ? 'LANÇADO' : 'RASCUNHO',
                        style: TextStyle(
                          color: isLancado ? Colors.green : Colors.amber[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.badge_rounded, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('Militar de Serviço: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Expanded(
                  child: isLancado
                      ? Text(r.militarServicoNome ?? 'Não informado', style: const TextStyle(fontSize: 13))
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: r.militarServicoId,
                            hint: const Text('Selecionar militar...', style: TextStyle(fontSize: 12)),
                            items: _militaresTI.map((m) {
                              return DropdownMenuItem<int?>(
                                value: m['id'] as int,
                                child: Text(m['label'] as String, style: const TextStyle(fontSize: 12)),
                              );
                            }).toList(),
                            onChanged: (id) {
                              setState(() {
                                r.militarServicoId = id;
                                final m = _militaresTI.firstWhere((x) => x['id'] == id, orElse: () => {});
                                r.militarServicoNome = m['label'];
                              });
                            },
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

  Widget _buildCardManutencao(bool isDark) {
    final itens = _relatorio!.itensManutencao;

    return Card(
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
                const Icon(Icons.handyman_rounded, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Text('Itens em Manutenção (${itens.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            itens.isEmpty
                ? const Text('Nenhum item deu entrada em manutenção nas 24h.', style: TextStyle(fontSize: 12, color: Colors.grey))
                : Column(
                    children: itens.map((it) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.computer_rounded, size: 18),
                        title: Text('${it['nome']} (BMP: ${it['bmp'] ?? 'S/N'})', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        subtitle: Text('Defeito: ${it['defeito'] ?? 'Não especificado'}', style: const TextStyle(fontSize: 11.5)),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardCautelas(bool isDark) {
    final cautelas = _relatorio!.cautelasPeriodo;
    final devs = _relatorio!.devolucoesPeriodo;

    return Card(
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
                const Icon(Icons.inventory_2_rounded, color: Colors.blue, size: 18),
                const SizedBox(width: 8),
                Text('Cautelas e Devoluções (24h)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            Text('• ${cautelas.length} saídas de material / missões ativas', style: const TextStyle(fontSize: 12.5)),
            Text('• ${devs.length} devoluções de material registradas', style: const TextStyle(fontSize: 12.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildCardPendencias(bool isDark) {
    final criadas = _relatorio!.pendenciasCriadas;
    final resolvidas = _relatorio!.pendenciasResolvidas;

    return Card(
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
                const Icon(Icons.checklist_rounded, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Text('Pendências e Metas do Período', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            Text('• ${criadas.length} pendências criadas no período', style: const TextStyle(fontSize: 12.5)),
            Text('• ${resolvidas.length} pendências solucionadas no período', style: const TextStyle(fontSize: 12.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildColunaOcorrencias(bool isDark) {
    final r = _relatorio!;
    final isLancado = r.isLancado;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161E2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Text('Ocorrências do Plantão', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              if (!isLancado)
                TextButton.icon(
                  icon: _isSaving
                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined, size: 16),
                  label: const Text('Salvar Rascunho'),
                  onPressed: _isSaving ? null : _salvarRascunho,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isLancado
                ? 'Relatório oficial consolidado. Ocorrências registradas pelo militar de serviço:'
                : 'O militar de serviço deve descrever aqui alterações, rondas ou recados para o próximo plantão:',
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _ocorrenciasCtrl,
              readOnly: isLancado,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: isLancado ? 'Sem ocorrências registradas.' : 'Digite as alterações do plantão...',
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Se já foi lançado, mostra recibo de emails
          if (isLancado) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.mark_email_read_rounded, color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Lançado por ${r.lancadoPorNome ?? "Operador"} em ${r.lancadoEm != null ? DateFormat("dd/MM/yyyy HH:mm").format(r.lancadoEm!) : ""}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green),
                      ),
                    ],
                  ),
                  if (r.emailsDisparados.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'E-mails enviados: ${r.emailsDisparados.join(", ")}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            // Botão LANÇAR RELATÓRIO
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _isLaunching
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 20),
                label: const Text('Lançar Relatório (Concluir e Enviar E-mails)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                onPressed: _isLaunching ? null : _confirmarLancamento,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
