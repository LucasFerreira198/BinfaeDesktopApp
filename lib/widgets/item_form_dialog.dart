import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/stock_provider.dart';
import '../theme/app_theme.dart';

class ItemFormDialog extends StatefulWidget {
  final ItemModel? item;

  const ItemFormDialog({super.key, this.item});

  @override
  State<ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends State<ItemFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nomeController;
  late TextEditingController _bmpController;
  late TextEditingController _codigoInternoController;
  late TextEditingController _numeroSerieController;
  late TextEditingController _quantidadeController;
  late TextEditingController _quantidadeMinimaController;
  late TextEditingController _observacoesController;

  int? _selectedGrupoId;
  int? _selectedSubgrupoId;
  int? _selectedLocalId;
  String _tipoControle = 'UNITARIO';
  String _unidadeMedida = 'UNIDADE';
  String _estadoConservacao = 'BOM';
  String _status = 'DISPONIVEL';

  bool _isSubmitting = false;

  final List<String> _tiposControle = ['UNITARIO', 'GRANEL'];
  final List<String> _unidades = ['UNIDADE', 'METRO', 'LITRO', 'KG', 'CAIXA', 'PACOTE', 'ROLO', 'PAR'];
  final List<String> _estadosConservacao = ['NOVO', 'BOM', 'REGULAR', 'COM_DEFEITO', 'SUCATA'];
  final List<String> _statusList = ['DISPONIVEL', 'CAUTELADO', 'EM_MANUTENCAO', 'EM_USO', 'BAIXADO'];

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nomeController = TextEditingController(text: item?.nome ?? '');
    _bmpController = TextEditingController(text: item?.bmp ?? '');
    _codigoInternoController = TextEditingController(text: item?.codigoInterno ?? '');
    _numeroSerieController = TextEditingController(text: item?.numeroSerie ?? '');
    _quantidadeController = TextEditingController(text: item != null ? item.quantidade.toString() : '1');
    _quantidadeMinimaController = TextEditingController(text: item != null ? item.quantidadeMinima.toString() : '0');
    _observacoesController = TextEditingController(text: item?.observacoes ?? '');

    _tipoControle = item?.tipoControle ?? 'UNITARIO';
    _unidadeMedida = item?.unidadeMedida ?? 'UNIDADE';
    _estadoConservacao = item?.estadoConservacao ?? 'BOM';
    _status = item?.status ?? 'DISPONIVEL';
    _selectedLocalId = item?.localId;
    _selectedSubgrupoId = item?.subgrupoId;

    if (item?.subgrupo != null) {
      _selectedGrupoId = item!.subgrupo!.grupoId;
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _bmpController.dispose();
    _codigoInternoController.dispose();
    _numeroSerieController.dispose();
    _quantidadeController.dispose();
    _quantidadeMinimaController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final qty = double.tryParse(_quantidadeController.text.replaceAll(',', '.')) ?? 1.0;
    final qtyMin = double.tryParse(_quantidadeMinimaController.text.replaceAll(',', '.')) ?? 0.0;

    final data = <String, dynamic>{
      'nome': _nomeController.text.trim(),
      'tipo_controle': _tipoControle,
      'quantidade': qty,
      'quantidade_minima': qtyMin,
      'unidade_medida': _unidadeMedida,
      'estado_conservacao': _estadoConservacao,
      'status': _status,
      'observacoes': _observacoesController.text.trim().isEmpty ? null : _observacoesController.text.trim(),
      'bmp': _bmpController.text.trim().isEmpty ? null : _bmpController.text.trim(),
      'codigo_interno': _codigoInternoController.text.trim().isEmpty ? null : _codigoInternoController.text.trim(),
      'numero_serie': _numeroSerieController.text.trim().isEmpty ? null : _numeroSerieController.text.trim(),
      'subgrupo_id': _selectedSubgrupoId,
      'local_id': _selectedLocalId,
    };

    setState(() => _isSubmitting = true);

    try {
      final stock = Provider.of<StockProvider>(context, listen: false);
      if (widget.item == null) {
        await stock.createItem(data);
      } else {
        await stock.updateItem(widget.item!.id, data);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(widget.item == null ? 'Material cadastrado com sucesso!' : 'Material atualizado com sucesso!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool isDark = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101622) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF1E2838) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: AppColors.cyan),
              ),
              const SizedBox(width: 10),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label, {String? hint, IconData? icon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 18, color: const Color(0xFF94A3B8)) : null,
      filled: true,
      fillColor: isDark ? const Color(0xFF151D2A) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isDark ? const Color(0xFF232B3E) : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isDark ? const Color(0xFF232B3E) : const Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.cyan, width: 1.5),
      ),
      labelStyle: const TextStyle(fontSize: 12.5),
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stock = Provider.of<StockProvider>(context);

    final groups = stock.groups;
    final filteredSubgroups = _selectedGrupoId != null
        ? stock.subgroups.where((s) => s.grupoId == _selectedGrupoId).toList()
        : stock.subgroups;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0B0F17) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? const Color(0xFF1E2838) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Container(
        width: 760,
        constraints: const BoxConstraints(maxHeight: 740),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Modal com Badge e Subtítulo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
                        ),
                        child: Icon(
                          widget.item == null ? Icons.add_box_rounded : Icons.edit_note_rounded,
                          color: AppColors.cyan,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item == null ? 'Cadastrar Novo Material' : 'Editar Material',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            widget.item == null
                                ? 'Informe os dados patrimoniais e de estoque do item'
                                : 'Atualize os parâmetros e a localização do item patrimonial',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF151D2A) : const Color(0xFFF1F5F9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Conteúdo Rolável Dividido em Seções Visuais
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Seção 1: Identificação do Material
                      _buildSectionCard(
                        title: '1. Identificação Patrimonial',
                        icon: Icons.qr_code_2_rounded,
                        isDark: isDark,
                        children: [
                          TextFormField(
                            controller: _nomeController,
                            decoration: _inputDeco(
                              'Nome do Material *',
                              hint: 'Ex: Teclado USB Dell KB216, Rádio APX2000',
                              icon: Icons.inventory_2_outlined,
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome do material' : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _bmpController,
                                  decoration: _inputDeco('BMP (Patrimônio)', hint: 'Ex: 5540', icon: Icons.qr_code),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _codigoInternoController,
                                  decoration: _inputDeco('Código Interno', hint: 'Ex: TEC-001', icon: Icons.tag),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _numeroSerieController,
                                  decoration: _inputDeco('Número de Série', hint: 'Ex: CN-012345', icon: Icons.fingerprint),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Seção 2: Classificação & Localização
                      _buildSectionCard(
                        title: '2. Classificação & Localização Física',
                        icon: Icons.category_rounded,
                        isDark: isDark,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: _selectedGrupoId,
                                  decoration: _inputDeco('Grupo', icon: Icons.category_outlined),
                                  dropdownColor: isDark ? const Color(0xFF151D2A) : Colors.white,
                                  items: groups.map((g) {
                                    return DropdownMenuItem<int>(
                                      value: g.id,
                                      child: Text(g.nome),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedGrupoId = val;
                                      _selectedSubgrupoId = null;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: _selectedSubgrupoId,
                                  decoration: _inputDeco('Subgrupo', icon: Icons.subdirectory_arrow_right),
                                  dropdownColor: isDark ? const Color(0xFF151D2A) : Colors.white,
                                  items: filteredSubgroups.map((s) {
                                    return DropdownMenuItem<int>(
                                      value: s.id,
                                      child: Text(s.nome),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setState(() => _selectedSubgrupoId = val),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            value: _selectedLocalId,
                            decoration: _inputDeco('Local Físico de Armazenamento', icon: Icons.place_outlined),
                            dropdownColor: isDark ? const Color(0xFF151D2A) : Colors.white,
                            items: stock.locations.map((loc) {
                              return DropdownMenuItem<int>(
                                value: loc.id,
                                child: Text(loc.caminhoCompleto ?? loc.nome),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedLocalId = val),
                          ),
                        ],
                      ),

                      // Seção 3: Controle de Estoque & Parâmetros
                      _buildSectionCard(
                        title: '3. Controle de Estoque & Medidas',
                        icon: Icons.insights_rounded,
                        isDark: isDark,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _tipoControle,
                                  decoration: _inputDeco('Tipo de Controle', icon: Icons.tune),
                                  dropdownColor: isDark ? const Color(0xFF151D2A) : Colors.white,
                                  items: _tiposControle.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                  onChanged: (val) => setState(() => _tipoControle = val ?? 'UNITARIO'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _quantidadeController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: _inputDeco('Saldo em Estoque *', hint: 'Ex: 1.0', icon: Icons.numbers),
                                  validator: (v) => v == null || double.tryParse(v.replaceAll(',', '.')) == null
                                      ? 'Quantidade inválida'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _quantidadeMinimaController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: _inputDeco('Estoque Mínimo', hint: 'Ex: 0.0', icon: Icons.warning_amber),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _unidadeMedida,
                                  decoration: _inputDeco('Unidade', icon: Icons.straighten),
                                  dropdownColor: isDark ? const Color(0xFF151D2A) : Colors.white,
                                  items: _unidades.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                                  onChanged: (val) => setState(() => _unidadeMedida = val ?? 'UNIDADE'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Seção 4: Condição & Status Operacional
                      _buildSectionCard(
                        title: '4. Condição Operacional & Status',
                        icon: Icons.health_and_safety_outlined,
                        isDark: isDark,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _estadoConservacao,
                                  decoration: _inputDeco('Estado de Conservação', icon: Icons.verified_outlined),
                                  dropdownColor: isDark ? const Color(0xFF151D2A) : Colors.white,
                                  items: _estadosConservacao
                                      .map((e) => DropdownMenuItem(value: e, child: Text(e.replaceAll('_', ' '))))
                                      .toList(),
                                  onChanged: (val) => setState(() => _estadoConservacao = val ?? 'BOM'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _status,
                                  decoration: _inputDeco('Status Atual no Sistema', icon: Icons.radio_button_checked),
                                  dropdownColor: isDark ? const Color(0xFF151D2A) : Colors.white,
                                  items: _statusList
                                      .map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' '))))
                                      .toList(),
                                  onChanged: (val) => setState(() => _status = val ?? 'DISPONIVEL'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Seção 5: Observações / Especificações Técnicas
                      _buildSectionCard(
                        title: '5. Observações & Especificações Técnicas',
                        icon: Icons.notes_rounded,
                        isDark: isDark,
                        children: [
                          TextFormField(
                            controller: _observacoesController,
                            maxLines: 3,
                            decoration: _inputDeco(
                              'Observações Técnicas / Garantia',
                              hint: 'Anotações adicionais, endereço MAC, licenças, número de série adicional, etc.',
                              icon: Icons.description_outlined,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Rodapé do Modal com Ações
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cyan,
                      foregroundColor: const Color(0xFF0A0E17),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A0E17)),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      _isSubmitting
                          ? 'Salvando...'
                          : (widget.item == null ? 'Cadastrar Material' : 'Salvar Alterações'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
