import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class ImagePickerHelper {
  /// Abre a caixa de diálogo para seleção de imagem no Windows.
  /// Tenta via plugin FilePicker e possui fallback nativo via PowerShell (Windows Forms)
  /// para máxima resiliência no ambiente Windows Desktop corporativo.
  static Future<Uint8List?> pickImageBytes() async {
    // 1. Tentar via FilePicker padrão
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Selecione uma Imagem para o Perfil',
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null && file.bytes!.isNotEmpty) {
          return file.bytes;
        } else if (file.path != null && file.path!.isNotEmpty) {
          final f = File(file.path!);
          if (await f.exists()) {
            return await f.readAsBytes();
          }
        }
      }
      // Se o usuário cancelou a seleção no FilePicker
      if (result == null) {
        return null;
      }
    } catch (e) {
      debugPrint('[ImagePickerHelper] FilePicker gerou exceção ($e), ativando fallback nativo PowerShell...');
      return await _pickImageViaPowerShell();
    }

    return null;
  }

  /// Fallback nativo usando OpenFileDialog do Windows Forms via PowerShell
  static Future<Uint8List?> _pickImageViaPowerShell() async {
    try {
      if (!Platform.isWindows) return null;

      const script = r'''
Add-Type -AssemblyName System.Windows.Forms
$dlg = New-Object System.Windows.Forms.OpenFileDialog
$dlg.Title = "Selecione uma Imagem para o Perfil"
$dlg.Filter = "Imagens (*.jpg;*.jpeg;*.png;*.webp;*.bmp)|*.jpg;*.jpeg;*.png;*.webp;*.bmp"
$dlg.Multiselect = $false
$dlg.RestoreDirectory = $true
if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  [Console]::Write($dlg.FileName)
}
''';

      final process = await Process.run(
        'powershell',
        ['-NoProfile', '-WindowStyle', 'Hidden', '-Command', script],
        runInShell: true,
      );

      if (process.exitCode == 0) {
        final selectedPath = process.stdout.toString().trim();
        if (selectedPath.isNotEmpty) {
          final file = File(selectedPath);
          if (await file.exists()) {
            return await file.readAsBytes();
          }
        }
      }
    } catch (e) {
      debugPrint('[ImagePickerHelper] Falha no fallback PowerShell: $e');
    }
    return null;
  }
}
