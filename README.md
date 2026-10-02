# Binfae Desktop App 💻

Aplicativo executável oficial para Windows (**`.exe`**) do sistema de gestão de estoque, materiais e TI do BINFAE.

---

## ✨ Recursos do Aplicativo Desktop

1. **Executável Nativo Windows (.exe):**
   - Instalador padrão (NSIS) e versão portátil (Portable `.exe`) que roda sem precisar instalar dependências.
   - Acesso nativo a impressoras térmicas e a laser para impressão de termos de cautela e etiquetas patrimoniais com QR Code.

2. **Arquitetura Offline-First (0ms de resposta):**
   - Mantém uma cópia sincronizada dos dados em memória e armazenamento local.
   - Pesquisa ampla, filtros por status, grupo, subgrupo e local com resposta instantânea (0ms), mesmo em conexões lentas ou com o servidor em hibernação.
   - Sincronização automática em segundo plano com o backend (`https://systeminformaticabinfae.onrender.com`).

3. **Gestão Completa de Estoque & TI:**
   - Cadastro, edição e baixa de materiais com suporte a BMP, Código Interno e Número de Série.
   - Controle a Granel e Unitário com alertas automáticos de estoque mínimo.
   - Gestão de Cautelas Operacionais, Devoluções e Transferência de Locais Físicos.
   - Emissão de Termos de Cautela e Etiquetas de QR Code em lote ou individuais.
   - Gestão de Efetivo Militar (SARAM, Postos/Graduações, Permissões).
   - Auditoria completa de movimentações.

---

## 🛠️ Como Executar Localmente

### Pré-requisitos
- Node.js 20+
- npm

### Passos
```bash
# 1. Instalar dependências
npm install

# 2. Iniciar em modo de desenvolvimento
npm start

# 3. Gerar os executáveis (.exe)
npm run dist
```

---

## 📦 Compilação Automática no GitHub Actions
Cada commit na branch `main` dispara o workflow `.github/workflows/build-exe.yml`, que compila o executável na nuvem e publica os instaladores diretamente na aba **Releases** do repositório.
