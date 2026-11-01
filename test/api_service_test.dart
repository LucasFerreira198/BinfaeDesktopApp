import 'package:flutter_test/flutter_test.dart';
import 'package:binfae_desktop_app/services/api_service.dart';

void main() {
  group('ApiService & Security Config Tests', () {
    test('sanitizeProxyHost remove protocolo e caminhos', () {
      expect(ApiService.sanitizeProxyHost('https://proxy.fab.mil.br/'), 'proxy.fab.mil.br');
      expect(ApiService.sanitizeProxyHost('http://10.0.0.1:8080'), '10.0.0.1');
      expect(ApiService.sanitizeProxyHost('  proxy.local:3128/auth '), 'proxy.local');
    });

    test('sanitizeProxyPort extrai porta ou fallback correto', () {
      expect(ApiService.sanitizeProxyPort('proxy.fab.mil.br:8080', 3128), 8080);
      expect(ApiService.sanitizeProxyPort('proxy.fab.mil.br', 3128), 3128);
      expect(ApiService.sanitizeProxyPort('proxy.fab.mil.br:invalid', 8080), 8080);
    });

    test('AppHttpOverrides padroniza bypassSsl como false para seguranca estrita', () {
      final overrides = AppHttpOverrides(
        enabled: true,
        host: 'proxy.fab.mil.br',
        port: 8080,
      );
      expect(overrides.bypassSsl, isFalse);
    });
  });
}
