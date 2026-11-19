import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/auth_provider.dart';
import '../providers/stock_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/updater_service.dart';
import '../theme/app_theme.dart';
import '../widgets/item_detail_dialog.dart';
import '../widgets/item_form_dialog.dart';
import '../widgets/user_avatar.dart';
import '../widgets/user_profile_dialog.dart';
import '../widgets/command_palette_dialog.dart';
import 'home_dashboard_view.dart';
import 'stock_view.dart';
import 'cautelas_view.dart';
import 'maintenance_view.dart';
import 'pendencias_view.dart';
import 'escala_view.dart';
import 'relatorio_diario_view.dart';
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

  // Fullscreen state
  bool _isFullScreen = false;

  // Responsive sidebar collapse state
  bool _isSidebarCollapsed = false;
  bool _userToggledSidebar = false;

  @override
  void initState() {
    super.initState();

    // Sincronização inicial em background e checagem de atualizações
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StockProvider>(context, listen: false).syncData();
      _checkForUpdates();
    });

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.isFullScreen().then((fs) {
        if (mounted) setState(() => _isFullScreen = fs);
      }).catchError((_) {});
    }

    // Registra listener de teclado global para atalhos e scanner USB Wedge
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  Future<void> _toggleFullScreen() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        final isFs = await windowManager.isFullScreen();
        await windowManager.setFullScreen(!isFs);
        if (mounted) {
          setState(() {
            _isFullScreen = !isFs;
          });
        }
      } catch (_) {}
    }
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
          UpdaterService.showUpdateModal(context, release);
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

  void _openCommandPalette() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final themeProv = Provider.of<ThemeProvider>(context, listen: false);
    final stock = Provider.of<StockProvider>(context, listen: false);
    final isAdmin = auth.user?.admin == true;

    final actions = [
      // Ações Rápidas
      CommandPaletteAction(
        title: 'Novo Material',
        subtitle: 'Cadastrar novo item no acervo de informática',
        icon: Icons.add_circle_outline,
        shortcut: 'Ctrl + N',
        category: 'Ações',
        onExecute: () {
          showDialog(
            context: context,
            builder: (ctx) => const ItemFormDialog(),
          );
        },
      ),
      CommandPaletteAction(
        title: 'Buscar no Estoque',
        subtitle: 'Focar campo de pesquisa de materiais',
        icon: Icons.search,
        shortcut: 'Ctrl + F',
        category: 'Ações',
        onExecute: () {
          if (_selectedIndex != 1) {
            setState(() => _selectedIndex = 1);
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _searchFocusNode.requestFocus();
          });
        },
      ),
      CommandPaletteAction(
        title: 'Sincronizar Dados',
        subtitle: 'Atualizar banco de dados local com o servidor',
        icon: Icons.sync,
        shortcut: 'F5',
        category: 'Ações',
        onExecute: () {
          stock.syncData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sincronizando dados com o servidor...'),
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
      CommandPaletteAction(
        title: 'Alternar Tela Cheia',
        subtitle: 'Maximizar ou restaurar tamanho da janela',
        icon: Icons.fullscreen,
        shortcut: 'F11',
        category: 'Ações',
        onExecute: _toggleFullScreen,
      ),
      CommandPaletteAction(
        title: 'Alternar Tema Claro / Escuro',
        subtitle: 'Mudar tema visual da interface',
        icon: Icons.brightness_6_outlined,
        category: 'Ações',
        onExecute: () => themeProv.toggleTheme(),
      ),
      CommandPaletteAction(
        title: 'Meu Perfil Militar',
        subtitle: 'Visualizar credenciais, graduação e foto',
        icon: Icons.person_outline,
        category: 'Ações',
        onExecute: () {
          showDialog(
            context: context,
            builder: (_) => const UserProfileDialog(),
          );
        },
      ),
      CommandPaletteAction(
        title: 'Verificar Atualizações',
        subtitle: 'Checar novas versões do Informatica BINFAE-GL',
        icon: Icons.system_update_alt,
        category: 'Ações',
        onExecute: () => _checkForUpdates(manual: true),
      ),

      // Telas e Módulos
      CommandPaletteAction(
        title: 'Dashboard Operacional',
        subtitle: 'Métricas gerais, resumo de estoque e gráficos',
        icon: Icons.dashboard_outlined,
        category: 'Módulos',
        onExecute: () => setState(() => _selectedIndex = 0),
      ),
      CommandPaletteAction(
        title: 'Materiais e Gestão de Estoque',
        subtitle: 'Catálogo de materiais, BMPs e níveis de estoque',
        icon: Icons.inventory_2_outlined,
        category: 'Módulos',
        onExecute: () => setState(() => _selectedIndex = 1),
      ),
      CommandPaletteAction(
        title: 'Cautela de Materiais e Missões',
        subtitle: 'Cautelas ativas, devoluções e termos de cautela',
        icon: Icons.assignment_turned_in_outlined,
        category: 'Módulos',
        onExecute: () => setState(() => _selectedIndex = 2),
      ),
      CommandPaletteAction(
        title: 'Manutenção e Reparos',
        subtitle: 'Bancada técnica, diagnósticos e laudos de reparo',
        icon: Icons.handyman_outlined,
        category: 'Módulos',
        onExecute: () => setState(() => _selectedIndex = 3),
      ),
      CommandPaletteAction(
        title: 'Pendências e Metas',
        subtitle: 'Controle de pendências e tarefas técnicas',
        icon: Icons.checklist_rtl_outlined,
        category: 'Módulos',
        onExecute: () => setState(() => _selectedIndex = 4),
      ),
      CommandPaletteAction(
        title: 'Escala de Sobreaviso',
        subtitle: 'Escala militar, contatos de emergência e plantão',
        icon: Icons.calendar_month_outlined,
        category: 'Módulos',
        onExecute: () => setState(() => _selectedIndex = 5),
      ),
      CommandPaletteAction(
        title: 'Relatório Diário (24h)',
        subtitle: 'Livro de serviço diário e ocorrências do plantão',
        icon: Icons.assignment_outlined,
        category: 'Módulos',
        onExecute: () => setState(() => _selectedIndex = 6),
      ),
      CommandPaletteAction(
        title: 'Locais Físicos e Estrutura',
        subtitle: 'Gestão de armários, gavetas e setores da base',
        icon: Icons.place_outlined,
        category: 'Módulos',
        onExecute: () => setState(() => _selectedIndex = 7),
      ),
      CommandPaletteAction(
        title: 'Grupos e Subgrupos',
        subtitle: 'Categorização de peças e equipamentos',
        icon: Icons.category_outlined,
        category: 'Módulos',
        onExecute: () => setState(() => _selectedIndex = 8),
      ),
      CommandPaletteAction(
        title: 'Histórico Geral de Movimentações',
        subtitle: 'Auditoria de entradas, saídas e transferências',
        icon: Icons.history_outlined,
        category: 'Módulos',
        onExecute: () => setState(() => _selectedIndex = 9),
      ),
      if (isAdmin)
        CommandPaletteAction(
          title: 'Painel Administrativo',
          subtitle: 'Gestão de usuários militares, permissões e sistema',
          icon: Icons.admin_panel_settings_outlined,
          category: 'Módulos',
          onExecute: () => setState(() => _selectedIndex = 10),
        ),
      CommandPaletteAction(
        title: 'Configurações e Perfil',
        subtitle: 'Preferências do sistema, rede e aparência',
        icon: Icons.settings_outlined,
        category: 'Módulos',
        onExecute: () => setState(() => _selectedIndex = isAdmin ? 11 : 10),
      ),
    ];

    showDialog(
      context: context,
      builder: (ctx) => CommandPaletteDialog(actions: actions),
    );
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;

    // Atalho: Ctrl + K / Cmd + K (Command Palette)
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyK) {
      _openCommandPalette();
      return true;
    }

    // Atalho: F11 (Alternar Tela Cheia)
    if (event.logicalKey == LogicalKeyboardKey.f11) {
      _toggleFullScreen();
      return true;
    }

    // Atalho: Ctrl + F (Focar busca no estoque)
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyF) {
      if (_selectedIndex != 1) {
        setState(() => _selectedIndex = 1);
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

  Future<void> _processScannedBarcode(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return;

    final api = Provider.of<ApiService>(context, listen: false);
    final stock = Provider.of<StockProvider>(context, listen: false);

    // 1. Checa se o material escaneado está em Cautela Ativa
    try {
      final statusRes = await api.checkItemCautelaStatus(cleanCode);
      if (statusRes['cautelado'] == true && statusRes['cautela'] != null) {
        final cautelaInfo = statusRes['cautela'] as Map<String, dynamic>;
        final militarInfo = cautelaInfo['militar'] as Map<String, dynamic>?;
        final itemInfo = statusRes['item'] as Map<String, dynamic>?;

        final isDark = Theme.of(context).brightness == Brightness.dark;
        if (!mounted) return;

        final shouldReturn = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF151D2F) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.assignment_return_outlined, color: AppColors.primary, size: 26),
                const SizedBox(width: 10),
                const Text('Material Cautelado Identificado'),
              ],
            ),
            content: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'O material escaneado encontra-se sob cautela ativa:',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E3D5B) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemInfo?['nome'] ?? 'Material',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (itemInfo?['bmp'] != null) ...[
                          const SizedBox(height: 4),
                          Text('BMP: ${itemInfo!['bmp']}', style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                        const Divider(height: 16),
                        Text(
                          'Missão / Cautela: ${cautelaInfo['missao_nome'] ?? ''} (${cautelaInfo['tipo'] == 'MISSAO' ? 'Missão Operacional' : 'Cautela Fixa'})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Militar Responsável: ${militarInfo?['posto_graduacao'] ?? ''} ${militarInfo?['nome_guerra'] ?? ''} (SARAM ${militarInfo?['saram'] ?? ''})',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                        if (cautelaInfo['telefone_contato'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Telefone: ${cautelaInfo['telefone_contato']}',
                            style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Deseja realizar a descautelação (devolução) deste material agora?',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Não Devolver'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Confirmar Devolução'),
              ),
            ],
          ),
        );

        if (shouldReturn == true) {
          try {
            await api.scanDevolverItem(cleanCode);
            await stock.syncData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppColors.success,
                  content: Text('Material devolvido com sucesso! Status atualizado para DISPONÍVEL.'),
                ),
              );
            }
          } catch (err) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(backgroundColor: AppColors.danger, content: Text('Erro ao devolver: $err')),
              );
            }
          }
          return;
        }
      }
    } catch (_) {}

    // Caso não esteja cautelado (ou o usuário optou por não devolver), abre detalhes no estoque
    final item = stock.findItemByCode(cleanCode);
    if (item != null) {
      showDialog(
        context: context,
        builder: (ctx) => ItemDetailDialog(item: item),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.warning,
          content: Text('Código "$cleanCode" lido pelo scanner, mas nenhum material foi localizado.'),
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
    final apiService = Provider.of<ApiService>(context, listen: false);

    final user = auth.user;
    final isAdmin = user?.admin == true;

    // Lista de telas disponíveis
    final views = [
      HomeDashboardView(
        onNavigate: (index, {statusFilter}) {
          if (statusFilter != null) {
            stock.setStatus(statusFilter);
          }
          setState(() => _selectedIndex = index);
        },
        onNewItem: () {
          showDialog(
            context: context,
            builder: (ctx) => const ItemFormDialog(),
          );
        },
        onNewCautela: () {
          setState(() => _selectedIndex = 2);
        },
      ),
      StockView(
        searchFocusNode: _searchFocusNode,
        onNavigate: (index) => setState(() => _selectedIndex = index),
      ),
      const CautelasView(),
      MaintenanceView(
        onNavigate: (index) => setState(() => _selectedIndex = index),
      ),
      PendenciasView(
        onNavigate: (index) => setState(() => _selectedIndex = index),
      ),
      EscalaView(
        onNavigate: (index) => setState(() => _selectedIndex = index),
      ),
      RelatorioDiarioView(
        onNavigate: (index) => setState(() => _selectedIndex = index),
      ),
      const LocationsView(),
      const GroupsView(),
      const HistoryView(),
      if (isAdmin) const AdminView(),
      const SettingsView(),
    ];

    if (_selectedIndex >= views.length) {
      _selectedIndex = 0;
    }

    final titles = [
      'Dashboard Operacional',
      'Materiais e Gestão de Estoque',
      'Cautela de Materiais e Missões',
      'Manutenção e Reparos',
      'Pendências e Metas',
      'Escala de Sobreaviso',
      'Relatório Diário (24h)',
      'Locais Físicos e Estrutura',
      'Grupos e Subgrupos',
      'Histórico Geral de Movimentações',
      if (isAdmin) 'Painel Administrativo',
      'Configurações e Perfil',
    ];

    final icons = [
      Icons.dashboard_outlined,
      Icons.inventory_2_outlined,
      Icons.assignment_turned_in_outlined,
      Icons.handyman_outlined,
      Icons.checklist_rtl_outlined,
      Icons.calendar_month_outlined,
      Icons.assignment_outlined,
      Icons.place_outlined,
      Icons.category_outlined,
      Icons.history_outlined,
      if (isAdmin) Icons.admin_panel_settings_outlined,
      Icons.settings_outlined,
    ];


    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 1100;
    final isCollapsed = _userToggledSidebar ? _isSidebarCollapsed : isCompact;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar Esquerda Responsiva / Retrátil (Largura 260px ou 72px)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: isCollapsed ? 72 : 260,
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceContainerLow : Colors.white,
              border: Border(
                right: BorderSide(
                  color: isDark ? AppColors.outlineVariant : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // Top Header Brand (BINFAE-GL // Ala 11 // C&TI)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceContainer : const Color(0xFFF1F5F9),
                  ),
                  child: Row(
                    mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primaryContainer.withOpacity(0.4)),
                        ),
                        child: const Center(
                          child: Icon(Icons.military_tech_rounded, color: AppColors.primary, size: 22),
                        ),
                      ),
                      if (!isCollapsed) ...[
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BINFAE-GL',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  color: AppColors.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Ala 11 // C&TI',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurfaceVariant,
                                  letterSpacing: 0.6,
                                ),
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Tactical Navigation Ribbon (NAVEGAÇÃO TÁTICA / 12 NÓS)
                if (!isCollapsed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    color: isDark ? AppColors.surfaceContainerLowest : const Color(0xFFE2E8F0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'NAVEGAÇÃO TÁTICA',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: AppColors.outline,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceContainerHigh : Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '12 NÓS',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.tertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 6),

                // Lista de Itens de Navegação com suporte a modo compacto
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _NavHoverItem(
                          index: 0,
                          currentIndex: _selectedIndex,
                          label: 'Dashboard',
                          icon: Icons.dashboard_outlined,
                          isDark: isDark,
                          isCollapsed: isCollapsed,
                          onTap: () => setState(() => _selectedIndex = 0),
                        ),
                        _NavHoverItem(
                          index: 1,
                          currentIndex: _selectedIndex,
                          label: 'Materiais e Estoque',
                          icon: Icons.inventory_2_outlined,
                          isDark: isDark,
                          isCollapsed: isCollapsed,
                          onTap: () => setState(() => _selectedIndex = 1),
                        ),
                        _NavHoverItem(
                          index: 2,
                          currentIndex: _selectedIndex,
                          label: 'Cautelas e Missões',
                          icon: Icons.fact_check_outlined,
                          isDark: isDark,
                          isCollapsed: isCollapsed,
                          onTap: () => setState(() => _selectedIndex = 2),
                        ),
                        _NavHoverItem(
                          index: 3,
                          currentIndex: _selectedIndex,
                          label: 'Manutenção',
                          icon: Icons.handyman_outlined,
                          isDark: isDark,
                          isCollapsed: isCollapsed,
                          badgeWidget: stock.maintenanceItems.isNotEmpty
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.warning.withOpacity(0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '${stock.maintenanceItems.length}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () => setState(() => _selectedIndex = 3),
                        ),
                        _NavHoverItem(
                          index: 4,
                          currentIndex: _selectedIndex,
                          label: 'Pendências e Metas',
                          icon: Icons.checklist_rtl_outlined,
                          isDark: isDark,
                          isCollapsed: isCollapsed,
                          onTap: () => setState(() => _selectedIndex = 4),
                        ),
                        _NavHoverItem(
                          index: 5,
                          currentIndex: _selectedIndex,
                          label: 'Escala de Sobreaviso',
                          icon: Icons.calendar_month_outlined,
                          isDark: isDark,
                          isCollapsed: isCollapsed,
                          onTap: () => setState(() => _selectedIndex = 5),
                        ),
                        _NavHoverItem(
                          index: 6,
                          currentIndex: _selectedIndex,
                          label: 'Relatório Diário (24h)',
                          icon: Icons.summarize_outlined,
                          isDark: isDark,
                          isCollapsed: isCollapsed,
                          onTap: () => setState(() => _selectedIndex = 6),
                        ),
                        _NavHoverItem(
                          index: 7,
                          currentIndex: _selectedIndex,
                          label: 'Locais Físicos',
                          icon: Icons.location_on_outlined,
                          isDark: isDark,
                          isCollapsed: isCollapsed,
                          badgeWidget: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.tertiary.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.tertiary.withOpacity(0.3), width: 0.8),
                            ),
                            child: const Text('Árvore', style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.tertiary)),
                          ),
                          onTap: () => setState(() => _selectedIndex = 7),
                        ),
                        _NavHoverItem(
                          index: 8,
                          currentIndex: _selectedIndex,
                          label: 'Grupos e Subgrupos',
                          icon: Icons.category_outlined,
                          isDark: isDark,
                          isCollapsed: isCollapsed,
                          onTap: () => setState(() => _selectedIndex = 8),
                        ),
                        _NavHoverItem(
                          index: 9,
                          currentIndex: _selectedIndex,
                          label: 'Histórico Geral',
                          icon: Icons.history_outlined,
                          isDark: isDark,
                          isCollapsed: isCollapsed,
                          onTap: () => setState(() => _selectedIndex = 9),
                        ),
                        if (isAdmin)
                          _NavHoverItem(
                            index: 10,
                            currentIndex: _selectedIndex,
                            label: 'Painel Administrativo',
                            icon: Icons.admin_panel_settings_outlined,
                            isDark: isDark,
                            isCollapsed: isCollapsed,
                            onTap: () => setState(() => _selectedIndex = 10),
                          ),
                        _NavHoverItem(
                          index: isAdmin ? 11 : 10,
                          currentIndex: _selectedIndex,
                          label: 'Configurações',
                          icon: Icons.settings_outlined,
                          isDark: isDark,
                          isCollapsed: isCollapsed,
                          onTap: () => setState(() => _selectedIndex = isAdmin ? 11 : 10),
                        ),
                      ],
                    ),
                  ),
                ),

                // Rodapé Tático da Sidebar (SQLite Local + Proxy BAGL)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceContainerLowest : const Color(0xFFF1F5F9),
                    border: Border(
                      top: BorderSide(color: isDark ? AppColors.outlineVariant : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: stock.syncError != null
                                  ? AppColors.error
                                  : (stock.isSyncing ? AppColors.warning : AppColors.tertiary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!isCollapsed) ...[
                            Expanded(
                              child: Text(
                                stock.isSyncing
                                    ? 'Sincronizando...'
                                    : (stock.syncError != null ? 'Erro SQLite' : 'SQLite Local: OK'),
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.onSurfaceVariant : const Color(0xFF475569),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.surfaceContainerHigh : Colors.white,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text('F5', style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 9, color: AppColors.outline)),
                            ),
                          ],
                        ],
                      ),
                      if (!isCollapsed) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'SARAM LINK',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.outline,
                              ),
                            ),
                            Text(
                              apiService.proxyEnabled ? 'PROXY PORT 8080' : 'ENCRIPTADO',
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.tertiary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: 1.0,
                            minHeight: 3,
                            backgroundColor: AppColors.surfaceContainerHighest,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.tertiary),
                          ),
                        ),
                      ],
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
                // Header Superior Responsivo Tático (Google Stitch Layout)
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceContainerLowest : Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? AppColors.outlineVariant : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Esquerda: Toggle Sidebar + Título da Tela + Tag Militar
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(isCollapsed ? Icons.menu : Icons.menu_open, size: 20),
                              tooltip: isCollapsed ? 'Expandir Menu Lateral' : 'Recolher Menu Lateral',
                              onPressed: () {
                                setState(() {
                                  _userToggledSidebar = true;
                                  _isSidebarCollapsed = !isCollapsed;
                                });
                              },
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              _selectedIndex < icons.length ? icons[_selectedIndex] : Icons.inventory_2_outlined,
                              size: 19,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _selectedIndex < titles.length ? titles[_selectedIndex] : 'Informatica - BINFAE-GL',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.onSurface : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (screenWidth >= 1200) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.surfaceContainerHigh : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'v2.4.0',
                                  style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Direita: Status da API, Relógios Táticos, Busca e Perfil
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Status API Online com ponto pulsante (Stitch Telemetry)
                          if (screenWidth >= 1150) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.surfaceContainerHigh : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.tertiary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'API ONLINE',
                                    style: TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.tertiary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    '(28ms)',
                                    style: TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 10,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],

                          // Relógios Táticos Dual (BRT / ZULU)
                          if (screenWidth >= 980) ...[
                            const _LiveTacticalClock(),
                            const SizedBox(width: 8),
                          ],

                          // Notificação de Release se houver
                          if (_latestRelease != null) ...[
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => UpdaterService.showUpdateModal(context, _latestRelease!),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.download_rounded, size: 13, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text(
                                        _latestRelease!.version.isNotEmpty ? "v${_latestRelease!.version}" : _latestRelease!.tag,
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],

                          // Botão de Command Palette (Ctrl+K)
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: _openCommandPalette,
                              child: Container(
                                height: 32,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.surfaceContainerLowest : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark ? AppColors.outlineVariant : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.search,
                                      size: 15,
                                      color: isDark ? AppColors.outline : const Color(0xFF64748B),
                                    ),
                                    if (screenWidth >= 880) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        'Busca rápida...',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? AppColors.outline : const Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppColors.surfaceContainerHigh : const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: const Text(
                                        'Ctrl+K',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'JetBrains Mono',
                                          color: AppColors.outline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Botão de Tela Cheia (F11)
                          IconButton(
                            icon: Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen, size: 20),
                            tooltip: _isFullScreen ? 'Sair da Tela Cheia (F11)' : 'Tela Cheia (F11)',
                            onPressed: _toggleFullScreen,
                          ),

                          // Botão de Tema
                          IconButton(
                            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 19),
                            tooltip: 'Alternar Tema Claro/Escuro',
                            onPressed: () => themeProv.toggleTheme(),
                          ),
                          const SizedBox(width: 6),

                          // Dropdown de Perfil Militar Tático (Stitch Profile Badge)
                          PopupMenuButton<String>(
                            tooltip: 'Opções de Conta',
                            offset: const Offset(0, 48),
                            color: isDark ? AppColors.surfaceContainerHigh : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: isDark ? AppColors.outlineVariant : const Color(0xFFE2E8F0)),
                            ),
                            onSelected: (val) {
                              if (val == 'profile') {
                                showDialog(
                                  context: context,
                                  builder: (_) => const UserProfileDialog(),
                                );
                              } else if (val == 'settings') {
                                setState(() => _selectedIndex = isAdmin ? 11 : 10);
                              } else if (val == 'update') {
                                _checkForUpdates(manual: true);
                              } else if (val == 'fullscreen') {
                                _toggleFullScreen();
                              } else if (val == 'theme') {
                                themeProv.toggleTheme();
                              } else if (val == 'logout') {
                                auth.logout();
                              }
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'profile',
                                child: Row(
                                  children: [
                                    UserAvatar(
                                      fotoUrl: user?.fotoUrl,
                                      name: user?.displayName,
                                      radius: 12,
                                      iconSize: 12,
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(user?.displayName ?? 'S2 D. PAULA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        const Text('Editar Meu Perfil & Foto', style: TextStyle(fontSize: 10, color: AppColors.primary)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'settings',
                                child: const Row(
                                  children: [
                                    Icon(Icons.settings_outlined, size: 18),
                                    SizedBox(width: 10),
                                    Text('Configurações do App', style: TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'fullscreen',
                                child: Row(
                                  children: [
                                    Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen, size: 18, color: AppColors.primary),
                                    const SizedBox(width: 10),
                                    Text(_isFullScreen ? 'Sair da Tela Cheia (F11)' : 'Tela Cheia (F11)', style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'update',
                                child: Row(
                                  children: [
                                    Icon(Icons.system_update_alt, size: 18, color: AppColors.primary),
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
                                    SizedBox(width: 10),
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
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.surfaceContainerLow : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark ? AppColors.outlineVariant : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (screenWidth >= 820) ...[
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            user?.displayName ?? '2º Sgt Silva',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? AppColors.onSurface : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          Text(
                                            'SARAM ${user?.militar?.saram ?? 6842910}',
                                            style: const TextStyle(
                                              fontFamily: 'JetBrains Mono',
                                              fontSize: 9.5,
                                              color: AppColors.secondary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Stack(
                                      children: [
                                        UserAvatar(
                                          fotoUrl: user?.fotoUrl,
                                          name: user?.displayName,
                                          radius: 14,
                                          iconSize: 14,
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.tertiary,
                                              border: Border.all(color: isDark ? AppColors.surfaceContainerLow : Colors.white, width: 1),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.expand_more_rounded, size: 16, color: AppColors.outline),
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
  final bool isCollapsed;
  final VoidCallback onTap;

  const _NavHoverItem({
    required this.index,
    required this.currentIndex,
    required this.label,
    required this.icon,
    required this.isDark,
    this.badgeWidget,
    this.isCollapsed = false,
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
    final isCollapsed = widget.isCollapsed;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 8 : 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: active
            ? AppColors.primaryContainer
            : (_isHovered
                ? (widget.isDark ? AppColors.surfaceContainerHigh : const Color(0xFFF1F5F9))
                : Colors.transparent),
        borderRadius: BorderRadius.circular(8),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.primaryContainer.withOpacity(0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: isCollapsed
          ? Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    widget.icon,
                    size: 20,
                    color: active
                        ? Colors.white
                        : (_isHovered
                            ? (widget.isDark ? AppColors.onSurface : const Color(0xFF0F172A))
                            : (widget.isDark ? AppColors.onSurfaceVariant : const Color(0xFF64748B))),
                  ),
                  if (widget.badgeWidget != null)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                ],
              ),
            )
          : Row(
              children: [
                Icon(
                  widget.icon,
                  size: 19,
                  color: active
                      ? Colors.white
                      : (_isHovered
                          ? (widget.isDark ? AppColors.onSurface : const Color(0xFF0F172A))
                          : (widget.isDark ? AppColors.onSurfaceVariant : const Color(0xFF64748B))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.bold : (_isHovered ? FontWeight.w600 : FontWeight.w500),
                      color: active
                          ? Colors.white
                          : (_isHovered
                              ? (widget.isDark ? AppColors.onSurface : const Color(0xFF0F172A))
                              : (widget.isDark ? AppColors.onSurfaceVariant : const Color(0xFF475569))),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.badgeWidget != null) widget.badgeWidget!,
              ],
            ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 6 : 10, vertical: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: isCollapsed
              ? Tooltip(
                  message: widget.label,
                  preferBelow: false,
                  verticalOffset: 16,
                  child: content,
                )
              : content,
        ),
      ),
    );
  }
}

class _LiveTacticalClock extends StatefulWidget {
  const _LiveTacticalClock();

  @override
  State<_LiveTacticalClock> createState() => _LiveTacticalClockState();
}

class _LiveTacticalClockState extends State<_LiveTacticalClock> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final brt =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}';
    final zulu =
        '${_now.toUtc().hour.toString().padLeft(2, '0')}:${_now.toUtc().minute.toString().padLeft(2, '0')}:${_now.toUtc().second.toString().padLeft(2, '0')}Z';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceContainerLow : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'BRT: $brt',
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('|', style: TextStyle(color: AppColors.outlineVariant)),
          ),
          Text(
            'ZULU: $zulu',
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.tertiary,
            ),
          ),
        ],
      ),
    );
  }
}
