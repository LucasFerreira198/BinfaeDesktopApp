import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/stock_provider.dart';
import '../theme/app_theme.dart';

class LocationFormDialog extends StatefulWidget {
  final LocationModel? location;

  const LocationFormDialog({super.key, this.location});

  @override
  State<LocationFormDialog> createState() => _LocationFormDialogState();
}

class _LocationFormDialogState extends State<LocationFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nomeController;
  late TextEditingController _descricaoController;
  String _tipo = 'DEPOSITO';
  int? _selectedParentId;
  bool _isSubmitting = false;

  final List<String> _tiposEstrutura = [
    'DEPOSITO',
    'ARMARIO',
    'PRATELEIRA',
    'GAVETA',
    'SALA',
    'BANCADA',
    'SETOR',
  ];

  @override
  void initState() {
    super.initState();
    final loc = widget.location;
    _nomeController = TextEditingController(text: loc?.nome ?? '');
    _descricaoController = TextEditingController(text: loc?.descricao ?? '');
    _tipo = loc?.tipo ?? 'DEPOSITO';
    _selectedParentId = loc?.parentId;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  // Prevenção de dependência circular
  Set<int> _getDescendantIds(int rootId, List<LocationModel> allLocs) {
    final descendants = <int>{rootId};
    var added = true;
    while (added) {
      added = false;
      for (final loc in allLocs) {
        if (loc.parentId != null && descendants.contains(loc.parentId) && !descendants.contains(loc.id)) {
          descendants.add(loc.id);
          added = true;
        }
      }
    }
    return descendants;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final data = <String, dynamic>{
      'nome': _nomeController.text.trim(),
      'tipo': _tipo,
      'parent_id': _selectedParentId,
      'descricao': _descricaoController.text.trim().isEmpty ? null : _descricaoController.text.trim(),
    };

    setState(() => _isSubmitting = true);

    try {
      final stock = Provider.of<StockProvider>(context, listen: false);
      if (widget.location == null) {
        await stock.createLocation(data);
      } else {
        await stock.updateLocation(widget.location!.id, data);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(widget.location == null ? 'Local cadastrado com sucesso!' : 'Local atualizado com sucesso!'),
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

    // Filtrar possíveis pais para evitar referências circulares
    final allLocs = stock.locations;
    final invalidParentIds = widget.location != null ? _getDescendantIds(widget.location!.id, allLocs) : <int>{};

    final availableParents = allLocs.where((l) => !invalidParentIds.contains(l.id)).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(26),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.location == null ? 'Novo Local Físico' : 'Editar Local Físico',
                    style: TextStyle(
                      fontSize: 18,
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
              const SizedBox(height: 18),

              // Nome do Local
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Local *',
                  hintText: 'Ex: Depósito Bravo, Armário 1, Gaveta 3...',
                  prefixIcon: Icon(Icons.place_outlined, size: 20),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome do local' : null,
              ),
              const SizedBox(height: 14),

              // Tipo de Estrutura
              DropdownButtonFormField<String>(
                value: _tipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Estrutura',
                  prefixIcon: Icon(Icons.apartment_outlined, size: 20),
                ),
                items: _tiposEstrutura.map((t) {
                  return DropdownMenuItem<String>(
                    value: t,
                    child: Text(t),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _tipo = val ?? 'DEPOSITO'),
              ),
              const SizedBox(height: 14),

              // Local Pai / Hierarquia
              DropdownButtonFormField<int?>(
                value: _selectedParentId,
                decoration: const InputDecoration(
                  labelText: 'Local Superior (Pai na Hierarquia)',
                  prefixIcon: Icon(Icons.account_tree_outlined, size: 20),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Nenhum (Local Raiz / Depósito Principal)'),
                  ),
                  ...availableParents.map((loc) {
                    return DropdownMenuItem<int?>(
                      value: loc.id,
                      child: Text(loc.caminhoCompleto ?? loc.nome),
                    );
                  }),
                ],
                onChanged: (val) => setState(() => _selectedParentId = val),
              ),
              const SizedBox(height: 14),

              // Descrição
              TextFormField(
                controller: _descricaoController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descrição / Observações',
                  hintText: 'Instruções de acesso ou localização física...',
                  prefixIcon: Icon(Icons.notes, size: 20),
                ),
              ),
              const SizedBox(height: 24),

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
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check, size: 18),
                    label: Text(widget.location == null ? 'Salvar Local' : 'Atualizar Local'),
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
