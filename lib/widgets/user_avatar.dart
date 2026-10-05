import 'dart:convert';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? fotoUrl;
  final String? name;
  final double radius;
  final double iconSize;
  final Color? borderColor;
  final double borderWidth;

  const UserAvatar({
    super.key,
    this.fotoUrl,
    this.name,
    this.radius = 16,
    this.iconSize = 16,
    this.borderColor,
    this.borderWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatarContent;

    if (fotoUrl != null && fotoUrl!.trim().isNotEmpty) {
      final cleanUrl = fotoUrl!.trim();
      if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
        avatarContent = ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.network(
            cleanUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallback(),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: radius * 2,
                height: radius * 2,
                color: const Color(0xFF151D2A),
                child: Center(
                  child: SizedBox(
                    width: iconSize * 0.8,
                    height: iconSize * 0.8,
                    child: const CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF00D2B4)),
                  ),
                ),
              );
            },
          ),
        );
      } else if (cleanUrl.startsWith('data:image')) {
        try {
          final commaIdx = cleanUrl.indexOf(',');
          final b64 = commaIdx != -1 ? cleanUrl.substring(commaIdx + 1) : cleanUrl;
          final bytes = base64Decode(b64);
          avatarContent = ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Image.memory(
              bytes,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallback(),
            ),
          );
        } catch (_) {
          avatarContent = _buildFallback();
        }
      } else {
        avatarContent = _buildFallback();
      }
    } else {
      avatarContent = _buildFallback();
    }

    if (borderWidth > 0 && borderColor != null) {
      return Container(
        width: radius * 2 + borderWidth * 2,
        height: radius * 2 + borderWidth * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor!, width: borderWidth),
        ),
        child: Center(child: avatarContent),
      );
    }

    return avatarContent;
  }

  Widget _buildFallback() {
    String initials = '';
    if (name != null && name!.trim().isNotEmpty) {
      final parts = name!.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts[0].isNotEmpty) {
        initials = parts[0][0].toUpperCase();
      }
    }

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF00D2B4), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: initials.isNotEmpty
            ? Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: radius * 0.75,
                  letterSpacing: -0.5,
                ),
              )
            : Icon(Icons.shield, color: Colors.white, size: iconSize),
      ),
    );
  }
}
