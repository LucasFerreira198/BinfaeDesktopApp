import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../theme/app_theme.dart';
import '../utils/image_picker_helper.dart';

/// Modal interativo militar para ajuste manual, centralização, rotação
/// e zoom de fotos de perfil antes de salvar.
class AvatarEditorDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final String? userName;
  final String? postoGraduacao;

  const AvatarEditorDialog({
    super.key,
    required this.imageBytes,
    this.userName,
    this.postoGraduacao,
  });

  @override
  State<AvatarEditorDialog> createState() => _AvatarEditorDialogState();
}

class _AvatarEditorDialogState extends State<AvatarEditorDialog> {
  static const double cropSize = 280.0;

  final GlobalKey _cropBoundaryKey = GlobalKey();

  late Uint8List _currentBytes;
  bool _isLoading = true;
  bool _isExporting = false;
  bool _showGrid = true;

  double _imgWidth = 100.0;
  double _imgHeight = 100.0;
  double _baseScale = 1.0;

  // Parâmetros de ajuste manual
  double _offsetX = 0.0;
  double _offsetY = 0.0;
  double _zoom = 1.0; // Multiplicador de 0.6x a 4.0x
  int _rotationDegrees = 0; // 0, 90, 180, 270

  @override
  void initState() {
    super.initState();
    _currentBytes = widget.imageBytes;
    _decodeImageDimensions();
  }

  Future<void> _decodeImageDimensions() async {
    setState(() => _isLoading = true);
    try {
      final codec = await ui.instantiateImageCodec(_currentBytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;

      if (mounted) {
        setState(() {
          _imgWidth = img.width.toDouble();
          _imgHeight = img.height.toDouble();

          // Calcula escala base para preencher totalmente o frame de 280x280
          final scaleX = cropSize / _imgWidth;
          final scaleY = cropSize / _imgHeight;
          _baseScale = math.max(scaleX, scaleY);

          // Centraliza inicialmente
          _offsetX = 0.0;
          _offsetY = 0.0;
          _zoom = 1.0;
          _rotationDegrees = 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[AvatarEditorDialog] Erro ao decodificar imagem: $e');
      if (mounted) {
        setState(() {
          _baseScale = 1.0;
          _isLoading = false;
        });
      }
    }
  }

  void _resetPosition() {
    setState(() {
      _offsetX = 0.0;
      _offsetY = 0.0;
      _zoom = 1.0;
      _rotationDegrees = 0;
    });
  }

  void _rotateClockwise() {
    setState(() {
      _rotationDegrees = (_rotationDegrees + 90) % 360;
    });
  }

  void _nudge(double dx, double dy) {
    setState(() {
      _offsetX += dx;
      _offsetY += dy;
    });
  }

  Future<void> _pickAnotherImage() async {
    final newBytes = await ImagePickerHelper.pickImageBytes();
    if (newBytes != null && mounted) {
      setState(() {
        _currentBytes = newBytes;
      });
      await _decodeImageDimensions();
    }
  }

  Future<void> _exportAndSave() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final boundary = _cropBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Área de corte não encontrada');
      }

      // Captura com pixelRatio de 1.5 para alta definição nítida (420x420 px)
      final ui.Image image = await boundary.toImage(pixelRatio: 1.5);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Falha ao gerar dados PNG da foto');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final base64String = base64Encode(pngBytes);
      final dataUrl = 'data:image/png;base64,$base64String';

      if (mounted) {
        Navigator.of(context).pop(dataUrl);
      }
    } catch (e) {
      debugPrint('[AvatarEditorDialog] Erro ao exportar corte: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Erro ao recortar imagem: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveScale = _baseScale * _zoom;
    final radians = _rotationDegrees * (math.pi / 180.0);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0D121D) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? const Color(0xFF222F43) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Container(
        width: 780,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho do Modal
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
                      child: const Icon(Icons.crop_rotate_rounded, color: AppColors.cyan, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ajustar e Centralizar Foto',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Arraste para mover, ajuste o zoom e centralize o rosto perfeitamente',
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
            const SizedBox(height: 20),

            // Conteúdo Principal: 2 Colunas (Canvas de Edição à esquerda, Painel de Controle e Preview à direita)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Coluna 1: Canvas de Edição e Enquadramento
                  Expanded(
                    flex: 11,
                    child: Column(
                      children: [
                        // Caixa do Canvas Interativo com Arraste e Zoom por Scroll
                        Container(
                          width: cropSize + 24,
                          height: cropSize + 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFF080C14),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E2838) : const Color(0xFFE2E8F0),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.cyan,
                                    ),
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(cropSize / 2),
                                    child: SizedBox(
                                      width: cropSize,
                                      height: cropSize,
                                      child: Listener(
                                        onPointerSignal: (event) {
                                          if (event is PointerScrollEvent) {
                                            setState(() {
                                              final delta = -event.scrollDelta.dy * 0.002;
                                              _zoom = (_zoom + delta).clamp(0.6, 4.0);
                                            });
                                          }
                                        },
                                        child: GestureDetector(
                                          onPanUpdate: (details) {
                                            setState(() {
                                              _offsetX += details.delta.dx;
                                              _offsetY += details.delta.dy;
                                            });
                                          },
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              // 1. ÁREA CAPTURADA PELO REPAINT BOUNDARY (sem linhas guias)
                                              RepaintBoundary(
                                                key: _cropBoundaryKey,
                                                child: Container(
                                                  width: cropSize,
                                                  height: cropSize,
                                                  color: const Color(0xFF0F172A),
                                                  child: Transform(
                                                    alignment: Alignment.center,
                                                    transform: Matrix4.identity()
                                                      ..translate(_offsetX, _offsetY)
                                                      ..rotateZ(radians)
                                                      ..scale(effectiveScale),
                                                    child: Center(
                                                      child: Image.memory(
                                                        _currentBytes,
                                                        fit: BoxFit.contain,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // 2. OVERLAY VISUAL DE ENQUADRAMENTO (Fora do RepaintBoundary)
                                              IgnorePointer(
                                                child: CustomPaint(
                                                  size: const Size(cropSize, cropSize),
                                                  painter: CropGuidePainter(
                                                    showGrid: _showGrid,
                                                    borderColor: AppColors.cyan,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Barra de Ferramentas de Zoom & Ajustes Rápidos
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF131A26) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E2838) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            children: [
                              // Slider de Zoom
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.zoom_out, size: 18),
                                    tooltip: 'Reduzir Zoom',
                                    onPressed: () => setState(() => _zoom = (_zoom - 0.1).clamp(0.6, 4.0)),
                                  ),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: AppColors.cyan,
                                        thumbColor: AppColors.cyan,
                                        inactiveTrackColor: isDark ? const Color(0xFF222F43) : const Color(0xFFCBD5E1),
                                        trackHeight: 4,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                      ),
                                      child: Slider(
                                        value: _zoom,
                                        min: 0.6,
                                        max: 4.0,
                                        onChanged: (v) => setState(() => _zoom = v),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.zoom_in, size: 18),
                                    tooltip: 'Aumentar Zoom',
                                    onPressed: () => setState(() => _zoom = (_zoom + 0.1).clamp(0.6, 4.0)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF222F43) : const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                    child: Text(
                                      '${(_zoom * 100).toInt()}%',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.cyan,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const Divider(height: 10, thickness: 0.8),

                              // Botões de Ação: Giro 90°, Resetar, Grid e Micro-Ajuste
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Botão Girar 90°
                                  TextButton.icon(
                                    onPressed: _rotateClockwise,
                                    icon: const Icon(Icons.rotate_right_rounded, size: 16),
                                    label: const Text('Girar 90°', style: TextStyle(fontSize: 11)),
                                    style: TextButton.styleFrom(
                                      foregroundColor: isDark ? Colors.white70 : const Color(0xFF334155),
                                    ),
                                  ),

                                  // Botão Resetar Centralização
                                  TextButton.icon(
                                    onPressed: _resetPosition,
                                    icon: const Icon(Icons.filter_center_focus_rounded, size: 16),
                                    label: const Text('Centralizar', style: TextStyle(fontSize: 11)),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.cyan,
                                    ),
                                  ),

                                  // Alternar Linhas Guias / Crosshairs
                                  TextButton.icon(
                                    onPressed: () => setState(() => _showGrid = !_showGrid),
                                    icon: Icon(_showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded, size: 16),
                                    label: Text(_showGrid ? 'Guias On' : 'Guias Off', style: const TextStyle(fontSize: 11)),
                                    style: TextButton.styleFrom(
                                      foregroundColor: isDark ? Colors.white60 : const Color(0xFF64748B),
                                    ),
                                  ),

                                  // Micro-Ajuste Direcional (D-pad compacto)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _miniNudgeBtn(Icons.arrow_back, () => _nudge(-6, 0), 'Mover esquerda'),
                                      _miniNudgeBtn(Icons.arrow_upward, () => _nudge(0, -6), 'Mover cima'),
                                      _miniNudgeBtn(Icons.arrow_downward, () => _nudge(0, 6), 'Mover baixo'),
                                      _miniNudgeBtn(Icons.arrow_forward, () => _nudge(6, 0), 'Mover direita'),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 20),

                  // Coluna 2: Pré-visualização em Tempo Real e Informações
                  Expanded(
                    flex: 9,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card de Pré-visualização do Perfil
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF101622) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E2838) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.cyan.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.visibility_outlined, size: 14, color: AppColors.cyan),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'COMO VAI FICAR NO SISTEMA',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                      color: AppColors.cyan,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Avatar Grande (Preview 96px)
                              Row(
                                children: [
                                  Container(
                                    width: 92,
                                    height: 92,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.cyan, width: 2.2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.cyan.withOpacity(0.3),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Transform.scale(
                                        scale: 92 / cropSize,
                                        child: SizedBox(
                                          width: cropSize,
                                          height: cropSize,
                                          child: Transform(
                                            alignment: Alignment.center,
                                            transform: Matrix4.identity()
                                              ..translate(_offsetX, _offsetY)
                                              ..rotateZ(radians)
                                              ..scale(effectiveScale),
                                            child: Center(
                                              child: Image.memory(
                                                _currentBytes,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.userName ?? 'Militar Responsável',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.cyan.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
                                          ),
                                          child: Text(
                                            widget.postoGraduacao ?? 'EFETIVO MILITAR',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.cyan,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Tamanho oficial de exibição no cabeçalho e perfil.',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),
                              const Divider(height: 1),
                              const SizedBox(height: 14),

                              // Avatar Pequeno (Barra lateral / Cautelas - 36px)
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.cyan.withOpacity(0.7), width: 1.5),
                                    ),
                                    child: ClipOval(
                                      child: Transform.scale(
                                        scale: 36 / cropSize,
                                        child: SizedBox(
                                          width: cropSize,
                                          height: cropSize,
                                          child: Transform(
                                            alignment: Alignment.center,
                                            transform: Matrix4.identity()
                                              ..translate(_offsetX, _offsetY)
                                              ..rotateZ(radians)
                                              ..scale(effectiveScale),
                                            child: Center(
                                              child: Image.memory(
                                                _currentBytes,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Exibição na barra lateral e histórico',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Card de Dicas de Enquadramento
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF101622) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E2838) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.lightbulb_outline_rounded, size: 15, color: Colors.amber),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Dicas de Enquadramento:',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _buildBulletText('Clique e arraste a imagem com o mouse para mover.', isDark),
                              _buildBulletText('Use a roda do mouse ou o slider para dar zoom no rosto.', isDark),
                              _buildBulletText('Alinhe os olhos ou nariz com as linhas guias centrais.', isDark),
                              _buildBulletText('Gire a foto em 90° caso esteja na orientação errada.', isDark),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Botão Escolher Outra Foto
                        OutlinedButton.icon(
                          onPressed: _pickAnotherImage,
                          icon: const Icon(Icons.folder_open_rounded, size: 16),
                          label: const Text('Escolher Outro Arquivo'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? Colors.white70 : const Color(0xFF334155),
                            side: BorderSide(
                              color: isDark ? const Color(0xFF2E3D52) : const Color(0xFFCBD5E1),
                            ),
                            minimumSize: const Size(double.infinity, 40),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Rodapé com Ações
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isExporting ? null : _exportAndSave,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(_isExporting ? 'Processando...' : 'Confirmar e Aplicar Foto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniNudgeBtn(IconData icon, VoidCallback onTap, String tooltip) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2838) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 13, color: isDark ? Colors.white70 : const Color(0xFF334155)),
        ),
      ),
    );
  }

  Widget _buildBulletText(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.cyan, fontSize: 12, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pintor customizado para overlay de corte com vinheta escura, anel neon ciano
/// e mira/grid central de alinhamento facial.
class CropGuidePainter extends CustomPainter {
  final bool showGrid;
  final Color borderColor;

  CropGuidePainter({
    this.showGrid = true,
    this.borderColor = const Color(0xFF00D2B4),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Vinheta escura fora do círculo para dar contraste total à foto
    final darkPaint = Paint()
      ..color = Colors.black.withOpacity(0.68)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, darkPaint);

    // 2. Anel de contorno neon ciano
    final ringPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius, ringPaint);

    // 3. Grid e Crosshairs para mira e alinhamento facial
    if (showGrid) {
      final gridPaint = Paint()
        ..color = borderColor.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      // Linha vertical central
      canvas.drawLine(
        Offset(center.dx, center.dy - radius * 0.75),
        Offset(center.dx, center.dy + radius * 0.75),
        gridPaint,
      );

      // Linha horizontal central (nível dos olhos/nariz)
      canvas.drawLine(
        Offset(center.dx - radius * 0.75, center.dy),
        Offset(center.dx + radius * 0.75, center.dy),
        gridPaint,
      );

      // Círculo central de mira facial
      final centerDotPaint = Paint()
        ..color = borderColor.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, 14, centerDotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CropGuidePainter oldDelegate) {
    return oldDelegate.showGrid != showGrid || oldDelegate.borderColor != borderColor;
  }
}
