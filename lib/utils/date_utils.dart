import 'package:intl/intl.dart';

/// Utilitário central de conversão e formatação de datas e horários.
/// Garante que todas as datas armazenadas em UTC no banco de dados sejam
/// convertidas e exibidas no fuso horário local correto (Brasília / Horário Local).
class AppDateUtils {
  /// Converte qualquer valor de data (String ou DateTime) garantindo a conversão para o Fuso Horário Local (Brasília).
  static DateTime parseToLocal(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value.toLocal();

    final str = value.toString().trim();
    if (str.isEmpty) return DateTime.now();

    DateTime? dt;
    // Se a string não contiver indicador de fuso ('Z', '+' ou '-xx:xx'),
    // como o servidor grava em UTC, adicionamos 'Z' para o Dart interpretar como UTC antes do .toLocal()
    if (!str.endsWith('Z') && !str.contains('+') && !RegExp(r'-\d{2}:\d{2}$').hasMatch(str)) {
      dt = DateTime.tryParse('${str}Z') ?? DateTime.tryParse(str);
    } else {
      dt = DateTime.tryParse(str);
    }

    return (dt ?? DateTime.now()).toLocal();
  }

  /// Formata data e hora completa: dd/MM/yyyy HH:mm
  static String formatDateTime(dynamic value) {
    if (value == null) return '';
    try {
      final dt = parseToLocal(value);
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return value.toString();
    }
  }

  /// Formata data e hora compacta para listas e badges: dd/MM HH:mm
  static String formatShortDateTime(dynamic value) {
    if (value == null) return '';
    try {
      final dt = parseToLocal(value);
      return DateFormat('dd/MM HH:mm').format(dt);
    } catch (_) {
      return value.toString();
    }
  }

  /// Formata apenas a data: dd/MM/yyyy
  static String formatDate(dynamic value) {
    if (value == null) return '';
    try {
      final dt = parseToLocal(value);
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return value.toString();
    }
  }

  /// Formata apenas o horário: HH:mm
  static String formatTime(dynamic value) {
    if (value == null) return '';
    try {
      final dt = parseToLocal(value);
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return value.toString();
    }
  }

  /// Formata data por extenso: Segunda-feira, 05 de Outubro de 2026
  static String formatDateLong(DateTime dt) {
    try {
      return DateFormat("EEEE, dd 'de' MMMM 'de' yyyy", 'pt_BR').format(dt.toLocal());
    } catch (_) {
      return DateFormat("dd/MM/yyyy").format(dt.toLocal());
    }
  }
}
