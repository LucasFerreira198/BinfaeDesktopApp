# Binfae Desktop App 💻🛡️

Aplicativo executável nativo oficial para Windows (**`.exe`**) do sistema de gestão de estoque, materiais, efetivo militar e cautelas operacionais do **BINFAE-GL**, desenvolvido em **Flutter Desktop (C++ / DirectX)**.

---

## ✨ Principais Módulos e Diferenciais

### 1. 🚀 Executável Nativo Windows (Sem Electron / Sem WebViews)
- Desenvolvido em **Flutter C++ nativo**, compilado diretamente para código de máquina x64 com aceleração gráfica por hardware via **DirectX**.
- Taxa de quadros estável em **60 a 120 FPS**, consumo mínimo de memória RAM e inicialização instantânea.
- Disponível como instalador automático oficial (`BinfaeDesktop-Setup.exe`) e pacote portátil (`BinfaeDesktop-Portable-x64.zip`).

### 2. ⚡ Arquitetura Offline-First (Tempo de Resposta em 0ms)
- Espelhamento em tempo real do banco de dados na memória RAM e persistência local (`SharedPreferences`).
- Filtros instantâneos por termo de busca, BMP, número de série, localização física e subgrupo com resposta em **0ms**, eliminando qualquer travamento ou espera de rede.
- Sincronização inteligente e assíncrona em segundo plano com a API no Render.

### 3. 🎯 Cautela de Materiais e Missões Operacionais
- **Dois Tipos de Cautela:**
  - **Missões Operacionais:** Abertura rápida informando apenas o nome (início automático `now()`, sem exigência de destino nem previsão de retorno).
  - **Cautelas Fixas:** Destinadas a materiais de permanência prolongada em postos externos.
- **Painel de Acompanhamento:** Abas comutáveis **"Ativas"** e **"Concluídas"**, com barra de progresso visual de devolução de materiais em tempo real.
- **Fluxo Operacional Blindado:**
  - **Passo 1:** Seleção do militar responsável (busca por SARAM, nome de guerra ou nome completo).
  - **Passo 2:** Destaque do **número de telefone no canto direito** (obrigatório para cautela; permite editar e atualiza o cadastro do militar automaticamente no servidor).
  - **Passo 3:** Escolha do material no modo **Individual (Unitário)** ou **Conjunto / Em Lote** (leitor USB consecutivo para o mesmo militar).
- **Descautelação por Scanner USB:** Ao passar o leitor em qualquer material cautelado, o sistema identifica a missão, o militar e o telefone, solicitando confirmação imediata de devolução.
- **Conclusão Automática de Missões:** Ao registrar a devolução do último material pendente, a missão automaticamente recebe `data_fim = now()`, status `CONCLUIDA` e é arquivada na aba de Concluídas.

### 4. 🏷️ Identificação no Estoque Geral
- Qualquer material cautelado exibe uma tarja informativa em destaque na tabela geral e no modal de detalhes informando a missão, militar responsável e telefone de contato.

### 5. 🗄️ Estrutura Física em Árvore Hierárquica
- Organização multinível de locais de armazenamento (`Depósito > Armário > Prateleira`).
- Visualização em árvore com contagem automática de materiais diretos e acumulados em sublocais.

### 6. 🔒 Sessão Estrita de 24h & Correção de Fechamento de App
- **Persistência de Sessão:** O usuário não é mais deslogado ao fechar e reabrir o aplicativo. Os dados da conta são mantidos em cache seguro, prevenindo quedas por instabilidade de rede ou cold start do servidor.
- **Limite Máximo de 24 Horas:** O aplicativo valida a data e hora do login (`login_timestamp`). Se passarem mais de 24 horas, o acesso é encerrado e a tela de login é exibida para segurança da unidade militar.
- **Refresh Token Automático:** Renovação silenciosa de credenciais em segundo plano.

### 7. ⌨️ Atalhos Rápidos de Teclado
- `Ctrl + F`: Foca imediatamente no campo de busca do estoque.
- `Ctrl + N`: Abre o modal de cadastro de novo material.
- `F5`: Força a sincronização completa de dados com a API na nuvem.
- `Esc`: Fecha modais ou janelas de detalhes abertas.

### 8. 🔄 In-App Auto-Updater Integrado
- O executável verifica automaticamente novos lançamentos oficiais no GitHub Releases.
- Se houver uma nova versão, exibe modal intuitivo com notas de lançamento e link direto de download do `.exe`.

---

## 🛠️ Tecnologias Utilizadas

- **Linguagem & Framework:** Dart & Flutter Desktop SDK 3.x (Windows Runner C++)
- **Gerenciamento de Estado:** `provider`
- **Comunicação REST:** `http` com codificação UTF-8
- **Persistência Local:** `shared_preferences`
- **Geração de QR Code & PDF:** `qr_flutter`, `pdf`, `printing`
- **Compilação CI/CD:** GitHub Actions (Windows Server)

---

## 🚀 Como Executar e Compilar Localmente

### Pré-requisitos
1. Flutter SDK instalado (canal `stable`):
   ```powershell
   flutter config --enable-windows-desktop
   ```
2. Visual Studio 2022 Community com a carga de trabalho:
   - *"Desenvolvimento para Desktop com C++"*
   - *Windows 10/11 SDK*

### Executando em Desenvolvimento
```powershell
# 1. Instalar pacotes e dependências
flutter pub get

# 2. Executar no Windows
flutter run -d windows
```

### Compilando Executável Release Oficial (.exe)
```powershell
flutter build windows --release
```
O executável compilado estará disponível em:
`build\windows\x64\runner\Release\binfae_desktop.exe`

---

## 📦 CI/CD Automático no GitHub Actions
Cada commit enviado para a branch `main` dispara o workflow `.github/workflows/build-exe.yml`, que:
1. Prepara o ambiente Windows Server na nuvem.
2. Compila o binário de release nativo.
3. Empacota o instalador oficial (`BinfaeDesktop-Setup.exe`) e o arquivo portátil (`BinfaeDesktop-Portable-x64.zip`).
4. Publica os executáveis diretamente na aba **Releases** do repositório para download da equipe.
