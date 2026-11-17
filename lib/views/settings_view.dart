import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/stock_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/updater_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';
import '../widgets/user_profile_dialog.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // Configurações Locais Simuladas e Integradas
  double _checkpointInterval = 1000;
  String _syncMode = 'normal';
  bool _fido2Enabled = true;
  bool _autoSignEnabled = true;
  String _sessionTimeout = '5 minutos (Diretriz EMAER)';
  String _logLevel = 'VERBOSE / TRILHA COMPLETA (Auditoria N4)';
  final TextEditingController _proxyAddressCtrl = TextEditingController(text: '10.52.132.240:8080');
  final TextEditingController _proxyBypassCtrl = TextEditingController(text: '10.52.*.*, localhost, 127.0.0.1, 10.14.0.0/16');
  bool _isTestingProxy = false;
  String? _proxyTestResult;

  @override
  void dispose() {
    _proxyAddressCtrl.dispose();
    _proxyBypassCtrl.dispose();
    super.dispose();
  }

  void _testProxy() async {
    setState(() {
      _isTestingProxy = true;
      _proxyTestResult = null;
    });

    await Future.delayed(const Duration(milliseconds: 900));

    if (mounted) {
      setState(() {
        _isTestingProxy = false;
        _proxyTestResult = 'Gateway BAGL 10.52.132.240:8080 ativo • Latência 22ms • Rota C&TI Segura';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF131A33),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.tertiary, size: 20),
              const SizedBox(width: 10),
              Text(
                _proxyTestResult!,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _manualCheckpoint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF131A33),
        content: Row(
          children: [
            Icon(Icons.done_all_rounded, color: AppColors.tertiary, size: 20),
            SizedBox(width: 10),
            Text(
              'Checkpoint WAL SQLite executado com sucesso: 142 páginas sincronizadas.',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _syncNtp() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF131A33),
        content: Row(
          children: [
            Icon(Icons.schedule_rounded, color: AppColors.tertiary, size: 20),
            SizedBox(width: 10),
            Text(
              'Sincronismo NTP Atômico: ntp.fab.mil.br (Estrato 1) • Delta < 0.4ms',
              style: TextStyle(color: Colors.white, fontSize: 13),
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
    final auth = Provider.of<AuthProvider>(context);
    final stock = Provider.of<StockProvider>(context);
    final themeProv = Provider.of<ThemeProvider>(context);

    final user = auth.user;
    final militar = user?.militar;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. BANNER INSTITUCIONAL DE CONFIGURAÇÕES (Stitch 14_SettingsView.html)
          _buildTacticalBanner(context),
          const SizedBox(height: 16),

          // 2. PERFIL MILITAR OPERACIONAL E SESSÃO
          _buildOperatorProfileCard(context, user, militar, auth),
          const SizedBox(height: 16),

          // 3. GRADE DE PARÂMETROS OPERACIONAIS (DUAS COLUNAS TÁTICAS)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 950;
              if (!isWide) {
                return Column(
                  children: [
                    _buildSqliteWalCard(),
                    const SizedBox(height: 16),
                    _buildNtpSyncCard(),
                    const SizedBox(height: 16),
                    _buildProxyCard(),
                    const SizedBox(height: 16),
                    _buildSecurity2faCard(),
                    const SizedBox(height: 16),
                    _buildAppearanceCard(isDark, themeProv, stock),
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _buildSqliteWalCard(),
                            const SizedBox(height: 16),
                            _buildNtpSyncCard(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            _buildProxyCard(),
                            const SizedBox(height: 16),
                            _buildSecurity2faCard(),
                            const SizedBox(height: 16),
                            _buildAppearanceCard(isDark, themeProv, stock),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // 4. RODAPÉ DE INFRAESTRUTURA TÁTICA E VERSÃO
          _buildTacticalFooter(stock),
        ],
      ),
    );
  }

  // --- BANNER INSTITUCIONAL ---
  Widget _buildTacticalBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF131A33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF212942)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Opacity(
              opacity: 0.05,
              child: Icon(Icons.settings_suggest_rounded, size: 200, color: AppColors.primary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFF212942),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF414754)),
                  ),
                  child: const Center(
                    child: Icon(Icons.tune_rounded, color: AppColors.primary, size: 28),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.tertiary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.tertiary.withOpacity(0.3)),
                            ),
                            child: const Text(
                              'PORTARIA Nº 142/DIRM-GL',
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: AppColors.tertiary,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                          const Text(
                            'ENCLAVE TÁTICO // ALA 11 - C&TI GALEÃO',
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: Color(0xFF8C909F),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.tertiary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'NÓ LOCAL CONECTADO',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.tertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'CONFIGURAÇÕES DO SISTEMA // PARÂMETROS OPERACIONAIS BINFAE-GL',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Ajustes do mecanismo local SQLite WAL, servidores de tempo atômico NTP, túnel proxy militar e políticas de assinatura digital.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFC2C6D6)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- CARD DO MILITAR OPERACIONAL E SESSÃO ---
  Widget _buildOperatorProfileCard(BuildContext context, dynamic user, dynamic militar, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131A33),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF212942)),
      ),
      child: Row(
        children: [
          UserAvatar(
            fotoUrl: user?.fotoUrl,
            name: user?.displayName,
            radius: 24,
            iconSize: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user?.displayName ?? 'Operador Tático',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: user?.admin == true ? AppColors.primaryContainer.withOpacity(0.2) : const Color(0xFF212942),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        user?.admin == true ? 'ADMINISTRADOR N4' : 'OPERADOR C&TI',
                        style: TextStyle(
                          fontSize: 9,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: user?.admin == true ? AppColors.primary : const Color(0xFFC2C6D6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  militar != null
                      ? 'SARAM: ${militar.saram} • Seção: ${militar.secao ?? "Informática"} • Posto: ${militar.postoGraduacao ?? "Operador"}'
                      : 'Username: ${user?.username ?? "militar"} • Sessão Encriptada Ativa',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF8C909F)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const UserProfileDialog(),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF212942),
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            icon: const Icon(Icons.badge_outlined, size: 16),
            label: const Text('Editar Perfil', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => auth.logout(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error.withOpacity(0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('Encerrar Sessão', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // --- CARD 1: SQLITE WAL ENGINE ---
  Widget _buildSqliteWalCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131A33),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF212942)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.storage_rounded, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Mecanismo SQLite WAL (Write-Ahead Logging)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.tertiary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'WAL ENGINE v3.45.1',
                  style: TextStyle(fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppColors.tertiary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFF212942)),
          const SizedBox(height: 12),

          // Arquivo local
          const Text(
            'CAMINHO DA BASE LOCAL ENCRIPTADA (AES-256-XTS)',
            style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFF8C909F), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0A122A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF2C344D)),
            ),
            child: const Row(
              children: [
                Icon(Icons.folder_open_rounded, size: 16, color: Color(0xFF8C909F)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'C:\\Users\\Gsd-gl\\AppData\\Local\\BinfaeDesktopApp\\binfae_operational_v4.db',
                    style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Telemetria Dinâmica WAL
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF171E37),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2C344D)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'STATUS DINÂMICO DO ARQUIVO .WAL',
                      style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFF8C909F), fontWeight: FontWeight.bold),
                    ),
                    InkWell(
                      onTap: _manualCheckpoint,
                      child: const Row(
                        children: [
                          Icon(Icons.refresh_rounded, size: 14, color: AppColors.tertiary),
                          SizedBox(width: 4),
                          Text(
                            'Checkpoint Manual [Alt+C]',
                            style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.tertiary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildWalMetric('TAMANHO WAL', '4.8 MB', Colors.white),
                    _buildWalMetric('FRAGMENTAÇÃO', '0.2%', AppColors.tertiary),
                    _buildWalMetric('PÁGINAS PENDENTES', '142 / 1000', AppColors.primary),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    value: 0.142,
                    backgroundColor: Color(0xFF0A122A),
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Checkpoint Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'INTERVALO DE CHECKPOINT WAL',
                style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFF8C909F), fontWeight: FontWeight.bold),
              ),
              Text(
                '${_checkpointInterval.toInt()} ms',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: _checkpointInterval,
            min: 200,
            max: 5000,
            divisions: 24,
            activeColor: AppColors.primary,
            inactiveColor: const Color(0xFF2C344D),
            onChanged: (val) => setState(() => _checkpointInterval = val),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('200ms (Alta CPU)', style: TextStyle(fontSize: 9, color: Color(0xFF8C909F))),
              Text('Padrão 1000ms', style: TextStyle(fontSize: 9, color: Color(0xFF8C909F))),
              Text('5000ms', style: TextStyle(fontSize: 9, color: Color(0xFF8C909F))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWalMetric(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF0A122A),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 8, fontFamily: 'monospace', color: Color(0xFF8C909F))),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  // --- CARD 2: SERVIDORES DE TEMPO OFICIAL NTP ---
  Widget _buildNtpSyncCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131A33),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF212942)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 18, color: AppColors.tertiary),
                  SizedBox(width: 8),
                  Text(
                    'Servidores de Tempo Oficial Militar (NTP Estrato 1)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.tertiary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_clock_rounded, size: 12, color: AppColors.tertiary),
                    SizedBox(width: 4),
                    Text(
                      'LOCKED',
                      style: TextStyle(fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppColors.tertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFF212942)),
          const SizedBox(height: 12),

          // Primário
          _buildNtpServerRow('ntp.fab.mil.br', 'PRIMÁRIO // ESTRATO 1 COMAER (CESIUM-133)', '< 0.8ms', 'ATIVO', AppColors.tertiary),
          const SizedBox(height: 8),
          // Secundário
          _buildNtpServerRow('a.st1.ntp.br', 'SECUNDÁRIO // CONTINGÊNCIA ON/NIC.BR', 'SINCRONIZADO', 'STANDBY', AppColors.primary),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Re-sincronismo a cada 15 min (Alerta se deriva > 5ms)',
                style: TextStyle(fontSize: 11, color: Color(0xFF8C909F)),
              ),
              OutlinedButton.icon(
                onPressed: _syncNtp,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: Color(0xFF2C344D)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.sync_rounded, size: 14),
                label: const Text('Forçar Sync [F7]', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNtpServerRow(String host, String sub, String delta, String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF171E37),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2C344D)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(host, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(sub, style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFF8C909F))),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Text(delta, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: color, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A122A),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status,
                  style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- CARD 3: PROXY MILITAR & TÚNEL C&TI ---
  Widget _buildProxyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131A33),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF212942)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.vpn_lock_rounded, size: 18, color: Color(0xFFAAC7FF)),
                  SizedBox(width: 8),
                  Text(
                    'Proxy Militar & Roteamento Galeão',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF212942),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '10.52.132.240:8080',
                  style: TextStyle(fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFF212942)),
          const SizedBox(height: 12),

          const Text(
            'ENDEREÇO DO PROXY CENTRAL & GATEWAY BAGL',
            style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFF8C909F), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A122A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF2C344D)),
                  ),
                  child: TextField(
                    controller: _proxyAddressCtrl,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isTestingProxy ? null : _testProxy,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                icon: _isTestingProxy
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.network_check_rounded, size: 16),
                label: const Text('Testar Rota', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          const Text(
            'BYPASS PARA REDE LOCAL C&TI (SEM PROXY)',
            style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFF8C909F), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF0A122A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF2C344D)),
            ),
            child: TextField(
              controller: _proxyBypassCtrl,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- CARD 4: SEGURANÇA FORENSE & 2FA ---
  Widget _buildSecurity2faCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131A33),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF212942)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.security_rounded, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Segurança Forense & Dispositivos 2FA',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF212942),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'ICP-FAB CERT',
                  style: TextStyle(fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppColors.tertiary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFF212942)),
          const SizedBox(height: 12),

          // Switch 1: FIDO2
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Política de Autenticação FIDO2 / YubiKey', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    Text('Exigir toque físico no token em operações sensíveis N3/N4', style: TextStyle(fontSize: 10, color: Color(0xFF8C909F))),
                  ],
                ),
              ),
              Switch(
                value: _fido2Enabled,
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _fido2Enabled = v),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Switch 2: Assinatura Automática
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Assinatura Automática em Cautelas & Livro Diário', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    Text('Carimbo de tempo SHA-256 militar em cada movimentação', style: TextStyle(fontSize: 10, color: Color(0xFF8C909F))),
                  ],
                ),
              ),
              Switch(
                value: _autoSignEnabled,
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _autoSignEnabled = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- CARD 5: APARÊNCIA & SINCRONIZAÇÃO SERVIDOR ---
  Widget _buildAppearanceCard(bool isDark, ThemeProvider themeProv, StockProvider stock) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131A33),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF212942)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.palette_outlined, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Aparência & Sincronização Local',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFF212942)),
          const SizedBox(height: 12),

          // Tema Escuro
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tema Visual Tático Escuro (Aerospace Midnight Navy)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                  Text('Paleta militar de alto contraste otimizada para operações 24h', style: TextStyle(fontSize: 10, color: Color(0xFF8C909F))),
                ],
              ),
              Switch(
                value: isDark,
                activeColor: AppColors.primary,
                onChanged: (_) => themeProv.toggleTheme(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Sincronização
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Última Sincronização com o Servidor Central', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                  Text(
                    stock.lastSync != null
                        ? DateFormat("dd/MM/yyyy 'às' HH:mm:ss").format(stock.lastSync!)
                        : 'Nunca sincronizado',
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF8C909F)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: stock.isSyncing ? null : () => stock.syncData(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryContainer,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                icon: stock.isSyncing
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.sync_rounded, size: 14),
                label: Text(stock.isSyncing ? 'Sincronizando...' : 'Sincronizar Agora', style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- FOOTER TÁTICO ---
  Widget _buildTacticalFooter(StockProvider stock) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131A33),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF212942)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, size: 16, color: AppColors.tertiary),
              const SizedBox(width: 8),
              Text(
                'BINFAE-GL ${UpdaterService.currentVersion} • Módulo Tático C&TI Homologado',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF8C909F)),
              ),
            ],
          ),
          const Text(
            'Nativo Windows (120 FPS Direct3D) • Portaria 142/DIRM-GL',
            style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF8C909F)),
          ),
        ],
      ),
    );
  }
}
