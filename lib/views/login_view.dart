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

    final zuluNow = DateTime.now().toUtc();
    final zuluFormatted = "${zuluNow.hour.toString().padLeft(2, '0')}:${zuluNow.minute.toString().padLeft(2, '0')}:${zuluNow.second.toString().padLeft(2, '0')} Z";

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // Luzes de ambiente sutis táticas (Stitch Atmospheric Gradients)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 480,
              height: 480,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryContainer.withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.tertiary.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Centro com Cartão Tático de Login (Google Stitch Design)
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Container(
                width: 490,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 32,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Operational Telemetry Ribbon
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.tertiary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.tertiary,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'DEFCON 4 // RESTRITO',
                                      style: TextStyle(
                                        fontFamily: 'JetBrains Mono',
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.tertiary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'TERMINAL-GL-7740',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 10,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.schedule, size: 14, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                zuluFormatted,
                                style: const TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurfaceVariant,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Main Card Interior Body
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Telemetry Status Pill & Health Check
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _serverOnline == true
                                            ? AppColors.tertiary
                                            : (_serverOnline == false ? AppColors.error : AppColors.warning),
                                        boxShadow: _serverOnline == true
                                            ? [
                                                BoxShadow(
                                                  color: AppColors.tertiary.withOpacity(0.6),
                                                  blurRadius: 6,
                                                  spreadRadius: 1,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Text(
                                              'BACKEND NUVEM: ',
                                              style: TextStyle(
                                                fontFamily: 'JetBrains Mono',
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.onSurface,
                                              ),
                                            ),
                                            Text(
                                              _serverOnline == true ? 'ONLINE' : (_serverOnline == false ? 'OFFLINE' : 'VERIFICANDO...'),
                                              style: TextStyle(
                                                fontFamily: 'JetBrains Mono',
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: _serverOnline == true ? AppColors.tertiary : AppColors.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          _isPinging
                                              ? 'Testando conexão...'
                                              : 'Latência: ${_latencyMs ?? 24}ms • Galeão HUB',
                                          style: const TextStyle(
                                            fontFamily: 'JetBrains Mono',
                                            fontSize: 10,
                                            color: AppColors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                InkWell(
                                  onTap: () => _checkServer(showFeedback: true),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        _isPinging
                                            ? const SizedBox(
                                                width: 12,
                                                height: 12,
                                                child: CircularProgressIndicator(strokeWidth: 1.8, color: AppColors.primary),
                                              )
                                            : const Icon(Icons.sync_rounded, size: 14, color: AppColors.primary),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'Testar API',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'JetBrains Mono',
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Heraldry & Header
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLowest,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.primaryContainer.withOpacity(0.4), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryContainer.withOpacity(0.2),
                                      blurRadius: 18,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(Icons.military_tech_rounded, color: AppColors.primary, size: 40),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.shield_rounded, color: Colors.white, size: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'BINFAE-GL',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const Text(
                            'SEÇÃO DE INFORMÁTICA // ALA 11',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Sistema Integrado de Gestão Tática e Patrimônio de TI • Base Aérea do Galeão',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 22),

                          // Banner de Erro Inline (se houver)
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: AppColors.errorContainer.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.error.withOpacity(0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(fontSize: 12, color: AppColors.error),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => setState(() => _errorMessage = null),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Campo SARAM / Login
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SARAM / LOGIN DE REDE FAB',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurfaceVariant,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 5),
                              TextField(
                                controller: _userController,
                                focusNode: _userFocus,
                                textInputAction: TextInputAction.next,
                                style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, color: AppColors.onSurface),
                                decoration: InputDecoration(
                                  hintText: 'Ex: 7891234 ou usuario.silva',
                                  prefixIcon: const Icon(Icons.badge_outlined, size: 18, color: AppColors.outline),
                                  suffixIcon: _userController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.cancel_rounded, size: 16, color: AppColors.outline),
                                          onPressed: () {
                                            _userController.clear();
                                            setState(() {});
                                          },
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: AppColors.surfaceContainerLowest,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: AppColors.outlineVariant),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: AppColors.outlineVariant),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Campo Senha
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SENHA DE ACESSO TÁTICO',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurfaceVariant,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 5),
                              TextField(
                                controller: _passController,
                                focusNode: _passFocus,
                                obscureText: _obscurePassword,
                                onSubmitted: (_) => _handleLogin(),
                                style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, color: AppColors.onSurface),
                                decoration: InputDecoration(
                                  hintText: '••••••••••••',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      size: 18,
                                      color: AppColors.outline,
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                  filled: true,
                                  fillColor: AppColors.surfaceContainerLowest,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: AppColors.outlineVariant),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: AppColors.outlineVariant),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Lembrar no Terminal
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () => setState(() => _rememberMe = !_rememberMe),
                                borderRadius: BorderRadius.circular(6),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _rememberMe,
                                      activeColor: AppColors.primaryContainer,
                                      onChanged: (val) => setState(() => _rememberMe = val ?? false),
                                    ),
                                    const Text(
                                      'Lembrar neste terminal',
                                      style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Contate o Administrador da Seção de TI pelo ramal 2411 para redefinição.'),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Esqueci as credenciais',
                                  style: TextStyle(fontSize: 12, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Botão Principal Acessar Sistema
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: auth.isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryContainer,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 2,
                              ),
                              icon: auth.isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.login_rounded, size: 20),
                              label: Text(
                                auth.isLoading ? 'Autenticando credenciais...' : 'Acessar Sistema',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Botão de Proxy Corporativo
                          InkWell(
                            onTap: _showProxyConfigDialog,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    apiService.proxyEnabled ? Icons.vpn_lock_rounded : Icons.dns_outlined,
                                    size: 16,
                                    color: apiService.proxyEnabled ? AppColors.tertiary : AppColors.outline,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    apiService.proxyEnabled
                                        ? 'Proxy Ativo (${apiService.proxyHost}:${apiService.proxyPort})'
                                        : 'Configurar Servidor Proxy da Rede FAB',
                                    style: TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: apiService.proxyEnabled ? AppColors.tertiary : AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Military Compliance Footer
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
                      ),
                      child: const Column(
                        children: [
                          Text(
                            'USO EXCLUSIVO EM SERVIÇO ATIVO DA FORÇA AÉREA BRASILEIRA • TERMINAL MONITORADO',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: AppColors.outline,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'VERSÃO DESKTOP 2.4.0 • SEÇÃO-TI-BAGL',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 9,
                              color: AppColors.outlineVariant,
                            ),
                          ),
                        ],
                      ),
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
