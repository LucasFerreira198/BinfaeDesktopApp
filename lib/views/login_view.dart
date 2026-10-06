import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/updater_service.dart';
import '../theme/app_theme.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final FocusNode _userFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();

  bool _obscurePassword = true;
  bool? _serverOnline;
  int? _latencyMs;
  bool _isPinging = false;
  bool _rememberMe = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPreferencesAndCheckServer();
  }

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _loadPreferencesAndCheckServer() async {
    final apiService = Provider.of<ApiService>(context, listen: false);

    // Carrega último nome de usuário e preferência de "lembrar"
    final savedUser = await apiService.getSavedUsername();
    final savedRemember = await apiService.getSavedRememberMePreference();

    if (mounted) {
      setState(() {
        _rememberMe = savedRemember;
        if (savedUser != null && savedUser.isNotEmpty) {
          _userController.text = savedUser;
        }
      });
      // Se já houver usuário preenchido, foca na senha; caso contrário, foca no usuário
      if (savedUser != null && savedUser.isNotEmpty) {
        _passFocus.requestFocus();
      } else {
        _userFocus.requestFocus();
      }
    }

    await _checkServer();
  }

  Future<void> _checkServer({bool showFeedback = false}) async {
    if (_isPinging) return;
    setState(() => _isPinging = true);

    final apiService = Provider.of<ApiService>(context, listen: false);
    final stopwatch = Stopwatch()..start();
    final online = await apiService.checkHealth();
    stopwatch.stop();

    if (mounted) {
      setState(() {
        _serverOnline = online;
        _latencyMs = stopwatch.elapsedMilliseconds;
        _isPinging = false;
      });

      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: online ? AppColors.success : AppColors.danger,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            content: Row(
              children: [
                Icon(online ? Icons.check_circle : Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  online
                      ? 'Servidor Vercel SP conectado (${stopwatch.elapsedMilliseconds} ms)'
                      : 'Servidor inacessível. Verifique sua conexão ou proxy.',
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleLogin() async {
    final user = _userController.text.trim();
    final pass = _passController.text;

    if (user.isEmpty || pass.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, informe seu SARAM/usuário e a senha.';
      });
      return;
    }

    setState(() => _errorMessage = null);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.login(user, pass, rememberMe: _rememberMe);

    if (!success && mounted) {
      setState(() {
        _errorMessage = auth.errorMessage ?? 'Falha ao autenticar. Verifique suas credenciais.';
      });
    }
  }

  void _showProxyConfigDialog() {
    final apiService = Provider.of<ApiService>(context, listen: false);

    bool enabled = apiService.proxyEnabled;
    final hostController = TextEditingController(text: apiService.proxyHost);
    final portController = TextEditingController(
      text: apiService.proxyPort > 0 ? apiService.proxyPort.toString() : '8080',
    );
    final userController = TextEditingController(text: apiService.proxyUsername);
    final passController = TextEditingController(text: apiService.proxyPassword);
    bool bypassSsl = apiService.proxyBypassSsl;
    bool obscurePassword = true;

    bool isTesting = false;
    String? testResult;
    bool? testSuccess;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.settings_ethernet_rounded, color: AppColors.primaryLight, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Configurações de Proxy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('Rede Corporativa / Militar Autenticada', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Switch para Usar ou Não o Proxy
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: enabled
                              ? AppColors.primary.withOpacity(0.12)
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: enabled
                                ? AppColors.primary
                                : (isDark ? const Color(0xFF2E3D5B) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  enabled ? Icons.vpn_lock_rounded : Icons.public_off_rounded,
                                  color: enabled ? AppColors.primaryLight : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Usar Servidor Proxy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    Text(
                                      enabled ? 'O tráfego passará pelo proxy corporativo' : 'Conexão direta sem proxy',
                                      style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white60 : Colors.black54),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Switch(
                              value: enabled,
                              activeColor: AppColors.primary,
                              onChanged: (val) {
                                setModalState(() {
                                  enabled = val;
                                  testResult = null;
                                  testSuccess = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Campos de Configuração do Proxy
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: enabled ? 1.0 : 0.45,
                        child: AbsorbPointer(
                          absorbing: !enabled,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Servidor Proxy (Host / IP)
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Servidor / IP do Proxy', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: hostController,
                                          style: const TextStyle(fontSize: 12.5),
                                          decoration: InputDecoration(
                                            hintText: 'proxy.galeao.intraer',
                                            prefixIcon: const Icon(Icons.dns_rounded, size: 18),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                            filled: true,
                                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Porta
                                  Expanded(
                                    flex: 1,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Porta', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: portController,
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(fontSize: 12.5),
                                          decoration: InputDecoration(
                                            hintText: '8080',
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                            filled: true,
                                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Usuário do Proxy
                              Text('Usuário da Rede / SARAM (se autenticado)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: userController,
                                style: const TextStyle(fontSize: 12.5),
                                decoration: InputDecoration(
                                  hintText: 'Ex: usuario ou dominio\\usuario',
                                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Senha do Proxy
                              Text('Senha de Acesso ao Proxy', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: passController,
                                obscureText: obscurePassword,
                                style: const TextStyle(fontSize: 12.5),
                                decoration: InputDecoration(
                                  hintText: 'Senha da rede corporativa',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      size: 18,
                                    ),
                                    onPressed: () => setModalState(() => obscurePassword = !obscurePassword),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Opção de Bypass SSL (Inspeção HTTPS de Proxy)
                              InkWell(
                                onTap: () => setModalState(() => bypassSsl = !bypassSsl),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Checkbox(
                                          value: bypassSsl,
                                          activeColor: AppColors.primary,
                                          onChanged: (v) => setModalState(() => bypassSsl = v ?? true),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Permitir inspeção SSL de Proxy (Ignora erros de certificados intermediários)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Feedback do Teste
                      if (testResult != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: testSuccess == true
                                ? AppColors.success.withOpacity(0.12)
                                : AppColors.danger.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: testSuccess == true
                                  ? AppColors.success.withOpacity(0.4)
                                  : AppColors.danger.withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                testSuccess == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                size: 18,
                                color: testSuccess == true ? AppColors.success : AppColors.danger,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  testResult!,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: testSuccess == true
                                        ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46))
                                        : (isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Botão de Testar Conexão
                      if (enabled)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isTesting
                                ? null
                                : () async {
                                    setModalState(() {
                                      isTesting = true;
                                      testResult = null;
                                      testSuccess = null;
                                    });
                                    final host = hostController.text.trim();
                                    final port = int.tryParse(portController.text.trim()) ?? 8080;
                                    final user = userController.text.trim();
                                    final pass = passController.text;

                                    if (host.isEmpty) {
                                      setModalState(() {
                                        isTesting = false;
                                        testResult = 'Informe o host/IP do servidor proxy.';
                                        testSuccess = false;
                                      });
                                      return;
                                    }

                                    try {
                                      final sw = Stopwatch()..start();
                                      final ok = await apiService.testProxy(
                                        enabled: true,
                                        host: host,
                                        port: port,
                                        username: user,
                                        password: pass,
                                        bypassSsl: bypassSsl,
                                      );
                                      sw.stop();
                                      setModalState(() {
                                        isTesting = false;
                                        if (ok) {
                                          testSuccess = true;
                                          testResult = 'Conexão via proxy bem-sucedida! (${sw.elapsedMilliseconds} ms)';
                                        } else {
                                          testSuccess = false;
                                          testResult = 'Proxy respondeu, mas a API retornou código de erro.';
                                        }
                                      });
                                    } catch (e) {
                                      setModalState(() {
                                        isTesting = false;
                                        testSuccess = false;
                                        testResult = 'Erro no proxy: $e';
                                      });
                                    }
                                  },
                            icon: isTesting
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.network_check_rounded, size: 16),
                            label: Text(isTesting ? 'Testando Conexão...' : 'Testar Conexão com o Proxy'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final host = hostController.text.trim();
                    final port = int.tryParse(portController.text.trim()) ?? 8080;
                    final user = userController.text.trim();
                    final pass = passController.text;

                    await apiService.saveProxySettings(
                      enabled: enabled,
                      host: host,
                      port: port,
                      username: user,
                      password: pass,
                      bypassSsl: bypassSsl,
                    );

                    Navigator.of(ctx).pop();
                    await _checkServer(showFeedback: true);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.success,
                          content: Text(
                            enabled
                                ? 'Configurações de proxy salvas e ativadas com sucesso!'
                                : 'Proxy desativado. Conexão direta restaurada.',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Salvar Configurações'),
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
    final auth = Provider.of<AuthProvider>(context);
    final apiService = Provider.of<ApiService>(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C14) : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // Luzes de ambiente sutis ao fundo (Glows decorativos estilo desktop)
          Positioned(
            top: -120,
            left: -100,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(isDark ? 0.18 : 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF10B981).withOpacity(isDark ? 0.12 : 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Botão de Engrenagem no canto superior direito da janela
          Positioned(
            top: 24,
            right: 24,
            child: Material(
              color: Colors.transparent,
              child: Tooltip(
                message: apiService.proxyEnabled
                    ? 'Proxy Ativo (${apiService.proxyHost}:${apiService.proxyPort}) - Clique para ajustar'
                    : 'Configurações de Proxy Corporativo',
                child: InkWell(
                  onTap: _showProxyConfigDialog,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF131D31) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: apiService.proxyEnabled
                            ? AppColors.primary
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
                        width: apiService.proxyEnabled ? 1.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.settings_outlined,
                          size: 22,
                          color: apiService.proxyEnabled
                              ? AppColors.primaryLight
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                        if (apiService.proxyEnabled)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF10B981),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF131D31) : Colors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Centro com o Cartão de Login Modernizado
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Container(
                width: 460,
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.45 : 0.08),
                      blurRadius: 36,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Botão discreto de engrenagem no canto superior direito do cartão
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Tooltip(
                        message: 'Configurações de Proxy de Rede',
                        child: InkWell(
                          onTap: _showProxyConfigDialog,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: apiService.proxyEnabled
                                  ? AppColors.primary.withOpacity(0.12)
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: apiService.proxyEnabled
                                    ? AppColors.primary
                                    : (isDark ? const Color(0xFF2E3D5B) : const Color(0xFFCBD5E1)),
                              ),
                            ),
                            child: Icon(
                              Icons.settings_outlined,
                              size: 18,
                              color: apiService.proxyEnabled
                                  ? AppColors.primaryLight
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    // Emblema Institucional Militar FAB / BINFAE
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.40),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.shield_rounded, color: Colors.white, size: 44),
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: const Icon(Icons.dns_rounded, color: Colors.white, size: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Títulos Oficiais
                    Text(
                      'FORÇA AÉREA BRASILEIRA • BINFAE-GL',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: isDark ? AppColors.primaryLight : const Color(0xFF6D28D9),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Sistema de Informática',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Gestão Integrada de Patrimônio & Cautelas',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Badge Interativa de Status da Conexão com a Nuvem
                    InkWell(
                      onTap: () => _checkServer(showFeedback: true),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A2235) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _serverOnline == true
                                ? AppColors.success.withOpacity(0.3)
                                : _serverOnline == false
                                    ? AppColors.danger.withOpacity(0.3)
                                    : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isPinging)
                              const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight),
                              )
                            else
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _serverOnline == true
                                      ? AppColors.success
                                      : _serverOnline == false
                                          ? AppColors.danger
                                          : AppColors.warning,
                                  boxShadow: _serverOnline == true
                                      ? [
                                          BoxShadow(
                                            color: AppColors.success.withOpacity(0.6),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            const SizedBox(width: 8),
                            Text(
                              _isPinging
                                  ? 'Testando conexão...'
                                  : _serverOnline == true
                                      ? 'Nuvem SP Online ${_latencyMs != null ? "($_latencyMs ms)" : ""}'
                                      : _serverOnline == false
                                          ? 'Servidor Inacessível (Toque p/ testar)'
                                          : 'Verificando Nuvem...',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _serverOnline == true
                                    ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                                    : _serverOnline == false
                                        ? AppColors.danger
                                        : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.refresh_rounded,
                              size: 13,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (apiService.proxyEnabled) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _showProxyConfigDialog,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.primary.withOpacity(0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.vpn_lock_rounded, size: 12, color: AppColors.primaryLight),
                              const SizedBox(width: 5),
                              Text(
                                'Proxy: ${apiService.proxyHost}:${apiService.proxyPort}',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.edit_outlined, size: 11, color: isDark ? Colors.white54 : Colors.black45),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),

                    // Banner de Erro Inline (se houver)
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.danger.withOpacity(0.35)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.danger,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.danger),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() => _errorMessage = null),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Campo SARAM / Usuário
                    TextField(
                      controller: _userController,
                      focusNode: _userFocus,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'SARAM ou Usuário',
                        hintText: 'Ex: 7654321 ou operador',
                        prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                        suffixIcon: _userController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _userController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF131B2E) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF243049) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF243049) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),

                    // Campo Senha
                    TextField(
                      controller: _passController,
                      focusNode: _passFocus,
                      obscureText: _obscurePassword,
                      onSubmitted: (_) => _handleLogin(),
                      decoration: InputDecoration(
                        labelText: 'Senha de Acesso',
                        hintText: 'Digite sua senha',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF131B2E) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF243049) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF243049) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // CARD DE OPÇÃO: "LEMBRAR POR 24 HORAS" (Novo recurso solicitado)
                    InkWell(
                      onTap: () {
                        setState(() => _rememberMe = !_rememberMe);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _rememberMe
                              ? (isDark ? AppColors.primary.withOpacity(0.12) : const Color(0xFFF3E8FF))
                              : (isDark ? const Color(0xFF131B2E) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _rememberMe
                                ? AppColors.primary.withOpacity(0.5)
                                : (isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: _rememberMe
                                    ? AppColors.primary.withOpacity(0.2)
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _rememberMe ? Icons.history_toggle_off_rounded : Icons.schedule_outlined,
                                size: 18,
                                color: _rememberMe ? AppColors.primaryLight : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Lembrar por 24 horas',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: _rememberMe ? AppColors.primary : const Color(0xFF64748B),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          '24H',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _rememberMe
                                        ? 'Sessão mantida ativa mesmo ao fechar o app.'
                                        : 'Ao fechar o app, o login será exigido novamente.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: _rememberMe
                                          ? (isDark ? AppColors.primaryLight : const Color(0xFF6D28D9))
                                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Transform.scale(
                              scale: 0.85,
                              child: Switch(
                                value: _rememberMe,
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  setState(() => _rememberMe = val);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Botão Principal de Login
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: auth.isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: auth.isLoading
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Autenticando credenciais...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.login_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text('Acessar Sistema', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                    SizedBox(width: 6),
                                    Icon(Icons.arrow_forward_rounded, size: 16),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Rodapé de Segurança e Versão
                    Text(
                      'Uso restrito • Base Aérea do Galeão • ${UpdaterService.currentVersion} Nativo',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
