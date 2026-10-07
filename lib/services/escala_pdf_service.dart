import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/escala.dart';

class EscalaPdfService {
  static const PdfColor colorRedWeekend = PdfColor.fromInt(0xFFDC2626); // Vermelho vibrante
  static const PdfColor colorPurpleHoliday = PdfColor.fromInt(0xFF7E22CE); // Roxo vibrante
  static const PdfColor colorHeaderBg = PdfColor.fromInt(0xFF1E293B); // Azul escuro FAB
  static const PdfColor colorBorder = PdfColor.fromInt(0xFF94A3B8); // Cinza borda

  /// Gera o documento PDF da escala mensal formatado para caber em EXATAMENTE 1 PÁGINA A4 Paisagem
  static Future<Uint8List> generateEscalaPdf(EscalaMensalModel escala) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // 1. CABEÇALHO OFICIAL
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: pw.BoxDecoration(
                  color: colorHeaderBg,
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Center(
                  child: pw.Text(
                    escala.titulo.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 5),

              // 2. CORPO DIVIDIDO: TABELA DIÁRIA (ESQUERDA) + QUADRO ESTATÍSTICO (DIREITA)
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // --- TABELA DIÁRIA PRINCIPAL (62% da largura) ---
                    pw.Expanded(
                      flex: 62,
                      child: _buildTabelaDias(escala.dias),
                    ),
                    pw.SizedBox(width: 8),

                    // --- QUADRO ESTATÍSTICO LATERAL (38% da largura) ---
                    pw.Expanded(
                      flex: 38,
                      child: _buildTabelaEstatisticas(escala.estatisticas),
                    ),
                  ],
                ),
              ),

              // 3. RODAPÉ COMPACTO
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Legenda: [Vermelho] Final de Semana | [Roxo] Feriado Nacional / Militar',
                    style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'Gerado pelo Sistema BINFAE-GL em ${DateFormat("dd/MM/yyyy HH:mm").format(DateTime.now())} • Página 1 de 1',
                    style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildTabelaDias(List<EscalaDiaModel> dias) {
    return pw.Table(
      border: pw.TableBorder.all(color: colorBorder, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(48), // DATA
        1: pw.FixedColumnWidth(64), // DIA
        2: pw.FlexColumnWidth(1.2), // SERVIÇO
        3: pw.FlexColumnWidth(1.0), // EXPD 1
        4: pw.FlexColumnWidth(1.0), // EXPD 2
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _cellHeader('DATA'),
            _cellHeader('DIA'),
            _cellHeader('SERVIÇO'),
            _cellHeader('EXPD 1'),
            _cellHeader('EXPD 2'),
          ],
        ),
        // Linhas de cada dia do mês
        ...dias.map((d) {
          PdfColor? rowBg;
          PdfColor textColor = PdfColors.black;

          if (d.isFimDeSemana) {
            rowBg = colorRedWeekend;
            textColor = PdfColors.white;
          } else if (d.isFeriado) {
            rowBg = colorPurpleHoliday;
            textColor = PdfColors.white;
          }

          final dataStr = DateFormat('dd/MM/yyyy').format(d.data);
          final svStr = d.militarSvGuerra ?? (d.militarSvNome ?? '');
          final exp1Str = d.isFimDeSemana ? '' : (d.militarExpd1Guerra ?? (d.militarExpd1Nome ?? ''));
          final exp2Str = d.isFimDeSemana ? '' : (d.militarExpd2Guerra ?? (d.militarExpd2Nome ?? ''));

          return pw.TableRow(
            decoration: rowBg != null ? pw.BoxDecoration(color: rowBg) : null,
            children: [
              _cellData(dataStr, textColor, isBold: true),
              _cellData(d.diaSemana, textColor),
              _cellData(svStr, textColor, isBold: true),
              _cellData(exp1Str, textColor),
              _cellData(exp2Str, textColor),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTabelaEstatisticas(List<EstatisticaMilitarModel> stats) {
    return pw.Table(
      border: pw.TableBorder.all(color: colorBorder, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.5), // MILITAR
        1: pw.FixedColumnWidth(26), // EXPD
        2: pw.FixedColumnWidth(24), // SV
        3: pw.FixedColumnWidth(24), // SEM 1
        4: pw.FixedColumnWidth(24), // SEM 2
        5: pw.FixedColumnWidth(24), // SEM 3
        6: pw.FixedColumnWidth(24), // SEM 4
        7: pw.FixedColumnWidth(24), // SEM 5
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _cellHeader('MILITAR'),
            _cellHeader('expd'),
            _cellHeader('sv'),
            _cellHeader('Sem 1'),
            _cellHeader('Sem 2'),
            _cellHeader('Sem 3'),
            _cellHeader('Sem 4'),
            _cellHeader('Sem 5'),
          ],
        ),
        // Linhas de militares
        ...stats.map((s) {
          final milStr = '${s.postoGraduacao} ${s.nomeGuerra}';
          return pw.TableRow(
            children: [
              _cellData(milStr, PdfColors.black, isBold: true, alignLeft: true),
              _cellData('${s.totalExpd}', PdfColors.black),
              _cellData('${s.totalSv}', PdfColors.black, isBold: true),
              _cellData('${s.semana1}', PdfColors.black),
              _cellData('${s.semana2}', PdfColors.black),
              _cellData('${s.semana3}', PdfColors.black),
              _cellData('${s.semana4}', PdfColors.black),
              _cellData('${s.semana5}', PdfColors.black),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _cellHeader(String text) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 2),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _cellData(String text, PdfColor color, {bool isBold = false, bool alignLeft = false}) {
    return pw.Container(
      alignment: alignLeft ? pw.Alignment.centerLeft : pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(vertical: 1.8, horizontal: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 6.2,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
        maxLines: 1,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }
}
