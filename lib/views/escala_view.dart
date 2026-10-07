import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../models/escala.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/escala_pdf_service.dart';
import '../theme/app_theme.dart';

class EscalaView extends StatefulWidget {
  final void Function(int targetIndex)? onNavigate;

  const EscalaView({super.key, this.onNavigate});

  @override
  State<EscalaView> createState() => _EscalaViewState();
}

class _EscalaViewState extends State<EscalaView> {
  final ApiService _api = ApiService();

  int _ano = DateTime.now().year;
  int _mes = DateTime.now().month;
  EscalaMensalModel? _escala;
  List<Map<String, dynamic>> _militaresTI = [];
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _meses = [
    '', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    try {
      final mil = await _api.listMilitaresInformatica();
      final esc = await _api.getEscalaMensal(_ano, _mes);
      if (mounted) {
        setState(() {
          _militaresTI = mil;
          _escala = esc;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar escala: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _recalcularEstatisticasLocais() {
    if (_escala == null) return;
    final map = <int, EstatisticaMilitarModel>{};

    for (final m in _militaresTI) {
      final id = m['id'] as int;
      map[id] = EstatisticaMilitarModel(
        militarId: id,
        nomeGuerra: m['nome_guerra'] ?? '',
        postoGraduacao: m['posto_graduacao'] ?? '',
        saram: m['saram'] ?? 0,
      );
    }

    for (final d in _escala!.dias) {
      final sem = d.semanaDoMes;
      if (d.militarSvId != null && map.containsKey(d.militarSvId)) {
        final st = map[d.militarSvId]!;
        st.totalSv++;
        if (sem == 1) st.semana1++;
        else if (sem == 2) st.semana2++;
        else if (sem == 3) st.semana3++;
        else if (sem == 4) st.semana4++;
        else if (sem >= 5) st.semana5++;
      }
      if (d.militarExpd1Id != null && map.containsKey(d.militarExpd1Id)) {
        map[d.militarExpd1Id]!.totalExpd++;
      }
      if (d.militarExpd2Id != null && map.containsKey(d.militarExpd2Id)) {
        map[d.militarExpd2Id]!.totalExpd++;
      }
    }

    setState(() {
      _escala!.estatisticas.clear();
      _escala!.estatisticas.addAll(map.values);
    });
  }

  Future<void> _salvarEscala() async {
    if (_escala == null) return;
    setState(() => _isSaving = true);
    try {
      final payload = {
        'ano': _ano,
        'mes': _mes,
        'titulo': _escala!.titulo,
        'dias': _escala!.dias.map((d) => d.toUpdateJson()).toList(),
      };
      final atualizada = await _api.salvarEscalaMensal(_ano, _mes, payload);
      if (mounted) {
        setState(() {
          _escala = atualizada;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escala salva com sucesso!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar escala: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportarPdf() async {
    if (_escala == null) return;
    try {
      final pdfBytes = await EscalaPdfService.generateEscalaPdf(_escala!);
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'Escala_${_meses[_mes]}_$_ano.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _mudarMes(int delta) {
    int novoMes = _mes + delta;
    int novoAno = _ano;
    if (novoMes < 1) {
      novoMes = 12;
      novoAno--;
    } else if (novoMes > 12) {
      novoMes = 1;
      novoAno++;
    }
    setState(() {
      _mes = novoMes;
      _ano = novoAno;
    });
    _carregarDados();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);
    final isAdmin = auth.isAdmin;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E17) : const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER COM SELETOR DE MÊS E AÇÕES
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Escala de Sobreaviso da TI',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                    ),
                    Text(
                      'Célula de Gestão de Material e Tecnologia da Informação',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ],
                ),
                const Spacer(),
                // Seletor de Mês/Ano
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: () => _mudarMes(-1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '${_meses[_mes].toUpperCase()} / $_ano',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: () => _mudarMes(1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text('Exportar PDF (1 Página)'),
                  onPressed: _escala == null ? null : _exportarPdf,
                ),
                if (isAdmin) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    icon: _isSaving
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Salvar Escala'),
                    onPressed: _isSaving || _escala == null ? null : _salvarEscala,
                  ),
                ],
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Atualizar',
                  onPressed: _carregarDados,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // CONTEÚDO PRINCIPAL
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _escala == null
                      ? const Center(child: Text('Nenhum dado encontrado.'))
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // TABELA PRINCIPAL DE DIAS (ESQUERDA)
                            Expanded(
                              flex: 65,
                              child: _buildTabelaDias(isDark, isAdmin),
                            ),
                            const SizedBox(width: 16),
                            // QUADRO ESTATÍSTICO (DIREITA)
                            Expanded(
                              flex: 35,
                              child: _buildQuadroEstatistico(isDark),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabelaDias(bool isDark, bool isAdmin) {
    final dias = _escala!.dias;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161E2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
      ),
      child: Column(
        children: [
          // Cabeçalho da Tabela
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 85, child: Text('DATA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                SizedBox(width: 110, child: Text('DIA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(flex: 3, child: Text('SERVIÇO (SV)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                SizedBox(width: 8),
                Expanded(flex: 3, child: Text('EXPD 1', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                SizedBox(width: 8),
                Expanded(flex: 3, child: Text('EXPD 2', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
            ),
          ),
          // Linhas dos Dias
          Expanded(
            child: ListView.separated(
              itemCount: dias.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
              itemBuilder: (ctx, i) {
                final d = dias[i];
                Color? rowBg;
                Color textColor = isDark ? Colors.white : Colors.black87;

                if (d.isFimDeSemana) {
                  rowBg = Colors.red.shade700;
                  textColor = Colors.white;
                } else if (d.isFeriado) {
                  rowBg = Colors.purple.shade700;
                  textColor = Colors.white;
                }

                return Container(
                  color: rowBg,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 85,
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(d.data),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: Text(
                          d.diaSemana,
                          style: TextStyle(fontSize: 12, color: textColor),
                        ),
                      ),
                      // Dropdown SERVIÇO
                      Expanded(
                        flex: 3,
                        child: _buildDropdownMilitar(
                          value: d.militarSvId,
                          textColor: textColor,
                          isWeekendOrHoliday: d.isFimDeSemana || d.isFeriado,
                          enabled: isAdmin,
                          onChanged: (id) {
                            setState(() {
                              d.militarSvId = id;
                              final m = _militaresTI.firstWhere((x) => x['id'] == id, orElse: () => {});
                              d.militarSvNome = m['label'];
                              d.militarSvGuerra = m['nome_guerra'];
                              d.militarSvPosto = m['posto_graduacao'];
                            });
                            _recalcularEstatisticasLocais();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Dropdown EXPD 1
                      Expanded(
                        flex: 3,
                        child: d.isFimDeSemana
                            ? const Center(child: Text('-', style: TextStyle(color: Colors.white70)))
                            : _buildDropdownMilitar(
                                value: d.militarExpd1Id,
                                textColor: textColor,
                                isWeekendOrHoliday: d.isFeriado,
                                enabled: isAdmin,
                                onChanged: (id) {
                                  setState(() {
                                    d.militarExpd1Id = id;
                                    final m = _militaresTI.firstWhere((x) => x['id'] == id, orElse: () => {});
                                    d.militarExpd1Nome = m['label'];
                                    d.militarExpd1Guerra = m['nome_guerra'];
                                    d.militarExpd1Posto = m['posto_graduacao'];
                                  });
                                  _recalcularEstatisticasLocais();
                                },
                              ),
                      ),
                      const SizedBox(width: 8),
                      // Dropdown EXPD 2
                      Expanded(
                        flex: 3,
                        child: d.isFimDeSemana
                            ? const Center(child: Text('-', style: TextStyle(color: Colors.white70)))
                            : _buildDropdownMilitar(
                                value: d.militarExpd2Id,
                                textColor: textColor,
                                isWeekendOrHoliday: d.isFeriado,
                                enabled: isAdmin,
                                onChanged: (id) {
                                  setState(() {
                                    d.militarExpd2Id = id;
                                    final m = _militaresTI.firstWhere((x) => x['id'] == id, orElse: () => {});
                                    d.militarExpd2Nome = m['label'];
                                    d.militarExpd2Guerra = m['nome_guerra'];
                                    d.militarExpd2Posto = m['posto_graduacao'];
                                  });
                                  _recalcularEstatisticasLocais();
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownMilitar({
    required int? value,
    required Color textColor,
    required bool isWeekendOrHoliday,
    required bool enabled,
    required void Function(int?) onChanged,
  }) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isWeekendOrHoliday
            ? Colors.black.withOpacity(0.2)
            : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isWeekendOrHoliday ? Colors.white30 : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: value,
          isExpanded: true,
          dropdownColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(fontSize: 11.5, color: isWeekendOrHoliday ? Colors.white : null),
          hint: Text('Selecionar...', style: TextStyle(fontSize: 11, color: isWeekendOrHoliday ? Colors.white70 : Colors.grey)),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('(Vazio)', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
            ),
            ..._militaresTI.map((m) {
              return DropdownMenuItem<int?>(
                value: m['id'] as int,
                child: Text(
                  m['label'] as String,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ],
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  Widget _buildQuadroEstatistico(bool isDark) {
    final stats = _escala!.estatisticas;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161E2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('MILITAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                SizedBox(width: 32, child: Text('expd', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                SizedBox(width: 30, child: Text('sv', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.blue))),
                SizedBox(width: 34, child: Text('Sem 1', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                SizedBox(width: 34, child: Text('Sem 2', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                SizedBox(width: 34, child: Text('Sem 3', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                SizedBox(width: 34, child: Text('Sem 4', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                SizedBox(width: 34, child: Text('Sem 5', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: stats.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
              itemBuilder: (ctx, i) {
                final s = stats[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          '${s.postoGraduacao} ${s.nomeGuerra}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        child: Text('${s.totalExpd}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5)),
                      ),
                      SizedBox(
                        width: 30,
                        child: Text(
                          '${s.totalSv}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ),
                      SizedBox(width: 34, child: Text('${s.semana1}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))),
                      SizedBox(width: 34, child: Text('${s.semana2}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))),
                      SizedBox(width: 34, child: Text('${s.semana3}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))),
                      SizedBox(width: 34, child: Text('${s.semana4}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))),
                      SizedBox(width: 34, child: Text('${s.semana5}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
