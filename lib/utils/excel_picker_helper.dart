import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class ExcelPickResult {
  final Uint8List bytes;
  final String fileName;
  final String? path;

  ExcelPickResult({
    required this.bytes,
    required this.fileName,
    this.path,
  });
}

class ExcelPickerHelper {
  /// Abre a caixa de diálogo para seleção de planilha Excel ou CSV.
  /// Suporta .xlsx, .xls e .csv.
  /// Possui fallback nativo via PowerShell (Windows Forms) para máxima resiliência no Windows.
  static Future<ExcelPickResult?> pickExcelFile() async {
    // 1. Tentar via FilePicker padrão
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Selecione a Planilha de Militares (Excel ou CSV)',
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? data = file.bytes;
        if ((data == null || data.isEmpty) && file.path != null && file.path!.isNotEmpty) {
          final f = File(file.path!);
          if (await f.exists()) {
            data = await f.readAsBytes();
          }
        }
        if (data != null && data.isNotEmpty) {
          return ExcelPickResult(
            bytes: data,
            fileName: file.name.isNotEmpty ? file.name : 'militares.xlsx',
            path: file.path,
          );
        }
      }

      if (result == null) {
        return null;
      }
    } catch (e) {
      debugPrint('[ExcelPickerHelper] FilePicker gerou exceção ($e), ativando fallback nativo PowerShell...');
      return await _pickExcelViaPowerShell();
    }

    return null;
  }

  /// Fallback nativo usando OpenFileDialog do Windows Forms via PowerShell
  static Future<ExcelPickResult?> _pickExcelViaPowerShell() async {
    try {
      if (!Platform.isWindows) return null;

      const script = r'''
Add-Type -AssemblyName System.Windows.Forms
$dlg = New-Object System.Windows.Forms.OpenFileDialog
$dlg.Title = "Selecione a Planilha de Militares (Excel ou CSV)"
$dlg.Filter = "Planilhas (*.xlsx;*.xls;*.csv)|*.xlsx;*.xls;*.csv|Todos os arquivos (*.*)|*.*"
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
            final bytes = await file.readAsBytes();
            final name = selectedPath.split(Platform.pathSeparator).last;
            return ExcelPickResult(
              bytes: bytes,
              fileName: name,
              path: selectedPath,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[ExcelPickerHelper] Falha no fallback PowerShell: $e');
    }
    return null;
  }
}
