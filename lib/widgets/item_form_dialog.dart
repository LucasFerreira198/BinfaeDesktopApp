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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 650),
        padding: const EdgeInsets.all(26),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.item == null ? 'Cadastrar Novo Material' : 'Editar Material',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome
                      TextFormField(
                        controller: _nomeController,
                        decoration: const InputDecoration(
                          labelText: 'Nome do Material *',
                          hintText: 'Ex: Teclado USB Dell KB216',
                          prefixIcon: Icon(Icons.inventory_2_outlined, size: 20),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome do material' : null,
                      ),
                      const SizedBox(height: 14),

                      // Identificadores (BMP, Código Interno, Número de Série)
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _bmpController,
                              decoration: const InputDecoration(
                                labelText: 'BMP (Patrimônio)',
                                hintText: 'Ex: 123456',
                                prefixIcon: Icon(Icons.qr_code, size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _codigoInternoController,
                              decoration: const InputDecoration(
                                labelText: 'Código Interno',
                                hintText: 'Ex: TEC-001',
                                prefixIcon: Icon(Icons.tag, size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _numeroSerieController,
                              decoration: const InputDecoration(
                                labelText: 'Número de Série',
                                hintText: 'Ex: CN-012345',
                                prefixIcon: Icon(Icons.fingerprint, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Categorias: Grupo e Subgrupo em cascata
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _selectedGrupoId,
                              decoration: const InputDecoration(
                                labelText: 'Grupo',
                                prefixIcon: Icon(Icons.category_outlined, size: 18),
                              ),
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
                              decoration: const InputDecoration(
                                labelText: 'Subgrupo',
                                prefixIcon: Icon(Icons.subdirectory_arrow_right, size: 18),
                              ),
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
                      const SizedBox(height: 14),

                      // Local Físico de Armazenamento
                      DropdownButtonFormField<int>(
                        value: _selectedLocalId,
                        decoration: const InputDecoration(
                          labelText: 'Local Físico de Armazenamento',
                          prefixIcon: Icon(Icons.place_outlined, size: 18),
                        ),
                        items: stock.locations.map((loc) {
                          return DropdownMenuItem<int>(
                            value: loc.id,
                            child: Text(loc.caminhoCompleto ?? loc.nome),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedLocalId = val),
                      ),
                      const SizedBox(height: 14),

                      // Estoque e Quantidades
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _tipoControle,
                              decoration: const InputDecoration(labelText: 'Tipo de Controle'),
                              items: _tiposControle.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                              onChanged: (val) => setState(() => _tipoControle = val ?? 'UNITARIO'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _quantidadeController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Saldo em Estoque *'),
                              validator: (v) => v == null || double.tryParse(v.replaceAll(',', '.')) == null
                                  ? 'Quantidade inválida'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _quantidadeMinimaController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Estoque Mínimo'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _unidadeMedida,
                              decoration: const InputDecoration(labelText: 'Unidade'),
                              items: _unidades.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                              onChanged: (val) => setState(() => _unidadeMedida = val ?? 'UNIDADE'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Estado de Conservação e Status
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _estadoConservacao,
                              decoration: const InputDecoration(labelText: 'Estado de Conservação'),
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
                              decoration: const InputDecoration(labelText: 'Status Atual'),
                              items: _statusList
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' '))))
                                  .toList(),
                              onChanged: (val) => setState(() => _status = val ?? 'DISPONIVEL'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Observações
                      TextFormField(
                        controller: _observacoesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Observações / Especificações Técnicas',
                          hintText: 'Anotações adicionais sobre o material, licenças, etc.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Ações
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check, size: 18),
                    label: Text(widget.item == null ? 'Cadastrar Material' : 'Salvar Alterações'),
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
