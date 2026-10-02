import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AdminView extends StatefulWidget {
  const AdminView({super.key});

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<UserModel> _users = [];
  List<MilitaryModel> _militaries = [];
  bool _isLoadingUsers = true;
  bool _isLoadingMilitaries = true;
  String? _userError;
  String? _militaryError;

  final List<String> _postosGraduacoes = [
    'Soldado',
    'Cabo',
    '3º Sargento',
    '2º Sargento',
    '1º Sargento',
    'Suboficial',
    'Aspirante',
    '2º Tenente',
    '1º Tenente',
    'Capitão',
    'Major',
    'Tenente-Coronel',
    'Coronel',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    _loadUsers();
    _loadMilitaries();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
      _userError = null;
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final list = await api.listUsers();
      if (mounted) {
        setState(() {
          _users = list;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userError = e.toString().replaceAll('Exception: ', '');
          _isLoadingUsers = false;
        });
      }
    }
  }

  Future<void> _loadMilitaries() async {
    setState(() {
      _isLoadingMilitaries = true;
      _militaryError = null;
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final list = await api.listMilitaries();
      if (mounted) {
        setState(() {
          _militaries = list;
          _isLoadingMilitaries = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _militaryError = e.toString().replaceAll('Exception: ', '');
          _isLoadingMilitaries = false;
        });
      }
    }
  }

  // --- Diálogo: Criar Usuário ---
  void _openCreateUserDialog() {
    int? selectedSaram;
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    bool isAdmin = false;
    bool isAtivo = true;
    bool isMilitarLink = true;

    showDialog(
      context: context,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Cadastrar Novo Usuário'),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tipo de conta
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text('Militar do Efetivo', style: TextStyle(fontSize: 13)),
                              value: true,
                              groupValue: isMilitarLink,
                              onChanged: (v) => setModalState(() => isMilitarLink = v ?? true),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text('Admin Avulso', style: TextStyle(fontSize: 13)),
                              value: false,
                              groupValue: isMilitarLink,
                              onChanged: (v) => setModalState(() {
                                isMilitarLink = v ?? false;
                                if (!isMilitarLink) isAdmin = true;
                              }),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (isMilitarLink) ...[
                        DropdownButtonFormField<int>(
                          value: selectedSaram,
                          decoration: const InputDecoration(
                            labelText: 'Selecione o Militar *',
                            prefixIcon: Icon(Icons.shield, size: 18),
                          ),
                          items: _militaries.map((m) {
                            return DropdownMenuItem<int>(
                              value: m.saram,
                              child: Text('${m.postoGraduacao} ${m.nomeGuerra} (SARAM: ${m.saram})'),
                            );
                          }).toList(),
                          onChanged: (val) => setModalState(() => selectedSaram = val),
                        ),
                      ] else ...[
                        TextField(
                          controller: usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Nome de Usuário (Username) *',
                            prefixIcon: Icon(Icons.person_outline, size: 18),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Senha de Acesso *',
                          prefixIcon: Icon(Icons.lock_outline, size: 18),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Toggles
                      SwitchListTile(
                        title: const Text('Administrador do Sistema', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Concede privilégios administrativos totais no app', style: TextStyle(fontSize: 11)),
                        value: isAdmin,
                        activeColor: AppColors.primary,
                        onChanged: (v) => setModalState(() => isAdmin = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        title: const Text('Conta Ativa', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Permite autenticação e uso do sistema', style: TextStyle(fontSize: 11)),
                        value: isAtivo,
                        activeColor: AppColors.success,
                        onChanged: (v) => setModalState(() => isAtivo = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final pass = passwordController.text;
                          if (pass.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe uma senha.')));
                            return;
                          }
                          if (isMilitarLink && selectedSaram == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um militar.')));
                            return;
                          }
                          if (!isMilitarLink && usernameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe um username.')));
                            return;
                          }

                          setModalState(() => isSubmitting = true);
                          try {
                            final api = Provider.of<ApiService>(context, listen: false);
                            await api.createUser(
                              saram: isMilitarLink ? selectedSaram : null,
                              username: !isMilitarLink ? usernameController.text.trim() : null,
                              password: pass,
                              admin: isAdmin,
                              ativo: isAtivo,
                            );
                            if (mounted) {
                              Navigator.pop(ctx);
                              _loadUsers();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(backgroundColor: AppColors.success, content: Text('Usuário criado com sucesso!')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(backgroundColor: AppColors.danger, content: Text(e.toString().replaceAll('Exception: ', ''))),
                              );
                            }
                          } finally {
                            setModalState(() => isSubmitting = false);
                          }
                        },
                  child: const Text('Criar Usuário'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Diálogo: Editar Usuário ---
  void _openEditUserDialog(UserModel user) {
    bool isAdmin = user.admin;
    bool isAtivo = user.ativo;
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final identifier = user.militar?.saram ?? user.id;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Editar Usuário: ${user.displayName}'),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      title: const Text('Perfil Administrador', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Acesso ao painel administrativo e configurações avançadas', style: TextStyle(fontSize: 11)),
                      value: isAdmin,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setModalState(() => isAdmin = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Usuário Ativo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Desative para suspender o acesso sem deletar a conta', style: TextStyle(fontSize: 11)),
                      value: isAtivo,
                      activeColor: AppColors.success,
                      onChanged: (v) => setModalState(() => isAtivo = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Redefinir Senha (opcional)',
                        hintText: 'Deixe em branco para manter a senha atual',
                        prefixIcon: Icon(Icons.lock_outline, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setModalState(() => isSubmitting = true);
                          try {
                            final api = Provider.of<ApiService>(context, listen: false);
                            await api.updateUser(
                              identifier,
                              admin: isAdmin,
                              ativo: isAtivo,
                              password: passwordController.text.trim().isNotEmpty ? passwordController.text.trim() : null,
                            );
                            if (mounted) {
                              Navigator.pop(ctx);
                              _loadUsers();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(backgroundColor: AppColors.success, content: Text('Usuário atualizado!')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(backgroundColor: AppColors.danger, content: Text(e.toString().replaceAll('Exception: ', ''))),
                              );
                            }
                          } finally {
                            setModalState(() => isSubmitting = false);
                          }
                        },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Diálogo: Cadastrar / Editar Militar ---
  void _openMilitaryDialog([MilitaryModel? military]) {
    final saramController = TextEditingController(text: military != null ? military.saram.toString() : '');
    final nomeCompletoController = TextEditingController(text: military?.nomeCompleto ?? '');
    final nomeGuerraController = TextEditingController(text: military?.nomeGuerra ?? '');
    final secaoController = TextEditingController(text: military?.secao ?? '');
    final emailController = TextEditingController(text: military?.email ?? '');
    final celularController = TextEditingController(text: military?.celular ?? '');
    String posto = military?.postoGraduacao ?? 'Soldado';

    showDialog(
      context: context,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(military == null ? 'Cadastrar Militar no Efetivo' : 'Editar Militar: ${military.nomeGuerra}'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: saramController,
                              keyboardType: TextInputType.number,
                              enabled: military == null,
                              decoration: const InputDecoration(
                                labelText: 'SARAM *',
                                hintText: 'Ex: 1234567',
                                prefixIcon: Icon(Icons.badge_outlined, size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _postosGraduacoes.contains(posto) ? posto : _postosGraduacoes.first,
                              decoration: const InputDecoration(
                                labelText: 'Posto / Graduação *',
                                prefixIcon: Icon(Icons.military_tech_outlined, size: 18),
                              ),
                              items: _postosGraduacoes.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                              onChanged: (val) => setModalState(() => posto = val ?? 'Soldado'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: nomeGuerraController,
                              decoration: const InputDecoration(
                                labelText: 'Nome de Guerra *',
                                hintText: 'Ex: Silva, Santos...',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: secaoController,
                              decoration: const InputDecoration(
                                labelText: 'Seção / Subdivisão',
                                hintText: 'Ex: Informática, Almoxarifado',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: nomeCompletoController,
                        decoration: const InputDecoration(
                          labelText: 'Nome Completo *',
                          hintText: 'Ex: João da Silva Santos',
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: emailController,
                              decoration: const InputDecoration(
                                labelText: 'E-mail',
                                hintText: 'Ex: militar@fab.mil.br',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: celularController,
                              decoration: const InputDecoration(
                                labelText: 'Celular / Ramal',
                                hintText: 'Ex: (11) 99999-9999',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final saram = int.tryParse(saramController.text.trim());
                          if (saram == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe um SARAM válido.')));
                            return;
                          }
                          if (nomeGuerraController.text.trim().isEmpty || nomeCompletoController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha os campos obrigatórios.')));
                            return;
                          }

                          setModalState(() => isSubmitting = true);
                          final data = <String, dynamic>{
                            'saram': saram,
                            'posto_graduacao': posto,
                            'nome_guerra': nomeGuerraController.text.trim(),
                            'nome_completo': nomeCompletoController.text.trim(),
                            'secao': secaoController.text.trim().isEmpty ? null : secaoController.text.trim(),
                            'email': emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                            'celular': celularController.text.trim().isEmpty ? null : celularController.text.trim(),
                          };

                          try {
                            final api = Provider.of<ApiService>(context, listen: false);
                            if (military == null) {
                              await api.createMilitary(data);
                            } else {
                              await api.updateMilitary(military.saram, data);
                            }
                            if (mounted) {
                              Navigator.pop(ctx);
                              _loadMilitaries();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.success,
                                  content: Text(military == null ? 'Militar cadastrado no efetivo!' : 'Dados do militar atualizados!'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(backgroundColor: AppColors.danger, content: Text(e.toString().replaceAll('Exception: ', ''))),
                              );
                            }
                          } finally {
                            setModalState(() => isSubmitting = false);
                          }
                        },
                  child: Text(military == null ? 'Cadastrar Militar' : 'Salvar Alterações'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Painel de Controle do Administrador',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gestão de contas de usuários, permissões e cadastro de militares do efetivo',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const [
                  Tab(icon: Icon(Icons.people_alt_outlined, size: 18), text: 'Usuários do Sistema'),
                  Tab(icon: Icon(Icons.shield_outlined, size: 18), text: 'Militares do Efetivo'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Abas
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUsersTab(isDark),
                _buildMilitariesTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab(bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_users.length} contas cadastradas',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
            ElevatedButton.icon(
              onPressed: _openCreateUserDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: const Text('Novo Usuário', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _isLoadingUsers
              ? const Center(child: CircularProgressIndicator())
              : _userError != null
                  ? Center(child: Text('Erro: $_userError'))
                  : Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF151D2F) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ListView.separated(
                          itemCount: _users.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF1F293D) : const Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final u = _users[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: u.admin ? AppColors.primary.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                                    child: Icon(
                                      u.admin ? Icons.admin_panel_settings : Icons.person_outline,
                                      size: 18,
                                      color: u.admin ? AppColors.primary : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          u.displayName,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          u.militar != null
                                              ? 'SARAM: ${u.militar!.saram} • ${u.militar!.secao ?? "Sem seção"}'
                                              : 'Username: ${u.username}',
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Badge Admin
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: u.admin ? AppColors.primary.withOpacity(0.12) : Colors.grey.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      u.admin ? 'Administrador' : 'Operador',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: u.admin ? AppColors.primary : Colors.grey,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Badge Ativo
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: u.ativo ? AppColors.success.withOpacity(0.12) : AppColors.danger.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      u.ativo ? 'Ativo' : 'Inativo',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: u.ativo ? AppColors.success : AppColors.danger,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    tooltip: 'Editar Permissões e Senha',
                                    onPressed: () => _openEditUserDialog(u),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildMilitariesTab(bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_militaries.length} militares no efetivo',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
            ElevatedButton.icon(
              onPressed: () => _openMilitaryDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('Cadastrar Militar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _isLoadingMilitaries
              ? const Center(child: CircularProgressIndicator())
              : _militaryError != null
                  ? Center(child: Text('Erro: $_militaryError'))
                  : Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF151D2F) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ListView.separated(
                          itemCount: _militaries.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF1F293D) : const Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final m = _militaries[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 70,
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${m.saram}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${m.postoGraduacao} ${m.nomeGuerra}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          m.nomeCompleto,
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      m.secao ?? 'Geral',
                                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                                    ),
                                  ),
                                  if (m.celular != null || m.email != null) ...[
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        m.celular ?? m.email ?? '',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    tooltip: 'Editar Militar',
                                    onPressed: () => _openMilitaryDialog(m),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}
