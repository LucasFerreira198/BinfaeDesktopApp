import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';

class ReleaseInfo {
  final String tag;
  final String title;
  final String body;
  final String? exeDownloadUrl;
  final int? exeSize;

  ReleaseInfo({
    required this.tag,
    required this.title,
    required this.body,
    this.exeDownloadUrl,
    this.exeSize,
  });
}

class UpdaterService {
  static const String currentVersion = 'v2.0.1';
  static const String repoOwner = 'LucasFerreira198';
  static const String repoName = 'BinfaeDesktopApp';

  static Future<ReleaseInfo?> checkLatestRelease() async {
    try {
      final uri = Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest');
      final response = await http.get(uri, headers: {
        'Accept': 'application/vnd.github.v3+json',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final tag = data['tag_name'] as String? ?? '';
        final title = data['name'] as String? ?? 'Atualização';
        final body = data['body'] as String? ?? '';

        String? downloadUrl;
        int? size;
        if (data['assets'] is List) {
          for (final asset in data['assets']) {
            final name = asset['name'] as String? ?? '';
            if (name.endsWith('.exe')) {
              downloadUrl = asset['browser_download_url'] as String?;
              size = asset['size'] as int?;
              break;
            }
          }
        }

        return ReleaseInfo(
          tag: tag,
          title: title,
          body: body,
          exeDownloadUrl: downloadUrl,
          exeSize: size,
        );
      }
    } catch (_) {}
    return null;
  }

  static bool isNewerVersion(String latestTag) {
    final cleanLatest = latestTag.replaceAll(RegExp(r'[^0-9.]'), '');
    final cleanCurrent = currentVersion.replaceAll(RegExp(r'[^0-9.]'), '');

    final latestParts = cleanLatest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final currentParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    while (latestParts.length < 3) {
      latestParts.add(0);
    }
    while (currentParts.length < 3) {
      currentParts.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  static Future<void> downloadAndInstall({
    required String downloadUrl,
    required void Function(double progress, String statusText) onProgress,
    required void Function(String error) onError,
  }) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        onError('Erro ao conectar ao servidor de downloads (${response.statusCode})');
        return;
      }

      final totalBytes = response.contentLength ?? 0;
      final tempDir = Directory.systemTemp.path;
      final installerPath = '$tempDir\\BinfaeDesktop-Setup.exe';
      final file = File(installerPath);
      final sink = file.openWrite();

      int received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (totalBytes > 0) {
          final progress = (received / totalBytes).clamp(0.0, 1.0);
          final recMb = (received / (1024 * 1024)).toStringAsFixed(1);
          final totMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
          onProgress(progress, '$recMb MB de $totMb MB (${(progress * 100).toStringAsFixed(0)}%)');
        } else {
          final recMb = (received / (1024 * 1024)).toStringAsFixed(1);
          onProgress(0.5, '$recMb MB baixados');
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      onProgress(1.0, 'Iniciando instalação e reiniciando aplicativo...');

      // Pequena pausa para garantir liberação dos arquivos
      await Future.delayed(const Duration(milliseconds: 600));

      // Executa instalador e encerra processo atual
      await Process.start(
        installerPath,
        ['/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS'],
        runInShell: true,
      );

      exit(0);
    } catch (e) {
      onError('Falha no download da atualização: $e');
    }
  }

  static void showUpdateModal(BuildContext context, ReleaseInfo release) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UpdateDialog(release: release),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final ReleaseInfo release;

  const _UpdateDialog({required this.release});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _status = '';
  String? _error;

  void _startUpdate() {
    if (widget.release.exeDownloadUrl == null) {
      setState(() => _error = 'Instalador (.exe) não encontrado na release.');
      return;
    }

    setState(() {
      _isDownloading = true;
      _error = null;
      _status = 'Iniciando download da atualização...';
    });

    UpdaterService.downloadAndInstall(
      downloadUrl: widget.release.exeDownloadUrl!,
      onProgress: (p, s) {
        if (mounted) {
          setState(() {
            _progress = p;
            _status = s;
          });
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _error = err;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF0E1422) : Colors.white,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.system_update_alt, color: AppColors.primaryLight, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Atualização do Sistema',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Versão disponível: ${widget.release.tag}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isDownloading)
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Conteúdo
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(fontSize: 12, color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (!_isDownloading) ...[
              Text(
                'Uma nova versão do Informatica - BINFAE-GL está disponível. A atualização será baixada e instalada automaticamente sem sair do aplicativo.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151D2F) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: AppColors.primaryLight),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Versão instalada: ${UpdaterService.currentVersion} ➔ Nova: ${widget.release.tag}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Lembrar Mais Tarde'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _startUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                    ),
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Atualizar Agora', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ] else ...[
              // Modo de Progresso do Download
              Text(
                'Baixando instalador oficial...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  minHeight: 10,
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _status,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    '${(_progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Não feche a janela durante o download.',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
