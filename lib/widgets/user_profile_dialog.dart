import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'user_avatar.dart';

class UserProfileDialog extends StatefulWidget {
  const UserProfileDialog({super.key});

  @override
  State<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fotoUrlController;
  late TextEditingController _nomeGuerraController;
  late TextEditingController _secaoController;
  late TextEditingController _celularController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;

  bool _obscurePassword = true;
  bool _isSaving = false;
  String _previewFotoUrl = '';

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    final militar = user?.militar;

    _fotoUrlController = TextEditingController(text: user?.fotoUrl ?? '');
    _previewFotoUrl = user?.fotoUrl ?? '';
    _nomeGuerraController = TextEditingController(text: militar?.nomeGuerra ?? user?.username ?? '');
    _secaoController = TextEditingController(text: militar?.secao ?? 'Informática');
    _celularController = TextEditingController(text: militar?.celular ?? '');
    _emailController = TextEditingController(text: militar?.email ?? '');
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();

    _fotoUrlController.addListener(() {
      if (mounted) {
        setState(() {
          _previewFotoUrl = _fotoUrlController.text.trim();
        });
      }
    });
  }

  @override
  void dispose() {
    _fotoUrlController.dispose();
    _nomeGuerraController.dispose();
    _secaoController.dispose();
    _celularController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text.isNotEmpty) {
      if (_passwordController.text.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('A nova senha deve ter no mínimo 6 caracteres.'),
          ),
        );
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('As senhas informadas não coincidem.'),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      await auth.updateProfile(
        fotoUrl: _fotoUrlController.text.trim().isEmpty ? '' : _fotoUrlController.text.trim(),
        password: _passwordController.text.trim().isEmpty ? null : _passwordController.text.trim(),
        celular: _celularController.text.trim().isEmpty ? null : _celularController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        nomeGuerra: _nomeGuerraController.text.trim().isEmpty ? null : _nomeGuerraController.text.trim(),
        secao: _secaoController.text.trim().isEmpty ? null : _secaoController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Perfil e foto atualizados com sucesso!'),
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildCardSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool isDark = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101622) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF1E2838) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: AppColors.cyan),
              ),
              const SizedBox(width: 10),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label, {String? hint, IconData? icon, Widget? suffix}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 18, color: const Color(0xFF94A3B8)) : null,
      suffixIcon: suffix,
      filled: true,
      fillColor: isDark ? const Color(0xFF151D2A) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isDark ? const Color(0xFF232B3E) : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isDark ? const Color(0xFF232B3E) : const Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.cyan, width: 1.5),
      ),
      labelStyle: const TextStyle(fontSize: 12.5),
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final militar = user?.militar;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0B0F17) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? const Color(0xFF1E2838) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Container(
        width: 660,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Modal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.manage_accounts_rounded, color: AppColors.cyan, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Meu Perfil Militar',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Atualize sua foto de perfil, contatos e credenciais',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF151D2A) : const Color(0xFFF1F5F9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Corpo do Formulário com Scroll
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Seção 1: Foto de Perfil & Avatar
                      _buildCardSection(
                        title: '1. Foto de Perfil & Identidade Visual',
                        icon: Icons.add_a_photo_outlined,
                        isDark: isDark,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Avatar Preview Grande com anel de neon ciano
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.cyan, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.cyan.withOpacity(0.25),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: UserAvatar(
                                  fotoUrl: _previewFotoUrl.isNotEmpty ? _previewFotoUrl : null,
                                  name: user?.displayName,
                                  radius: 36,
                                  iconSize: 32,
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextFormField(
                                      controller: _fotoUrlController,
                                      decoration: _inputDeco(
                                        'URL da Foto ou Avatar',
                                        hint: 'Cole o link direto da imagem (ex: https://.../foto.jpg)',
                                        icon: Icons.link,
                                        suffix: _previewFotoUrl.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.clear, size: 16),
                                                tooltip: 'Remover foto',
                                                onPressed: () => _fotoUrlController.clear(),
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'A foto será exibida na barra lateral, no cabeçalho e nas cautelas em todo o sistema.',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Seção 2: Dados Militares e Lotação
                      _buildCardSection(
                        title: '2. Dados do Militar & Lotação',
                        icon: Icons.shield_outlined,
                        isDark: isDark,
                        children: [
                          Row(
                            children: [
                              // Posto / Graduação (Fixo / Identidade)
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: militar?.postoGraduacao ?? (user?.admin == true ? 'ADMIN' : 'S2'),
                                  enabled: false,
                                  decoration: _inputDeco('Posto / Graduação', icon: Icons.military_tech_outlined),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // SARAM (Fixo)
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: militar?.saram != null ? militar!.saram.toString() : 'N/A',
                                  enabled: false,
                                  decoration: _inputDeco('SARAM', icon: Icons.badge_outlined),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // Nome de Guerra
                              Expanded(
                                child: TextFormField(
                                  controller: _nomeGuerraController,
                                  decoration: _inputDeco('Nome de Guerra', hint: 'Ex: D. PAULA', icon: Icons.person_outline),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Seção / Divisão
                              Expanded(
                                child: TextFormField(
                                  controller: _secaoController,
                                  decoration: _inputDeco('Seção de Lotação', hint: 'Ex: Informática, Guarda', icon: Icons.corporate_fare_outlined),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Seção 3: Comunicação & Contato
                      _buildCardSection(
                        title: '3. Comunicação & Contato Operacional',
                        icon: Icons.phone_android_outlined,
                        isDark: isDark,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _celularController,
                                  decoration: _inputDeco('Telefone / Celular com DDD', hint: 'Ex: (21) 98765-4321', icon: Icons.phone),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _emailController,
                                  decoration: _inputDeco('E-mail Corporativo ou Pessoal', hint: 'Ex: militar@fab.mil.br', icon: Icons.email_outlined),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Seção 4: Segurança da Conta (Alterar Senha)
                      _buildCardSection(
                        title: '4. Segurança da Conta (Alterar Senha)',
                        icon: Icons.lock_outline,
                        isDark: isDark,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: _inputDeco(
                                    'Nova Senha (deixe vazio p/ manter)',
                                    hint: 'Mínimo 6 dígitos',
                                    icon: Icons.vpn_key_outlined,
                                    suffix: IconButton(
                                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscurePassword,
                                  decoration: _inputDeco(
                                    'Confirmar Nova Senha',
                                    hint: 'Repita a nova senha',
                                    icon: Icons.check_circle_outline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Rodapé com Botões de Ação
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cyan,
                      foregroundColor: const Color(0xFF0A0E17),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A0E17)),
                          )
                        : const Icon(Icons.check_circle, size: 18),
                    label: Text(
                      _isSaving ? 'Salvando...' : 'Salvar Perfil',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
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
