import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/stock_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/item_detail_dialog.dart';
import '../widgets/item_form_dialog.dart';
import 'stock_view.dart';
import 'locations_view.dart';
import 'groups_view.dart';
import 'history_view.dart';
import 'admin_view.dart';
import 'settings_view.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _selectedIndex = 0;
  final FocusNode _searchFocusNode = FocusNode();

  // Wedge Barcode Scanner buffer
  String _barcodeBuffer = '';
  DateTime? _lastCharTime;
  DateTime? _firstCharTime;

  // Auto-updater state
  String? _newReleaseTag;
  String? _newReleaseUrl;
  bool _dismissedUpdate = false;

  @override
  void initState() {
    super.initState();

    // Sincronização inicial em background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StockProvider>(context, listen: false).syncData();
      _checkForUpdates();
    });

    // Registra listener de teclado global para atalhos e scanner USB Wedge
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final release = await api.checkLatestRelease();
      if (release != null && release['tag_name'] != null) {
        final tag = release['tag_name'] as String;
        // Se a tag for diferente da versão atual v1.0.0
        if (tag != 'v1.0.0' && tag != '1.0.0' && mounted) {
          String? downloadUrl;
          if (release['assets'] is List) {
            for (final asset in release['assets']) {
              final name = asset['name'] as String? ?? '';
              if (name.endsWith('.exe')) {
                downloadUrl = asset['browser_download_url'] as String?;
                break;
              }
            }
          }
          setState(() {
            _newReleaseTag = tag;
            _newReleaseUrl = downloadUrl ?? release['html_url'] as String?;
          });
        }
      }
    } catch (_) {}
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final isCtrl = HardwareKeyboard.instance.isControlPressed;

    // Atalho: Ctrl + F (Focar busca no estoque)
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyF) {
      if (_selectedIndex != 0) {
        setState(() => _selectedIndex = 0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
      return true;
    }

    // Atalho: Ctrl + N (Novo Material)
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyN) {
      showDialog(
        context: context,
        builder: (ctx) => const ItemFormDialog(),
      );
      return true;
    }

    // Atalho: F5 (Sincronização com API)
    if (event.logicalKey == LogicalKeyboardKey.f5) {
      Provider.of<StockProvider>(context, listen: false).syncData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sincronizando dados com o servidor...'),
          duration: Duration(seconds: 2),
        ),
      );
      return true;
    }

    // Suporte ao leitor USB de código de barras (Wedge Scanner)
    final now = DateTime.now();
    if (event.character != null && event.character!.isNotEmpty) {
      final char = event.character!;
      if (_lastCharTime != null && now.difference(_lastCharTime!).inMilliseconds < 65) {
        _barcodeBuffer += char;
      } else {
        _barcodeBuffer = char;
        _firstCharTime = now;
      }
      _lastCharTime = now;
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_barcodeBuffer.length >= 2 &&
          _firstCharTime != null &&
          now.difference(_firstCharTime!).inMilliseconds < 600) {
        final scanned = _barcodeBuffer.trim();
        _barcodeBuffer = '';
        _firstCharTime = null;

        _processScannedBarcode(scanned);
        return true;
      }
      _barcodeBuffer = '';
    }

    return false;
  }

  void _processScannedBarcode(String code) {
    final stock = Provider.of<StockProvider>(context, listen: false);
    final item = stock.findItemByCode(code);

    if (item != null) {
      showDialog(
        context: context,
        builder: (ctx) => ItemDetailDialog(item: item),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.warning,
          content: Text('Código "$code" lido pelo scanner, mas nenhum material foi localizado.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);
    final themeProv = Provider.of<ThemeProvider>(context);
    final stock = Provider.of<StockProvider>(context);

    final user = auth.user;
    final isAdmin = user?.admin == true;

    // Lista de telas disponíveis
    final views = [
      StockView(searchFocusNode: _searchFocusNode),
      const LocationsView(),
      const GroupsView(),
      const HistoryView(),
      if (isAdmin) const AdminView(),
      const SettingsView(),
    ];

    // Ajusta o índice se o painel admin for oculto
    if (!isAdmin && _selectedIndex == 4) {
      _selectedIndex = 0;
    }

    final titles = [
      'Inventário e Gestão de Materiais',
      'Locais Físicos e Estrutura',
      'Grupos e Subgrupos',
      'Histórico de Movimentações',
      if (isAdmin) 'Painel Administrativo',
      'Configurações e Perfil',
    ];

    return Scaffold(
      body: Row(
        children: [
          // Sidebar de Navegação Widescreen Persistente
          Container(
            width: 240,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1626) : Colors.white,
              border: Border(
                right: BorderSide(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // Top Header Brand
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.shield, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BINFAE',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Gestão de Patrimônio & TI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Itens de Navegação
                _buildNavItem(0, 'Materiais e Estoque', Icons.inventory_2_outlined, isDark),
                _buildNavItem(1, 'Locais Físicos', Icons.place_outlined, isDark),
                _buildNavItem(2, 'Grupos e Subgrupos', Icons.category_outlined, isDark),
                _buildNavItem(3, 'Histórico Geral', Icons.history_outlined, isDark),
                if (isAdmin)
                  _buildNavItem(4, 'Painel Administrativo', Icons.admin_panel_settings_outlined, isDark),
                _buildNavItem(isAdmin ? 5 : 4, 'Configurações', Icons.settings_outlined, isDark),

                const Spacer(),

                // Indicador de Leitor USB de Código de Barras Conectado
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_scanner, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Leitor USB Wedge Ativo',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                // Status de Sincronização no Rodapé da Barra
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF151D2F) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: stock.syncError != null
                              ? AppColors.danger
                              : (stock.isSyncing ? AppColors.warning : AppColors.success),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          stock.isSyncing
                              ? 'Sincronizando...'
                              : (stock.syncError != null ? 'Erro de conexão' : 'Banco em 0ms (RAM)'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 16),
                        tooltip: 'Sincronizar (F5)',
                        onPressed: stock.isSyncing ? null : () => stock.syncData(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Área Principal da Aplicação
          Expanded(
            child: Column(
              children: [
                // Banner de Nova Atualização Disponível (se houver)
                if (_newReleaseTag != null && !_dismissedUpdate)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    color: AppColors.primary.withOpacity(0.12),
                    child: Row(
                      children: [
                        const Icon(Icons.system_update_alt, size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Nova versão ($_newReleaseTag) do BINFAE Desktop disponível para instalação.',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                        if (_newReleaseUrl != null)
                          TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Baixe a nova versão no GitHub: $_newReleaseUrl')),
                              );
                            },
                            child: const Text('Baixar Instalador', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() => _dismissedUpdate = true),
                        ),
                      ],
                    ),
                  ),

                // Barra Superior do Desktop
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0E1422) : Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedIndex < titles.length ? titles[_selectedIndex] : 'BINFAE',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Row(
                        children: [
                          // Botão de Tema
                          IconButton(
                            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 20),
                            tooltip: 'Alternar Tema Claro/Escuro',
                            onPressed: () => themeProv.toggleTheme(),
                          ),
                          const SizedBox(width: 12),

                          // Usuário Militar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1F293D) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.person, size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  user?.displayName ?? 'Militar',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                if (isAdmin) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text('ADMIN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Conteúdo da Tela Selecionada
                Expanded(
                  child: views[_selectedIndex < views.length ? _selectedIndex : 0],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon, bool isDark) {
    final active = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: active
                    ? AppColors.primary
                    : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.bold : FontWeight.w500,
                    color: active
                        ? (isDark ? Colors.white : AppColors.primary)
                        : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF475569)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
