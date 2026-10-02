# Binfae Desktop App 💻

Aplicativo executável nativo oficial para Windows (**`.exe`**) do sistema de gestão de estoque, materiais e TI do BINFAE, desenvolvido em **Flutter Desktop (C++/DirectX)**.

---

## ✨ Recursos do Aplicativo Desktop Nativo

1. **Executável Nativo Windows (Flutter DirectX):**
   - 100% nativo (sem Electron, sem navegadores embutidos ou WebViews lentas).
   - Renderização fluida a 120 FPS acelerada por hardware (DirectX).
   - Instalador automático oficial (`BinfaeDesktop-Setup.exe`) e pacote portátil (`BinfaeDesktop-Portable-x64.zip`).

2. **Arquitetura Offline-First (0ms de resposta):**
   - Banco de dados espelhado em memória e armazenamento local (`SharedPreferences`).
   - Busca instantânea e filtros por status, grupo, subgrupo e local com tempo de resposta em **0ms**, eliminando travamentos.
   - Sincronização inteligente em segundo plano com a API da BINFAE (`https://systeminformaticabinfae.onrender.com`).

3. **Gestão Completa de Estoque & TI:**
   - Cadastro, edição e baixa de materiais com suporte a BMP, Código Interno e Número de Série.
   - Controle a Granel e Unitário com alertas automáticos de estoque mínimo.
   - Gestão de Cautelas Operacionais, Devoluções e Transferência de Locais Físicos.
   - Geração de QR Code patrimonial nativo para leitura e identificação.
   - Gestão de Efetivo Militar (SARAM, Postos/Graduações, Permissões).

---

## 🛠️ Como Executar Localmente

### Pré-requisitos
- Flutter SDK (canal `stable`) com suporte ao Windows habilitado:
  ```powershell
  flutter config --enable-windows-desktop
  ```
- Visual Studio 2022 com a carga de trabalho *"Desenvolvimento para Desktop com C++"*

### Passos
```powershell
# 1. Instalar dependências
flutter pub get

# 2. Executar em modo de desenvolvimento
flutter run -d windows

# 3. Compilar executável release
flutter build windows --release
```

---

## 📦 Compilação Automática no GitHub Actions
Cada commit na branch `main` dispara o workflow `.github/workflows/build-exe.yml`, que compila o Flutter nativo no Windows Server na nuvem e publica o instalador `.exe` e o `.zip` diretamente na aba **Releases** do repositório.
