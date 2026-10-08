import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../models/config_ti.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/image_picker_helper.dart';
import '../widgets/avatar_editor_dialog.dart';
import '../widgets/user_avatar.dart';

class AdminView extends StatefulWidget {
  const AdminView({super.key});

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<UserModel> _users = [];
  List<MilitaryModel> _militaries = [];
  InformaticaConfigModel? _configTI;
  bool _isLoadingUsers = true;
  bool _isLoadingMilitaries = true;
  bool _isLoadingConfigTI = true;
  bool _isSavingConfigTI = false;
  String? _userError;
  String? _militaryError;

  final TextEditingController _smtpHostCtrl = TextEditingController();
  final TextEditingController _smtpPortCtrl = TextEditingController();
  final TextEditingController _smtpUserCtrl = TextEditingController();
  final TextEditingController _smtpPasswordCtrl = TextEditingController();
  final TextEditingController _smtpFromCtrl = TextEditingController();
  bool _obscureSmtpPassword = true;

  final List<String> _postosGraduacoes = [
    'S2',
    'S1',
    'CB',
    '3S',
    '2S',
    '1S',
    'SO',
    'Asp',
    '2T',
    '1T',
    'Cap',
    'Maj',
    'TC',
    'Cel',
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
    'Civil',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _smtpHostCtrl.dispose();
    _smtpPortCtrl.dispose();
    _smtpUserCtrl.dispose();
    _smtpPasswordCtrl.dispose();
    _smtpFromCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await _loadUsers();
    if (mounted) await _loadMilitaries();
    if (mounted) await _loadConfigTI();
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

  Future<void> _loadConfigTI() async {
    setState(() => _isLoadingConfigTI = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final cfg = await api.getConfigTI();
      if (mounted) {
        setState(() {
          _configTI = cfg;
          _smtpHostCtrl.text = cfg.smtpHost ?? '';
          _smtpPortCtrl.text = cfg.smtpPort.toString();
          _smtpUserCtrl.text = cfg.smtpUser ?? '';
          _smtpPasswordCtrl.text = cfg.smtpPassword ?? '';
          _smtpFromCtrl.text = cfg.smtpFrom ?? '';
          _isLoadingConfigTI = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingConfigTI = false);
    }
  }

  Future<void> _saveConfigTI() async {
    if (_configTI == null) return;
    setState(() => _isSavingConfigTI = true);
    try {
      _configTI!.smtpHost = _smtpHostCtrl.text.trim();
      _configTI!.smtpPort = int.tryParse(_smtpPortCtrl.text.trim()) ?? 587;
      _configTI!.smtpUser = _smtpUserCtrl.text.trim();
      if (_smtpPasswordCtrl.text.trim().isNotEmpty) {
        _configTI!.smtpPassword = _smtpPasswordCtrl.text.trim();
      }
      _configTI!.smtpFrom = _smtpFromCtrl.text.trim();

      final api = Provider.of<ApiService>(context, listen: false);
      final updated = await api.updateConfigTI(_configTI!.toJson());
      if (mounted) {
        setState(() {
          _configTI = updated;
          _isSavingConfigTI = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Configurações da TI salvas com sucesso!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingConfigTI = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    }
  }

  // --- Diálogo: Testar Envio de E-mail SMTP ---
  Future<void> _openTestEmailDialog() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final defaultDest = auth.user?.email ?? _smtpFromCtrl.text.trim();
    final destCtrl = TextEditingController(text: defaultDest);
    bool isTesting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.mark_email_read_outlined, color: Colors.amber, size: 22),
                ),
                const SizedBox(width: 12),
                const Text('Testar Conexão SMTP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dispara um e-mail de teste para validar se o servidor SMTP, porta, credenciais e TLS estão funcionando corretamente.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: destCtrl,
                    decoration: InputDecoration(
                      labelText: 'E-mail de Destino do Teste *',
                      hintText: 'ex: seu.email@fab.mil.br',
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  if (isTesting) ...[
                    const SizedBox(height: 18),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Conectando e enviando e-mail de teste...', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isTesting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Disparar Teste', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: isTesting
                    ? null
                    : () async {
                        final email = destCtrl.text.trim();
                        if (email.isEmpty || !email.contains('@')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Informe um e-mail de teste válido.'), backgroundColor: Colors.orange),
                          );
                          return;
                        }

                        setModalState(() => isTesting = true);
                        try {
                          final api = Provider.of<ApiService>(context, listen: false);
                          final res = await api.testarEmail(
                            destinatario: email,
                            smtpHost: _smtpHostCtrl.text.trim(),
                            smtpPort: int.tryParse(_smtpPortCtrl.text.trim()) ?? 587,
                            smtpUser: _smtpUserCtrl.text.trim(),
                            smtpPassword: _smtpPasswordCtrl.text.trim(),
                            smtpFrom: _smtpFromCtrl.text.trim(),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            final sucesso = res['sucesso'] == true;
                            showDialog(
                              context: context,
                              builder: (dCtx) => AlertDialog(
                                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: Row(
                                  children: [
                                    Icon(sucesso ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                        color: sucesso ? AppColors.success : AppColors.danger, size: 24),
                                    const SizedBox(width: 10),
                                    Text(sucesso ? 'Teste com Sucesso!' : 'Falha no Teste SMTP'),
                                  ],
                                ),
                                content: Text(res['mensagem']?.toString() ?? ''),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dCtx),
                                    child: const Text('Fechar'),
                                  ),
                                ],
                              ),
                            );
                          }
                        } catch (e) {
                          setModalState(() => isTesting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.danger),
                            );
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Diálogo: Disparar Comunicado / E-mail para Usuários Selecionados ---
  Future<void> _openSendEmailDialog({UserModel? preselectedUser}) async {
    final assuntoCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    final emailsExtrasCtrl = TextEditingController();
    final selectedUserIds = <int>{};

    if (preselectedUser != null) {
      selectedUserIds.add(preselectedUser.id);
    } else {
      for (final u in _users) {
        if (u.hasEmail) selectedUserIds.add(u.id);
      }
    }

    bool isSending = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final usersWithEmailCount = _users.where((u) => u.hasEmail).length;

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.forward_to_inbox_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Text('Disparar Comunicado por E-mail', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 650,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selecione os usuários cadastrados que devem receber este comunicado oficial por e-mail.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    // Assunto
                    TextFormField(
                      controller: assuntoCtrl,
                      decoration: InputDecoration(
                        labelText: 'Assunto do E-mail *',
                        hintText: 'Ex: Convocação para Reunião da TI / Aviso de Manutenção',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Mensagem
                    TextFormField(
                      controller: msgCtrl,
                      minLines: 4,
                      maxLines: 7,
                      decoration: InputDecoration(
                        labelText: 'Mensagem / Corpo do E-mail *',
                        hintText: 'Digite o texto do comunicado institucional que será enviado aos militares...',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Destinatários Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Destinatários (${selectedUserIds.length} selecionados / $usersWithEmailCount com e-mail)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  for (final u in _users) {
                                    if (u.hasEmail) selectedUserIds.add(u.id);
                                  }
                                });
                              },
                              child: const Text('Marcar Todos', style: TextStyle(fontSize: 12)),
                            ),
                            TextButton(
                              onPressed: () {
                                setModalState(() => selectedUserIds.clear());
                              },
                              child: const Text('Limpar', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Lista de Usuários
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                      ),
                      child: ListView.separated(
                        itemCount: _users.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.grey[900]! : Colors.grey[200]!),
                        itemBuilder: (context, idx) {
                          final u = _users[idx];
                          final hasMail = u.hasEmail;
                          final isSelected = selectedUserIds.contains(u.id);

                          return CheckboxListTile(
                            dense: true,
                            enabled: hasMail,
                            value: isSelected,
                            activeColor: AppColors.primary,
                            checkColor: Colors.black,
                            title: Row(
                              children: [
                                Text(u.displayName, style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: hasMail ? null : Colors.grey,
                                )),
                                const SizedBox(width: 8),
                                if (u.admin)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('ADMIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              hasMail ? '✉️ ${u.email}' : '❌ Sem e-mail cadastrado',
                              style: TextStyle(
                                fontSize: 11,
                                color: hasMail ? (isDark ? Colors.grey[400] : Colors.grey[700]) : Colors.red[300],
                              ),
                            ),
                            onChanged: hasMail
                                ? (val) {
                                    setModalState(() {
                                      if (val == true) {
                                        selectedUserIds.add(u.id);
                                      } else {
                                        selectedUserIds.remove(u.id);
                                      }
                                    });
                                  }
                                : null,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // E-mails extras opcionais
                    TextFormField(
                      controller: emailsExtrasCtrl,
                      decoration: InputDecoration(
                        labelText: 'Outros E-mails Adicionais (opcional)',
                        hintText: 'Separe múltiplos e-mails por vírgula (ex: chefe@fab.mil.br, ti@binfae.fab.mil.br)',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),

                    if (isSending) ...[
                      const SizedBox(height: 18),
                      const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('Disparando e-mails para os destinatários...', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSending ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  'Enviar (${selectedUserIds.length} destinatários)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: isSending
                    ? null
                    : () async {
                        final assunto = assuntoCtrl.text.trim();
                        final msg = msgCtrl.text.trim();
                        if (assunto.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Informe o assunto do e-mail.'), backgroundColor: Colors.orange),
                          );
                          return;
                        }
                        if (msg.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Informe a mensagem do e-mail.'), backgroundColor: Colors.orange),
                          );
                          return;
                        }

                        final extras = emailsExtrasCtrl.text
                            .split(RegExp(r'[,;]'))
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty && e.contains('@'))
                            .toList();

                        if (selectedUserIds.isEmpty && extras.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Selecione pelo menos um usuário ou insira um e-mail adicional.'), backgroundColor: Colors.orange),
                          );
                          return;
                        }

                        setModalState(() => isSending = true);
                        try {
                          final api = Provider.of<ApiService>(context, listen: false);
                          final res = await api.enviarEmailUsuarios(
                            assunto: assunto,
                            mensagem: msg,
                            usuarioIds: selectedUserIds.toList(),
                            emailsAdicionais: extras,
                            smtpHost: _smtpHostCtrl.text.trim(),
                            smtpPort: int.tryParse(_smtpPortCtrl.text.trim()) ?? 465,
                            smtpUser: _smtpUserCtrl.text.trim(),
                            smtpPassword: _smtpPasswordCtrl.text.trim(),
                            smtpFrom: _smtpFromCtrl.text.trim(),
                          );

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            final total = res['total_enviados'] ?? 0;
                            final isSuccess = res['sucesso'] == true && total > 0;
                            final listDest = (res['destinatarios'] as List?)?.join(', ') ?? '';
                            final msgStatus = res['mensagem'] as String? ?? '';

                            showDialog(
                              context: context,
                              builder: (dCtx) => AlertDialog(
                                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: Row(
                                  children: [
                                    Icon(
                                      isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                      color: isSuccess ? AppColors.success : AppColors.danger,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(isSuccess ? 'E-mails Disparados com Sucesso!' : 'Falha no Envio de E-mails'),
                                  ],
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(isSuccess
                                        ? 'Total de mensagens entregues: $total'
                                        : 'Nenhum e-mail pôde ser entregue.'),
                                    if (msgStatus.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isSuccess ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          msgStatus,
                                          style: TextStyle(fontSize: 12, color: isSuccess ? Colors.green : Colors.redAccent),
                                        ),
                                      ),
                                    ],
                                    if (listDest.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text('Destinatários: $listDest', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                    if (!isSuccess) ...[
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Dica: Acesse a aba "Configurações da TI", preencha o Servidor SMTP (Host, Porta, Usuário e Senha de Aplicativo), salve e use o botão "Testar Conexão".',
                                        style: TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dCtx),
                                    child: const Text('Fechar'),
                                  ),
                                ],
                              ),
                            );
                          }
                        } catch (e) {
                          setModalState(() => isSending = false);
                          if (mounted) {
                            showDialog(
                              context: context,
                              builder: (dCtx) => AlertDialog(
                                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: const Row(
                                  children: [
                                    Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 24),
                                    SizedBox(width: 10),
                                    Text('Erro no Envio de E-mail'),
                                  ],
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.toString().replaceAll('Exception: ', ''),
                                      style: const TextStyle(fontSize: 13, color: Colors.redAccent),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Acesse a aba "Configurações da TI", configure as credenciais do Servidor SMTP (Host, Usuário e Senha de Aplicativo), clique em "Salvar" e faça o teste com o botão "Testar Conexão".',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dCtx),
                                    child: const Text('Entendi'),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Diálogo: Criar Usuário ---
  void _openCreateUserDialog() {
    int? selectedSaram;
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final fotoUrlController = TextEditingController();
    final militarySearchController = TextEditingController();
    String militarySearchQuery = '';
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
                width: 520,
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
                        if (selectedSaram != null) ...[
                          Builder(
                            builder: (context) {
                              final sel = _militaries.firstWhere(
                                (m) => m.saram == selectedSaram,
                                orElse: () => MilitaryModel(
                                  saram: selectedSaram!,
                                  nomeCompleto: '',
                                  nomeGuerra: '',
                                  postoGraduacao: '',
                                ),
                              );
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${sel.postoGraduacao} ${sel.nomeGuerra} (SARAM: ${sel.saram})',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          Text(
                                            '${sel.nomeCompleto}${sel.secao != null && sel.secao!.isNotEmpty ? " • Seção: ${sel.secao}" : ""}',
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 16),
                                      tooltip: 'Limpar seleção',
                                      onPressed: () => setModalState(() => selectedSaram = null),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                        TextField(
                          controller: militarySearchController,
                          decoration: InputDecoration(
                            hintText: 'Buscar por guerra, nome, SARAM ou seção...',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: militarySearchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      militarySearchController.clear();
                                      setModalState(() => militarySearchQuery = '');
                                    },
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onChanged: (val) => setModalState(() => militarySearchQuery = val.trim().toLowerCase()),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 230,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.cardBorder),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Builder(
                              builder: (context) {
                                final filtered = _militaries.where((m) {
                                  if (militarySearchQuery.isEmpty) return true;
                                  final g = m.nomeGuerra.toLowerCase();
                                  final c = m.nomeCompleto.toLowerCase();
                                  final s = m.saram.toString();
                                  final sec = (m.secao ?? '').toLowerCase();
                                  return g.contains(militarySearchQuery) ||
                                      c.contains(militarySearchQuery) ||
                                      s.contains(militarySearchQuery) ||
                                      sec.contains(militarySearchQuery);
                                }).toList();

                                if (filtered.isEmpty) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        'Nenhum militar encontrado',
                                        style: TextStyle(color: Colors.grey, fontSize: 13),
                                      ),
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final m = filtered[index];
                                    final isSelected = selectedSaram == m.saram;
                                    return ListTile(
                                      dense: true,
                                      selected: isSelected,
                                      selectedTileColor: AppColors.primary.withOpacity(0.1),
                                      leading: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: isSelected ? AppColors.primary : AppColors.sidebarBackground,
                                        child: Text(
                                          m.postoGraduacao,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Colors.white : AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        '${m.postoGraduacao} ${m.nomeGuerra}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isSelected ? AppColors.primary : null,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${m.nomeCompleto} • SARAM: ${m.saram}${m.secao != null && m.secao!.isNotEmpty ? " • ${m.secao}" : ""}',
                                        style: const TextStyle(fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: isSelected
                                          ? const Icon(Icons.check_circle, color: AppColors.primary, size: 18)
                                          : const Icon(Icons.radio_button_unchecked, size: 18, color: Colors.grey),
                                      onTap: () => setModalState(() => selectedSaram = m.saram),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Builder(
                          builder: (context) {
                            final filteredCount = _militaries.where((m) {
                              if (militarySearchQuery.isEmpty) return true;
                              final g = m.nomeGuerra.toLowerCase();
                              final c = m.nomeCompleto.toLowerCase();
                              final s = m.saram.toString();
                              final sec = (m.secao ?? '').toLowerCase();
                              return g.contains(militarySearchQuery) ||
                                  c.contains(militarySearchQuery) ||
                                  s.contains(militarySearchQuery) ||
                                  sec.contains(militarySearchQuery);
                            }).length;
                            return Text(
                              '$filteredCount militares listados • Clique para selecionar',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            );
                          },
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

                      TextField(
                        controller: fotoUrlController,
                        decoration: InputDecoration(
                          labelText: 'URL da Foto / Avatar (opcional)',
                          hintText: 'https://.../foto.jpg ou use o botão ao lado',
                          prefixIcon: const Icon(Icons.link, size: 18),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add_a_photo_outlined, size: 18, color: AppColors.cyan),
                            tooltip: 'Carregar e ajustar foto do computador',
                            onPressed: () async {
                              final bytes = await ImagePickerHelper.pickImageBytes();
                              if (bytes != null && setModalState != null) {
                                final cropped = await showDialog<String>(
                                  context: context,
                                  builder: (_) => AvatarEditorDialog(imageBytes: bytes),
                                );
                                if (cropped != null) {
                                  setModalState(() {
                                    fotoUrlController.text = cropped;
                                  });
                                }
                              }
                            },
                          ),
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
                              fotoUrl: fotoUrlController.text.trim().isNotEmpty ? fotoUrlController.text.trim() : null,
                            );
                            if (mounted) {
                              Navigator.pop(ctx);
                              _loadUsers();
                              _loadMilitaries();
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
    final usernameController = TextEditingController(text: user.username);
    final passwordController = TextEditingController();
    final fotoUrlController = TextEditingController(text: user.fotoUrl ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final identifier = user.militar?.saram ?? (user.username.isNotEmpty ? user.username : user.id);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Editar Usuário: ${user.displayName}'),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome de Usuário (Username)',
                        hintText: 'Ex: admin.ti, lucas.silva...',
                        prefixIcon: Icon(Icons.alternate_email, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: fotoUrlController,
                      decoration: InputDecoration(
                        labelText: 'URL da Foto / Avatar',
                        hintText: 'https://.../foto.jpg ou use o botão ao lado',
                        prefixIcon: const Icon(Icons.link, size: 18),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add_a_photo_outlined, size: 18, color: AppColors.cyan),
                          tooltip: 'Carregar e ajustar foto do computador',
                          onPressed: () async {
                            final bytes = await ImagePickerHelper.pickImageBytes();
                            if (bytes != null && setModalState != null) {
                              final cropped = await showDialog<String>(
                                context: context,
                                builder: (_) => AvatarEditorDialog(
                                  imageBytes: bytes,
                                  userName: user.displayName,
                                ),
                              );
                              if (cropped != null) {
                                setModalState(() {
                                  fotoUrlController.text = cropped;
                                });
                              }
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: isSubmitting
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              _confirmDeleteUser(user);
                            },
                      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Excluir Conta'),
                    ),
                    Row(
                      children: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    final api = Provider.of<ApiService>(context, listen: false);
                                    final newUsername = usernameController.text.trim();
                                    await api.updateUser(
                                      identifier,
                                      username: newUsername.isNotEmpty ? newUsername : null,
                                      admin: isAdmin,
                                      ativo: isAtivo,
                                      password: passwordController.text.trim().isNotEmpty ? passwordController.text.trim() : null,
                                      fotoUrl: fotoUrlController.text.trim(),
                                    );
                                    if (mounted) {
                                      Navigator.pop(ctx);
                                      _loadUsers();
                                      _loadMilitaries();
                                      try {
                                        final auth = Provider.of<AuthProvider>(context, listen: false);
                                        if (auth.user?.id == user.id) {
                                          auth.refreshUser();
                                        }
                                      } catch (_) {}
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(backgroundColor: AppColors.success, content: Text('Usuário atualizado com sucesso!')),
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
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Confirmação e Exclusão de Usuário ---
  Future<void> _confirmDeleteUser(UserModel user) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final identifier = user.militar?.saram ?? (user.username.isNotEmpty ? user.username : user.id);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151D2F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
            SizedBox(width: 10),
            Text('Excluir Conta de Usuário', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deseja realmente excluir permanentemente a conta de acesso de "${user.displayName}"?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.danger.withOpacity(0.3)),
              ),
              child: Text(
                user.militar != null
                    ? 'O militar ${user.militar!.nomeGuerra} continuará cadastrado no efetivo militar, mas sua conta de login e permissões serão removidas.'
                    : 'A conta de administrador @${user.username} será completamente removida do sistema.',
                style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Excluir Usuário'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final api = Provider.of<ApiService>(context, listen: false);
        await api.deleteUser(identifier);
        if (mounted) {
          _loadUsers();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.success,
              content: Text('Conta de usuário excluída com sucesso!'),
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
      }
    }
  }

  // --- Diálogo: Cadastrar / Editar Militar ---
  void _openMilitaryDialog([MilitaryModel? military]) {
    final saramController = TextEditingController(text: military != null ? military.saram.toString() : '');
    final nomeCompletoController = TextEditingController(text: military?.nomeCompleto ?? '');
    final nomeGuerraController = TextEditingController(text: military?.nomeGuerra ?? '');
    final secaoController = TextEditingController(text: military?.secao ?? '');
    final emailController = TextEditingController(
      text: military != null
          ? (military.emails.isNotEmpty ? military.emails.join(', ') : (military.email ?? ''))
          : '',
    );
    final celularController = TextEditingController(text: military?.celular ?? '');
    final fotoUrlController = TextEditingController(text: military?.fotoUrl ?? '');
    String posto = military?.postoGraduacao ?? 'S2';
    bool isInformatica = military?.isInformatica ?? (military?.secao?.toLowerCase().contains('inform') ?? false);

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
                              onChanged: (val) => setModalState(() => posto = val ?? 'S2'),
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
                                labelText: 'E-mails (separe por vírgula)',
                                hintText: 'Ex: oficial@fab.mil.br, pessoal@gmail.com',
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
                      const SizedBox(height: 8),

                      SwitchListTile(
                        title: const Text('Militar da Seção de Informática (Elegível para Escala)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Permite ser escalado de sobreaviso ou expediente na TI', style: TextStyle(fontSize: 11)),
                        value: isInformatica,
                        activeColor: AppColors.primary,
                        onChanged: (v) => setModalState(() => isInformatica = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: fotoUrlController,
                        decoration: InputDecoration(
                          labelText: 'URL da Foto / Avatar',
                          hintText: 'https://.../foto.jpg ou use o botão ao lado',
                          prefixIcon: const Icon(Icons.link, size: 18),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add_a_photo_outlined, size: 18, color: AppColors.cyan),
                            tooltip: 'Carregar e ajustar foto do computador',
                            onPressed: () async {
                              final bytes = await ImagePickerHelper.pickImageBytes();
                              if (bytes != null && setModalState != null) {
                                final cropped = await showDialog<String>(
                                  context: context,
                                  builder: (_) => AvatarEditorDialog(
                                    imageBytes: bytes,
                                    userName: military?.nomeGuerra,
                                    postoGraduacao: military?.postoGraduacao,
                                  ),
                                );
                                if (cropped != null) {
                                  setModalState(() {
                                    fotoUrlController.text = cropped;
                                  });
                                }
                              }
                            },
                          ),
                        ),
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

                          final rawEmails = emailController.text
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList();
                          final primaryEmail = rawEmails.isNotEmpty ? rawEmails.first : null;

                          setModalState(() => isSubmitting = true);
                          final data = <String, dynamic>{
                            'saram': saram,
                            'posto_graduacao': posto,
                            'nome_guerra': nomeGuerraController.text.trim(),
                            'nome_completo': nomeCompletoController.text.trim(),
                            'secao': secaoController.text.trim().isEmpty ? null : secaoController.text.trim(),
                            'email': primaryEmail,
                            'emails': rawEmails,
                            'celular': celularController.text.trim().isEmpty ? null : celularController.text.trim(),
                            'foto_url': fotoUrlController.text.trim().isEmpty ? null : fotoUrlController.text.trim(),
                            'is_informatica': isInformatica,
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
                              _loadUsers();
                              try {
                                final auth = Provider.of<AuthProvider>(context, listen: false);
                                if (auth.user?.militarId == military?.id || auth.user?.militar?.saram == military?.saram) {
                                  auth.refreshUser();
                                }
                              } catch (_) {}
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
                  Tab(icon: Icon(Icons.settings_suggest_outlined, size: 18), text: 'Chefia & Notificações TI'),
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
                _buildConfigTITab(isDark),
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
            Row(
              children: [
                Text(
                  '${_users.length} contas cadastradas',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: 'Atualizar Lista de Usuários',
                  onPressed: _isLoadingUsers ? null : _loadUsers,
                ),
              ],
            ),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openSendEmailDialog(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                  label: const Text('Enviar Comunicado', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
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
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _isLoadingUsers
              ? const Center(child: CircularProgressIndicator())
              : _userError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off_rounded, size: 48, color: Colors.orange[400]),
                            const SizedBox(height: 12),
                            const Text(
                              'Não foi possível carregar a lista de usuários',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _userError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadUsers,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Tentar Novamente', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
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
                          itemCount: _users.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF1F293D) : const Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final u = _users[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Row(
                                children: [
                                  UserAvatar(
                                    fotoUrl: u.fotoUrl,
                                    name: u.displayName,
                                    radius: 18,
                                    iconSize: 18,
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
                                        if (u.hasEmail) ...[
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(Icons.email_outlined, size: 12, color: AppColors.primary.withOpacity(0.8)),
                                              const SizedBox(width: 4),
                                              Text(
                                                u.email!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
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
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(
                                      Icons.mail_outline_rounded,
                                      size: 18,
                                      color: u.hasEmail ? AppColors.primary : Colors.grey.withOpacity(0.4),
                                    ),
                                    tooltip: u.hasEmail
                                        ? 'Enviar e-mail para ${u.displayName}'
                                        : 'Usuário sem e-mail cadastrado',
                                    onPressed: u.hasEmail ? () => _openSendEmailDialog(preselectedUser: u) : null,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    tooltip: 'Editar Usuário e Permissões',
                                    onPressed: () => _openEditUserDialog(u),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    tooltip: 'Excluir Usuário',
                                    color: AppColors.danger.withOpacity(0.85),
                                    onPressed: () => _confirmDeleteUser(u),
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
            Row(
              children: [
                Text(
                  '${_militaries.length} militares no efetivo',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: 'Atualizar Lista de Militares',
                  onPressed: _isLoadingMilitaries ? null : _loadMilitaries,
                ),
              ],
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
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off_rounded, size: 48, color: Colors.orange[400]),
                            const SizedBox(height: 12),
                            const Text(
                              'Não foi possível carregar a lista de militares',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _militaryError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadMilitaries,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Tentar Novamente', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
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
                                  const SizedBox(width: 14),
                                  UserAvatar(
                                    fotoUrl: m.fotoUrl,
                                    name: m.nomeGuerra,
                                    radius: 16,
                                    iconSize: 16,
                                  ),
                                  const SizedBox(width: 14),
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

  Widget _buildConfigTITab(bool isDark) {
    if (_isLoadingConfigTI) {
      return const Center(child: CircularProgressIndicator());
    }

    final cfg = _configTI ?? InformaticaConfigModel(id: 1);

    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.only(top: 8, bottom: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161E2E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Servidor SMTP & E-mail
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.mark_email_read_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Servidor de E-mail (SMTP)',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Configurações para envio do Relatório Diário e Comunicados',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.network_check_rounded, size: 18),
                        label: const Text('Testar Conexão'),
                        onPressed: _openTestEmailDialog,
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Enviar Comunicado', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => _openSendEmailDialog(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Host do Servidor SMTP *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _smtpHostCtrl,
                          decoration: InputDecoration(
                            hintText: 'ex: smtp.gmail.com ou mail.fab.mil.br',
                            prefixIcon: const Icon(Icons.dns_outlined, size: 18),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Porta *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _smtpPortCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '587 ou 465',
                            prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Usuário / E-mail de Autenticação', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _smtpUserCtrl,
                          decoration: InputDecoration(
                            hintText: 'ex: informatica.binfae@gmail.com',
                            prefixIcon: const Icon(Icons.account_circle_outlined, size: 18),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Remetente (From Header)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _smtpFromCtrl,
                          decoration: InputDecoration(
                            hintText: 'ex: informatica.binfae@gmail.com',
                            prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Senha SMTP / Senha de App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _smtpPasswordCtrl,
                    obscureText: _obscureSmtpPassword,
                    decoration: InputDecoration(
                      hintText: 'Senha de aplicativo ou do servidor de e-mail',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureSmtpPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                        onPressed: () => setState(() => _obscureSmtpPassword = !_obscureSmtpPassword),
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.security_rounded, color: Colors.blue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chefia da Seção de Informática & Destinatários',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Configuração dos 2 militares mais antigos que recebem cópia do relatório diário',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              const Divider(height: 32),

              // 1º Militar mais antigo
              const Text('1º Militar Mais Antigo da Seção de TI *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int?>(
                value: cfg.militarAntigo1Id,
                decoration: InputDecoration(
                  hintText: 'Selecione o 1º militar mais antigo...',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('(Nenhum selecionado)')),
                  ..._militaries.map((m) => DropdownMenuItem<int?>(
                        value: m.id ?? m.saram,
                        child: Text('${m.postoGraduacao} ${m.nomeGuerra} (SARAM: ${m.saram})'),
                      )),
                ],
                onChanged: (id) => setState(() => cfg.militarAntigo1Id = id),
              ),
              const SizedBox(height: 18),

              // 2º Militar mais antigo
              const Text('2º Militar Mais Antigo da Seção de TI *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int?>(
                value: cfg.militarAntigo2Id,
                decoration: InputDecoration(
                  hintText: 'Selecione o 2º militar mais antigo...',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('(Nenhum selecionado)')),
                  ..._militaries.map((m) => DropdownMenuItem<int?>(
                        value: m.id ?? m.saram,
                        child: Text('${m.postoGraduacao} ${m.nomeGuerra} (SARAM: ${m.saram})'),
                      )),
                ],
                onChanged: (id) => setState(() => cfg.militarAntigo2Id = id),
              ),
              const Divider(height: 32),

              // Canais de Notificação
              const Text('Canais de Disparo do Relatório Diário 24h',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),

              SwitchListTile(
                title: const Text('Disparo Automático por E-mail',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text(
                    'Envia o relatório diário das últimas 24h para o militar de serviço e os 2 chefes ao clicar em "Lançar Relatório"',
                    style: TextStyle(fontSize: 12)),
                value: cfg.notificarEmailAtivo,
                activeColor: Colors.blue,
                onChanged: (v) => setState(() => cfg.notificarEmailAtivo = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),

              SwitchListTile(
                title: const Text('Disparo via WhatsApp (Integração Futura)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text(
                    'Prepara a rota para envio automático de cópia do relatório no grupo de WhatsApp da Informática',
                    style: TextStyle(fontSize: 12)),
                value: cfg.notificarWhatsappAtivo,
                activeColor: Colors.green,
                onChanged: (v) => setState(() => cfg.notificarWhatsappAtivo = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),

              // Botão Salvar
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isSavingConfigTI
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded, size: 20),
                  label: const Text('Salvar Configurações da TI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  onPressed: _isSavingConfigTI ? null : _saveConfigTI,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
