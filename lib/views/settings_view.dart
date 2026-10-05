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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);
    final stock = Provider.of<StockProvider>(context);
    final themeProv = Provider.of<ThemeProvider>(context);
    final api = Provider.of<ApiService>(context);

    final user = auth.user;
    final militar = user?.militar;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configurações',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Preferências do sistema, dados locais e conexão de rede',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 24),

          // 1. Card do Militar Conectado
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151D2F) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                UserAvatar(
                  fotoUrl: user?.fotoUrl,
                  name: user?.displayName,
                  radius: 26,
                  iconSize: 26,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'Usuário',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        militar != null
                            ? 'SARAM: ${militar.saram} • ${militar.secao ?? "Informática"}'
                            : (user?.admin == true ? 'Administrador do Sistema' : 'Operador'),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const UserProfileDialog(),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cyan,
                    foregroundColor: const Color(0xFF0A0E17),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Editar Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => auth.logout(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Encerrar Sessão'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Seção de Aparência e Tema
          _buildSectionHeader('APARÊNCIA', isDark),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151D2F) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF312E81) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDark ? Icons.dark_mode : Icons.light_mode,
                        color: isDark ? const Color(0xFF818CF8) : const Color(0xFFF59E0B),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tema Visual Escuro',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          isDark ? 'Ativado (paleta escura moderna)' : 'Desativado (modo claro)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: isDark,
                  onChanged: (_) => themeProv.toggleTheme(),
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Seção do Banco de Dados Local Offline (0ms)
          _buildSectionHeader('SINCRONIZAÇÃO E BASE LOCAL', isDark),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151D2F) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Última Sincronização com o Servidor',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stock.lastSync != null
                          ? DateFormat("dd/MM/yyyy 'às' HH:mm").format(stock.lastSync!)
                          : 'Nunca sincronizado',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: stock.isSyncing ? null : () => stock.syncData(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: stock.isSyncing
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.sync, size: 16),
                  label: Text(stock.isSyncing ? 'Sincronizando...' : 'Sincronizar Agora'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),


          // Informações de Versão
          Center(
            child: Text(
              'Informatica - BINFAE-GL ${UpdaterService.currentVersion} • Nativo Windows (120 FPS)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
        ),
      ),
    );
  }
}
