import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/stock_provider.dart';
import '../providers/theme_provider.dart';
import '../services/updater_service.dart';
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
  ReleaseInfo? _latestRelease;

  @override
  void initState() {
    super.initState();

    // Sincronização inicial em background e checagem de atualizações
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

  Future<void> _checkForUpdates({bool manual = false}) async {
    try {
      final release = await UpdaterService.checkLatestRelease();
      if (release != null && mounted) {
        final hasNewVersion = UpdaterService.isNewerVersion(release);
        if (hasNewVersion) {
          setState(() => _latestRelease = release);
          if (manual) {
            UpdaterService.showUpdateModal(context, release);
          }
        } else {
          setState(() => _latestRelease = null);
          if (manual) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppColors.success,
                content: Text('Você já está na versão mais recente do Informatica - BINFAE-GL! (${UpdaterService.currentVersion})'),
              ),
            );
          }
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

    if (!isAdmin && _selectedIndex == 4) {
      _selectedIndex = 0;
    }

    final titles = [
      'Materiais e Gestão de Estoque',
      'Locais Físicos e Estrutura',
      'Grupos e Subgrupos',
      'Histórico Geral de Movimentações',
      if (isAdmin) 'Painel Administrativo',
      'Configurações e Perfil',
    ];

    final icons = [
      Icons.inventory_2_outlined,
      Icons.place_outlined,
      Icons.category_outlined,
      Icons.history_outlined,
      if (isAdmin) Icons.admin_panel_settings_outlined,
      Icons.settings_outlined,
    ];

    return Scaffold(
      body: Row(
        children: [
          // Sidebar Esquerda Refinada
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B0F19) : Colors.white,
              border: Border(
                right: BorderSide(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // Top Header Brand (Escudo Estilizado com Micro-servidor)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(Icons.shield_outlined, color: Colors.white, size: 24),
                            Positioned(
                              bottom: 11,
                              child: Container(
                                padding: const EdgeInsets.all(1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: const Icon(Icons.dns, color: Colors.white, size: 9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Informatica',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'BINFAE-GL',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryLight,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                const SizedBox(height: 10),

                // Itens de Navegação com Indicador de Mouse Hover e Badges
                _NavHoverItem(
                  index: 0,
                  currentIndex: _selectedIndex,
                  label: 'Materiais e Estoque',
                  icon: Icons.inventory_2_outlined,
                  isDark: isDark,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                _NavHoverItem(
                  index: 1,
                  currentIndex: _selectedIndex,
                  label: 'Locais Físicos',
                  icon: Icons.place_outlined,
                  isDark: isDark,
                  badgeWidget: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.insights, size: 10, color: AppColors.primaryLight),
                        SizedBox(width: 2),
                        Text('Árvore', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
                      ],
                    ),
                  ),
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                _NavHoverItem(
                  index: 2,
                  currentIndex: _selectedIndex,
                  label: 'Grupos e Subgrupos',
                  icon: Icons.category_outlined,
                  isDark: isDark,
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
                _NavHoverItem(
                  index: 3,
                  currentIndex: _selectedIndex,
                  label: 'Histórico Geral',
                  icon: Icons.history_outlined,
                  isDark: isDark,
                  badgeWidget: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '1 Novo',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  onTap: () => setState(() => _selectedIndex = 3),
                ),
                if (isAdmin)
                  _NavHoverItem(
                    index: 4,
                    currentIndex: _selectedIndex,
                    label: 'Painel Administrativo',
                    icon: Icons.admin_panel_settings_outlined,
                    isDark: isDark,
                    onTap: () => setState(() => _selectedIndex = 4),
                  ),
                _NavHoverItem(
                  index: isAdmin ? 5 : 4,
                  currentIndex: _selectedIndex,
                  label: 'Configurações',
                  icon: Icons.settings_outlined,
                  isDark: isDark,
                  onTap: () => setState(() => _selectedIndex = isAdmin ? 5 : 4),
                ),

                const Spacer(),

                // Indicador de Leitor USB Wedge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_scanner, size: 14, color: AppColors.primaryLight),
                      const SizedBox(width: 8),
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

                // Status de Sincronização em RAM no Rodapé da Barra
                Container(
                  margin: const EdgeInsets.all(14),
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
                      const SizedBox(width: 8),
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
                // Header Superior Evoluído
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
                      // Título da View Atual com Ícone
                      Row(
                        children: [
                          Icon(
                            _selectedIndex < icons.length ? icons[_selectedIndex] : Icons.inventory_2_outlined,
                            size: 20,
                            color: AppColors.primaryLight,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _selectedIndex < titles.length ? titles[_selectedIndex] : 'Informatica - BINFAE-GL',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),

                      // Ações do Header (Notificação Discreta de Download + Tema + Perfil Dropdown)
                      Row(
                        children: [
                          // Notificação discreta de Atualização [v... disponível]
                          if (_latestRelease != null) ...[
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => UpdaterService.showUpdateModal(context, _latestRelease!),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.35),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.download_rounded, size: 14, color: Colors.white),
                                      const SizedBox(width: 6),
                                      Text(
                                        '[${_latestRelease!.version.isNotEmpty ? "v${_latestRelease!.version}" : _latestRelease!.tag} disponível]',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],

                          // Botão de Tema
                          IconButton(
                            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 20),
                            tooltip: 'Alternar Tema Claro/Escuro',
                            onPressed: () => themeProv.toggleTheme(),
                          ),
                          const SizedBox(width: 12),

                          // Dropdown de Perfil Militar (S2 D. PAULA / Usuário)
                          PopupMenuButton<String>(
                            tooltip: 'Opções de Conta',
                            offset: const Offset(0, 48),
                            color: isDark ? const Color(0xFF151D2F) : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)),
                            ),
                            onSelected: (val) {
                              if (val == 'settings') {
                                setState(() => _selectedIndex = isAdmin ? 5 : 4);
                              } else if (val == 'update') {
                                _checkForUpdates(manual: true);
                              } else if (val == 'theme') {
                                themeProv.toggleTheme();
                              } else if (val == 'logout') {
                                auth.logout();
                              }
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'settings',
                                child: Row(
                                  children: [
                                    const Icon(Icons.person_outline, size: 18),
                                    const SizedBox(width: 10),
                                    Text(user?.displayName ?? 'S2 D. PAULA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'update',
                                child: Row(
                                  children: [
                                    Icon(Icons.system_update_alt, size: 18, color: AppColors.primaryLight),
                                    SizedBox(width: 10),
                                    Text('Verificar Atualizações', style: TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'theme',
                                child: Row(
                                  children: [
                                    Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 18),
                                    const SizedBox(width: 10),
                                    Text(isDark ? 'Modo Claro' : 'Modo Escuro', style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'logout',
                                child: Row(
                                  children: [
                                    Icon(Icons.logout, size: 18, color: AppColors.danger),
                                    SizedBox(width: 10),
                                    Text('Encerrar Sessão', style: TextStyle(fontSize: 13, color: AppColors.danger)),
                                  ],
                                ),
                              ),
                            ],
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF151D2F) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Avatar com anel de gradiente
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [Color(0xFF7C3AED), Color(0xFF10B981)],
                                        ),
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.shield, color: Colors.white, size: 15),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      user?.displayName ?? 'S2 D. PAULA',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (isAdmin) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text('ADMIN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                    ],
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_drop_down, size: 18),
                                  ],
                                ),
                              ),
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
}

class _NavHoverItem extends StatefulWidget {
  final int index;
  final int currentIndex;
  final String label;
  final IconData icon;
  final bool isDark;
  final Widget? badgeWidget;
  final VoidCallback onTap;

  const _NavHoverItem({
    required this.index,
    required this.currentIndex,
    required this.label,
    required this.icon,
    required this.isDark,
    this.badgeWidget,
    required this.onTap,
  });

  @override
  State<_NavHoverItem> createState() => _NavHoverItemState();
}

class _NavHoverItemState extends State<_NavHoverItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.currentIndex == widget.index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: active
                  ? (widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF))
                  : (_isHovered
                      ? (widget.isDark ? const Color(0xFF151D2F) : const Color(0xFFF8FAFC))
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(
                  color: active
                      ? AppColors.primary
                      : (_isHovered ? AppColors.primaryLight.withOpacity(0.6) : Colors.transparent),
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 19,
                  color: active
                      ? AppColors.primary
                      : (_isHovered
                          ? AppColors.primaryLight
                          : (widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.bold : (_isHovered ? FontWeight.w600 : FontWeight.w500),
                      color: active
                          ? (widget.isDark ? Colors.white : AppColors.primary)
                          : (_isHovered
                              ? (widget.isDark ? Colors.white : const Color(0xFF0F172A))
                              : (widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
                    ),
                  ),
                ),
                if (widget.badgeWidget != null) widget.badgeWidget!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
