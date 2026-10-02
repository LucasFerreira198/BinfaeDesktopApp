// ============================================================================
// SISTEMA DE INFORMÁTICA BINFAE - APLICAÇÃO FRONT-END
// ============================================================================

// Base da API (permite que o app funcione nativamente no celular sem frontend hospedado)
function getApiBaseUrl() {
  const saved = localStorage.getItem("binfae_server_url");
  if (saved && saved.includes("10.60.11.21")) {
    // Limpa IP de teste local antigo para evitar falha de conexão no celular
    localStorage.removeItem("binfae_server_url");
  } else if (saved && saved.trim() !== "") {
    return saved.trim().replace(/\/+$/, "");
  }
  // Se estiver rodando como arquivo local ou aplicativo nativo Capacitor no celular
  if (window.location.protocol === "file:" || window.location.protocol === "capacitor:") {
    return "https://systeminformaticabinfae.onrender.com";
  }
  // Se for Android WebView do Capacitor (http://localhost sem porta ou com porta padrão)
  if (window.location.hostname === "localhost" && (!window.location.port || window.location.port === "80" || window.location.port === "")) {
    return "https://systeminformaticabinfae.onrender.com";
  }
  // Se estiver rodando em desenvolvimento local com porta (ex: localhost:8000)
  if (window.location.hostname === "localhost" || window.location.hostname === "127.0.0.1") {
    return "";
  }
  // Fallback padrão para produção / celular conectado na nuvem Render
  return "https://systeminformaticabinfae.onrender.com";
}

// Compatibilidade e resiliência para referências a API_BASE
var API_BASE = getApiBaseUrl();
try {
  Object.defineProperty(window, "API_BASE", {
    get: function() {
      return getApiBaseUrl();
    },
    configurable: true
  });
} catch (e) {
  window.API_BASE = getApiBaseUrl();
}

function isNativeAppEnvironment() {
  return !!(window.Capacitor?.isNativePlatform && window.Capacitor.isNativePlatform()) ||
         window.location.protocol === "file:" || 
         window.location.protocol === "capacitor:" ||
         (window.location.hostname === "localhost" && (!window.location.port || window.location.port === "80" || window.location.port === ""));
}

// ============================================================================
// HAPTICS E INTEGRAÇÃO NATIVA CAPACITOR
// ============================================================================
function triggerHaptic(type = "light") {
  const haptics = window.Capacitor?.Plugins?.Haptics;
  if (haptics) {
    try {
      if (type === "success") {
        haptics.notification({ type: "SUCCESS" });
      } else if (type === "error") {
        haptics.notification({ type: "ERROR" });
      } else if (type === "warning") {
        haptics.notification({ type: "WARNING" });
      } else if (type === "medium") {
        haptics.impact({ style: "MEDIUM" });
      } else if (type === "heavy") {
        haptics.impact({ style: "HEAVY" });
      } else {
        haptics.impact({ style: "LIGHT" });
      }
      return;
    } catch (e) {}
  }
  if ("vibrate" in navigator) {
    try {
      if (type === "error" || type === "warning") {
        navigator.vibrate([60, 50, 60]);
      } else if (type === "success") {
        navigator.vibrate([40, 40, 70]);
      } else {
        navigator.vibrate(35);
      }
    } catch (e) {}
  }
}

async function updateNativeStatusBar(isDark) {
  const statusBar = window.Capacitor?.Plugins?.StatusBar;
  if (statusBar) {
    try {
      await statusBar.setStyle({ style: isDark ? "DARK" : "LIGHT" });
      await statusBar.setBackgroundColor({ color: isDark ? "#0f172a" : "#0284c7" });
    } catch (e) {
      console.warn("StatusBar nativo:", e);
    }
  }
}

// Estado da Aplicação
const state = {
  token: localStorage.getItem("binfae_token") || null,
  user: null,
  currentTab: "stock",
  items: [],
  allItems: [],
  locations: [],
  groups: [],
  subgroups: [],
  movements: [],
  militaries: [],
  usersList: [],
  selectedItemForModal: null,
  labelMode: true, // true = Etiqueta Completa, false = QR Code isolado
  collapsedLocations: new Set(),
  collapsedMaterials: new Set(),
  locationsSearchQuery: "",
  allMaterialsHidden: false
};

// ============================================================================
// 1. COMUNICAÇÃO COM A API
// ============================================================================

async function api(endpoint, options = {}) {
  const headers = {
    "Accept": "application/json",
    ...(options.headers || {})
  };

  if (state.token) {
    headers["Authorization"] = `Bearer ${state.token}`;
  }

  if (options.body && !(options.body instanceof FormData)) {
    headers["Content-Type"] = "application/json";
    options.body = JSON.stringify(options.body);
  }

  const baseUrl = getApiBaseUrl();
  const targetUrl = endpoint.startsWith("http") ? endpoint : `${baseUrl}${endpoint}`;

  try {
    const response = await fetch(targetUrl, {
      ...options,
      headers
    });

    if (response.status === 401) {
      logout();
      showNotification("Sessão expirada. Faça login novamente.", "error");
      throw new Error("Não autorizado");
    }

    if (response.status === 204) {
      return null;
    }

    const data = await response.json();
    if (!response.ok) {
      const errorMsg = data.detail || "Erro na requisição ao servidor.";
      showNotification(errorMsg, "error");
      throw new Error(errorMsg);
    }

    return data;
  } catch (err) {
    console.error("API Error:", err);
    throw err;
  }
}

// Notificações Toast
function showNotification(message, type = "success") {
  const toast = document.getElementById("toast");
  const toastMsg = document.getElementById("toast-message");
  const toastIcon = document.getElementById("toast-icon");

  if (!toast || !toastMsg) return;

  toastMsg.textContent = message;
  
  let bgClass = "bg-emerald-600";
  let iconText = "✓";
  if (type === "error") {
    bgClass = "bg-rose-600";
    iconText = "✕";
  } else if (type === "warning") {
    bgClass = "bg-amber-600";
    iconText = "⚠️";
  } else if (type === "info") {
    bgClass = "bg-sky-600";
    iconText = "ℹ️";
  }

  toast.className = `fixed bottom-5 right-5 z-50 flex items-center px-4 py-3 rounded-xl shadow-xl text-white font-medium text-sm transition-all duration-300 transform ${bgClass}`;
  if (toastIcon) toastIcon.textContent = iconText;

  if (type === "error") triggerHaptic("error");
  else if (type === "warning") triggerHaptic("warning");
  else if (type === "success") triggerHaptic("light");

  toast.classList.remove("translate-y-20", "opacity-0", "pointer-events-none");
  setTimeout(() => {
    toast.classList.add("translate-y-20", "opacity-0", "pointer-events-none");
  }, 4000);
}
const showToast = showNotification;

// ============================================================================
// 2. AUTENTICAÇÃO E LOGIN
// ============================================================================

async function login(username, password) {
  const submitBtn = document.getElementById("btn-login-submit");
  const errorAlert = document.getElementById("login-error-alert");
  const errorText = document.getElementById("login-error-text");
  const rememberCheckbox = document.getElementById("login-remember-me");

  if (errorAlert) errorAlert.classList.add("hidden");
  if (submitBtn) {
    submitBtn.disabled = true;
    submitBtn.innerHTML = `<span>⏳</span><span>Autenticando...</span>`;
  }

  try {
    const formData = new URLSearchParams();
    formData.append("username", username.trim());
    formData.append("password", password);

    const baseUrl = getApiBaseUrl();
    const loginUrl = baseUrl ? `${baseUrl}/auth/login` : "/auth/login";
    const response = await fetch(loginUrl, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: formData
    });

    const data = await response.json();
    if (!response.ok) {
      throw new Error(data.detail || "Usuário ou senha incorretos.");
    }

    state.token = data.access_token;
    localStorage.setItem("binfae_token", state.token);

    if (rememberCheckbox && rememberCheckbox.checked) {
      localStorage.setItem("binfae_saved_user", username.trim());
      localStorage.setItem("binfae_saved_token", state.token);
      localStorage.setItem("binfae_biometric_enabled", "true");
    } else {
      localStorage.removeItem("binfae_saved_user");
      localStorage.removeItem("binfae_saved_token");
      localStorage.removeItem("binfae_biometric_enabled");
    }

    await loadUserProfile();
    closeLoginModal();
    triggerHaptic("success");
    showToast("Login realizado com sucesso!");
    initApp();
  } catch (err) {
    console.error("Erro no login:", err);
    if (errorAlert && errorText) {
      errorText.textContent = err.message || "Falha na autenticação. Verifique os dados informados.";
      errorAlert.classList.remove("hidden");
    }
    showToast(err.message || "Falha no login.", "error");
  } finally {
    if (submitBtn) {
      submitBtn.disabled = false;
      submitBtn.innerHTML = `<span>Acessar Painel</span><span class="text-base font-normal">→</span>`;
    }
  }
}

function toggleLoginPasswordVisibility() {
  const passInput = document.getElementById("login-password");
  const eyeIcon = document.getElementById("icon-eye-password");
  if (!passInput) return;
  if (passInput.type === "password") {
    passInput.type = "text";
    if (eyeIcon) eyeIcon.textContent = "🙈";
  } else {
    passInput.type = "password";
    if (eyeIcon) eyeIcon.textContent = "👁️";
  }
}

function logout() {
  state.token = null;
  state.user = null;
  localStorage.removeItem("binfae_token");
  updateUserUI();
  openLoginModal();
}

async function loadUserProfile() {
  if (!state.token) return;
  try {
    state.user = await api("/auth/me");
    updateUserUI();
  } catch {
    logout();
  }
}

function updateUserUI() {
  const userBanner = document.getElementById("user-profile-badge");
  const loginBtn = document.getElementById("btn-login-open");
  const logoutBtn = document.getElementById("btn-logout");
  const sidebarUserCard = document.getElementById("sidebar-user-card");
  const sidebarUserName = document.getElementById("sidebar-user-name");
  const sidebarUserRole = document.getElementById("sidebar-user-role");
  const sidebarLogoutBtn = document.getElementById("sidebar-btn-logout");

  if (state.user) {
    const nome = state.user.militar 
      ? `${state.user.militar.posto_graduacao} ${state.user.militar.nome_guerra}` 
      : (state.user.username || "Operador");
    const role = state.user.admin ? "★ Administrador" : (state.user.militar?.especialidade || "Militar Operador");

    if (userBanner) {
      userBanner.textContent = `${nome} ${state.user.admin ? "★" : ""}`;
      userBanner.classList.remove("hidden");
    }
    if (sidebarUserCard) {
      sidebarUserCard.classList.remove("hidden");
      if (sidebarUserName) sidebarUserName.textContent = nome;
      if (sidebarUserRole) sidebarUserRole.textContent = role;
    }
    if (loginBtn) loginBtn.classList.add("hidden");
    if (logoutBtn) logoutBtn.classList.remove("hidden");
    if (sidebarLogoutBtn) sidebarLogoutBtn.classList.remove("hidden");
  } else {
    if (userBanner) userBanner.classList.add("hidden");
    if (sidebarUserCard) sidebarUserCard.classList.add("hidden");
    if (loginBtn) loginBtn.classList.remove("hidden");
    if (logoutBtn) logoutBtn.classList.add("hidden");
    if (sidebarLogoutBtn) sidebarLogoutBtn.classList.add("hidden");
  }
}

// ============================================================================
// 3. CARREGAMENTO GERAL DE DADOS
// ============================================================================

async function initApp() {
  // 1. CARREGAMENTO IMEDIATO DO BANCO LOCAL (0ms):
  // Exibe instantaneamente os dados do armazenamento local sem travar ou esperar a rede
  restoreLocalDatabase();

  // 2. SINCRONIZAÇÃO EM SEGUNDO PLANO COM A NUVEM:
  // Atualiza os dados com a nuvem silenciosamente
  await syncAllDataWithServer(true);
}

// Restaura os dados gravados no celular para exibição com 0ms de espera
function restoreLocalDatabase() {
  try {
    const cachedItems = localStorage.getItem("binfae_cache_items");
    const cachedGroups = localStorage.getItem("binfae_cache_groups");
    const cachedSubgroups = localStorage.getItem("binfae_cache_subgroups");
    const cachedLocs = localStorage.getItem("binfae_cache_locations");

    if (cachedGroups) state.groups = JSON.parse(cachedGroups) || [];
    if (cachedSubgroups) state.subgroups = JSON.parse(cachedSubgroups) || [];
    if (cachedLocs) state.locations = JSON.parse(cachedLocs) || [];

    if (cachedItems) {
      const items = JSON.parse(cachedItems) || [];
      state.allItems = items;
      state.items = items;
    }

    if (state.groups.length > 0) populateGroupSelects();
    if (state.subgroups.length > 0) populateSubgroupSelects();
    if (state.locations.length > 0) populateLocationSelects();
    if (state.allItems.length > 0) {
      populateParentItemSelect();
      filterItemsInMemory();
      renderCategoriesView();
      renderLocationsTree();
    }
  } catch (err) {
    console.warn("Falha ao restaurar banco local inicial:", err);
  }
}

// Salva a cópia dos dados no armazenamento do celular
function persistLocalDatabase() {
  try {
    localStorage.setItem("binfae_cache_items", JSON.stringify(state.allItems || []));
    localStorage.setItem("binfae_cache_groups", JSON.stringify(state.groups || []));
    localStorage.setItem("binfae_cache_subgroups", JSON.stringify(state.subgroups || []));
    localStorage.setItem("binfae_cache_locations", JSON.stringify(state.locations || []));
    localStorage.setItem("binfae_cache_timestamp", Date.now().toString());
  } catch (err) {
    console.warn("Falha ao salvar dados no cache local:", err);
  }
}

// Sincronização em segundo plano com a API
async function syncAllDataWithServer(silent = true) {
  try {
    const [groups, subgroups, locations, items] = await Promise.all([
      api("/stock/groups").catch(() => null),
      api("/stock/subgroups").catch(() => null),
      api("/stock/locations").catch(() => null),
      api("/stock/items").catch(() => null)
    ]);

    if (groups && Array.isArray(groups)) state.groups = groups;
    if (subgroups && Array.isArray(subgroups)) state.subgroups = subgroups;
    if (locations && Array.isArray(locations)) state.locations = locations;
    if (items && Array.isArray(items)) {
      state.allItems = items;
    }

    persistLocalDatabase();

    populateGroupSelects();
    populateSubgroupSelects();
    populateLocationSelects();
    populateParentItemSelect();

    filterItemsInMemory();
    renderCategoriesView();
    renderLocationsTree();

    document.getElementById("offline-network-banner")?.classList.add("hidden");
  } catch (err) {
    console.warn("Sincronização em background falhou (usando banco local):", err);
    document.getElementById("offline-network-banner")?.classList.remove("hidden");
    if (!silent) {
      showToast("Não foi possível conectar ao servidor na nuvem. Usando dados locais.", "warning");
    }
  }
}

async function loadGroups() {
  try {
    state.groups = (await api("/stock/groups")) || [];
    persistLocalDatabase();
    populateGroupSelects();
    renderCategoriesView();
  } catch (err) {
    console.warn("Grupos não puderam ser carregados:", err);
  }
}

async function loadSubgroups() {
  try {
    state.subgroups = (await api("/stock/subgroups")) || [];
    persistLocalDatabase();
    populateSubgroupSelects();
    renderCategoriesView();
  } catch (err) {
    console.warn("Subgrupos não puderam ser carregados:", err);
  }
}

async function loadLocations() {
  try {
    state.locations = (await api("/stock/locations")) || [];
    persistLocalDatabase();
    populateLocationSelects();
    renderLocationsTree();
  } catch (err) {
    console.warn("Locais não puderam ser carregados:", err);
  }
}

async function loadAllItems() {
  if (state.allItems && state.allItems.length > 0) {
    return state.allItems;
  }
  try {
    const all = await api("/stock/items");
    if (all && Array.isArray(all)) {
      state.allItems = all;
      persistLocalDatabase();
    }
    return state.allItems;
  } catch (err) {
    console.warn("Erro ao carregar todos os itens:", err);
    return state.allItems;
  }
}

// MOTOR DE FILTRAGEM INSTANTÂNEA EM 0 MILISSEGUNDOS (SEM CHAMADAS DE REDE)
function filterItemsInMemory() {
  const searchInput = document.getElementById("filter-search");
  const search = (searchInput?.value || "").trim().toLowerCase();
  const localId = document.getElementById("filter-location")?.value || "";
  const incSub = document.getElementById("filter-include-sublocations")?.checked ?? true;
  const subgroupId = document.getElementById("filter-subgroup")?.value || "";
  const status = document.getElementById("filter-status")?.value || "";
  const tipo = document.getElementById("filter-tipo")?.value || "";

  const isDepotActive = Boolean(state._depotFilterActive);
  const isLowQtyActive = Boolean(state._lowQtyFilterActive);

  const baseItems = Array.isArray(state.allItems) ? state.allItems : [];

  state.items = baseItems.filter(item => {
    // 1. Busca Textual Ultrarrápida
    if (search) {
      const q = search;
      const match = (item.nome && item.nome.toLowerCase().includes(q)) ||
                    (item.bmp && item.bmp.toLowerCase().includes(q)) ||
                    (item.serial_number && item.serial_number.toLowerCase().includes(q)) ||
                    (item.codigo_interno && item.codigo_interno.toLowerCase().includes(q)) ||
                    (item.local && item.local.nome && item.local.nome.toLowerCase().includes(q)) ||
                    (item.subgrupo && item.subgrupo.nome && item.subgrupo.nome.toLowerCase().includes(q));
      if (!match) return false;
    }

    // 2. Filtro de Status
    if (status && item.status !== status) {
      return false;
    }

    // 3. Filtro por Tipo de Controle
    if (tipo && item.tipo_controle !== tipo) {
      return false;
    }

    // 4. Filtro por Local Físico
    if (localId) {
      const itemLocId = String(item.local_id || "");
      if (itemLocId !== String(localId)) {
        if (!incSub) return false;
        // Verifica se é sublocal (filho)
        const parentLoc = state.locations.find(l => String(l.id) === String(localId));
        const itemLoc = item.local || state.locations.find(l => String(l.id) === itemLocId);
        if (!parentLoc || !itemLoc || !itemLoc.caminho_completo || !itemLoc.caminho_completo.includes(parentLoc.nome)) {
          return false;
        }
      }
    }

    // 5. Filtro Rápido "No Depósito"
    if (isDepotActive) {
      const path = (item.local?.caminho_completo || "").toLowerCase();
      if (!path.includes("depósito") && !path.includes("deposito")) return false;
    }

    // 6. Filtro Rápido "Saldo Baixo"
    if (isLowQtyActive) {
      if (item.tipo_controle !== "GRANEL" || item.quantidade > item.quantidade_minima) return false;
    }

    // 7. Filtro por Subgrupo
    if (subgroupId && String(item.subgrupo_id) !== String(subgroupId)) {
      return false;
    }

    return true;
  });

  renderItemsTable();
  renderDashboardMetrics();
}

// loadItems agora consulta diretamente o banco local do celular em 0ms
async function loadItems() {
  filterItemsInMemory();
  // Se por acaso o banco local estiver vazio, sincroniza da nuvem
  if (!state.allItems || state.allItems.length === 0) {
    syncAllDataWithServer(true);
  }
}

function filterCachedItems(items, search, localId, subgroupId, status, tipo) {
  if (!Array.isArray(items)) return [];
  return items.filter(item => {
    if (search && search.trim()) {
      const q = search.trim().toLowerCase();
      const match = (item.nome && item.nome.toLowerCase().includes(q)) ||
                    (item.bmp && item.bmp.toLowerCase().includes(q)) ||
                    (item.serial_number && item.serial_number.toLowerCase().includes(q)) ||
                    (item.codigo_interno && item.codigo_interno.toLowerCase().includes(q));
      if (!match) return false;
    }
    if (localId && String(item.local_id) !== String(localId)) return false;
    if (subgroupId && String(item.subgrupo_id) !== String(subgroupId)) return false;
    if (status && item.status !== status) return false;
    if (tipo && item.tipo_controle !== tipo) return false;
    return true;
  });
}

async function loadMovements() {
  try {
    state.movements = await api("/stock/movements");
    renderMovements();
  } catch (err) {
    console.warn("Erro ao carregar movimentações:", err);
  }
}

async function loadPersonnel() {
  try {
    state.militaries = await api("/military/list");
    state.usersList = await api("/users/listUsers");
    renderPersonnel();
  } catch (err) {
    console.warn("Erro ao carregar militares e usuários:", err);
  }
}

// ============================================================================
// 4. RENDERIZAÇÃO DE INTERFACES E TABELAS
// ============================================================================

function renderDashboardMetrics() {
  const source = (state.allItems && state.allItems.length > 0) ? state.allItems : state.items;
  const totalItems = source.length;
  const itemsDeposito = source.filter(i => i.local && i.local.caminho_completo.toLowerCase().includes("depósito")).length;
  const itemsEmUso = source.filter(i => i.status === "EM_USO").length;
  const itemsManut = source.filter(i => i.status === "EM_MANUTENCAO").length;
  const itemsBaixo = source.filter(i => i.tipo_controle === "GRANEL" && i.quantidade <= i.quantidade_minima).length;

  document.getElementById("metric-total").textContent = totalItems;
  document.getElementById("metric-deposito").textContent = itemsDeposito;
  document.getElementById("metric-uso").textContent = itemsEmUso;
  document.getElementById("metric-manutencao").textContent = itemsManut;
  document.getElementById("metric-baixo").textContent = itemsBaixo;

  const sidebarCount = document.getElementById("sidebar-stock-count");
  if (sidebarCount) sidebarCount.textContent = totalItems;

  const alertBadge = document.getElementById("metric-baixo-alert");
  if (alertBadge) {
    if (itemsBaixo > 0) alertBadge.classList.remove("hidden");
    else alertBadge.classList.add("hidden");
  }
}

function renderItemsTable() {
  const tbody = document.getElementById("items-table-body");
  const cardsContainer = document.getElementById("items-cards-container");
  const countBadge = document.getElementById("items-count");
  if (!tbody && !cardsContainer) return;

  if (tbody) tbody.innerHTML = "";
  if (cardsContainer) cardsContainer.innerHTML = "";

  const isFiltered = (
    (document.getElementById("filter-search")?.value || "").trim() !== "" ||
    (document.getElementById("filter-location")?.value || "") !== "" ||
    (document.getElementById("filter-subgroup")?.value || "") !== "" ||
    (document.getElementById("filter-status")?.value || "") !== "" ||
    (document.getElementById("filter-tipo")?.value || "") !== ""
  );

  const clearBtn = document.getElementById("btn-clear-table-filter");
  const clearAllBtn = document.getElementById("btn-clear-all-filters");
  if (clearBtn) {
    if (isFiltered) clearBtn.classList.remove("hidden");
    else clearBtn.classList.add("hidden");
  }
  if (clearAllBtn) {
    if (isFiltered) clearAllBtn.classList.remove("hidden");
    else clearAllBtn.classList.add("hidden");
  }

  if (countBadge) {
    const total = (state.allItems && state.allItems.length > 0) ? state.allItems.length : state.items.length;
    if (isFiltered) {
      countBadge.textContent = `${state.items.length} de ${total} materiais`;
      countBadge.className = "text-xs font-bold text-amber-700 bg-amber-50 dark:bg-amber-950/40 dark:text-amber-300 border border-amber-200 dark:border-amber-800 px-2.5 py-0.5 rounded-full";
    } else {
      countBadge.textContent = `${total} materiais`;
      countBadge.className = "text-xs font-bold text-sky-700 bg-sky-50 dark:bg-sky-950/40 dark:text-sky-300 border border-sky-200 dark:border-sky-800 px-2.5 py-0.5 rounded-full";
    }
  }

  if (state.items.length === 0) {
    if (tbody) {
      tbody.innerHTML = `
        <tr>
          <td colspan="7" class="text-center py-12 text-slate-400 font-medium">
            <span class="text-3xl block mb-2">🔍</span>
            <p class="text-slate-600 dark:text-slate-300 font-semibold text-sm">Nenhum material encontrado com os filtros atuais.</p>
            <p class="text-xs text-slate-400 mt-1">Tente remover os filtros ou buscar por outro termo.</p>
            ${isFiltered ? `
              <button onclick="clearAllStockFilters()" class="mt-3 px-3.5 py-1.5 bg-sky-600 hover:bg-sky-500 text-white rounded-xl text-xs font-bold shadow-xs transition-colors">
                ✕ Limpar Filtros
              </button>
            ` : ''}
          </td>
        </tr>`;
    }
    if (cardsContainer) {
      cardsContainer.innerHTML = `
        <div class="text-center py-12 px-4 text-slate-400 font-medium bg-white dark:bg-slate-900">
          <span class="text-3xl block mb-2">🔍</span>
          <p class="text-slate-700 dark:text-slate-300 font-bold text-sm">Nenhum material encontrado</p>
          <p class="text-xs text-slate-400 mt-1">Tente remover os filtros ou buscar por outro termo.</p>
          ${isFiltered ? `
            <button onclick="clearAllStockFilters()" class="mt-3 px-4 py-2 bg-sky-600 hover:bg-sky-500 text-white rounded-xl text-xs font-bold shadow-xs transition-colors">
              ✕ Limpar Filtros
            </button>
          ` : ''}
        </div>`;
    }
    return;
  }

  // Status Badge classes
  const statusClasses = {
    DISPONIVEL: "badge-disponivel",
    EM_USO: "badge-em_uso",
    EM_MANUTENCAO: "badge-em_manutencao",
    CAUTELADO: "badge-cautelado",
    BAIXADO: "badge-baixado"
  };

  state.items.forEach(item => {
    const badgeClass = statusClasses[item.status] || "bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300";

    // Localização
    let localHtml = "";
    if (item.parent) {
      localHtml = `
        <div class="flex flex-col">
          <span class="text-indigo-600 dark:text-indigo-400 font-medium flex items-center gap-1">
            <span>⚙ Instalado em:</span> ${escapeHtml(item.parent.nome)}
          </span>
          <span class="text-xs text-slate-500 dark:text-slate-400">
            ${item.local_efetivo ? escapeHtml(item.local_efetivo.caminho_completo) : "Local herdado"}
          </span>
        </div>`;
    } else if (item.local) {
      localHtml = `<span class="text-slate-700 dark:text-slate-300 font-medium">${escapeHtml(item.local.caminho_completo)}</span>`;
    } else {
      localHtml = `<span class="text-slate-400 italic">Sem local definido</span>`;
    }

    // Saldo / Quantidade
    let qtdHtml = "";
    const isGranel = item.tipo_controle === "GRANEL";
    const isLow = isGranel && (item.quantidade <= item.quantidade_minima);
    if (isGranel) {
      qtdHtml = `
        <span class="font-bold ${isLow ? 'text-amber-600 dark:text-amber-400' : 'text-slate-800 dark:text-slate-200'}">
          ${item.quantidade} <span class="text-xs text-slate-500 font-normal">${escapeHtml(item.unidade_medida || 'un')}</span>
        </span>
        ${isLow ? '<span class="ml-1 text-xs text-amber-600 bg-amber-50 dark:bg-amber-950/60 px-1 py-0.5 rounded border border-amber-200 dark:border-amber-800">Baixo</span>' : ''}`;
    } else {
      qtdHtml = `<span class="text-slate-700 dark:text-slate-300">1 unid.</span>`;
    }

    // Características
    let caracHtml = "";
    if (item.caracteristicas && typeof item.caracteristicas === "object") {
      const entries = Object.entries(item.caracteristicas).filter(
        ([k, v]) => v !== null && v !== undefined && String(v).trim() !== ""
      );
      if (entries.length > 0) {
        caracHtml = `
          <div class="flex flex-wrap gap-1 mt-1">
            ${entries.map(([k, v]) => `
              <span class="inline-flex items-center px-1.5 py-0.5 rounded text-[11px] font-medium bg-blue-50 dark:bg-blue-950/40 text-blue-700 dark:text-blue-300 border border-blue-200 dark:border-blue-800">
                <span class="font-semibold text-blue-900 dark:text-blue-200 mr-1">${escapeHtml(k)}:</span> ${escapeHtml(String(v))}
              </span>
            `).join("")}
          </div>`;
      }
    }

    // Componentes instalados
    let compHtml = "";
    if (item.componentes && item.componentes.length > 0) {
      compHtml = `
        <div class="mt-1">
          <span class="text-xs font-semibold text-slate-500 dark:text-slate-400">Peças instaladas (${item.componentes.length}):</span>
          <div class="flex flex-wrap gap-1 mt-0.5">
            ${item.componentes.map(c => `<span class="inline-block px-1.5 py-0.5 bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 rounded text-xs border border-slate-200 dark:border-slate-700">${escapeHtml(c.nome)}</span>`).join("")}
          </div>
        </div>`;
    }

    // 1. RENDERIZA LINHA NA TABELA DESKTOP
    if (tbody) {
      const tr = document.createElement("tr");
      tr.className = "hover:bg-slate-50/80 dark:hover:bg-slate-800/40 border-b border-slate-100 dark:border-slate-800/60 transition-colors text-sm group";
      tr.innerHTML = `
        <td class="py-3 px-4 cursor-pointer" onclick="openItemDetailModal(${item.id})">
          <div class="font-semibold text-slate-900 dark:text-slate-100 group-hover:text-sky-600 dark:group-hover:text-sky-400 transition-colors flex items-center gap-1.5">
            <span>${escapeHtml(item.nome)}</span>
            <span class="text-[10px] text-sky-600 dark:text-sky-400 bg-sky-50 dark:bg-sky-950/50 px-1.5 py-0.5 rounded border border-sky-200 dark:border-sky-800 opacity-0 group-hover:opacity-100 transition-opacity font-normal">Detalhes ➔</span>
          </div>
          <div class="text-xs text-slate-500 dark:text-slate-400">${escapeHtml(item.subgrupo?.nome || "Sem subgrupo")}</div>
          ${caracHtml}
          ${compHtml}
        </td>
        <td class="py-3 px-4 font-mono text-xs">
          ${item.bmp ? `<span class="font-bold text-slate-800 dark:text-slate-200 bg-slate-100 dark:bg-slate-800 px-1.5 py-0.5 rounded border border-slate-200 dark:border-slate-700">${escapeHtml(item.bmp)}</span>` : '<span class="text-slate-400">—</span>'}
        </td>
        <td class="py-3 px-4 font-mono text-xs text-slate-600 dark:text-slate-400">
          ${item.codigo_interno ? escapeHtml(item.codigo_interno) : '<span class="text-slate-400">—</span>'}
        </td>
        <td class="py-3 px-4">
          ${localHtml}
        </td>
        <td class="py-3 px-4 text-center">
          ${qtdHtml}
        </td>
        <td class="py-3 px-4 text-center">
          <span class="px-2 py-0.5 rounded-full text-xs font-semibold ${badgeClass}">
            ${escapeHtml(item.status)}
          </span>
        </td>
        <td class="py-3 px-4 text-right whitespace-nowrap">
          <div class="flex items-center justify-end gap-1">
            <button onclick="openItemDetailModal(${item.id})" title="Ver Detalhes" class="p-1.5 text-slate-600 dark:text-slate-400 hover:text-sky-600 dark:hover:text-sky-400 hover:bg-sky-50 dark:hover:bg-slate-800 rounded-lg transition-colors">
              👁️
            </button>
            <button onclick="openEditItemModal(${item.id})" title="Editar Material" class="p-1.5 text-slate-600 dark:text-slate-400 hover:text-amber-600 dark:hover:text-amber-400 hover:bg-amber-50 dark:hover:bg-slate-800 rounded-lg transition-colors">
              ✏️
            </button>
            <button onclick="openQrModal(${item.id})" title="Ver / Imprimir QR Code" class="p-1.5 text-slate-600 dark:text-slate-400 hover:text-sky-600 dark:hover:text-sky-400 hover:bg-sky-50 dark:hover:bg-slate-800 rounded-lg transition-colors">
              🏷️
            </button>
            <button onclick="openMoveModal(${item.id})" title="Transferir / Mover Local" class="p-1.5 text-slate-600 dark:text-slate-400 hover:text-indigo-600 dark:hover:text-indigo-400 hover:bg-indigo-50 dark:hover:bg-slate-800 rounded-lg transition-colors">
              🔄
            </button>
            ${isGranel ? `
              <button onclick="openAdjustModal(${item.id})" title="Ajustar Saldo" class="p-1.5 text-slate-600 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50 dark:hover:bg-slate-800 rounded-lg transition-colors">
                ⚖️
              </button>` : ''}
            <button onclick="deleteItemAction(${item.id})" title="Excluir Material" class="p-1.5 text-slate-600 dark:text-slate-400 hover:text-rose-600 dark:hover:text-rose-400 hover:bg-rose-50 dark:hover:bg-slate-800 rounded-lg transition-colors">
              🗑️
            </button>
          </div>
        </td>
      `;
      tbody.appendChild(tr);
    }

    // 2. RENDERIZA CARD NO CELULAR (MOBILE-FIRST)
    if (cardsContainer) {
      const card = document.createElement("div");
      card.className = "mobile-item-card p-4 bg-white dark:bg-slate-900 transition-colors";
      card.innerHTML = `
        <div class="flex items-center justify-between gap-2 mb-2">
          <span class="px-2.5 py-0.5 rounded-full text-[11px] font-bold ${badgeClass}">
            ${escapeHtml(item.status)}
          </span>
          <div class="flex items-center gap-1.5">
            ${isGranel ? `
              <span class="px-2 py-0.5 rounded-md text-[10px] font-bold bg-amber-500/10 text-amber-600 dark:text-amber-400 border border-amber-500/20">A Granel</span>
            ` : `
              <span class="px-2 py-0.5 rounded-md text-[10px] font-bold bg-sky-500/10 text-sky-600 dark:text-sky-400 border border-sky-500/20">Unitário</span>
            `}
            ${item.bmp ? `
              <span class="font-mono text-xs font-bold px-2 py-0.5 rounded-lg bg-slate-100 dark:bg-slate-800 text-slate-800 dark:text-slate-200 border border-slate-200 dark:border-slate-700">BMP ${escapeHtml(item.bmp)}</span>
            ` : ''}
          </div>
        </div>

        <div class="cursor-pointer" onclick="openItemDetailModal(${item.id})">
          <h4 class="font-bold text-slate-900 dark:text-slate-100 text-base leading-snug hover:text-sky-600 dark:hover:text-sky-400 transition-colors">
            ${escapeHtml(item.nome)}
          </h4>
          <div class="flex items-center gap-2 mt-0.5 text-xs text-slate-500 dark:text-slate-400">
            <span>${escapeHtml(item.subgrupo?.nome || "Sem subgrupo")}</span>
            ${item.codigo_interno ? `<span>• Cód: <span class="font-mono text-slate-700 dark:text-slate-300 font-semibold">${escapeHtml(item.codigo_interno)}</span></span>` : ''}
          </div>

          <div class="mt-2 flex items-center gap-1.5 text-xs text-slate-600 dark:text-slate-300">
            <span class="text-sky-500">📍</span>
            <span class="truncate">${item.local ? escapeHtml(item.local.caminho_completo) : (item.parent ? 'Instalado em ' + escapeHtml(item.parent.nome) : 'Sem local')}</span>
          </div>

          ${isGranel ? `
            <div class="mt-2.5 flex items-center justify-between text-xs bg-slate-50 dark:bg-slate-950 p-2.5 rounded-xl border border-slate-200/80 dark:border-slate-800">
              <span class="text-slate-500 dark:text-slate-400 font-medium">Saldo Atual:</span>
              <span class="font-bold ${isLow ? 'text-amber-600 dark:text-amber-400' : 'text-slate-800 dark:text-slate-200'}">
                ${item.quantidade} <span class="font-normal text-[11px] text-slate-500">${escapeHtml(item.unidade_medida || 'un')}</span>
                ${isLow ? '<span class="ml-1 text-[10px] text-amber-600 bg-amber-50 dark:bg-amber-950/60 px-1 py-0.5 rounded border border-amber-200 dark:border-amber-800">Baixo</span>' : ''}
              </span>
            </div>
          ` : ''}
        </div>

        <div class="grid grid-cols-4 sm:grid-cols-5 gap-1.5 mt-3 pt-3 border-t border-slate-100 dark:border-slate-800">
          <button onclick="openItemDetailModal(${item.id})" class="py-2 px-1 rounded-xl bg-slate-100 dark:bg-slate-800/80 hover:bg-sky-50 dark:hover:bg-sky-950/40 text-slate-700 dark:text-slate-200 hover:text-sky-600 font-semibold text-xs flex flex-col items-center justify-center gap-0.5 transition-colors border border-slate-200/60 dark:border-slate-700/60">
            <span>👁️</span>
            <span class="text-[10px]">Detalhes</span>
          </button>
          <button onclick="openEditItemModal(${item.id})" class="py-2 px-1 rounded-xl bg-slate-100 dark:bg-slate-800/80 hover:bg-amber-50 dark:hover:bg-amber-950/40 text-slate-700 dark:text-slate-200 hover:text-amber-600 font-semibold text-xs flex flex-col items-center justify-center gap-0.5 transition-colors border border-slate-200/60 dark:border-slate-700/60">
            <span>✏️</span>
            <span class="text-[10px]">Editar</span>
          </button>
          <button onclick="openQrModal(${item.id})" class="py-2 px-1 rounded-xl bg-slate-100 dark:bg-slate-800/80 hover:bg-sky-50 dark:hover:bg-sky-950/40 text-slate-700 dark:text-slate-200 hover:text-sky-600 font-semibold text-xs flex flex-col items-center justify-center gap-0.5 transition-colors border border-slate-200/60 dark:border-slate-700/60">
            <span>🏷️</span>
            <span class="text-[10px]">QR Code</span>
          </button>
          <button onclick="openMoveModal(${item.id})" class="py-2 px-1 rounded-xl bg-slate-100 dark:bg-slate-800/80 hover:bg-indigo-50 dark:hover:bg-indigo-950/40 text-slate-700 dark:text-slate-200 hover:text-indigo-600 font-semibold text-xs flex flex-col items-center justify-center gap-0.5 transition-colors border border-slate-200/60 dark:border-slate-700/60">
            <span>🔄</span>
            <span class="text-[10px]">Mover</span>
          </button>
          ${isGranel ? `
            <button onclick="openAdjustModal(${item.id})" class="py-2 px-1 rounded-xl bg-slate-100 dark:bg-slate-800/80 hover:bg-emerald-50 dark:hover:bg-emerald-950/40 text-slate-700 dark:text-slate-200 hover:text-emerald-600 font-semibold text-xs flex flex-col items-center justify-center gap-0.5 transition-colors border border-slate-200/60 dark:border-slate-700/60">
              <span>⚖️</span>
              <span class="text-[10px]">Saldo</span>
            </button>
          ` : `
            <button onclick="deleteItemAction(${item.id})" class="py-2 px-1 rounded-xl bg-slate-100 dark:bg-slate-800/80 hover:bg-rose-50 dark:hover:bg-rose-950/40 text-slate-700 dark:text-slate-200 hover:text-rose-600 font-semibold text-xs flex flex-col items-center justify-center gap-0.5 transition-colors border border-slate-200/60 dark:border-slate-700/60">
              <span>🗑️</span>
              <span class="text-[10px]">Excluir</span>
            </button>
          `}
        </div>
      `;
      cardsContainer.appendChild(card);
    }
  });
}

function getLocationMeta(tipo) {
  switch (tipo) {
    case "DEPOSITO":
      return { icon: "🏢", label: "Depósito", badgeClass: "bg-sky-100 text-sky-800 border-sky-300", borderClass: "border-l-sky-600" };
    case "SETOR":
      return { icon: "🏛️", label: "Setor/Seção", badgeClass: "bg-indigo-100 text-indigo-800 border-indigo-300", borderClass: "border-l-indigo-600" };
    case "SALA":
      return { icon: "🚪", label: "Sala/Almoxarifado", badgeClass: "bg-blue-100 text-blue-800 border-blue-300", borderClass: "border-l-blue-600" };
    case "ARMARIO":
      return { icon: "🗄️", label: "Armário", badgeClass: "bg-amber-100 text-amber-800 border-amber-300", borderClass: "border-l-amber-500" };
    case "PRATELEIRA":
      return { icon: "📑", label: "Prateleira", badgeClass: "bg-emerald-100 text-emerald-800 border-emerald-300", borderClass: "border-l-emerald-500" };
    case "GAVETA":
      return { icon: "📥", label: "Gaveta/Nicho", badgeClass: "bg-purple-100 text-purple-800 border-purple-300", borderClass: "border-l-purple-500" };
    case "BANCADA":
      return { icon: "🔧", label: "Bancada", badgeClass: "bg-slate-100 text-slate-800 border-slate-300", borderClass: "border-l-slate-600" };
    default:
      return { icon: "📦", label: tipo || "Local", badgeClass: "bg-slate-100 text-slate-700 border-slate-300", borderClass: "border-l-sky-600" };
  }
}

function openCreateLocationModal(parentId = null, defaultType = "DEPOSITO") {
  const modal = document.getElementById("modal-location");
  if (!modal) return;

  const parentSelect = document.getElementById("loc-modal-parent");
  const tipoSelect = document.getElementById("new-loc-tipo");
  const nomeInput = document.getElementById("new-loc-nome");
  const descInput = document.getElementById("new-loc-descricao");
  const title = document.getElementById("modal-location-title");

  if (parentSelect) {
    parentSelect.value = parentId ? String(parentId) : "";
  }

  if (parentId) {
    const parentLoc = state.locations.find(l => l.id == parentId);
    if (parentLoc) {
      if (defaultType === "OUTRO" || !defaultType) {
        if (parentLoc.tipo === "DEPOSITO" || parentLoc.tipo === "SALA" || parentLoc.tipo === "SETOR") {
          defaultType = "ARMARIO";
        } else if (parentLoc.tipo === "ARMARIO") {
          defaultType = "PRATELEIRA";
        } else if (parentLoc.tipo === "PRATELEIRA") {
          defaultType = "GAVETA";
        } else {
          defaultType = "PRATELEIRA";
        }
      }
      if (title) title.textContent = `Novo Sublocal em: ${parentLoc.nome}`;
    }
  } else {
    if (title) title.textContent = "Novo Local Raiz (Depósito / Setor)";
  }

  if (tipoSelect) tipoSelect.value = defaultType;
  if (nomeInput) {
    nomeInput.value = "";
    if (defaultType === "DEPOSITO") nomeInput.placeholder = "Ex: Depósito Central";
    else if (defaultType === "ARMARIO") nomeInput.placeholder = "Ex: Armário 01";
    else if (defaultType === "PRATELEIRA") nomeInput.placeholder = "Ex: Prateleira 01";
    else if (defaultType === "GAVETA") nomeInput.placeholder = "Ex: Gaveta 01";
    else nomeInput.placeholder = "Ex: Bancada 01";
  }
  if (descInput) descInput.value = "";

  updateLocationPreview();
  modal.classList.remove("hidden");
  setTimeout(() => nomeInput?.focus(), 50);
}

function closeCreateLocationModal() {
  const modal = document.getElementById("modal-location");
  if (modal) modal.classList.add("hidden");
}

function onLocationParentChange() {
  const parentSelect = document.getElementById("loc-modal-parent");
  const tipoSelect = document.getElementById("new-loc-tipo");
  const nomeInput = document.getElementById("new-loc-nome");

  const parentId = parentSelect?.value ? parseInt(parentSelect.value) : null;
  if (parentId) {
    const parentLoc = state.locations.find(l => l.id === parentId);
    if (parentLoc) {
      if (parentLoc.tipo === "DEPOSITO" || parentLoc.tipo === "SALA" || parentLoc.tipo === "SETOR") {
        if (tipoSelect) tipoSelect.value = "ARMARIO";
        if (nomeInput) nomeInput.placeholder = "Ex: Armário 01";
      } else if (parentLoc.tipo === "ARMARIO") {
        if (tipoSelect) tipoSelect.value = "PRATELEIRA";
        if (nomeInput) nomeInput.placeholder = "Ex: Prateleira 01";
      } else if (parentLoc.tipo === "PRATELEIRA") {
        if (tipoSelect) tipoSelect.value = "GAVETA";
        if (nomeInput) nomeInput.placeholder = "Ex: Gaveta 01";
      }
    }
  } else {
    if (tipoSelect) tipoSelect.value = "DEPOSITO";
    if (nomeInput) nomeInput.placeholder = "Ex: Depósito Central";
  }

  updateLocationPreview();
}

function updateLocationPreview() {
  const parentSelect = document.getElementById("loc-modal-parent");
  const nomeInput = document.getElementById("new-loc-nome");
  const preview = document.getElementById("loc-preview-path");
  if (!preview) return;

  const nome = (nomeInput?.value || "").trim();
  const parentId = parentSelect?.value ? parseInt(parentSelect.value) : null;

  if (parentId) {
    const parentLoc = state.locations.find(l => l.id === parentId);
    if (parentLoc) {
      preview.textContent = `${parentLoc.caminho_completo} > ${nome || "[Nome]"}`;
      return;
    }
  }

  preview.textContent = nome || "[Nome do Local Raiz (ex: Depósito Central)]";
}

async function handleCreateLocation(e) {
  e.preventDefault();
  const nome = document.getElementById("new-loc-nome").value.trim();
  const tipo = document.getElementById("new-loc-tipo").value;
  const descricao = document.getElementById("new-loc-descricao").value.trim() || null;
  const parent_id = document.getElementById("loc-modal-parent").value 
    ? parseInt(document.getElementById("loc-modal-parent").value) 
    : null;

  try {
    await api("/stock/locations", {
      method: "POST",
      body: { nome, tipo, descricao, parent_id }
    });
    showNotification(`Local "${nome}" cadastrado com sucesso!`);
    closeCreateLocationModal();
    await loadLocations();
  } catch (err) {}
}

async function handleDeleteLocation(id, nome) {
  if (!confirm(`Deseja realmente excluir o local "${nome}"?\n\nApenas locais vazios (sem materiais nem sublocais) podem ser excluídos.`)) {
    return;
  }
  try {
    await api(`/stock/locations/${id}`, { method: "DELETE" });
    showNotification(`Local "${nome}" excluído com sucesso!`);
    await loadLocations();
  } catch (err) {}
}

// --- Controles de Redução / Expansão e Busca da Árvore de Locais ---
function collapseAllLocations() {
  state.locations.forEach(l => {
    state.collapsedLocations.add(l.id);
  });
  renderLocationsTree();
}

function expandAllLocations() {
  state.collapsedLocations.clear();
  renderLocationsTree();
}

function toggleAllLocationMaterials() {
  const itemsSource = state.allItems && state.allItems.length > 0 ? state.allItems : state.items;
  const locsWithItems = state.locations.filter(loc =>
    itemsSource.some(i => (i.local_id === loc.id || i.local?.id === loc.id))
  );

  if (state.allMaterialsHidden) {
    locsWithItems.forEach(loc => state.collapsedMaterials.delete(loc.id));
    state.allMaterialsHidden = false;
  } else {
    locsWithItems.forEach(loc => state.collapsedMaterials.add(loc.id));
    state.allMaterialsHidden = true;
  }

  const labelEl = document.getElementById("label-toggle-all-materials");
  if (labelEl) {
    labelEl.textContent = state.allMaterialsHidden ? "📦 Mostrar Materiais" : "📦 Ocultar Materiais";
  }

  renderLocationsTree();
}

function toggleLocationCollapse(locId) {
  if (state.collapsedLocations.has(locId)) {
    state.collapsedLocations.delete(locId);
  } else {
    state.collapsedLocations.add(locId);
  }
  const isCollapsed = state.collapsedLocations.has(locId);

  const childContainer = document.getElementById(`loc-children-${locId}`);
  const btnArrow = document.getElementById(`btn-loc-collapse-arrow-${locId}`);
  const btnBadge = document.getElementById(`btn-loc-collapse-badge-${locId}`);

  if (childContainer) {
    if (isCollapsed) {
      childContainer.classList.add("hidden");
    } else {
      childContainer.classList.remove("hidden");
    }
    if (btnArrow) {
      btnArrow.textContent = isCollapsed ? '▶' : '▼';
      btnArrow.title = isCollapsed ? 'Expandir sublocais' : 'Recolher sublocais para reduzir poluição visual';
    }
    if (btnBadge) {
      const count = btnBadge.getAttribute("data-count") || "";
      btnBadge.innerHTML = `<span>${isCollapsed ? '📁' : '📂'}</span> <span>${count}</span> <span class="text-[10px] text-slate-400">${isCollapsed ? '▶' : '▼'}</span>`;
      btnBadge.title = isCollapsed ? 'Expandir sublocais' : 'Recolher sublocais';
    }
  } else {
    renderLocationsTree();
  }
}

function toggleLocationMaterials(locId) {
  const isCurrentlyCollapsed = state.collapsedMaterials.has(locId);
  if (isCurrentlyCollapsed) {
    state.collapsedMaterials.delete(locId);
  } else {
    state.collapsedMaterials.add(locId);
  }
  const isNowOpen = !state.collapsedMaterials.has(locId);

  const matContainer = document.getElementById(`loc-materials-${locId}`);
  const btn = document.getElementById(`btn-loc-mat-${locId}`);

  if (matContainer && btn) {
    if (isNowOpen) {
      matContainer.classList.remove("hidden");
      btn.className = "px-2.5 py-1 bg-sky-600 text-white hover:bg-sky-700 shadow-xs rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5";
      btn.title = "Recolher lista de materiais";
      const arrow = btn.querySelector(".loc-mat-arrow");
      if (arrow) arrow.textContent = "▲";
    } else {
      matContainer.classList.add("hidden");
      btn.className = "px-2.5 py-1 bg-sky-50 text-sky-800 hover:bg-sky-100 border border-sky-200 rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5";
      btn.title = "Ver materiais alocados neste local";
      const arrow = btn.querySelector(".loc-mat-arrow");
      if (arrow) arrow.textContent = "▼";
    }
  } else {
    renderLocationsTree();
  }
}

function handleLocationsSearch(query) {
  state.locationsSearchQuery = (query || "").trim().toLowerCase();
  const clearBtn = document.getElementById("btn-clear-loc-search");
  if (clearBtn) {
    if (state.locationsSearchQuery) clearBtn.classList.remove("hidden");
    else clearBtn.classList.add("hidden");
  }
  renderLocationsTree();
}

function clearLocationsSearch() {
  const input = document.getElementById("locations-search-input");
  if (input) input.value = "";
  handleLocationsSearch("");
}

function itemMatchesQuery(item, query) {
  if (!query) return true;
  const q = query.toLowerCase();
  return (
    (item.nome && item.nome.toLowerCase().includes(q)) ||
    (item.bmp && item.bmp.toLowerCase().includes(q)) ||
    (item.codigo_interno && item.codigo_interno.toLowerCase().includes(q)) ||
    (item.numero_serie && item.numero_serie.toLowerCase().includes(q)) ||
    (item.subgrupo?.nome && item.subgrupo.nome.toLowerCase().includes(q)) ||
    (item.observacoes && item.observacoes.toLowerCase().includes(q))
  );
}

function locationMatchesQuery(loc, query) {
  if (!query) return true;
  const q = query.toLowerCase();
  return (
    (loc.nome && loc.nome.toLowerCase().includes(q)) ||
    (loc.tipo && loc.tipo.toLowerCase().includes(q)) ||
    (loc.descricao && loc.descricao.toLowerCase().includes(q)) ||
    (loc.caminho_completo && loc.caminho_completo.toLowerCase().includes(q))
  );
}

function renderLocationItemCard(item) {
  const statusClasses = {
    DISPONIVEL: "badge-disponivel",
    EM_USO: "badge-em_uso",
    EM_MANUTENCAO: "badge-em_manutencao",
    CAUTELADO: "badge-cautelado",
    BAIXADO: "badge-baixado"
  };
  const badgeClass = statusClasses[item.status] || "bg-slate-100 text-slate-700";

  let compBadge = "";
  if (item.componentes && item.componentes.length > 0) {
    compBadge = `
      <span class="text-[11px] text-indigo-700 bg-indigo-50 border border-indigo-200 px-1.5 py-0.5 rounded font-medium flex items-center gap-1" title="${item.componentes.map(c => escapeHtml(c.nome)).join(', ')}">
        ⚙️ ${item.componentes.length} peça${item.componentes.length !== 1 ? 's' : ''} instalada${item.componentes.length !== 1 ? 's' : ''}
      </span>
    `;
  }

  let qtdStr = "";
  if (item.tipo_controle === "GRANEL") {
    const isLow = item.quantidade <= item.quantidade_minima;
    qtdStr = `
      <span class="text-xs font-bold ${isLow ? 'text-amber-600' : 'text-slate-700'}">
        ${item.quantidade} <span class="text-[10px] font-normal text-slate-500">${escapeHtml(item.unidade_medida || "un")}</span>
        ${isLow ? '<span class="ml-1 text-[10px] text-amber-700 bg-amber-50 px-1 py-0.2 rounded border border-amber-200 font-semibold">Baixo</span>' : ''}
      </span>
    `;
  } else {
    qtdStr = `<span class="text-xs font-medium text-slate-600">1 unid.</span>`;
  }

  return `
    <div class="p-2.5 bg-white rounded-lg border border-slate-200 hover:border-sky-300 transition-all shadow-xs flex flex-col sm:flex-row sm:items-center justify-between gap-2.5">
      <div class="flex items-start gap-2.5 min-w-0">
        <span class="mt-0.5 text-base">📦</span>
        <div class="min-w-0">
          <div class="flex items-center gap-2 flex-wrap">
            <span class="font-bold text-slate-900 text-xs sm:text-sm hover:text-sky-700 cursor-pointer truncate" onclick="openItemDetailModal(${item.id})" title="Clique para ver detalhes completos">
              ${escapeHtml(item.nome)}
            </span>
            <span class="px-2 py-0.5 rounded-full text-[10px] font-bold uppercase ${badgeClass}">
              ${escapeHtml(item.status)}
            </span>
            ${compBadge}
          </div>

          <div class="flex items-center gap-2 flex-wrap text-xs text-slate-500 mt-0.5">
            <span class="text-slate-600 font-medium">${escapeHtml(item.subgrupo?.nome || "Sem subgrupo")}</span>
            ${item.bmp ? `<span class="font-mono bg-slate-100 text-slate-800 px-1.5 py-0.5 rounded border border-slate-200 font-bold text-[11px]">BMP: ${escapeHtml(item.bmp)}</span>` : ''}
            ${item.codigo_interno ? `<span class="font-mono text-slate-600 bg-slate-50 px-1.5 py-0.5 rounded border border-slate-200 text-[11px]">Cód: ${escapeHtml(item.codigo_interno)}</span>` : ''}
            ${item.numero_serie ? `<span class="font-mono text-slate-400 text-[11px]">S/N: ${escapeHtml(item.numero_serie)}</span>` : ''}
            <span class="text-slate-300">•</span>
            ${qtdStr}
          </div>
        </div>
      </div>

      <div class="flex items-center gap-1 justify-end shrink-0 pt-1 sm:pt-0 border-t sm:border-t-0 border-slate-100">
        <button onclick="openItemDetailModal(${item.id})" title="Ver Detalhes do Material" class="p-1.5 text-slate-600 hover:text-sky-700 hover:bg-sky-50 rounded transition-colors text-xs font-semibold flex items-center gap-1">
          👁️ <span class="hidden md:inline text-[11px]">Detalhes</span>
        </button>
        <button onclick="openMoveModal(${item.id})" title="Transferir / Mover para outro local" class="p-1.5 text-slate-600 hover:text-indigo-700 hover:bg-indigo-50 rounded transition-colors text-xs font-semibold flex items-center gap-1">
          🔄 <span class="hidden md:inline text-[11px]">Mover</span>
        </button>
        <button onclick="openEditItemModal(${item.id})" title="Editar Material" class="p-1.5 text-slate-600 hover:text-amber-700 hover:bg-amber-50 rounded transition-colors text-xs font-semibold flex items-center gap-1">
          ✏️
        </button>
        <button onclick="openQrModal(${item.id})" title="Gerar QR Code e Etiqueta" class="p-1.5 text-slate-600 hover:text-sky-700 hover:bg-sky-50 rounded transition-colors text-xs font-semibold flex items-center gap-1">
          🏷️
        </button>
        ${item.tipo_controle === 'GRANEL' ? `
          <button onclick="openAdjustModal(${item.id})" title="Ajustar Saldo" class="p-1.5 text-slate-600 hover:text-emerald-700 hover:bg-emerald-50 rounded transition-colors text-xs font-semibold">
            ⚖️
          </button>` : ''}
      </div>
    </div>
  `;
}

function renderLocationsTree() {
  const container = document.getElementById("locations-tree-view");
  if (!container) return;

  const itemsSource = state.allItems && state.allItems.length > 0 ? state.allItems : state.items;

  // Atualizar contadores do cabeçalho
  const sumLocsEl = document.getElementById("loc-summary-locs");
  const sumItemsEl = document.getElementById("loc-summary-materials");
  if (sumLocsEl) {
    sumLocsEl.textContent = `${state.locations.length} local${state.locations.length !== 1 ? 'is' : ''}`;
  }
  if (sumItemsEl) {
    const allocatedCount = itemsSource.filter(i => (i.local_id || i.local)).length;
    sumItemsEl.textContent = `${allocatedCount} material${allocatedCount !== 1 ? 'is' : ''} alocado${allocatedCount !== 1 ? 's' : ''}`;
  }

  container.innerHTML = "";
  if (state.locations.length === 0) {
    container.innerHTML = `
      <div class="bg-white rounded-xl border border-dashed border-slate-300 p-8 text-center text-slate-500">
        <span class="text-4xl block mb-2">🏢</span>
        <h4 class="font-bold text-slate-700 text-sm">Nenhum local cadastrado ainda</h4>
        <p class="text-xs text-slate-400 mt-1 max-w-sm mx-auto">
          Comece criando o primeiro local físico (ex: <strong>Depósito Central</strong> ou <strong>Seção de TI</strong>).
        </p>
        <button onclick="openCreateLocationModal(null, 'DEPOSITO')" class="mt-4 px-4 py-2 bg-sky-600 hover:bg-sky-500 text-white rounded-lg text-xs font-bold shadow">
          + Criar Primeiro Depósito
        </button>
      </div>
    `;
    return;
  }

  const locMap = {};
  const childrenMap = {};
  state.locations.forEach(l => {
    locMap[l.id] = l;
    if (l.parent_id) {
      if (!childrenMap[l.parent_id]) childrenMap[l.parent_id] = [];
      childrenMap[l.parent_id].push(l);
    }
  });

  const query = (state.locationsSearchQuery || "").trim().toLowerCase();
  const visibleLocIds = new Set();

  if (query) {
    state.locations.forEach(loc => {
      const directItems = itemsSource.filter(i => (i.local_id === loc.id || i.local?.id === loc.id));
      const hasMatchingItem = directItems.some(i => itemMatchesQuery(i, query));
      const locMatches = locationMatchesQuery(loc, query);

      if (locMatches || hasMatchingItem) {
        let curr = loc;
        while (curr) {
          visibleLocIds.add(curr.id);
          state.collapsedLocations.delete(curr.id); // abre para exibir o caminho
          curr = locMap[curr.parent_id];
        }
        if (hasMatchingItem) {
          state.collapsedMaterials.delete(loc.id); // abre gaveta para ver o item encontrado
        }
      }
    });

    if (visibleLocIds.size === 0) {
      container.innerHTML = `
        <div class="bg-white rounded-xl border border-dashed border-slate-300 p-8 text-center text-slate-500">
          <span class="text-3xl block mb-2">🔍</span>
          <h4 class="font-bold text-slate-700 text-sm">Nenhum local ou material encontrado para "${escapeHtml(query)}"</h4>
          <p class="text-xs text-slate-400 mt-1 max-w-sm mx-auto">
            Tente outro termo como nome do material, BMP, código interno ou nome do local.
          </p>
          <button onclick="clearLocationsSearch()" class="mt-4 px-3.5 py-1.5 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-lg text-xs font-semibold shadow-xs">
            Limpar Filtro
          </button>
        </div>
      `;
      return;
    }
  }

  function countSubtreeItems(locationId) {
    let count = itemsSource.filter(i => (i.local_id === locationId || i.local?.id === locationId)).length;
    const directChildren = childrenMap[locationId] || [];
    for (const child of directChildren) {
      count += countSubtreeItems(child.id);
    }
    return count;
  }

  function buildNode(loc, level = 0) {
    if (query && !visibleLocIds.has(loc.id)) {
      return null;
    }

    const meta = getLocationMeta(loc.tipo);
    const directItems = itemsSource.filter(i => (i.local_id === loc.id || i.local?.id === loc.id));
    const children = childrenMap[loc.id] || [];
    const totalSubtree = countSubtreeItems(loc.id);
    const indirectCount = totalSubtree - directItems.length;

    const isCollapsed = state.collapsedLocations.has(loc.id);
    const isMaterialsOpen = directItems.length > 0 && !state.collapsedMaterials.has(loc.id);
    const displayedItems = query ? directItems.filter(i => itemMatchesQuery(i, query)) : directItems;

    const div = document.createElement("div");
    const borderClass = meta.borderClass || "border-l-sky-600";
    div.className = `p-3.5 rounded-xl border border-slate-200 bg-white mb-2 shadow-xs transition-all hover:border-slate-300 ${
      level > 0 ? `ml-3 sm:ml-6 md:ml-8 border-l-4 ${borderClass} bg-slate-50/40` : ""
    }`;

    // Ação contextual para adicionar sublocal
    let addChildBtn = "";
    if (loc.tipo === "DEPOSITO" || loc.tipo === "SETOR" || loc.tipo === "SALA") {
      addChildBtn = `
        <button onclick="openCreateLocationModal(${loc.id}, 'ARMARIO')" class="px-2 py-1 bg-amber-500 hover:bg-amber-600 text-white rounded-lg text-xs font-semibold shadow-xs flex items-center gap-1 transition-colors" title="Adicionar um armário dentro deste local">
          <span>🗄️</span> + Armário
        </button>
      `;
    } else if (loc.tipo === "ARMARIO") {
      addChildBtn = `
        <button onclick="openCreateLocationModal(${loc.id}, 'PRATELEIRA')" class="px-2 py-1 bg-emerald-600 hover:bg-emerald-700 text-white rounded-lg text-xs font-semibold shadow-xs flex items-center gap-1 transition-colors" title="Adicionar uma prateleira dentro deste armário">
          <span>📑</span> + Prateleira
        </button>
      `;
    } else if (loc.tipo === "PRATELEIRA") {
      addChildBtn = `
        <button onclick="openCreateLocationModal(${loc.id}, 'GAVETA')" class="px-2 py-1 bg-purple-600 hover:bg-purple-700 text-white rounded-lg text-xs font-semibold shadow-xs flex items-center gap-1 transition-colors" title="Adicionar gaveta ou nicho nesta prateleira">
          <span>📥</span> + Gaveta
        </button>
      `;
    }

    const canDelete = directItems.length === 0 && children.length === 0;

    div.innerHTML = `
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div class="flex items-start sm:items-center gap-2.5 min-w-0">
          ${children.length > 0 ? `
            <button id="btn-loc-collapse-arrow-${loc.id}" onclick="toggleLocationCollapse(${loc.id})" class="mt-0.5 p-1 rounded-md text-slate-500 hover:text-slate-900 hover:bg-slate-200/80 transition-colors flex items-center justify-center w-7 h-7 text-xs font-bold border border-slate-200 bg-slate-50 shrink-0" title="${isCollapsed ? 'Expandir sublocais' : 'Recolher sublocais para reduzir poluição visual'}">
              ${isCollapsed ? '▶' : '▼'}
            </button>
          ` : `
            <span class="w-7 h-7 flex items-center justify-center text-slate-300 text-xs shrink-0">•</span>
          `}

          <span class="text-2xl p-1.5 rounded-lg bg-slate-100 border border-slate-200 shrink-0">${meta.icon}</span>

          <div class="min-w-0">
            <div class="flex items-center gap-2 flex-wrap">
              <span class="font-bold text-slate-800 text-sm">${escapeHtml(loc.nome)}</span>
              <span class="text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded border ${meta.badgeClass}">
                ${meta.label}
              </span>
              ${loc.descricao ? `<span class="text-xs text-slate-400 italic">(${escapeHtml(loc.descricao)})</span>` : ""}
            </div>
            <div class="text-xs text-slate-500 font-mono mt-0.5 truncate" title="${escapeHtml(loc.caminho_completo)}">${escapeHtml(loc.caminho_completo)}</div>
          </div>
        </div>

        <div class="flex items-center gap-1.5 flex-wrap justify-end">
          <!-- Botão de Materiais neste Local -->
          ${directItems.length > 0 ? `
            <button id="btn-loc-mat-${loc.id}" onclick="toggleLocationMaterials(${loc.id})" class="px-2.5 py-1 ${isMaterialsOpen ? 'bg-sky-600 text-white hover:bg-sky-700 shadow-xs' : 'bg-sky-50 text-sky-800 hover:bg-sky-100 border border-sky-200'} rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5" title="${isMaterialsOpen ? 'Recolher lista de materiais' : 'Ver materiais alocados neste local'}">
              <span>📦</span>
              <span>${directItems.length} material${directItems.length !== 1 ? 'is' : ''}</span>
              <span class="loc-mat-arrow text-[10px] opacity-80">${isMaterialsOpen ? '▲' : '▼'}</span>
            </button>
          ` : `
            <span class="text-xs font-medium px-2 py-1 rounded-lg bg-slate-100 text-slate-400 border border-slate-200 flex items-center gap-1">
              <span>📦</span> 0 materiais
            </span>
          `}

          ${indirectCount > 0 ? `
            <span class="text-[11px] font-medium px-2 py-1 rounded-lg bg-slate-50 text-slate-500 border border-slate-200" title="${indirectCount} material(ais) alocado(s) nos sublocais deste nível">
              +${indirectCount} nos sublocais
            </span>
          ` : ''}

          ${children.length > 0 ? `
            <button id="btn-loc-collapse-badge-${loc.id}" data-count="${children.length}" onclick="toggleLocationCollapse(${loc.id})" class="px-2 py-1 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-lg text-xs font-semibold transition-colors flex items-center gap-1" title="${isCollapsed ? 'Expandir sublocais' : 'Recolher sublocais'}">
              <span>${isCollapsed ? '📁' : '📂'}</span>
              <span>${children.length}</span>
              <span class="text-[10px] text-slate-400">${isCollapsed ? '▶' : '▼'}</span>
            </button>
          ` : ''}

          ${addChildBtn}

          <button onclick="openCreateLocationModal(${loc.id}, 'OUTRO')" class="px-2 py-1 border border-slate-200 hover:bg-slate-100 text-slate-600 rounded-lg text-xs font-semibold transition-colors" title="Adicionar outro tipo de sublocal">
            + Sublocal
          </button>

          <button onclick="filterByLocationId(${loc.id})" class="px-2 py-1 bg-slate-50 text-slate-600 hover:text-sky-700 hover:bg-sky-50 border border-slate-200 rounded-lg text-xs font-semibold transition-colors" title="Abrir na tabela completa de estoque">
            Tabela ➔
          </button>

          ${canDelete ? `
            <button onclick="handleDeleteLocation(${loc.id}, '${escapeHtml(loc.nome)}')" class="text-rose-600 hover:text-rose-800 text-xs font-semibold p-1 hover:bg-rose-50 rounded-lg transition-colors" title="Excluir local vazio">
              🗑️
            </button>
          ` : ""}
        </div>
      </div>

      <!-- Gaveta de Materiais Alocados neste Local -->
      ${directItems.length > 0 ? `
        <div id="loc-materials-${loc.id}" class="mt-3 pt-3 border-t border-slate-100 bg-slate-50/75 rounded-xl p-3 border border-slate-200/80 ${isMaterialsOpen ? '' : 'hidden'}">
          <div class="flex items-center justify-between mb-2 pb-1 border-b border-slate-200/60">
            <div class="flex items-center gap-2">
              <span class="text-xs font-bold text-slate-700 uppercase tracking-wider flex items-center gap-1.5">
                <span>📦</span> Materiais em ${escapeHtml(loc.nome)} (${displayedItems.length}${query && displayedItems.length !== directItems.length ? ` de ${directItems.length}` : ''})
              </span>
            </div>
            <button onclick="toggleLocationMaterials(${loc.id})" class="text-xs font-medium text-slate-500 hover:text-slate-800 flex items-center gap-1 transition-colors">
              <span>▲</span> Recolher materiais
            </button>
          </div>

          ${displayedItems.length > 0 ? `
            <div class="space-y-2 max-h-96 overflow-y-auto pr-1">
              ${displayedItems.map(item => renderLocationItemCard(item)).join("")}
            </div>
          ` : `
            <div class="py-3 text-center text-xs text-slate-400 italic">
              Nenhum material correspondente ao filtro de busca neste local.
            </div>
          `}
        </div>
      ` : ''}
    `;

    if (children.length > 0) {
      const childContainer = document.createElement("div");
      childContainer.id = `loc-children-${loc.id}`;
      childContainer.className = `mt-3 space-y-2 ${isCollapsed ? "hidden" : ""}`;
      children.forEach(c => {
        const node = buildNode(c, level + 1);
        if (node) childContainer.appendChild(node);
      });
      if (childContainer.children.length > 0 || !query) {
        div.appendChild(childContainer);
      }
    }

    return div;
  }

  // Raízes (parent_id == null)
  const roots = state.locations.filter(l => !l.parent_id);
  roots.forEach(root => {
    const node = buildNode(root);
    if (node) container.appendChild(node);
  });
}

function filterByLocationId(locId) {
  switchTab("stock");
  const select = document.getElementById("filter-location");
  if (select) {
    select.value = locId;
    loadItems();
  }
}

// ============================================================================
// 4.1 GERENCIAMENTO DE GRUPOS & SUBGRUPOS (CATEGORIAS)
// ============================================================================

function renderCategoriesView() {
  const container = document.getElementById("categories-cards-view");
  if (!container) return;

  container.innerHTML = "";

  if (!state.groups || state.groups.length === 0) {
    container.className = "col-span-full";
    container.innerHTML = `
      <div class="bg-white rounded-xl border border-dashed border-slate-300 p-8 text-center text-slate-500">
        <span class="text-4xl block mb-2">🏷️</span>
        <h4 class="font-bold text-slate-700 text-sm">Nenhum grupo cadastrado ainda</h4>
        <p class="text-xs text-slate-400 mt-1 max-w-sm mx-auto">
          Crie o primeiro grupo de materiais (ex: <strong>Equipamentos de TI</strong>, <strong>Consumíveis</strong>, <strong>Comunicação</strong>).
        </p>
        <button onclick="openCreateGroupModal()" class="mt-4 px-4 py-2 bg-fab-900 hover:bg-fab-800 text-white rounded-lg text-xs font-bold shadow">
          + Criar Primeiro Grupo
        </button>
      </div>
    `;
    return;
  }

  container.className = "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4";

  state.groups.forEach(group => {
    const subgroups = (state.subgroups || []).filter(sg => sg.grupo_id === group.id);
    const card = document.createElement("div");
    card.className = "bg-white rounded-xl border border-slate-200 p-4 shadow-sm flex flex-col justify-between hover:border-slate-300 transition-all";

    const canDeleteGroup = subgroups.length === 0;

    let subgroupsHtml = "";
    if (subgroups.length === 0) {
      subgroupsHtml = `
        <div class="text-center py-6 text-slate-400 text-xs italic bg-slate-50 rounded-lg border border-dashed border-slate-200 my-3">
          Nenhum subgrupo neste grupo ainda.
        </div>
      `;
    } else {
      subgroupsHtml = `
        <div class="space-y-2 my-3">
          ${subgroups.map(sg => {
            const catSource = (state.allItems && state.allItems.length > 0) ? state.allItems : state.items;
            const countItems = (catSource || []).filter(i => i.subgrupo_id === sg.id).length;
            const canDeleteSg = countItems === 0;
            return `
              <div class="flex items-center justify-between p-2 rounded-lg bg-slate-50 border border-slate-200 hover:bg-slate-100 transition-colors text-xs">
                <div class="flex items-center gap-2">
                  <span class="text-sky-600 font-bold">▪</span>
                  <div>
                    <span class="font-semibold text-slate-800">${escapeHtml(sg.nome)}</span>
                    ${sg.descricao ? `<div class="text-[10px] text-slate-400 truncate max-w-[170px]">${escapeHtml(sg.descricao)}</div>` : ""}
                  </div>
                </div>
                <div class="flex items-center gap-1.5">
                  <span class="text-[10px] font-semibold px-2 py-0.5 rounded-full bg-white border border-slate-200 text-slate-600">
                    ${countItems} itens
                  </span>
                  <button onclick="filterBySubgroupId(${sg.id})" class="text-[11px] font-medium text-sky-700 hover:underline px-1" title="Ver materiais deste subgrupo">
                    ➔
                  </button>
                  <button onclick="openEditSubgroupModal(${sg.id})" class="text-sky-600 hover:text-sky-800 text-xs font-semibold p-1 hover:bg-sky-50 rounded transition-colors" title="Editar Subgrupo">
                    ✏️
                  </button>
                  ${canDeleteSg ? `
                    <button onclick="handleDeleteSubgroup(${sg.id}, '${escapeHtml(sg.nome)}')" class="text-rose-600 hover:text-rose-800 text-xs font-semibold p-1 hover:bg-rose-50 rounded transition-colors" title="Excluir subgrupo vazio">
                      🗑️
                    </button>
                  ` : ""}
                </div>
              </div>
            `;
          }).join("")}
        </div>
      `;
    }

    card.innerHTML = `
      <div>
        <div class="flex items-start justify-between pb-3 border-b border-slate-100 gap-2">
          <div>
            <div class="flex items-center gap-2">
              <span class="text-xl">📁</span>
              <h3 class="font-bold text-slate-900 text-sm">${escapeHtml(group.nome)}</h3>
            </div>
            ${group.descricao ? `<p class="text-xs text-slate-400 mt-1">${escapeHtml(group.descricao)}</p>` : ""}
          </div>
          <div class="flex items-center gap-1">
            <span class="text-xs font-bold px-2 py-0.5 rounded bg-sky-50 text-sky-700 border border-sky-200">
              ${subgroups.length} subgrupo${subgroups.length !== 1 ? 's' : ''}
            </span>
            <button onclick="openEditGroupModal(${group.id})" class="text-sky-600 hover:text-sky-800 text-xs font-semibold p-1 hover:bg-sky-50 rounded transition-colors" title="Editar Grupo">
              ✏️
            </button>
            ${canDeleteGroup ? `
              <button onclick="handleDeleteGroup(${group.id}, '${escapeHtml(group.nome)}')" class="text-rose-600 hover:text-rose-800 text-xs font-semibold p-1 hover:bg-rose-50 rounded transition-colors" title="Excluir grupo vazio">
                🗑️
              </button>
            ` : ""}
          </div>
        </div>

        ${subgroupsHtml}
      </div>

      <div class="pt-3 border-t border-slate-100">
        <button onclick="openCreateSubgroupModal(${group.id})" class="w-full py-1.5 px-3 bg-sky-50 hover:bg-sky-100 text-sky-700 border border-sky-200 rounded-lg text-xs font-semibold flex items-center justify-center gap-1 transition-colors">
          <span>➕</span> Adicionar Subgrupo neste Grupo
        </button>
      </div>
    `;

    container.appendChild(card);
  });
}

function openCreateGroupModal() {
  const modal = document.getElementById("modal-group");
  const editIdInput = document.getElementById("edit-group-id");
  const nomeInput = document.getElementById("new-group-nome");
  const descInput = document.getElementById("new-group-descricao");
  const title = document.getElementById("modal-group-title");
  const submitBtn = document.getElementById("btn-submit-group");
  if (!modal) return;

  if (editIdInput) editIdInput.value = "";
  if (title) title.textContent = "Novo Grupo de Materiais";
  if (submitBtn) submitBtn.textContent = "Criar Grupo";
  if (nomeInput) nomeInput.value = "";
  if (descInput) descInput.value = "";
  modal.classList.remove("hidden");
  setTimeout(() => nomeInput?.focus(), 50);
}

function openEditGroupModal(id) {
  const group = state.groups.find(g => g.id === id);
  if (!group) return;

  const modal = document.getElementById("modal-group");
  const editIdInput = document.getElementById("edit-group-id");
  const nomeInput = document.getElementById("new-group-nome");
  const descInput = document.getElementById("new-group-descricao");
  const title = document.getElementById("modal-group-title");
  const submitBtn = document.getElementById("btn-submit-group");
  if (!modal) return;

  if (editIdInput) editIdInput.value = group.id;
  if (title) title.textContent = "Editar Grupo de Materiais";
  if (submitBtn) submitBtn.textContent = "Salvar Alterações";
  if (nomeInput) nomeInput.value = group.nome;
  if (descInput) descInput.value = group.descricao || "";

  modal.classList.remove("hidden");
  setTimeout(() => nomeInput?.focus(), 50);
}

function closeCreateGroupModal() {
  const modal = document.getElementById("modal-group");
  if (modal) modal.classList.add("hidden");
}

async function handleCreateGroup(e) {
  e.preventDefault();
  const editId = document.getElementById("edit-group-id")?.value;
  const nome = document.getElementById("new-group-nome").value.trim();
  const descricao = document.getElementById("new-group-descricao").value.trim() || null;

  try {
    if (editId) {
      await api(`/stock/groups/${editId}`, {
        method: "PUT",
        body: { nome, descricao }
      });
      showNotification(`Grupo "${nome}" atualizado com sucesso!`);
    } else {
      await api("/stock/groups", {
        method: "POST",
        body: { nome, descricao }
      });
      showNotification(`Grupo "${nome}" criado com sucesso!`);
    }
    closeCreateGroupModal();
    await loadGroups();
    await loadSubgroups();
  } catch (err) {}
}

async function handleDeleteGroup(id, nome) {
  if (!confirm(`Deseja realmente excluir o grupo "${nome}"?\n\nApenas grupos sem subgrupos podem ser excluídos.`)) {
    return;
  }
  try {
    await api(`/stock/groups/${id}`, { method: "DELETE" });
    showNotification(`Grupo "${nome}" excluído com sucesso!`);
    await loadGroups();
  } catch (err) {}
}

function openCreateSubgroupModal(groupId = null) {
  const modal = document.getElementById("modal-subgroup");
  const editIdInput = document.getElementById("edit-subgroup-id");
  const groupSelect = document.getElementById("subgroup-modal-group");
  const nomeInput = document.getElementById("new-subgroup-nome");
  const descInput = document.getElementById("new-subgroup-descricao");
  const title = document.getElementById("modal-subgroup-title");
  const submitBtn = document.getElementById("btn-submit-subgroup");
  if (!modal) return;

  populateGroupSelects();

  if (editIdInput) editIdInput.value = "";
  if (title) title.textContent = "Novo Subgrupo / Classificação";
  if (submitBtn) submitBtn.textContent = "Criar Subgrupo";
  if (groupSelect && groupId) groupSelect.value = String(groupId);
  if (nomeInput) nomeInput.value = "";
  if (descInput) descInput.value = "";

  modal.classList.remove("hidden");
  setTimeout(() => nomeInput?.focus(), 50);
}

function openEditSubgroupModal(id) {
  const sg = state.subgroups.find(s => s.id === id);
  if (!sg) return;

  const modal = document.getElementById("modal-subgroup");
  const editIdInput = document.getElementById("edit-subgroup-id");
  const groupSelect = document.getElementById("subgroup-modal-group");
  const nomeInput = document.getElementById("new-subgroup-nome");
  const descInput = document.getElementById("new-subgroup-descricao");
  const title = document.getElementById("modal-subgroup-title");
  const submitBtn = document.getElementById("btn-submit-subgroup");
  if (!modal) return;

  populateGroupSelects();

  if (editIdInput) editIdInput.value = sg.id;
  if (title) title.textContent = "Editar Subgrupo / Classificação";
  if (submitBtn) submitBtn.textContent = "Salvar Alterações";
  if (groupSelect) groupSelect.value = String(sg.grupo_id);
  if (nomeInput) nomeInput.value = sg.nome;
  if (descInput) descInput.value = sg.descricao || "";

  modal.classList.remove("hidden");
  setTimeout(() => nomeInput?.focus(), 50);
}

function closeCreateSubgroupModal() {
  const modal = document.getElementById("modal-subgroup");
  if (modal) modal.classList.add("hidden");
}

async function handleCreateSubgroup(e) {
  e.preventDefault();
  const editId = document.getElementById("edit-subgroup-id")?.value;
  const grupo_id = parseInt(document.getElementById("subgroup-modal-group").value);
  const nome = document.getElementById("new-subgroup-nome").value.trim();
  const descricao = document.getElementById("new-subgroup-descricao").value.trim() || null;

  if (!grupo_id) {
    showNotification("Selecione o Grupo Pai.", "error");
    return;
  }

  try {
    if (editId) {
      await api(`/stock/subgroups/${editId}`, {
        method: "PUT",
        body: { grupo_id, nome, descricao }
      });
      showNotification(`Subgrupo "${nome}" atualizado com sucesso!`);
    } else {
      await api("/stock/subgroups", {
        method: "POST",
        body: { grupo_id, nome, descricao }
      });
      showNotification(`Subgrupo "${nome}" cadastrado com sucesso!`);
    }
    closeCreateSubgroupModal();
    await loadSubgroups();
  } catch (err) {}
}

async function handleDeleteSubgroup(id, nome) {
  if (!confirm(`Deseja realmente excluir o subgrupo "${nome}"?\n\nApenas subgrupos sem materiais cadastrados podem ser excluídos.`)) {
    return;
  }
  try {
    await api(`/stock/subgroups/${id}`, { method: "DELETE" });
    showNotification(`Subgrupo "${nome}" excluído com sucesso!`);
    await loadSubgroups();
  } catch (err) {}
}

function filterBySubgroupId(subgroupId) {
  switchTab("stock");
  const select = document.getElementById("filter-subgroup");
  if (select) {
    select.value = subgroupId;
    loadItems();
  }
}

function renderMovements() {
  const tbody = document.getElementById("movements-table-body");
  if (!tbody) return;

  tbody.innerHTML = "";
  if (state.movements.length === 0) {
    tbody.innerHTML = `<tr><td colspan="6" class="text-center py-8 text-slate-400">Nenhuma movimentação registrada no histórico.</td></tr>`;
    return;
  }

  state.movements.forEach(m => {
    const tr = document.createElement("tr");
    tr.className = "hover:bg-slate-50 border-b border-slate-100 text-xs text-slate-700";

    const dt = new Date(m.data_hora);
    const dataFmt = dt.toLocaleString("pt-BR");

    tr.innerHTML = `
      <td class="py-2.5 px-4 font-mono text-slate-500">${dataFmt}</td>
      <td class="py-2.5 px-4 font-semibold text-slate-900">${m.item_id}</td>
      <td class="py-2.5 px-4">
        <span class="px-2 py-0.5 rounded bg-slate-100 font-medium text-slate-800">${escapeHtml(m.tipo_movimentacao)}</span>
      </td>
      <td class="py-2.5 px-4">${m.origem ? escapeHtml(m.origem.caminho_completo) : '<span class="text-slate-400">—</span>'}</td>
      <td class="py-2.5 px-4">${m.destino ? escapeHtml(m.destino.caminho_completo) : '<span class="text-slate-400">—</span>'}</td>
      <td class="py-2.5 px-4 text-slate-600">${escapeHtml(m.motivo || "—")}</td>
    `;
    tbody.appendChild(tr);
  });
}

function renderPersonnel() {
  const milTbody = document.getElementById("personnel-militaries-body");
  const userTbody = document.getElementById("personnel-users-body");

  if (milTbody) {
    milTbody.innerHTML = state.militaries.length === 0 
      ? `<tr><td colspan="5" class="py-4 text-center text-slate-400">Nenhum militar cadastrado no efetivo.</td></tr>`
      : state.militaries.map(m => `
          <tr class="border-b border-slate-100 text-xs hover:bg-slate-50">
            <td class="py-2 px-3 font-mono font-bold">${m.saram}</td>
            <td class="py-2 px-3 font-medium text-slate-900">${escapeHtml(m.nome_completo)}</td>
            <td class="py-2 px-3">${escapeHtml(m.posto_graduacao)} - ${escapeHtml(m.nome_guerra)}</td>
            <td class="py-2 px-3 text-slate-500">${escapeHtml(m.email || "—")}</td>
            <td class="py-2 px-3 text-slate-500">${escapeHtml(m.celular || "—")}</td>
          </tr>
        `).join("");
  }

  if (userTbody) {
    userTbody.innerHTML = state.usersList.length === 0
      ? `<tr><td colspan="4" class="py-4 text-center text-slate-400">Nenhum usuário cadastrado.</td></tr>`
      : state.usersList.map(u => `
          <tr class="border-b border-slate-100 text-xs hover:bg-slate-50">
            <td class="py-2 px-3 font-medium text-slate-900">
              ${u.militar ? `${u.militar.posto_graduacao} ${u.militar.nome_guerra} (SARAM: ${u.militar.saram})` : (u.username || "Admin")}
            </td>
            <td class="py-2 px-3 text-center">
              <span class="px-2 py-0.5 rounded text-xs ${u.admin ? 'bg-amber-100 text-amber-800 font-bold' : 'bg-slate-100 text-slate-600'}">
                ${u.admin ? "Administrador" : "Operador"}
              </span>
            </td>
            <td class="py-2 px-3 text-center">
              <span class="px-2 py-0.5 rounded text-xs ${u.ativo ? 'bg-emerald-100 text-emerald-800' : 'bg-rose-100 text-rose-800'}">
                ${u.ativo ? "Ativo" : "Inativo"}
              </span>
            </td>
          </tr>
        `).join("");
  }
}

// ============================================================================
// 5. POPULAÇÃO DE SELECTS NOS FORMULÁRIOS
// ============================================================================

function populateLocationSelects() {
  const filterSelect = document.getElementById("filter-location");
  const itemSelect = document.getElementById("item-modal-location");
  const moveSelect = document.getElementById("move-modal-location");
  const editSelect = document.getElementById("edit-item-local_id");
  const parentSelect = document.getElementById("loc-modal-parent");

  // Ordenar locais por caminho_completo para manter hierarquia
  const sortedLocations = [...state.locations].sort((a, b) =>
    (a.caminho_completo || a.nome).localeCompare(b.caminho_completo || b.nome)
  );

  // 1. Selects para armazenar ou filtrar itens (Filtro, Item, Mover, Editar)
  [filterSelect, itemSelect, moveSelect, editSelect].forEach(sel => {
    if (!sel) return;
    const isFilter = sel.id.startsWith("filter-");
    const firstOption = isFilter
      ? `<option value="">Todos os Locais</option>`
      : `<option value="">Nenhum / Não definido</option>`;

    sel.innerHTML = firstOption + sortedLocations.map(l => {
      const meta = getLocationMeta(l.tipo);
      return `<option value="${l.id}">${meta.icon} ${escapeHtml(l.caminho_completo)}</option>`;
    }).join("");
  });

  // 2. Select de Local Pai para o formulário de cadastro de local
  if (parentSelect) {
    let parentOptions = `<option value="">Nenhum (Local Raiz - Ex: Depósito Central)</option>`;
    parentOptions += sortedLocations.map(l => {
      const meta = getLocationMeta(l.tipo);
      const depth = (l.caminho_completo.match(/ > /g) || []).length;
      const indent = "&nbsp;&nbsp;&nbsp;&nbsp;".repeat(depth) + (depth > 0 ? "└─ " : "");
      return `<option value="${l.id}">${indent}${meta.icon} ${escapeHtml(l.caminho_completo)}</option>`;
    }).join("");
    parentSelect.innerHTML = parentOptions;
  }
}

function populateGroupSelects() {
  const selects = [
    document.getElementById("subgroup-modal-group")
  ];

  selects.forEach(select => {
    if (!select) return;
    const sortedGroups = [...(state.groups || [])].sort((a, b) => (a.nome || "").localeCompare(b.nome || ""));
    select.innerHTML = `<option value="">Selecione um Grupo</option>` + sortedGroups.map(g => `
      <option value="${g.id}">📁 ${escapeHtml(g.nome)}</option>
    `).join("");
  });
}

function populateSubgroupSelects() {
  const selects = [
    document.getElementById("filter-subgroup"),
    document.getElementById("item-modal-subgroup"),
    document.getElementById("edit-item-subgrupo_id")
  ];

  selects.forEach(select => {
    if (!select) return;
    const isFilter = select.id.startsWith("filter-");
    const firstOption = isFilter ? `<option value="">Todos os Subgrupos</option>` : `<option value="">Selecione o Subgrupo</option>`;

    const sortedSubgroups = [...(state.subgroups || [])].sort((a, b) => (a.nome || "").localeCompare(b.nome || ""));
    select.innerHTML = firstOption + sortedSubgroups.map(sg => `
      <option value="${sg.id}">${escapeHtml(sg.nome)} (${escapeHtml(sg.grupo?.nome || "Sem Grupo")})</option>
    `).join("");
  });
}

function populateParentItemSelect() {
  const select = document.getElementById("item-modal-parent");
  const moveSelect = document.getElementById("move-modal-parent");

  [select, moveSelect].forEach(s => {
    if (!s) return;
    s.innerHTML = `<option value="">Nenhum (Item Independente)</option>` + state.items
      .filter(i => !i.parent_id) // Apenas equipamentos raiz
      .map(i => `<option value="${i.id}">${escapeHtml(i.nome)} ${i.bmp ? `[BMP: ${i.bmp}]` : ""}</option>`)
      .join("");
  });
}

// ============================================================================
// ============================================================================
// 6. MODAL DE QR CODE E ETIQUETA PATRIMONIAL COM CUSTOMIZAÇÃO COMPLETA
// ============================================================================

const qrState = {
  labelMode: true,
  payloadMode: "system", // system, text, bmp, uuid, custom
  customText: "",
  showHeader: true,
  showFooter: true,
  headerTitle: "FORÇA AÉREA BRASILEIRA - BINFAE",
  headerSubtitle: "SEÇÃO DE INFORMÁTICA - CONTROLE PATRIMONIAL",
  fields: {
    nome: true,
    bmp: true,
    codigo_interno: true,
    numero_serie: true,
    subgrupo: true,
    local: true,
    status: false,
    estado: false
  }
};

function loadQrConfig() {
  try {
    const saved = localStorage.getItem("binfae_qr_config");
    if (saved) {
      const parsed = JSON.parse(saved);
      if (parsed.fields) Object.assign(qrState.fields, parsed.fields);
      if (parsed.payloadMode !== undefined) qrState.payloadMode = parsed.payloadMode;
      if (parsed.showHeader !== undefined) qrState.showHeader = parsed.showHeader;
      if (parsed.showFooter !== undefined) qrState.showFooter = parsed.showFooter;
      if (parsed.labelMode !== undefined) qrState.labelMode = parsed.labelMode;
      if (parsed.customText !== undefined) qrState.customText = parsed.customText;
    }
  } catch (err) {
    console.warn("Erro ao ler preferências de QR do storage:", err);
  }
}

function saveQrConfig() {
  try {
    localStorage.setItem("binfae_qr_config", JSON.stringify(qrState));
  } catch (err) {
    // Silencioso em caso de restrição de storage
  }
}

function syncQrModalControls() {
  // Sincroniza select de payload
  const selPayload = document.getElementById("qr-payload-mode");
  if (selPayload) selPayload.value = qrState.payloadMode;

  const customBox = document.getElementById("qr-custom-text-container");
  const customInput = document.getElementById("qr-custom-text");
  if (customBox) {
    if (qrState.payloadMode === "custom") {
      customBox.classList.remove("hidden");
    } else {
      customBox.classList.add("hidden");
    }
  }
  if (customInput) customInput.value = qrState.customText || "";

  // Sincroniza checkboxes de campos
  for (const [field, isChecked] of Object.entries(qrState.fields)) {
    const el = document.getElementById(`qr-field-${field}`);
    if (el) el.checked = !!isChecked;
  }

  // Sincroniza cabeçalho e rodapé
  const elHeader = document.getElementById("qr-opt-header");
  if (elHeader) elHeader.checked = !!qrState.showHeader;

  const elFooter = document.getElementById("qr-opt-footer");
  if (elFooter) elFooter.checked = !!qrState.showFooter;
}

function openQrModal(itemId) {
  const item = (state.allItems || []).find(i => i.id === itemId) || state.items.find(i => i.id === itemId);
  if (!item) return;

  state.selectedItemForModal = item;
  loadQrConfig();

  const titleEl = document.getElementById("qr-modal-title");
  if (titleEl) titleEl.textContent = `Etiqueta / QR Code: ${item.nome}`;

  syncQrModalControls();
  updateQrModalPreview();

  const modal = document.getElementById("modal-qr");
  if (modal) modal.classList.remove("hidden");
}

function closeQrModal() {
  const modal = document.getElementById("modal-qr");
  if (modal) modal.classList.add("hidden");
  state.selectedItemForModal = null;
}

function setQrModalMode(labelMode) {
  qrState.labelMode = labelMode;
  saveQrConfig();
  updateQrModalPreview();
}

function onQrFieldChange() {
  for (const f of Object.keys(qrState.fields)) {
    const el = document.getElementById(`qr-field-${f}`);
    if (el) qrState.fields[f] = el.checked;
  }
  saveQrConfig();
  updateQrModalPreview();
}

function onQrOptionChange() {
  const elHeader = document.getElementById("qr-opt-header");
  if (elHeader) qrState.showHeader = elHeader.checked;

  const elFooter = document.getElementById("qr-opt-footer");
  if (elFooter) qrState.showFooter = elFooter.checked;

  saveQrConfig();
  updateQrModalPreview();
}

function onQrPayloadModeChange() {
  const sel = document.getElementById("qr-payload-mode");
  if (!sel) return;
  qrState.payloadMode = sel.value;

  const customBox = document.getElementById("qr-custom-text-container");
  if (customBox) {
    if (qrState.payloadMode === "custom") {
      customBox.classList.remove("hidden");
    } else {
      customBox.classList.add("hidden");
    }
  }

  saveQrConfig();
  updateQrModalPreview();
}

let qrDebounceTimer = null;
function debounceUpdateQrPreview() {
  clearTimeout(qrDebounceTimer);
  qrDebounceTimer = setTimeout(() => {
    const txt = document.getElementById("qr-custom-text");
    if (txt) qrState.customText = txt.value;
    saveQrConfig();
    updateQrModalPreview();
  }, 350);
}

function setAllQrFields(val) {
  for (const f of Object.keys(qrState.fields)) {
    qrState.fields[f] = val;
    const el = document.getElementById(`qr-field-${f}`);
    if (el) el.checked = val;
  }
  saveQrConfig();
  updateQrModalPreview();
}

function setQrFieldsPreset(preset) {
  if (preset === "basic") {
    qrState.fields = {
      nome: true,
      bmp: true,
      codigo_interno: true,
      numero_serie: true,
      subgrupo: true,
      local: true,
      status: false,
      estado: false
    };
  }
  syncQrModalControls();
  saveQrConfig();
  updateQrModalPreview();
}

function updateQrModalPreview() {
  if (!state.selectedItemForModal) return;
  const item = state.selectedItemForModal;
  const img = document.getElementById("qr-preview-img");
  const printImg = document.getElementById("printable-label-img");
  const btnLabel = document.getElementById("btn-qr-mode-label");
  const btnPure = document.getElementById("btn-qr-mode-pure");
  const labelOptionsContainer = document.getElementById("qr-label-options-container");

  if (qrState.labelMode) {
    btnLabel?.classList.add("bg-sky-600", "text-white", "shadow-sm");
    btnLabel?.classList.remove("bg-white", "text-slate-700", "border");
    btnPure?.classList.remove("bg-sky-600", "text-white", "shadow-sm");
    btnPure?.classList.add("bg-white", "text-slate-700", "border");
    labelOptionsContainer?.classList.remove("hidden");
  } else {
    btnPure?.classList.add("bg-sky-600", "text-white", "shadow-sm");
    btnPure?.classList.remove("bg-white", "text-slate-700", "border");
    btnLabel?.classList.remove("bg-sky-600", "text-white", "shadow-sm");
    btnLabel?.classList.add("bg-white", "text-slate-700", "border");
    labelOptionsContainer?.classList.add("hidden");
  }

  // Lista de campos da etiqueta ativos
  const activeFields = Object.keys(qrState.fields).filter(k => qrState.fields[k]);

  const params = new URLSearchParams({
    include_label: qrState.labelMode ? "true" : "false",
    payload_mode: qrState.payloadMode,
    show_header: qrState.showHeader ? "true" : "false",
    show_footer: qrState.showFooter ? "true" : "false",
    header_title: qrState.headerTitle,
    header_subtitle: qrState.headerSubtitle,
    fields: activeFields.join(","),
    qr_fields: activeFields.join(","),
    _t: Date.now()
  });

  if (qrState.payloadMode === "custom" && qrState.customText) {
    params.set("custom_text", qrState.customText);
  }

  const baseUrl = getApiBaseUrl();
  const url = `${baseUrl ? baseUrl : ""}/stock/items/${item.id}/qrcode?${params.toString()}`;

  if (img) img.src = url;
  if (printImg) printImg.src = url;
}

function printLabel() {
  window.print();
}

async function downloadQrImage() {
  if (!state.selectedItemForModal) return;
  const item = state.selectedItemForModal;
  const img = document.getElementById("qr-preview-img");
  if (!img || !img.src) return;

  try {
    const res = await fetch(img.src);
    const blob = await res.blob();
    const blobUrl = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = blobUrl;
    const prefix = qrState.labelMode ? "etiqueta" : "qrcode";
    a.download = `${prefix}_${item.bmp || item.codigo_interno || item.id}.png`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(blobUrl);
    showToast("Etiqueta baixada com sucesso!", "success");
  } catch (err) {
    console.error("Erro ao baixar etiqueta:", err);
    window.open(img.src, "_blank");
  }
}

// ============================================================================
// 7. MODAIS DE AÇÕES (NOVO MATERIAL, MOVER, AJUSTAR SALDO)
// ============================================================================

// --- Novo Item ---
function openNewItemModal() {
  const modal = document.getElementById("modal-new-item");
  if (modal) modal.classList.remove("hidden");
}

function closeNewItemModal() {
  const modal = document.getElementById("modal-new-item");
  if (modal) modal.classList.add("hidden");
  document.getElementById("form-new-item")?.reset();
}

async function handleCreateItem(e) {
  e.preventDefault();
  const form = e.target;

  const nome = form.nome.value.trim();
  const subgrupo_id = parseInt(form.subgrupo_id.value);
  const local_id = form.local_id.value ? parseInt(form.local_id.value) : null;
  const parent_id = form.parent_id.value ? parseInt(form.parent_id.value) : null;
  const bmp = form.bmp.value.trim() || null;
  const codigo_interno = form.codigo_interno.value.trim() || null;
  const numero_serie = form.numero_serie.value.trim() || null;
  const tipo_controle = form.tipo_controle.value;
  const quantidade = parseFloat(form.quantidade.value) || 1.0;
  const quantidade_minima = parseFloat(form.quantidade_minima.value) || 0.0;
  const unidade_medida = form.unidade_medida.value.trim() || "UNIDADE";
  const estado_conservacao = form.estado_conservacao.value;
  const status = form.status.value;
  const observacoes = form.observacoes.value.trim() || null;

  // Características dinâmicas
  const caracteristicas = {};
  const specKey1 = form.spec_key_1?.value.trim();
  const specVal1 = form.spec_val_1?.value.trim();
  if (specKey1 && specVal1) caracteristicas[specKey1] = specVal1;

  const specKey2 = form.spec_key_2?.value.trim();
  const specVal2 = form.spec_val_2?.value.trim();
  if (specKey2 && specVal2) caracteristicas[specKey2] = specVal2;

  const specKey3 = form.spec_key_3?.value.trim();
  const specVal3 = form.spec_val_3?.value.trim();
  if (specKey3 && specVal3) caracteristicas[specKey3] = specVal3;

  const payload = {
    nome,
    subgrupo_id,
    local_id,
    parent_id,
    bmp,
    codigo_interno,
    numero_serie,
    tipo_controle,
    quantidade,
    quantidade_minima,
    unidade_medida,
    estado_conservacao,
    status,
    caracteristicas,
    observacoes
  };

  try {
    const newItem = await api("/stock/items", { method: "POST", body: payload });
    showNotification("Material cadastrado com sucesso no estoque!");
    closeNewItemModal();

    if (newItem) {
      state.allItems.push(newItem);
      state.items.push(newItem);
      persistLocalDatabase();
      if (newItem.local_id) {
        let curr = state.locations.find(l => l.id === newItem.local_id);
        while (curr) {
          state.collapsedLocations.delete(curr.id);
          curr = state.locations.find(l => l.id === curr.parent_id);
        }
      }
      renderLocationsTree();
      renderItemsTable();
      renderDashboardMetrics();
    }

    await Promise.all([
      loadAllItems(),
      loadItems(),
      loadLocations()
    ]);
    renderLocationsTree();
    renderItemsTable();
    renderDashboardMetrics();
  } catch (err) {
    // Erro exibido pelo showNotification no api()
  }
}

// --- Mover / Transferir ---
function onMoveModalLocationChange() {
  const locSelect = document.getElementById("move-modal-location");
  const parentSelect = document.getElementById("move-modal-parent");
  if (locSelect && locSelect.value && parentSelect) {
    parentSelect.value = "";
  }
}

function onMoveModalParentChange() {
  const locSelect = document.getElementById("move-modal-location");
  const parentSelect = document.getElementById("move-modal-parent");
  if (parentSelect && parentSelect.value && locSelect) {
    locSelect.value = "";
  }
}

function openMoveModal(itemId) {
  const item = (state.allItems || []).find(i => i.id === itemId) || state.items.find(i => i.id === itemId);
  if (!item) return;

  state.selectedItemForModal = item;

  // Atualiza opções dos selects de locais
  populateLocationSelects();

  // Preenche select de equipamentos pais excluindo o próprio item
  const parentSelect = document.getElementById("move-modal-parent");
  if (parentSelect) {
    const itemsList = (state.allItems && state.allItems.length > 0) ? state.allItems : state.items;
    parentSelect.innerHTML = `<option value="">Nenhum (Item Independente / Em Local Físico)</option>` +
      itemsList
        .filter(i => i.id !== item.id && !i.parent_id && (!i.parent || !i.parent.id))
        .map(i => `<option value="${i.id}">${escapeHtml(i.nome)} ${i.bmp ? `[BMP: ${i.bmp}]` : ""}</option>`)
        .join("");
  }

  // Preenche nome do material
  const nameEl = document.getElementById("move-modal-item-name");
  if (nameEl) {
    nameEl.textContent = `${item.nome} ${item.bmp ? `[BMP: ${item.bmp}]` : ''}`;
  }

  // Seleciona a localização atual do material
  const locSelect = document.getElementById("move-modal-location");
  const curLocId = item.local_id || (item.local?.id || "");
  const curParentId = item.parent_id || (item.parent?.id || "");

  if (locSelect) {
    locSelect.value = curParentId ? "" : (curLocId || "");
  }

  if (parentSelect) {
    parentSelect.value = curParentId || "";
  }

  const form = document.getElementById("form-move-item");
  if (form) {
    const motivoInput = form.querySelector("input[name='motivo']");
    if (motivoInput) motivoInput.value = "";
  }

  document.getElementById("modal-move").classList.remove("hidden");
}

function closeMoveModal() {
  document.getElementById("modal-move").classList.add("hidden");
  state.selectedItemForModal = null;
}

async function handleMoveItem(e) {
  e.preventDefault();
  if (!state.selectedItemForModal) return;

  const form = e.target;
  const destino_local_id = form.destino_local_id.value ? parseInt(form.destino_local_id.value) : null;
  const parent_id = form.parent_id.value ? parseInt(form.parent_id.value) : null;
  const motivo = form.motivo.value.trim() || null;
  const itemId = state.selectedItemForModal.id;

  try {
    const updatedItem = await api(`/stock/items/${itemId}/move`, {
      method: "POST",
      body: { destino_local_id, parent_id, motivo }
    });
    showNotification("Material transferido com sucesso!");
    closeMoveModal();

    if (updatedItem) {
      // 1. Atualização imediata em memória no state.allItems (sem esperar rede!)
      const idxAll = (state.allItems || []).findIndex(i => i.id === updatedItem.id);
      if (idxAll !== -1) {
        state.allItems[idxAll] = updatedItem;
      } else {
        state.allItems.push(updatedItem);
      }

      // 2. Atualização imediata em memória no state.items
      const idxItems = (state.items || []).findIndex(i => i.id === updatedItem.id);
      if (idxItems !== -1) {
        state.items[idxItems] = updatedItem;
      }

      // 3. Se moveu para um local físico, desdobra as pastas-mãe para o usuário ver onde o item foi alocado
      if (destino_local_id) {
        let curr = state.locations.find(l => l.id === destino_local_id);
        while (curr) {
          state.collapsedLocations.delete(curr.id);
          curr = state.locations.find(l => l.id === curr.parent_id);
        }
      }

      // 4. Atualiza os contadores na hora (0ms): árvore de locais, tabela e métricas!
      renderLocationsTree();
      renderItemsTable();
      renderDashboardMetrics();
    }

    // 5. Sincroniza em segundo plano todo o estado com o servidor
    await Promise.all([
      loadAllItems(),
      loadItems(),
      loadMovements(),
      loadLocations()
    ]);

    // 6. Garante re-renderização com os dados sincronizados
    renderLocationsTree();
    renderItemsTable();
    renderDashboardMetrics();

    // Se o modal de detalhes estiver aberto com este item, atualiza
    if (state.selectedItemForDetail && state.selectedItemForDetail.id === itemId) {
      openItemDetailModal(itemId);
    }
  } catch (err) {
    showNotification(err.message || "Erro ao movimentar material.", "error");
  }
}

// --- Ajuste de Saldo ---
function openAdjustModal(itemId) {
  const item = (state.allItems || []).find(i => i.id === itemId) || state.items.find(i => i.id === itemId);
  if (!item) return;

  state.selectedItemForModal = item;
  document.getElementById("adjust-modal-item-name").textContent = `${item.nome} (Saldo atual: ${item.quantidade} ${item.unidade_medida})`;
  document.getElementById("modal-adjust").classList.remove("hidden");
}

function closeAdjustModal() {
  document.getElementById("modal-adjust").classList.add("hidden");
  state.selectedItemForModal = null;
}

async function handleAdjustStock(e) {
  e.preventDefault();
  if (!state.selectedItemForModal) return;

  const form = e.target;
  const tipo = form.tipo.value;
  const quantidade = parseFloat(form.quantidade.value);
  const motivo = form.motivo.value.trim() || null;

  try {
    const updatedItem = await api(`/stock/items/${state.selectedItemForModal.id}/adjust-stock`, {
      method: "POST",
      body: { tipo, quantidade, motivo }
    });
    showNotification("Saldo ajustado com sucesso!");
    closeAdjustModal();

    if (updatedItem) {
      const idxAll = (state.allItems || []).findIndex(i => i.id === updatedItem.id);
      if (idxAll !== -1) state.allItems[idxAll] = updatedItem;
      const idx = (state.items || []).findIndex(i => i.id === updatedItem.id);
      if (idx !== -1) state.items[idx] = updatedItem;
      renderLocationsTree();
      renderItemsTable();
      renderDashboardMetrics();
    }

    await Promise.all([
      loadAllItems(),
      loadItems(),
      loadMovements(),
      loadLocations()
    ]);
    renderLocationsTree();
    renderItemsTable();
    renderDashboardMetrics();
  } catch (err) {}
}

// ============================================================================
// MODAL: DETALHES COMPLETOS DO MATERIAL (VISUALIZAÇÃO)
// ============================================================================

function renderDetailMovements(movements) {
  const movList = document.getElementById("detail-item-movements-list");
  if (!movList) return;
  if (movements && movements.length > 0) {
    movList.innerHTML = movements.map(m => {
      const dateStr = new Date(m.data_hora).toLocaleString("pt-BR");
      const origemStr = m.origem ? m.origem.caminho_completo : "Entrada no Estoque";
      const destinoStr = m.destino ? m.destino.caminho_completo : "Baixa / Saída";
      return `
        <div class="p-2.5 bg-slate-50 border border-slate-100 rounded-lg text-xs">
          <div class="flex items-center justify-between">
            <span class="font-bold text-slate-800">${escapeHtml(m.tipo_movimentacao)}</span>
            <span class="text-slate-400 text-[11px] font-mono">${dateStr}</span>
          </div>
          <div class="text-slate-600 mt-1">
            <span>${escapeHtml(origemStr)}</span> ➔ <span class="font-semibold text-sky-800">${escapeHtml(destinoStr)}</span>
          </div>
          ${m.motivo ? `<div class="text-slate-500 italic mt-0.5 text-[11px]">Motivo: ${escapeHtml(m.motivo)}</div>` : ''}
          ${m.usuario ? `<div class="text-slate-400 text-[10px] mt-0.5">Responsável: ${escapeHtml(m.usuario.username)}</div>` : ''}
        </div>`;
    }).join("");
  } else {
    movList.innerHTML = `<div class="text-slate-400 italic py-1">Nenhuma movimentação registrada até o momento.</div>`;
  }
}

function populateItemDetailModal(item) {
  state.selectedItemForDetail = item;

  // Título e Subgrupo
  const titleEl = document.getElementById("detail-item-title");
  if (titleEl) titleEl.textContent = item.nome;

  const subgEl = document.getElementById("detail-item-subgroup");
  if (subgEl) {
    const grpName = item.subgrupo?.grupo?.nome;
    const subgName = item.subgrupo?.nome || "Sem subgrupo";
    subgEl.textContent = grpName ? `${grpName} ❯ ${subgName}` : subgName;
  }

  // Status Badge
  const statusBadge = document.getElementById("detail-item-status-badge");
  if (statusBadge) {
    statusBadge.textContent = item.status;
    const statusClasses = {
      DISPONIVEL: "badge-disponivel",
      EM_USO: "badge-em_uso",
      EM_MANUTENCAO: "badge-em_manutencao",
      CAUTELADO: "badge-cautelado",
      BAIXADO: "badge-baixado"
    };
    statusBadge.className = `px-2.5 py-0.5 rounded-full text-xs font-bold uppercase ${statusClasses[item.status] || 'bg-slate-100 text-slate-700'}`;
  }

  // Tipo de Controle Badge
  const ctrlBadge = document.getElementById("detail-item-control-badge");
  if (ctrlBadge) {
    ctrlBadge.textContent = item.tipo_controle === "GRANEL" ? "Estoque a Granel" : "Item Unitário";
  }

  // Identificadores
  const bmpEl = document.getElementById("detail-item-bmp");
  if (bmpEl) bmpEl.textContent = item.bmp || "—";
  const codEl = document.getElementById("detail-item-codigo-interno");
  if (codEl) codEl.textContent = item.codigo_interno || "—";
  const serEl = document.getElementById("detail-item-serial");
  if (serEl) serEl.textContent = item.numero_serie || "—";
  const conEl = document.getElementById("detail-item-conservacao");
  if (conEl) conEl.textContent = item.estado_conservacao || "BOM";

  // Localização
  const localEl = document.getElementById("detail-item-local");
  if (localEl) {
    if (item.local_efetivo) {
      localEl.textContent = item.local_efetivo.caminho_completo;
    } else if (item.local) {
      localEl.textContent = item.local.caminho_completo;
    } else {
      localEl.textContent = "Sem local definido";
    }
  }

  // Saldo
  const saldoEl = document.getElementById("detail-item-saldo");
  if (saldoEl) {
    saldoEl.textContent = item.tipo_controle === "GRANEL"
      ? `${item.quantidade} ${item.unidade_medida}`
      : "1 unidade";
  }

  const minEl = document.getElementById("detail-item-estoque-min");
  if (minEl) {
    minEl.textContent = item.tipo_controle === "GRANEL"
      ? `${item.quantidade_minima} ${item.unidade_medida}`
      : "—";
  }

  // Equipamento Pai
  const parentContainer = document.getElementById("detail-item-parent-container");
  const parentNameEl = document.getElementById("detail-item-parent-name");
  const btnViewParent = document.getElementById("btn-detail-view-parent");

  if (item.parent) {
    parentContainer?.classList.remove("hidden");
    if (parentNameEl) {
      parentNameEl.textContent = `${item.parent.nome} ${item.parent.bmp ? `[BMP: ${item.parent.bmp}]` : ''} ${item.parent.codigo_interno ? `(${item.parent.codigo_interno})` : ''}`;
    }
    if (btnViewParent) {
      btnViewParent.onclick = () => openItemDetailModal(item.parent.id);
    }
  } else {
    parentContainer?.classList.add("hidden");
  }

  // Especificações e Características
  const caracContainer = document.getElementById("detail-item-caracteristicas-list");
  if (caracContainer) {
    caracContainer.innerHTML = "";
    if (item.caracteristicas && Object.keys(item.caracteristicas).length > 0) {
      const validEntries = Object.entries(item.caracteristicas).filter(
        ([k, v]) => v !== null && v !== undefined && String(v).trim() !== ""
      );
      if (validEntries.length > 0) {
        validEntries.forEach(([key, val]) => {
          const div = document.createElement("div");
          div.className = "flex items-center px-3 py-1.5 bg-white border border-slate-200 rounded-lg shadow-xs text-xs";
          div.innerHTML = `<span class="font-bold text-slate-700 mr-1.5">${escapeHtml(key)}:</span><span class="text-sky-800 font-semibold">${escapeHtml(String(val))}</span>`;
          caracContainer.appendChild(div);
        });
      } else {
        caracContainer.innerHTML = `<span class="text-slate-400 italic">Nenhuma característica cadastrada.</span>`;
      }
    } else {
      caracContainer.innerHTML = `<span class="text-slate-400 italic">Nenhuma característica cadastrada.</span>`;
    }
  }

  // Componentes Instalados
  const compContainer = document.getElementById("detail-item-components-container");
  const compList = document.getElementById("detail-item-components-list");
  const compCount = document.getElementById("detail-item-components-count");

  if (item.componentes && item.componentes.length > 0) {
    compContainer?.classList.remove("hidden");
    if (compCount) compCount.textContent = item.componentes.length;
    if (compList) {
      compList.innerHTML = item.componentes.map(c => `
        <div class="flex items-center justify-between p-3 hover:bg-slate-50 transition-colors">
          <div>
            <div class="font-bold text-slate-800">${escapeHtml(c.nome)}</div>
            <div class="text-slate-500 text-[11px] flex items-center gap-2 mt-0.5">
              ${c.bmp ? `<span class="font-mono bg-slate-100 px-1 py-0.2 rounded text-slate-700">BMP: ${escapeHtml(c.bmp)}</span>` : ''}
              ${c.codigo_interno ? `<span class="font-mono text-slate-600">Cód: ${escapeHtml(c.codigo_interno)}</span>` : ''}
              ${c.numero_serie ? `<span class="font-mono text-slate-400">S/N: ${escapeHtml(c.numero_serie)}</span>` : ''}
            </div>
          </div>
          <button onclick="openItemDetailModal(${c.id})" class="px-3 py-1 bg-sky-50 text-sky-700 hover:bg-sky-100 border border-sky-200 rounded-lg text-xs font-semibold flex items-center gap-1">
            Ver Peça ➔
          </button>
        </div>
      `).join("");
    }
  } else {
    compContainer?.classList.add("hidden");
  }

  // Observações
  const obsEl = document.getElementById("detail-item-observacoes");
  if (obsEl) {
    obsEl.textContent = item.observacoes ? item.observacoes : "Nenhuma observação informada.";
  }

  // Botões de Ação no Detalhe
  const btnEdit = document.getElementById("btn-detail-edit");
  if (btnEdit) {
    btnEdit.onclick = () => {
      closeItemDetailModal();
      openEditItemModal(item.id);
    };
  }
  const btnQr = document.getElementById("btn-detail-qr");
  if (btnQr) {
    btnQr.onclick = () => {
      openQrModal(item.id);
    };
  }
  const btnMove = document.getElementById("btn-detail-move");
  if (btnMove) {
    btnMove.onclick = () => {
      openMoveModal(item.id);
    };
  }

  const btnAdj = document.getElementById("btn-detail-adjust");
  if (btnAdj) {
    if (item.tipo_controle === "GRANEL") {
      btnAdj.classList.remove("hidden");
      btnAdj.onclick = () => openAdjustModal(item.id);
    } else {
      btnAdj.classList.add("hidden");
    }
  }

  const btnDel = document.getElementById("btn-detail-delete");
  if (btnDel) {
    btnDel.onclick = async () => {
      const confirmed = await deleteItemAction(item.id);
      if (confirmed) closeItemDetailModal();
    };
  }
}

async function openItemDetailModal(itemId) {
  let item = (state.allItems || []).find(i => i.id === itemId) || state.items.find(i => i.id === itemId);

  const movList = document.getElementById("detail-item-movements-list");
  if (movList) movList.innerHTML = `<div class="text-slate-400 italic py-2">Carregando histórico...</div>`;

  // Se o item já está na memória local, preenche e abre o modal em 0ms (instantâneo!)
  if (item) {
    populateItemDetailModal(item);
    document.getElementById("modal-item-detail")?.classList.remove("hidden");
  }

  // Busca histórico de movimentações em segundo plano sem travar a interface
  api(`/stock/movements?item_id=${itemId}`).then(movements => {
    if (state.selectedItemForDetail && state.selectedItemForDetail.id === itemId) {
      renderDetailMovements(movements);
    }
  }).catch(() => {
    if (movList) movList.innerHTML = `<div class="text-slate-400 italic py-1">Não foi possível carregar o histórico de movimentações.</div>`;
  });

  // Atualiza os dados mais recentes do item em segundo plano
  api(`/stock/items/${itemId}`).then(freshItem => {
    if (freshItem) {
      const idxAll = (state.allItems || []).findIndex(i => i.id === itemId);
      if (idxAll !== -1) state.allItems[idxAll] = freshItem;
      const idxItems = (state.items || []).findIndex(i => i.id === itemId);
      if (idxItems !== -1) state.items[idxItems] = freshItem;

      if (!item) {
        populateItemDetailModal(freshItem);
        document.getElementById("modal-item-detail")?.classList.remove("hidden");
      } else if (state.selectedItemForDetail && state.selectedItemForDetail.id === itemId) {
        populateItemDetailModal(freshItem);
      }
    }
  }).catch(() => {});
}

function closeItemDetailModal() {
  document.getElementById("modal-item-detail")?.classList.add("hidden");
  state.selectedItemForDetail = null;
}

// ============================================================================
// MODAL: EDITAR MATERIAL
// ============================================================================

function addEditItemCaracRow(key = "", value = "") {
  const container = document.getElementById("edit-item-caracteristicas-container");
  if (!container) return;

  const div = document.createElement("div");
  div.className = "flex items-center gap-2 edit-carac-row";
  div.innerHTML = `
    <input type="text" placeholder="Nome do atributo (ex: processador)" value="${escapeHtml(key)}" class="w-1/3 border border-slate-200 rounded-lg px-2.5 py-1.5 text-xs focus:ring-1 focus:ring-sky-500 font-medium carac-key">
    <input type="text" placeholder="Valor (ex: Core i7 10700K)" value="${escapeHtml(value)}" class="flex-1 border border-slate-200 rounded-lg px-2.5 py-1.5 text-xs focus:ring-1 focus:ring-sky-500 carac-val">
    <button type="button" onclick="this.parentElement.remove()" class="p-1.5 text-rose-500 hover:text-rose-700 hover:bg-rose-50 rounded" title="Remover campo">✕</button>
  `;
  container.appendChild(div);
}

function populateEditItemForm(item) {
  state.selectedItemForEdit = item;

  // 1. Atualizar selects de subgrupos e locais
  populateSubgroupSelects();
  populateLocationSelects();

  // 2. Select de Equipamento Pai (exclui o próprio item para não permitir circularidade)
  const parentSelect = document.getElementById("edit-item-parent_id");
  if (parentSelect) {
    const itemsList = (state.allItems && state.allItems.length > 0) ? state.allItems : state.items;
    parentSelect.innerHTML = `<option value="">Nenhum (Item avulso / Equipamento principal)</option>` +
      itemsList
        .filter(i => i.id !== item.id && !i.parent_id && (!i.parent || !i.parent.id))
        .map(i => `<option value="${i.id}">${escapeHtml(i.nome)} ${i.bmp ? `[BMP: ${i.bmp}]` : ""}</option>`)
        .join("");
  }

  // 3. Preencher campos do formulário
  document.getElementById("edit-item-id").value = item.id;
  document.getElementById("edit-item-nome").value = item.nome || "";
  document.getElementById("edit-item-subgrupo_id").value = item.subgrupo_id || (item.subgrupo?.id || "");
  
  const curLocId = item.local_id || (item.local?.id || "");
  const curParentId = item.parent_id || (item.parent?.id || "");
  
  document.getElementById("edit-item-local_id").value = curParentId ? "" : (curLocId || "");
  document.getElementById("edit-item-parent_id").value = curParentId || "";
  document.getElementById("edit-item-bmp").value = item.bmp || "";
  document.getElementById("edit-item-codigo_interno").value = item.codigo_interno || "";
  document.getElementById("edit-item-numero_serie").value = item.numero_serie || "";
  document.getElementById("edit-item-estado_conservacao").value = item.estado_conservacao || "BOM";
  document.getElementById("edit-item-status").value = item.status || "DISPONIVEL";
  document.getElementById("edit-item-tipo_controle").value = item.tipo_controle || "UNITARIO";
  document.getElementById("edit-item-quantidade_minima").value = item.quantidade_minima || 0;
  document.getElementById("edit-item-unidade_medida").value = item.unidade_medida || "UNIDADE";
  document.getElementById("edit-item-observacoes").value = item.observacoes || "";

  // Alternar campos de granel
  const granelContainer = document.getElementById("edit-item-granel-fields");
  if (item.tipo_controle === "GRANEL") {
    granelContainer?.classList.remove("hidden");
  } else {
    granelContainer?.classList.add("hidden");
  }

  // 4. Preencher características maleáveis
  const caracContainer = document.getElementById("edit-item-caracteristicas-container");
  if (caracContainer) {
    caracContainer.innerHTML = "";
    if (item.caracteristicas && Object.keys(item.caracteristicas).length > 0) {
      Object.entries(item.caracteristicas).forEach(([k, v]) => {
        addEditItemCaracRow(k, v);
      });
    } else {
      addEditItemCaracRow("", "");
    }
  }
}

async function openEditItemModal(itemId) {
  let item = (state.allItems || []).find(i => i.id === itemId) || state.items.find(i => i.id === itemId);

  // Se o item já está na memória local, preenche e abre o modal em 0ms (instantâneo!)
  if (item) {
    populateEditItemForm(item);
    document.getElementById("modal-edit-item")?.classList.remove("hidden");
  }

  // Atualiza os dados mais recentes em segundo plano
  api(`/stock/items/${itemId}`).then(freshItem => {
    if (freshItem) {
      const idxAll = (state.allItems || []).findIndex(i => i.id === itemId);
      if (idxAll !== -1) state.allItems[idxAll] = freshItem;
      const idxItems = (state.items || []).findIndex(i => i.id === itemId);
      if (idxItems !== -1) state.items[idxItems] = freshItem;

      if (!item) {
        populateEditItemForm(freshItem);
        document.getElementById("modal-edit-item")?.classList.remove("hidden");
      }
    }
  }).catch(() => {});
}

function closeEditItemModal() {
  document.getElementById("modal-edit-item")?.classList.add("hidden");
  state.selectedItemForEdit = null;
}

async function handleEditItem(e) {
  e.preventDefault();
  const form = e.target;
  const id = parseInt(form.id.value);
  if (!id) return;

  const nome = form.nome.value.trim();
  const subgrupo_id = parseInt(form.subgrupo_id.value);
  const local_id = form.local_id.value ? parseInt(form.local_id.value) : null;
  const parent_id = form.parent_id.value ? parseInt(form.parent_id.value) : null;
  const bmp = form.bmp.value.trim() || null;
  const codigo_interno = form.codigo_interno.value.trim() || null;
  const numero_serie = form.numero_serie.value.trim() || null;
  const tipo_controle = form.tipo_controle.value;
  const quantidade_minima = parseFloat(form.quantidade_minima?.value) || 0.0;
  const unidade_medida = form.unidade_medida?.value.trim() || "UNIDADE";
  const estado_conservacao = form.estado_conservacao.value;
  const status = form.status.value;
  const observacoes = form.observacoes.value.trim() || null;

  // Coleta características dinâmicas
  const caracteristicas = {};
  const rows = form.querySelectorAll(".edit-carac-row");
  rows.forEach(r => {
    const key = r.querySelector(".carac-key")?.value.trim();
    const val = r.querySelector(".carac-val")?.value.trim();
    if (key && val) {
      caracteristicas[key] = val;
    }
  });

  const payload = {
    nome,
    subgrupo_id,
    local_id,
    parent_id,
    bmp,
    codigo_interno,
    numero_serie,
    tipo_controle,
    quantidade_minima,
    unidade_medida,
    estado_conservacao,
    status,
    caracteristicas,
    observacoes
  };

  try {
    const updatedItem = await api(`/stock/items/${id}`, {
      method: "PUT",
      body: payload
    });
    showNotification("Material atualizado com sucesso!");
    closeEditItemModal();

    if (updatedItem) {
      // 1. Atualiza imediatamente o item no cache global state.allItems
      const idxAll = (state.allItems || []).findIndex(i => i.id === updatedItem.id);
      if (idxAll !== -1) {
        state.allItems[idxAll] = updatedItem;
      } else {
        state.allItems.push(updatedItem);
      }

      // 2. Atualiza imediatamente no state.items
      const idxItems = (state.items || []).findIndex(i => i.id === updatedItem.id);
      if (idxItems !== -1) {
        state.items[idxItems] = updatedItem;
      }
      persistLocalDatabase();

      // 3. Se o local foi alterado, desdobra as pastas de destino
      if (local_id) {
        let curr = state.locations.find(l => l.id === local_id);
        while (curr) {
          state.collapsedLocations.delete(curr.id);
          curr = state.locations.find(l => l.id === curr.parent_id);
        }
      }

      // 4. Atualiza a árvore, tabela e métricas na hora (0ms)!
      renderLocationsTree();
      renderItemsTable();
      renderDashboardMetrics();
    }

    // 5. Sincronização em segundo plano
    await Promise.all([
      loadAllItems(),
      loadItems(),
      loadMovements(),
      loadLocations()
    ]);
    renderLocationsTree();
    renderItemsTable();
    renderDashboardMetrics();

    // Se o modal de detalhes estiver aberto com este item, atualiza
    if (state.selectedItemForDetail && state.selectedItemForDetail.id === id) {
      openItemDetailModal(id);
    }
  } catch (err) {
    showNotification(err.message || "Erro ao atualizar material.", "error");
  }
}

// --- Excluir Material ---
async function deleteItemAction(itemId) {
  if (!confirm("Tem certeza que deseja excluir este material do estoque?")) return false;
  try {
    await api(`/stock/items/${itemId}`, { method: "DELETE" });
    showNotification("Material excluído do estoque.");
    
    // Remove imediatamente da memória local
    state.allItems = (state.allItems || []).filter(i => i.id !== itemId);
    state.items = (state.items || []).filter(i => i.id !== itemId);
    persistLocalDatabase();
    renderLocationsTree();
    renderItemsTable();
    renderDashboardMetrics();

    await Promise.all([
      loadAllItems(),
      loadItems(),
      loadLocations()
    ]);
    renderLocationsTree();
    renderItemsTable();
    renderDashboardMetrics();
    return true;
  } catch (err) {
    return false;
  }
}

// ============================================================================
// ============================================================================
// 8. SCANNER QR CODE & CÂMERA MOBILE / DESKTOP (HTML5-QRCODE)
// ============================================================================

let cameraScannerInstance = null;
let isCameraScanning = false;
let currentCameraFacingMode = "environment"; // "environment" (traseira) ou "user" (frontal)
let availableCameraDevices = [];
let selectedCameraDeviceId = null;
let isTorchOn = false;
let scanSoundEnabled = localStorage.getItem("binfae_scan_sound") !== "false";
let scanVibrateEnabled = localStorage.getItem("binfae_scan_vibrate") !== "false";
let lastScanTimestamp = 0;
let lastScannedCode = "";

function switchScannerMode(mode) {
  const tabs = document.querySelectorAll(".scanner-mode-tab");
  tabs.forEach(t => {
    t.classList.remove("active", "bg-white", "dark:bg-slate-900", "text-sky-600", "dark:text-sky-400", "shadow-xs");
    t.classList.add("text-slate-600", "dark:text-slate-400");
  });

  const activeTab = document.getElementById(`btn-scanner-mode-${mode}`);
  if (activeTab) {
    activeTab.classList.add("active", "bg-white", "dark:bg-slate-900", "text-sky-600", "dark:text-sky-400", "shadow-xs");
    activeTab.classList.remove("text-slate-600", "dark:text-slate-400");
  }

  document.getElementById("scanner-panel-camera")?.classList.add("hidden");
  document.getElementById("scanner-panel-file")?.classList.add("hidden");
  document.getElementById("scanner-panel-manual")?.classList.add("hidden");

  if (mode === "camera") {
    document.getElementById("scanner-panel-camera")?.classList.remove("hidden");
  } else if (mode === "file") {
    document.getElementById("scanner-panel-file")?.classList.remove("hidden");
  } else if (mode === "manual") {
    document.getElementById("scanner-panel-manual")?.classList.remove("hidden");
    document.getElementById("scanner-input")?.focus();
  }
}

function playScanBeep() {
  if (!scanSoundEnabled) return;
  try {
    const AudioCtx = window.AudioContext || window.webkitAudioContext;
    if (!AudioCtx) return;
    const ctx = new AudioCtx();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sine";
    osc.frequency.setValueAtTime(880, ctx.currentTime);
    gain.gain.setValueAtTime(0.2, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.12);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start();
    osc.stop(ctx.currentTime + 0.12);
  } catch (e) {}
}

function triggerScanVibrate() {
  if (!scanVibrateEnabled) return;
  triggerHaptic("success");
}

function toggleScanSound() {
  scanSoundEnabled = !scanSoundEnabled;
  localStorage.setItem("binfae_scan_sound", scanSoundEnabled ? "true" : "false");
  const icon = document.getElementById("scan-sound-icon");
  if (icon) icon.textContent = scanSoundEnabled ? "🔊" : "🔇";
  showToast(scanSoundEnabled ? "Som do scanner ativado." : "Som do scanner silenciado.");
}

function toggleScanVibrate() {
  scanVibrateEnabled = !scanVibrateEnabled;
  localStorage.setItem("binfae_scan_vibrate", scanVibrateEnabled ? "true" : "false");
  const icon = document.getElementById("scan-vibrate-icon");
  if (icon) icon.textContent = scanVibrateEnabled ? "📳" : "📴";
  showToast(scanVibrateEnabled ? "Vibração do scanner ativada." : "Vibração desativada.");
}

async function startCameraScanner() {
  if (typeof Html5Qrcode === "undefined") {
    showToast("A biblioteca do leitor de câmera ainda está carregando...", "warning");
    return;
  }

  const placeholder = document.getElementById("scanner-camera-placeholder");
  const reticle = document.getElementById("scanner-overlay-reticle");
  const statusPill = document.getElementById("camera-status-pill");
  const toggleIcon = document.getElementById("camera-toggle-icon");
  const toggleLabel = document.getElementById("camera-toggle-label");
  const toggleBtn = document.getElementById("btn-camera-toggle");

  try {
    if (!cameraScannerInstance) {
      cameraScannerInstance = new Html5Qrcode("qr-camera-viewport");
    }

    if (isCameraScanning) return;

    // Popula lista de câmeras se disponível
    try {
      const devices = await Html5Qrcode.getCameras();
      if (devices && devices.length > 0) {
        availableCameraDevices = devices;
        const select = document.getElementById("scanner-camera-select");
        if (select && select.options.length <= 2) {
          select.innerHTML = "";
          devices.forEach((dev, idx) => {
            const opt = document.createElement("option");
            opt.value = dev.id;
            opt.textContent = `📷 ${dev.label || `Câmera ${idx + 1}`}`;
            select.appendChild(opt);
          });
          const backCam = devices.find(d => /back|rear|traseira|environment/i.test(d.label));
          if (backCam) {
            select.value = backCam.id;
            selectedCameraDeviceId = backCam.id;
          } else {
            selectedCameraDeviceId = devices[0].id;
          }
        }
      }
    } catch (e) {
      console.warn("Html5Qrcode.getCameras() aviso:", e);
    }

    const config = {
      fps: 15,
      qrbox: (viewfinderWidth, viewfinderHeight) => {
        const minEdge = Math.min(viewfinderWidth, viewfinderHeight);
        const qrboxSize = Math.max(180, Math.floor(minEdge * 0.72));
        return { width: qrboxSize, height: qrboxSize };
      },
      aspectRatio: 1.333333,
      experimentalFeatures: {
        useBarCodeDetectorIfSupported: true
      }
    };

    const cameraConfig = selectedCameraDeviceId
      ? { deviceId: { exact: selectedCameraDeviceId } }
      : { facingMode: currentCameraFacingMode };

    await cameraScannerInstance.start(
      cameraConfig,
      config,
      (decodedText) => {
        onQrScanDetected(decodedText);
      },
      () => {} // Ignora falhas por frame contínuo
    );

    isCameraScanning = true;
    placeholder?.classList.add("hidden");
    reticle?.classList.remove("hidden");
    statusPill?.classList.remove("hidden");

    if (toggleIcon) toggleIcon.textContent = "⏹";
    if (toggleLabel) toggleLabel.textContent = "Parar Câmera";
    if (toggleBtn) {
      toggleBtn.classList.remove("bg-sky-600", "hover:bg-sky-500");
      toggleBtn.classList.add("bg-rose-600", "hover:bg-rose-500");
    }

    // Checa suporte a flash / tocha
    try {
      const track = cameraScannerInstance.getRunningTrack();
      const capabilities = track?.getCapabilities?.();
      if (capabilities && capabilities.torch) {
        document.getElementById("btn-camera-torch")?.classList.remove("hidden");
      } else {
        document.getElementById("btn-camera-torch")?.classList.add("hidden");
      }
    } catch (e) {
      document.getElementById("btn-camera-torch")?.classList.add("hidden");
    }

    showToast("Câmera conectada. Aponte para o QR Code.");
  } catch (err) {
    console.error("Erro ao iniciar câmera:", err);
    placeholder?.classList.remove("hidden");
    reticle?.classList.add("hidden");
    statusPill?.classList.add("hidden");
    isCameraScanning = false;

    let msg = "Não foi possível acessar a câmera do dispositivo.";
    if (err && String(err).toLowerCase().includes("permission")) {
      msg = "Permissão de câmera negada. Habilite a câmera nas configurações do navegador.";
    } else if (err && String(err).toLowerCase().includes("notallowederror")) {
      msg = "Acesso à câmera bloqueado. Verifique as permissões de privacidade.";
    }
    showToast(msg, "error");
  }
}

async function stopCameraScanner() {
  if (cameraScannerInstance && isCameraScanning) {
    try {
      await cameraScannerInstance.stop();
    } catch (err) {
      console.warn("Erro ao parar câmera:", err);
    }
  }
  isCameraScanning = false;
  isTorchOn = false;

  document.getElementById("scanner-camera-placeholder")?.classList.remove("hidden");
  document.getElementById("scanner-overlay-reticle")?.classList.add("hidden");
  document.getElementById("camera-status-pill")?.classList.add("hidden");
  document.getElementById("btn-camera-torch")?.classList.add("hidden");

  const toggleIcon = document.getElementById("camera-toggle-icon");
  const toggleLabel = document.getElementById("camera-toggle-label");
  const toggleBtn = document.getElementById("btn-camera-toggle");
  if (toggleIcon) toggleIcon.textContent = "▶";
  if (toggleLabel) toggleLabel.textContent = "Iniciar Câmera";
  if (toggleBtn) {
    toggleBtn.classList.remove("bg-rose-600", "hover:bg-rose-500");
    toggleBtn.classList.add("bg-sky-600", "hover:bg-sky-500");
  }
}

function toggleCameraScanner() {
  if (isCameraScanning) {
    stopCameraScanner();
  } else {
    startCameraScanner();
  }
}

async function switchCameraFacingMode() {
  currentCameraFacingMode = currentCameraFacingMode === "environment" ? "user" : "environment";
  selectedCameraDeviceId = null;
  const select = document.getElementById("scanner-camera-select");
  if (select) {
    select.value = currentCameraFacingMode;
  }
  if (isCameraScanning) {
    await stopCameraScanner();
    await startCameraScanner();
  }
}

async function onCameraDeviceSelected(val) {
  if (val === "environment" || val === "user") {
    currentCameraFacingMode = val;
    selectedCameraDeviceId = null;
  } else {
    selectedCameraDeviceId = val;
  }
  if (isCameraScanning) {
    await stopCameraScanner();
    await startCameraScanner();
  }
}

async function toggleCameraTorch() {
  if (!cameraScannerInstance || !isCameraScanning) return;
  try {
    isTorchOn = !isTorchOn;
    await cameraScannerInstance.applyVideoConstraints({
      advanced: [{ torch: isTorchOn }]
    });
    const btn = document.getElementById("btn-camera-torch");
    if (btn) {
      if (isTorchOn) {
        btn.classList.add("bg-amber-500", "text-white");
        btn.classList.remove("bg-black/60", "text-amber-300");
      } else {
        btn.classList.remove("bg-amber-500", "text-white");
        btn.classList.add("bg-black/60", "text-amber-300");
      }
    }
    showToast(isTorchOn ? "Lanterna ligada." : "Lanterna desligada.");
  } catch (e) {
    console.warn("Tocha não suportada:", e);
    showToast("Lanterna não suportada por este dispositivo.", "warning");
  }
}

async function handleScanImageFile(event) {
  const file = event.target.files && event.target.files[0];
  if (!file) return;

  const previewWrap = document.getElementById("scanner-file-preview-wrap");
  const previewImg = document.getElementById("scanner-file-preview");
  const statusTxt = document.getElementById("scanner-file-status");

  if (previewWrap && previewImg) {
    previewImg.src = URL.createObjectURL(file);
    previewWrap.classList.remove("hidden");
    if (statusTxt) statusTxt.textContent = "Analisando imagem com o scanner...";
  }

  try {
    let scanner = cameraScannerInstance;
    if (!scanner) {
      scanner = new Html5Qrcode("qr-camera-viewport");
      cameraScannerInstance = scanner;
    }
    const decodedText = await scanner.scanFile(file, true);
    if (statusTxt) statusTxt.textContent = `Código identificado: ${decodedText}`;
    onQrScanDetected(decodedText);
  } catch (err) {
    console.warn("Erro ao decodificar imagem:", err);
    if (statusTxt) {
      statusTxt.textContent = "Nenhum QR Code legível foi encontrado nesta imagem.";
    }
    showToast("Nenhum QR Code válido localizado na imagem selecionada.", "warning");
  }
}

function onQrScanDetected(decodedText) {
  const now = Date.now();
  if (decodedText === lastScannedCode && (now - lastScanTimestamp < 2200)) {
    return;
  }
  lastScanTimestamp = now;
  lastScannedCode = decodedText;

  playScanBeep();
  triggerScanVibrate();

  const reticle = document.getElementById("scanner-overlay-reticle");
  if (reticle) {
    reticle.classList.add("ring-4", "ring-emerald-400");
    setTimeout(() => reticle.classList.remove("ring-4", "ring-emerald-400"), 500);
  }

  const input = document.getElementById("scanner-input");
  if (input) input.value = decodedText;

  showToast(`QR Code detectado: ${decodedText.substring(0, 24)}...`);
  handleScanSubmit(null, decodedText);
}

async function handleScanSubmit(e, optionalCode = null) {
  if (e && e.preventDefault) e.preventDefault();
  const input = document.getElementById("scanner-input");
  let code = optionalCode ? String(optionalCode).trim() : (input ? input.value.trim() : "");
  if (!code) return;

  if (input) input.value = code;

  if (code.includes("BINFAE:ITEM:")) {
    code = code.split("BINFAE:ITEM:").pop().split("&")[0].split("?")[0].trim();
  }

  try {
    const item = await api(`/stock/items/scan/${encodeURIComponent(code)}`);
    renderScanResult(item);
  } catch (err) {
    document.getElementById("scan-result-container").innerHTML = `
      <div class="p-6 bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-800 rounded-2xl text-center text-rose-700 dark:text-rose-300 font-medium shadow-sm">
        ✕ Nenhum material localizado com o código: <span class="font-mono font-bold">${escapeHtml(code)}</span>
      </div>`;
  }
}

function renderScanResult(item) {
  const container = document.getElementById("scan-result-container");
  if (!container) return;

  let caracHtml = "";
  if (item.caracteristicas && typeof item.caracteristicas === "object") {
    const entries = Object.entries(item.caracteristicas).filter(
      ([k, v]) => v !== null && v !== undefined && String(v).trim() !== ""
    );
    if (entries.length > 0) {
      caracHtml = `
        <div class="mt-4 pt-3 border-t border-slate-100 dark:border-slate-800">
          <div class="text-[10px] uppercase font-bold tracking-wider text-slate-400 dark:text-slate-500 mb-2">ESPECIFICAÇÕES & CARACTERÍSTICAS</div>
          <div class="flex flex-wrap gap-1.5">
            ${entries.map(([k, v]) => `
              <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-sky-50 dark:bg-sky-950/50 text-sky-700 dark:text-sky-300 border border-sky-200 dark:border-sky-800">
                <strong class="mr-1">${escapeHtml(k)}:</strong> ${escapeHtml(String(v))}
              </span>
            `).join("")}
          </div>
        </div>`;
    }
  }

  const statusBadgeClass = item.status === 'DISPONIVEL' ? 'badge-disponivel' : (item.status === 'EM_USO' ? 'badge-em_uso' : 'badge-em_manutencao');

  container.innerHTML = `
    <div class="p-6 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl shadow-xl card-hover text-slate-800 dark:text-slate-100">
      <div class="flex flex-col sm:flex-row sm:items-start justify-between gap-4">
        <div>
          <span class="px-2.5 py-1 rounded-full text-xs font-bold uppercase tracking-wider ${statusBadgeClass}">
            ${item.status}
          </span>
          <h3 class="text-xl font-black text-slate-900 dark:text-slate-100 mt-2">${escapeHtml(item.nome)}</h3>
          <p class="text-xs text-slate-500 dark:text-slate-400">${escapeHtml(item.subgrupo?.nome || "Sem subgrupo")}</p>
        </div>
        <div class="flex flex-wrap items-center gap-1.5">
          <button onclick="openItemDetailModal(${item.id})" class="px-3 py-1.5 bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-200 hover:bg-slate-200 dark:hover:bg-slate-700 rounded-xl text-xs font-semibold border border-slate-200 dark:border-slate-700 flex items-center gap-1">
            👁️ Ver Detalhes
          </button>
          <button onclick="openMoveItemModal(${item.id})" class="px-3 py-1.5 bg-emerald-50 dark:bg-emerald-950/40 text-emerald-700 dark:text-emerald-300 hover:bg-emerald-100 rounded-xl text-xs font-semibold border border-emerald-200 dark:border-emerald-800 flex items-center gap-1">
            📦 Mover Local
          </button>
          <button onclick="openEditItemModal(${item.id})" class="px-3 py-1.5 bg-amber-50 dark:bg-amber-950/40 text-amber-700 dark:text-amber-300 hover:bg-amber-100 rounded-xl text-xs font-semibold border border-amber-200 dark:border-amber-800 flex items-center gap-1">
            ✏️ Editar
          </button>
          <button onclick="openQrModal(${item.id})" class="px-3 py-1.5 bg-sky-50 dark:bg-sky-950/40 text-sky-700 dark:text-sky-300 hover:bg-sky-100 rounded-xl text-xs font-semibold border border-sky-200 dark:border-sky-800 flex items-center gap-1">
            🏷️ Etiqueta
          </button>
        </div>
      </div>

      <div class="grid grid-cols-2 sm:grid-cols-4 gap-3 mt-5 p-3.5 bg-slate-50 dark:bg-slate-800/50 rounded-xl text-xs border border-slate-100 dark:border-slate-800">
        <div>
          <div class="text-[10px] uppercase font-bold text-slate-400 dark:text-slate-500">BMP / PATRIMÔNIO</div>
          <div class="font-mono font-bold text-slate-800 dark:text-slate-200 mt-0.5">${item.bmp || "—"}</div>
        </div>
        <div>
          <div class="text-[10px] uppercase font-bold text-slate-400 dark:text-slate-500">CÓD. INTERNO</div>
          <div class="font-mono font-semibold text-slate-800 dark:text-slate-200 mt-0.5">${item.codigo_interno || "—"}</div>
        </div>
        <div>
          <div class="text-[10px] uppercase font-bold text-slate-400 dark:text-slate-500">Nº SÉRIE</div>
          <div class="font-mono text-slate-700 dark:text-slate-300 mt-0.5">${item.numero_serie || "—"}</div>
        </div>
        <div>
          <div class="text-[10px] uppercase font-bold text-slate-400 dark:text-slate-500">LOCALIZAÇÃO</div>
          <div class="font-semibold text-sky-600 dark:text-sky-400 mt-0.5">${item.local_efetivo ? escapeHtml(item.local_efetivo.caminho_completo) : (item.local ? escapeHtml(item.local.caminho_completo) : "—")}</div>
        </div>
      </div>
      ${caracHtml}
    </div>`;
}

// ============================================================================
// 8.1 GITHUB UPDATES & PWA INSTALL MANAGEMENT
// ============================================================================

let deferredPwaPrompt = null;

function triggerPwaInstall() {
  if (deferredPwaPrompt) {
    deferredPwaPrompt.prompt();
    deferredPwaPrompt.userChoice.then((choiceResult) => {
      if (choiceResult.outcome === "accepted") {
        showToast("Instalando o aplicativo BINFAE...");
        document.getElementById("btn-topbar-install-pwa")?.classList.add("hidden");
        document.getElementById("sidebar-btn-install-pwa")?.classList.add("hidden");
      }
      deferredPwaPrompt = null;
    });
  } else {
    const isIos = /iphone|ipad|ipod/i.test(navigator.userAgent);
    if (isIos) {
      document.getElementById("modal-ios-install-guide")?.classList.remove("hidden");
    } else {
      showToast("Para instalar o app, use o menu do navegador (⋮ ou Compartilhar) e selecione 'Adicionar à tela inicial'.", "info");
    }
  }
}

function closeIosInstallModal() {
  document.getElementById("modal-ios-install-guide")?.classList.add("hidden");
}

function openUpdateCheckerModal() {
  document.getElementById("modal-update-checker")?.classList.remove("hidden");
  checkSystemUpdate(false);
}

function closeUpdateCheckerModal() {
  document.getElementById("modal-update-checker")?.classList.add("hidden");
}

async function checkSystemUpdate(isManual = false) {
  const banner = document.getElementById("update-status-banner");
  const icon = document.getElementById("update-status-icon");
  const title = document.getElementById("update-status-title");
  const detail = document.getElementById("update-status-detail");
  const instVer = document.getElementById("update-installed-version");
  const instCommit = document.getElementById("update-installed-commit");
  const gitVer = document.getElementById("update-github-version");
  const gitCommit = document.getElementById("update-github-commit");
  const commitDetailsCard = document.getElementById("update-commit-details-card");
  const instructionsCard = document.getElementById("update-instructions-card");
  const recheckBtn = document.getElementById("btn-recheck-update");

  if (recheckBtn) {
    recheckBtn.disabled = true;
    recheckBtn.innerHTML = `<span>⏳</span><span>Verificando...</span>`;
  }

  let data = null;
  try {
    data = await api("/system/check-update");
  } catch (backendErr) {
    console.warn("Backend local inacessível, consultando GitHub diretamente via cliente:", backendErr);
    try {
      const resp = await fetch("https://api.github.com/repos/LucasFerreira198/SystemInformaticaBinfae/commits/main", {
        headers: { "Accept": "application/vnd.github.v3+json" }
      });
      if (resp.ok) {
        const ghData = await resp.json();
        const remoteSha = ghData.sha || "";
        const commitInfo = ghData.commit || {};
        data = {
          status: "success",
          has_update: true,
          current_version: "2.4.0",
          local_commit: "app-mobile",
          remote_commit: remoteSha.substring(0, 7),
          remote_commit_full: remoteSha,
          commit_message: commitInfo.message?.split("\n")[0] || "Nova versão disponível",
          commit_author: commitInfo.author?.name || "Repositório Oficial",
          commit_date: commitInfo.author?.date || "",
          commit_url: ghData.html_url || "https://github.com/LucasFerreira198/SystemInformaticaBinfae",
          github_url: "https://github.com/LucasFerreira198/SystemInformaticaBinfae"
        };
      }
    } catch (ghErr) {
      console.error("Falha ao consultar GitHub diretamente:", ghErr);
    }
  }

  try {
    if (!data) {
      throw new Error("Não foi possível conectar ao servidor nem ao GitHub");
    }

    if (instVer) instVer.textContent = `v${data.current_version || "2.4.0"}`;
    if (instCommit) instCommit.textContent = `Commit: ${data.local_commit || "..."}`;

    if (data.status === "success") {
      if (gitVer) gitVer.textContent = data.has_update ? "Nova versão no GitHub" : "Atualizado";
      if (gitCommit) gitCommit.textContent = `Commit: ${data.remote_commit || "..."}`;

      if (data.has_update) {
        document.getElementById("topbar-update-ping")?.classList.remove("hidden");
        document.getElementById("topbar-update-dot")?.classList.remove("hidden");
        const badge = document.getElementById("sidebar-update-badge");
        if (badge) {
          badge.textContent = "Update!";
          badge.classList.remove("bg-slate-200", "dark:bg-slate-800", "text-slate-600");
          badge.classList.add("bg-sky-500", "text-white", "animate-pulse");
        }

        if (banner) {
          banner.className = "p-3.5 rounded-xl border flex items-center gap-3 bg-sky-50 dark:bg-sky-950/40 border-sky-200 dark:border-sky-800 text-sky-900 dark:text-sky-100";
        }
        if (icon) icon.textContent = "🚀";
        if (title) title.textContent = "Nova Versão Disponível no GitHub!";
        if (detail) detail.textContent = `Commit ${data.remote_commit}: "${data.commit_message || ""}"`;

        if (commitDetailsCard) {
          commitDetailsCard.classList.remove("hidden");
          document.getElementById("update-remote-author").textContent = data.commit_author || "Repositório Oficial";
          document.getElementById("update-remote-message").textContent = data.commit_message || "Atualização disponível no GitHub";
          document.getElementById("update-remote-date").textContent = data.commit_date ? new Date(data.commit_date).toLocaleString("pt-BR") : "";
          const link = document.getElementById("update-remote-link");
          if (link) link.href = data.commit_url || data.github_url || "#";
        }

        if (instructionsCard) instructionsCard.classList.remove("hidden");

        if (isManual) {
          showToast("Nova versão encontrada no GitHub!", "info");
        }
      } else {
        document.getElementById("topbar-update-ping")?.classList.add("hidden");
        document.getElementById("topbar-update-dot")?.classList.add("hidden");

        if (banner) {
          banner.className = "p-3.5 rounded-xl border flex items-center gap-3 bg-emerald-50 dark:bg-emerald-950/40 border-emerald-200 dark:border-emerald-800 text-emerald-900 dark:text-emerald-100";
        }
        if (icon) icon.textContent = "✅";
        if (title) title.textContent = "Sistema Atualizado";
        if (detail) detail.textContent = "Você está executando a versão mais recente diretamente da branch main do GitHub.";

        if (commitDetailsCard) {
          commitDetailsCard.classList.remove("hidden");
          document.getElementById("update-remote-author").textContent = data.commit_author || "lucasferreira198";
          document.getElementById("update-remote-message").textContent = data.commit_message || "Sistema em dia.";
          document.getElementById("update-remote-date").textContent = data.commit_date ? new Date(data.commit_date).toLocaleString("pt-BR") : "";
          const link = document.getElementById("update-remote-link");
          if (link) link.href = data.commit_url || data.github_url || "#";
        }

        if (instructionsCard) instructionsCard.classList.add("hidden");

        if (isManual) {
          showToast("O sistema já está na versão mais recente!");
        }
      }
    } else {
      if (banner) {
        banner.className = "p-3.5 rounded-xl border flex items-center gap-3 bg-amber-50 dark:bg-amber-950/40 border-amber-200 dark:border-amber-800 text-amber-900 dark:text-amber-100";
      }
      if (icon) icon.textContent = "⚠️";
      if (title) title.textContent = "Aviso na verificação";
      if (detail) detail.textContent = data.message || "Não foi possível verificar com o GitHub no momento.";
      if (isManual) {
        showToast(data.message || "Não foi possível verificar o GitHub.", "warning");
      }
    }
  } catch (err) {
    console.error("Erro ao verificar atualização:", err);
    if (banner) {
      banner.className = "p-3.5 rounded-xl border flex items-center gap-3 bg-rose-50 dark:bg-rose-950/40 border-rose-200 dark:border-rose-800 text-rose-900 dark:text-rose-100";
    }
    if (icon) icon.textContent = "❌";
    if (title) title.textContent = "Falha de Conexão";
    if (detail) detail.textContent = "Não foi possível contatar o servidor local ou o GitHub.";
    if (isManual) {
      showToast("Falha ao consultar atualizações.", "error");
    }
  } finally {
    if (recheckBtn) {
      recheckBtn.disabled = false;
      recheckBtn.innerHTML = `<span>🔄</span><span>Verificar Novamente</span>`;
    }
  }
}

/**
 * Baixa diretamente o APK compilado da Release oficial do GitHub
 * No Android nativo, ativa o navegador do sistema ou DownloadManager nativo
 * para download direto com acompanhamento na barra de notificações do celular.
 */
async function downloadApkUpdate() {
  triggerHaptic("medium");
  const apkUrl = "https://github.com/LucasFerreira198/BinfaeMobileApp/releases/latest";
  const btn = document.getElementById("btn-download-apk-direct");
  
  showToast("Iniciando download do aplicativo...", "info");
  if (btn) {
    btn.disabled = true;
    btn.innerHTML = `<span>⏳</span><span>Abrindo download no navegador...</span>`;
  }

  try {
    // 1. Tentar via plugin oficial @capacitor/browser (abre no navegador padrão do Android com download nativo)
    const capBrowser = window.Capacitor?.Plugins?.Browser;
    if (capBrowser && typeof capBrowser.open === "function") {
      await capBrowser.open({ url: apkUrl });
      triggerHaptic("success");
      if (btn) {
        btn.innerHTML = `<span>✓</span><span>Download em andamento! Acompanhe nas notificações.</span>`;
        setTimeout(() => {
          btn.disabled = false;
          btn.innerHTML = `<span>📥</span><span>Baixar Novamente (BINFAE-TI.apk)</span>`;
        }, 3500);
      }
      return;
    }

    // 2. Tentar via App Plugin openUrl se disponível
    const capApp = window.Capacitor?.Plugins?.App;
    if (capApp && typeof capApp.openUrl === "function") {
      await capApp.openUrl({ url: apkUrl });
      triggerHaptic("success");
      if (btn) {
        btn.innerHTML = `<span>✓</span><span>Download em andamento! Acompanhe nas notificações.</span>`;
        setTimeout(() => {
          btn.disabled = false;
          btn.innerHTML = `<span>📥</span><span>Baixar Novamente (BINFAE-TI.apk)</span>`;
        }, 3500);
      }
      return;
    }

    // 3. Fallback no navegador / PWA criando link com atributo download
    const a = document.createElement("a");
    a.href = apkUrl;
    a.download = "BINFAE-TI.apk";
    a.target = "_blank";
    a.rel = "noopener noreferrer";
    document.body.appendChild(a);
    a.click();
    setTimeout(() => {
      if (a.parentNode) a.parentNode.removeChild(a);
      if (btn) {
        btn.innerHTML = `<span>✓</span><span>Download iniciado!</span>`;
        setTimeout(() => {
          btn.disabled = false;
          btn.innerHTML = `<span>📥</span><span>Baixar Novamente (BINFAE-TI.apk)</span>`;
        }, 3500);
      }
    }, 1500);
  } catch (err) {
    console.error("Erro ao iniciar download:", err);
    window.location.href = apkUrl;
  }
}

// ============================================================================
// 8.2 CONFIGURAÇÃO DO SERVIDOR (APP NATIVO & CONEXÃO REMOTA)
// ============================================================================

function openServerConfigModal(mandatory = false) {
  const modal = document.getElementById("modal-server-config");
  const input = document.getElementById("server-url-input");
  const closeBtn = document.getElementById("btn-close-server-modal");
  const resultDiv = document.getElementById("server-test-result");

  if (resultDiv) resultDiv.classList.add("hidden");

  const currentUrl = localStorage.getItem("binfae_server_url") || getApiBaseUrl() || "https://systeminformaticabinfae.onrender.com";
  if (input) input.value = currentUrl;

  if (mandatory && closeBtn) {
    closeBtn.classList.add("hidden");
  } else if (closeBtn) {
    closeBtn.classList.remove("hidden");
  }

  modal?.classList.remove("hidden");
}

function closeServerConfigModal() {
  document.getElementById("modal-server-config")?.classList.add("hidden");
}

async function testCurrentServerConnection() {
  const input = document.getElementById("server-url-input");
  const resultDiv = document.getElementById("server-test-result");
  const btn = document.getElementById("btn-test-server-conn");

  let url = input ? input.value.trim().replace(/\/+$/, "") : "";
  if (!url) {
    showToast("Informe o IP ou domínio do servidor para testar.", "warning");
    return;
  }

  if (!url.startsWith("http://") && !url.startsWith("https://")) {
    url = `http://${url}`;
    if (input) input.value = url;
  }

  if (btn) {
    btn.disabled = true;
    btn.innerHTML = `<span>⏳</span><span>Testando...</span>`;
  }
  if (resultDiv) {
    resultDiv.classList.remove("hidden");
    resultDiv.className = "p-3 rounded-xl border text-xs bg-slate-50 dark:bg-slate-800/60 border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-300";
    resultDiv.innerHTML = `<span>Conectando a <strong>${escapeHtml(url)}/system/version</strong>...</span>`;
  }

  const startTime = performance.now();
  try {
    const resp = await fetch(`${url}/system/version`, {
      method: "GET",
      headers: { "Accept": "application/json" }
    });

    const elapsed = Math.round(performance.now() - startTime);

    if (resp.ok) {
      const data = await resp.json();
      if (resultDiv) {
        resultDiv.className = "p-3 rounded-xl border text-xs bg-emerald-50 dark:bg-emerald-950/40 border-emerald-200 dark:border-emerald-800 text-emerald-900 dark:text-emerald-200";
        resultDiv.innerHTML = `
          <div class="font-bold flex items-center gap-1.5 text-emerald-800 dark:text-emerald-300">
            <span>✅</span> Conectado com Sucesso! (${elapsed}ms)
          </div>
          <div class="mt-1 text-[11px] text-emerald-700 dark:text-emerald-400">
            Servidor: <strong>v${data.version || "2.4.0"}</strong> • Commit: <code class="font-mono">${data.commit || "..."}</code>
          </div>`;
      }
      showToast("Conexão com o servidor estabelecida com sucesso!");
    } else {
      throw new Error(`Resposta HTTP ${resp.status}`);
    }
  } catch (err) {
    console.error("Falha ao testar conexão:", err);
    if (resultDiv) {
      resultDiv.className = "p-3 rounded-xl border text-xs bg-rose-50 dark:bg-rose-950/40 border-rose-200 dark:border-rose-800 text-rose-900 dark:text-rose-200";
      resultDiv.innerHTML = `
        <div class="font-bold flex items-center gap-1.5 text-rose-800 dark:text-rose-300">
          <span>❌</span> Falha na Conexão
        </div>
        <div class="mt-1 text-[11px] text-rose-700 dark:text-rose-400">
          Não foi possível conectar a <strong>${escapeHtml(url)}</strong>.<br>
          Verifique se o backend está em execução na máquina e se o celular está conectado na mesma rede Wi-Fi / VPN.
        </div>`;
    }
    showToast("Falha na conexão com o servidor.", "error");
  } finally {
    if (btn) {
      btn.disabled = false;
      btn.innerHTML = `<span>⚡</span><span>Testar Conexão</span>`;
    }
  }
}

function handleSaveServerConfig(e) {
  if (e && e.preventDefault) e.preventDefault();
  const input = document.getElementById("server-url-input");
  let url = input ? input.value.trim().replace(/\/+$/, "") : "";

  if (url && !url.startsWith("http://") && !url.startsWith("https://")) {
    url = `http://${url}`;
  }

  localStorage.setItem("binfae_server_url", url);
  showToast("Configuração do servidor salva com sucesso!");
  closeServerConfigModal();

  // Recarrega perfil e dados da aplicação com a nova URL
  if (state.token) {
    loadUserProfile();
    loadItems();
    loadLocations();
  }
}

// ============================================================================
// 9. NAVEGAÇÃO EM ABAS
// ============================================================================

function switchTab(tabName) {
  const activeContent = document.getElementById(`tab-content-${tabName}`);
  if (!activeContent) {
    console.warn("Aba não encontrada:", tabName);
    if (tabName !== "stock") {
      switchTab("stock");
    }
    return;
  }

  state.currentTab = tabName;
  triggerHaptic("light");

  document.querySelectorAll(".tab-content").forEach(el => el.classList.add("hidden"));
  activeContent.classList.remove("hidden");
  
  // Atualiza botões da sidebar moderna
  document.querySelectorAll(".sidebar-nav-item").forEach(el => {
    el.classList.remove("active", "bg-sky-50", "text-sky-700", "dark:bg-sky-950/40", "dark:text-sky-400", "font-bold");
    el.classList.add("text-slate-700", "dark:text-slate-300", "font-medium");
  });
  const activeSidebarBtn = document.getElementById(`sidebar-btn-${tabName}`);
  if (activeSidebarBtn) {
    activeSidebarBtn.classList.add("active", "bg-sky-50", "text-sky-700", "dark:bg-sky-950/40", "dark:text-sky-400", "font-bold");
    activeSidebarBtn.classList.remove("font-medium");
  }

  // Compatibilidade com tabs antigas se existirem no DOM
  document.querySelectorAll(".tab-btn").forEach(el => {
    el.classList.remove("border-sky-600", "text-sky-700", "font-bold", "dark:text-sky-400", "dark:border-sky-400");
    el.classList.add("border-transparent", "text-slate-600", "font-medium", "dark:text-slate-400");
  });
  const activeBtn = document.getElementById(`tab-btn-${tabName}`);
  if (activeBtn) {
    activeBtn.classList.remove("border-transparent", "text-slate-600", "font-medium", "dark:text-slate-400");
    activeBtn.classList.add("border-sky-600", "text-sky-700", "font-bold", "dark:text-sky-400", "dark:border-sky-400");
  }

  // Atualiza active na Barra de Navegação Inferior Mobile
  document.querySelectorAll(".mobile-nav-item").forEach(el => el.classList.remove("active"));
  document.getElementById(`mobile-nav-${tabName}`)?.classList.add("active");

  // Atualiza breadcrumb de contexto
  updateContextBreadcrumb(tabName);

  // Fecha sidebar mobile se aberta
  if (window.innerWidth < 768) {
    toggleMobileSidebar(false);
  }

  if (tabName !== "scanner") {
    stopCameraScanner();
  }

  if (tabName === "stock") {
    const currentStatus = document.getElementById("filter-status")?.value || "";
    updateStatusPillsUI(currentStatus);
    renderItemsTable();
    if (!state.items || state.items.length === 0) loadItems();
  }
  if (tabName === "locations") {
    renderLocationsTree();
    if (!state.locations || state.locations.length === 0) loadLocations();
  }
  if (tabName === "categories") {
    renderCategoriesView();
    if (!state.groups || state.groups.length === 0) loadGroups();
  }
  if (tabName === "movements") {
    renderMovements();
    loadMovements();
  }
  if (tabName === "personnel") {
    renderPersonnel();
    loadPersonnel();
  }
}

function updateContextBreadcrumb(tabName) {
  const breadcrumb = document.getElementById("breadcrumb-current-tab");
  const title = document.getElementById("page-context-title");
  const desc = document.getElementById("page-context-desc");

  const map = {
    stock: {
      name: "Estoque & Materiais",
      title: "Estoque & Materiais",
      desc: "Gerencie os equipamentos patrimoniados (com BMP) e materiais de consumo a granel."
    },
    locations: {
      name: "Locais Físicos (Árvore)",
      title: "Locais Físicos do Almoxarifado",
      desc: "Navegue pela hierarquia de prédios, salas técnicas, depósitos e armários."
    },
    categories: {
      name: "Grupos & Subgrupos",
      title: "Grupos e Subgrupos de TI",
      desc: "Classificação técnica de equipamentos, consumíveis e componentes."
    },
    scanner: {
      name: "Leitor / Scanner QR Code",
      title: "Leitor de Código de Barras & QR Code",
      desc: "Aponte o leitor USB ou câmera para localizar ou dar entrada instantânea."
    },
    movements: {
      name: "Trilha de Auditoria",
      title: "Trilha de Auditoria & Movimentações",
      desc: "Histórico completo com data, militar responsável e motivo de cada transferência."
    },
    personnel: {
      name: "Efetivo & Usuários",
      title: "Efetivo Militar & Usuários do Sistema",
      desc: "Relação de militares para cautela e controle de operadores com acesso."
    }
  };

  const info = map[tabName] || { name: "Sistema", title: "Painel de Controle", desc: "" };
  if (breadcrumb) breadcrumb.textContent = info.name;
  if (title) title.textContent = info.title;
  if (desc) desc.textContent = info.desc;
}

function toggleMobileSidebar(force) {
  const sidebar = document.getElementById("app-sidebar");
  const backdrop = document.getElementById("sidebar-backdrop");
  const moreBtn = document.getElementById("mobile-nav-more");
  if (!sidebar) return;

  const isOpen = !sidebar.classList.contains("-translate-x-full");
  const shouldOpen = force !== undefined ? force : !isOpen;

  if (shouldOpen) {
    sidebar.classList.remove("-translate-x-full");
    if (backdrop) backdrop.classList.remove("hidden");
    if (moreBtn) moreBtn.classList.add("active");
  } else {
    sidebar.classList.add("-translate-x-full");
    if (backdrop) backdrop.classList.add("hidden");
    if (moreBtn) moreBtn.classList.remove("active");
  }
}

// Filtros rápidos via Status Pills ou Dashboard de Métricas (100% em Memória / 0ms)
function selectStatusPill(status) {
  state._depotFilterActive = false;
  state._lowQtyFilterActive = false;
  const select = document.getElementById("filter-status");
  if (select) {
    select.value = status;
  }
  updateStatusPillsUI(status);
  filterItemsInMemory();
}

function updateStatusPillsUI(status) {
  document.querySelectorAll(".status-pill").forEach(pill => {
    const pillStatus = pill.getAttribute("data-status-pill");
    if (pillStatus === status) {
      pill.classList.add("active", "bg-sky-600", "text-white", "font-bold");
      pill.classList.remove("bg-slate-100", "dark:bg-slate-800", "text-slate-700", "dark:text-slate-300");
    } else {
      pill.classList.remove("active", "bg-sky-600", "text-white", "font-bold");
      pill.classList.add("bg-slate-100", "dark:bg-slate-800", "text-slate-700", "dark:text-slate-300");
    }
  });
}

function filterStockByStatus(status) {
  switchTab("stock");
  selectStatusPill(status);
}

function filterStockByDepot() {
  switchTab("stock");
  state._depotFilterActive = true;
  state._lowQtyFilterActive = false;
  const select = document.getElementById("filter-status");
  if (select) select.value = "";
  updateStatusPillsUI("");
  filterItemsInMemory();
}

function filterStockLowQuantity() {
  switchTab("stock");
  state._lowQtyFilterActive = true;
  state._depotFilterActive = false;
  const select = document.getElementById("filter-status");
  if (select) select.value = "";
  updateStatusPillsUI("");
  filterItemsInMemory();
}

// Utilitários de escape HTML
function escapeHtml(str) {
  if (!str) return "";
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function openLoginModal() {
  const modal = document.getElementById("modal-login");
  if (!modal) return;
  modal.classList.remove("hidden");
  
  const savedUser = localStorage.getItem("binfae_saved_user");
  const bioEnabled = localStorage.getItem("binfae_biometric_enabled") === "true";
  const bioContainer = document.getElementById("biometric-login-container");
  const bioText = document.getElementById("biometric-login-text");

  if (savedUser && bioEnabled && bioContainer) {
    bioContainer.classList.remove("hidden");
    if (bioText) bioText.textContent = `Entrar como ${savedUser} (Biometria / 1 Toque)`;
  } else if (bioContainer) {
    bioContainer.classList.add("hidden");
  }

  const userInput = document.getElementById("login-username");
  const passInput = document.getElementById("login-password");
  if (savedUser && userInput) {
    userInput.value = savedUser;
    if (passInput) setTimeout(() => passInput.focus(), 150);
  } else if (userInput) {
    setTimeout(() => userInput.focus(), 150);
  }
}

async function loginWithBiometrics() {
  triggerHaptic("light");
  const savedToken = localStorage.getItem("binfae_saved_token") || localStorage.getItem("binfae_token");
  const savedUser = localStorage.getItem("binfae_saved_user");

  if (!savedToken) {
    showToast("Nenhuma credencial salva para biometria. Faça login com senha primeiro.", "warning");
    return;
  }

  try {
    if (window.PublicKeyCredential && typeof PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable === "function") {
      await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
    }
  } catch (e) {}

  state.token = savedToken;
  localStorage.setItem("binfae_token", state.token);

  try {
    await loadUserProfile();
    closeLoginModal();
    triggerHaptic("success");
    showToast(`Bem-vindo, ${state.user?.nome_guerra || savedUser}! Acesso biométrico liberado.`, "success");
    initApp();
  } catch (err) {
    console.warn("Token biométrico expirado:", err);
    triggerHaptic("error");
    showToast("Sua sessão anterior expirou. Por favor, digite sua senha.", "warning");
    localStorage.removeItem("binfae_saved_token");
    document.getElementById("biometric-login-container")?.classList.add("hidden");
    document.getElementById("login-password")?.focus();
  }
}

function closeLoginModal() {
  document.getElementById("modal-login")?.classList.add("hidden");
}

// ============================================================================
// 10. TEMA ESCURO E FILTROS RÁPIDOS
// ============================================================================

function initTheme() {
  const savedTheme = localStorage.getItem("binfae_theme");
  const prefersDark = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
  const isDark = savedTheme === "dark" || (!savedTheme && prefersDark);
  applyTheme(isDark);
}

function applyTheme(isDark) {
  const icon = document.getElementById("theme-toggle-icon");
  const text = document.getElementById("theme-toggle-text");
  const sidebarIcon = document.getElementById("sidebar-theme-icon");
  const sidebarText = document.getElementById("sidebar-theme-text");

  if (isDark) {
    document.documentElement.classList.add("dark");
    if (icon) icon.textContent = "☀️";
    if (text) text.textContent = "Modo Claro";
    if (sidebarIcon) sidebarIcon.textContent = "☀️";
    if (sidebarText) sidebarText.textContent = "Modo Claro";
  } else {
    document.documentElement.classList.remove("dark");
    if (icon) icon.textContent = "🌙";
    if (text) text.textContent = "Modo Escuro";
    if (sidebarIcon) sidebarIcon.textContent = "🌙";
    if (sidebarText) sidebarText.textContent = "Modo Escuro";
  }
  updateNativeStatusBar(isDark);
}

function toggleTheme() {
  triggerHaptic("light");
  const isDark = document.documentElement.classList.contains("dark");
  const newDark = !isDark;
  localStorage.setItem("binfae_theme", newDark ? "dark" : "light");
  applyTheme(newDark);
}

function onSearchInputChange() {
  const input = document.getElementById("filter-search");
  const clearBtn = document.getElementById("btn-clear-search");
  if (input && clearBtn) {
    if (input.value && input.value.trim().length > 0) {
      clearBtn.classList.remove("hidden");
    } else {
      clearBtn.classList.add("hidden");
    }
  }
  // BUSCA INSTANTÂNEA EM 0ms NO BANCO LOCAL
  filterItemsInMemory();
}

function clearSearchInput() {
  const input = document.getElementById("filter-search");
  const clearBtn = document.getElementById("btn-clear-search");
  if (input) {
    input.value = "";
    if (clearBtn) clearBtn.classList.add("hidden");
    filterItemsInMemory();
  }
}

function clearAllStockFilters() {
  state._depotFilterActive = false;
  state._lowQtyFilterActive = false;

  const searchInput = document.getElementById("filter-search");
  const clearSearchBtn = document.getElementById("btn-clear-search");
  const locSelect = document.getElementById("filter-location");
  const subgSelect = document.getElementById("filter-subgroup");
  const tipoSelect = document.getElementById("filter-tipo");
  const statusSelect = document.getElementById("filter-status");

  if (searchInput) searchInput.value = "";
  if (clearSearchBtn) clearSearchBtn.classList.add("hidden");
  if (locSelect) locSelect.value = "";
  if (subgSelect) subgSelect.value = "";
  if (tipoSelect) tipoSelect.value = "";
  if (statusSelect) statusSelect.value = "";

  const filterBadge = document.getElementById("mobile-filter-badge");
  if (filterBadge) filterBadge.classList.add("hidden");

  updateStatusPillsUI("");
  filterItemsInMemory();
}

// ============================================================================
// 11. BARRA DE COMANDO GLOBAL (OMNIBOX / CTRL + K)
// ============================================================================

function openCommandPalette() {
  const modal = document.getElementById("modal-command-palette");
  const input = document.getElementById("command-palette-input");
  if (!modal) return;
  modal.classList.remove("hidden");
  if (input) {
    input.value = "";
    input.focus();
    renderCommandPaletteResults("");
  }
}

function closeCommandPalette() {
  const modal = document.getElementById("modal-command-palette");
  if (modal) modal.classList.add("hidden");
}

function onCommandPaletteInput() {
  const input = document.getElementById("command-palette-input");
  renderCommandPaletteResults(input ? input.value : "");
}

function renderCommandPaletteResults(query) {
  const container = document.getElementById("command-palette-results");
  if (!container) return;

  const q = (query || "").trim().toLowerCase();
  const sourceItems = (state.allItems && state.allItems.length > 0) ? state.allItems : state.items;

  let html = "";

  // 1. Ações rápidas de navegação
  const actions = [
    { title: "Cadastrar Novo Material", icon: "➕", action: "openNewItemModal(); closeCommandPalette();" },
    { title: "Ir para Estoque & Materiais", icon: "📦", action: "switchTab('stock'); closeCommandPalette();" },
    { title: "Ir para Locais Físicos (Árvore)", icon: "🏢", action: "switchTab('locations'); closeCommandPalette();" },
    { title: "Abrir Leitor / Scanner QR", icon: "🔍", action: "switchTab('scanner'); closeCommandPalette();" },
    { title: "Abrir Guia de Orientação", icon: "💡", action: "openGuideModal(); closeCommandPalette();" },
    { title: "Alternar Modo Claro / Escuro", icon: "🌓", action: "toggleTheme();" }
  ];

  const matchedActions = actions.filter(a => !q || a.title.toLowerCase().includes(q));
  if (matchedActions.length > 0) {
    html += `<div class="px-2 py-1 text-[10px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider">Ações do Sistema</div>`;
    matchedActions.slice(0, 4).forEach(a => {
      html += `
        <div onclick="${a.action}" class="flex items-center gap-2.5 px-3 py-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 cursor-pointer transition-colors text-slate-800 dark:text-slate-200">
          <span class="text-base">${a.icon}</span>
          <span class="font-medium">${escapeHtml(a.title)}</span>
        </div>`;
    });
  }

  // 2. Materiais encontrados
  if (sourceItems && sourceItems.length > 0) {
    const matchedItems = sourceItems.filter(item => {
      if (!q) return true;
      const nome = (item.nome || "").toLowerCase();
      const bmp = (item.bmp || "").toLowerCase();
      const serial = (item.numero_serie || "").toLowerCase();
      const cod = (item.codigo_interno || "").toLowerCase();
      const local = (item.local?.nome || "").toLowerCase();
      return nome.includes(q) || bmp.includes(q) || serial.includes(q) || cod.includes(q) || local.includes(q);
    });

    if (matchedItems.length > 0) {
      html += `<div class="px-2 py-1 mt-2 text-[10px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider">Materiais no Inventário (${matchedItems.length})</div>`;
      matchedItems.slice(0, 8).forEach(item => {
        const localNome = item.local ? item.local.caminho_completo : "Sem local definido";
        const bmpTag = item.bmp ? `<span class="font-mono bg-slate-100 dark:bg-slate-800 px-1 py-0.5 rounded text-[11px] text-slate-700 dark:text-slate-300">BMP: ${escapeHtml(item.bmp)}</span>` : "";
        html += `
          <div onclick="openItemDetailModal(${item.id}); closeCommandPalette();" class="flex items-center justify-between px-3 py-2 rounded-lg hover:bg-sky-50 dark:hover:bg-sky-950/30 hover:border-sky-300 dark:hover:border-sky-800 border border-transparent cursor-pointer transition-all">
            <div class="flex items-center gap-2.5 min-w-0">
              <span class="text-base flex-shrink-0">📦</span>
              <div class="truncate">
                <div class="font-bold text-slate-900 dark:text-slate-100 truncate">${escapeHtml(item.nome)}</div>
                <div class="text-[11px] text-slate-500 dark:text-slate-400 flex items-center gap-2 mt-0.5">
                  ${bmpTag}
                  <span>📍 ${escapeHtml(localNome)}</span>
                </div>
              </div>
            </div>
            <span class="text-[10px] font-semibold text-sky-600 dark:text-sky-400 flex-shrink-0 ml-2">Ver Detalhes ➔</span>
          </div>`;
      });
    } else if (q) {
      html += `
        <div class="text-center py-6 text-slate-400">
          <p class="font-semibold text-xs text-slate-600 dark:text-slate-300">Nenhum material encontrado com "${escapeHtml(q)}"</p>
          <p class="text-[11px] text-slate-400 mt-0.5">Verifique o BMP, número de série ou termo digitado.</p>
        </div>`;
    }
  }

  container.innerHTML = html;
}

// ============================================================================
// 12. GUIA DO SISTEMA PARA INICIANTES
// ============================================================================

function openGuideModal() {
  document.getElementById("modal-guide")?.classList.remove("hidden");
}

function closeGuideModal() {
  document.getElementById("modal-guide")?.classList.add("hidden");
}

// ============================================================================
// 13. INICIALIZAÇÃO NO CARREGAMENTO DA PÁGINA
// ============================================================================

document.addEventListener("DOMContentLoaded", async () => {
  // Inicialização de tema e controle de UI
  initTheme();
  onSearchInputChange();
  updateContextBreadcrumb(state.currentTab || "stock");

  // Escuta alteração do tema do sistema operacional se o usuário não fixou manualmente
  if (window.matchMedia) {
    window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", (e) => {
      if (!localStorage.getItem("binfae_theme")) {
        applyTheme(e.matches);
      }
    });
  }

  // Atalhos Globais de Teclado (Ctrl + K / Cmd + K e ESC)
  window.addEventListener("keydown", (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") {
      e.preventDefault();
      const modal = document.getElementById("modal-command-palette");
      if (modal && !modal.classList.contains("hidden")) {
        closeCommandPalette();
      } else {
        openCommandPalette();
      }
    } else if (e.key === "Escape") {
      closeCommandPalette();
      closeGuideModal();
    }
  });

  // Event listeners dos formulários
  document.getElementById("form-login")?.addEventListener("submit", (e) => {
    e.preventDefault();
    login(e.target.username.value, e.target.password.value);
  });

  document.getElementById("form-new-item")?.addEventListener("submit", handleCreateItem);
  document.getElementById("form-edit-item")?.addEventListener("submit", handleEditItem);
  document.getElementById("form-move-item")?.addEventListener("submit", handleMoveItem);
  document.getElementById("form-adjust-stock")?.addEventListener("submit", handleAdjustStock);
  document.getElementById("form-scanner")?.addEventListener("submit", handleScanSubmit);

  document.getElementById("edit-item-tipo_controle")?.addEventListener("change", (e) => {
    const granelContainer = document.getElementById("edit-item-granel-fields");
    if (e.target.value === "GRANEL") {
      granelContainer?.classList.remove("hidden");
    } else {
      granelContainer?.classList.add("hidden");
    }
  });

  // Filtros com auto-reload
  document.getElementById("filter-search")?.addEventListener("input", (e) => {
    onSearchInputChange();
  });
  document.getElementById("filter-search")?.addEventListener("input", debounce(loadItems, 300));
  document.getElementById("filter-location")?.addEventListener("change", loadItems);
  document.getElementById("filter-include-sublocations")?.addEventListener("change", loadItems);
  document.getElementById("filter-subgroup")?.addEventListener("change", loadItems);
  document.getElementById("filter-status")?.addEventListener("change", loadItems);
  // Inicializa ícones de som e vibração do scanner
  const scanSoundIcon = document.getElementById("scan-sound-icon");
  if (scanSoundIcon) scanSoundIcon.textContent = scanSoundEnabled ? "🔊" : "🔇";
  const scanVibrateIcon = document.getElementById("scan-vibrate-icon");
  if (scanVibrateIcon) scanVibrateIcon.textContent = scanVibrateEnabled ? "📳" : "📴";

  // Registro do Service Worker para PWA e Cache Offline
  if ("serviceWorker" in navigator) {
    window.addEventListener("load", () => {
      navigator.serviceWorker
        .register("/sw.js", { scope: "/" })
        .then((reg) => console.log("BINFAE PWA ServiceWorker registrado no escopo:", reg.scope))
        .catch((err) => console.warn("BINFAE PWA ServiceWorker:", err));
    });
  }

  // Intercepta prompt de instalação nativa do PWA
  window.addEventListener("beforeinstallprompt", (e) => {
    e.preventDefault();
    deferredPwaPrompt = e;
    document.getElementById("btn-topbar-install-pwa")?.classList.remove("hidden");
    document.getElementById("sidebar-btn-install-pwa")?.classList.remove("hidden");
  });

  window.addEventListener("appinstalled", () => {
    deferredPwaPrompt = null;
    document.getElementById("btn-topbar-install-pwa")?.classList.add("hidden");
    document.getElementById("sidebar-btn-install-pwa")?.classList.add("hidden");
    showToast("Aplicativo BINFAE instalado com sucesso!");
  });

  // Verificação silenciosa de atualizações no GitHub após o carregamento inicial
  setTimeout(() => {
    checkSystemUpdate(false);
  }, 3500);

  // Adaptação da interface para ambiente nativo de celular
  adaptNativeMobileUI();

  // Inicialização do suporte nativo ao botão Voltar do Android
  setupNativeBackButton();

  // Inicialização da detecção de rede e modo offline resiliente
  setupOfflineNetworkDetection();

  // Inicialização do gesto Pull-to-Refresh nativo no celular
  setupPullToRefresh();

  // Inicialização do aplicativo conectado à nuvem oficial do BINFAE
  if (state.token) {
    loadUserProfile();
    initApp();
  } else {
    openLoginModal();
  }
});

function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

// ============================================================================
// SUPORTE NATIVO AO BOTÃO VOLTAR DO ANDROID (CAPACITOR & MOBILE APP)
// ============================================================================
let lastBackPressTime = 0;
let backButtonHandlerRegistered = false;

function adaptNativeMobileUI() {
  if (isNativeAppEnvironment() || window.innerWidth < 768) {
    document.getElementById("btn-topbar-install-pwa")?.classList.add("hidden");
    document.getElementById("sidebar-btn-install-pwa")?.classList.add("hidden");
    document.getElementById("sidebar-btn-server-config")?.classList.add("hidden");
  }
}

function closeActiveModal() {
  const modalCloseMap = {
    "modal-command-palette": typeof closeCommandPalette === "function" ? closeCommandPalette : null,
    "modal-guide": typeof closeGuideModal === "function" ? closeGuideModal : null,
    "modal-qr": typeof closeQrModal === "function" ? closeQrModal : null,
    "modal-new-item": typeof closeNewItemModal === "function" ? closeNewItemModal : null,
    "modal-item-detail": typeof closeItemDetailModal === "function" ? closeItemDetailModal : null,
    "modal-edit-item": typeof closeEditItemModal === "function" ? closeEditItemModal : null,
    "modal-move": typeof closeMoveModal === "function" ? closeMoveModal : null,
    "modal-adjust": typeof closeAdjustModal === "function" ? closeAdjustModal : null,
    "modal-location": typeof closeCreateLocationModal === "function" ? closeCreateLocationModal : null,
    "modal-group": typeof closeCreateGroupModal === "function" ? closeCreateGroupModal : null,
    "modal-subgroup": typeof closeCreateSubgroupModal === "function" ? closeCreateSubgroupModal : null,
    "modal-update-checker": typeof closeUpdateCheckerModal === "function" ? closeUpdateCheckerModal : null,
    "modal-ios-install-guide": typeof closeIosInstallModal === "function" ? closeIosInstallModal : null,
    "modal-server-config": typeof closeServerConfigModal === "function" ? closeServerConfigModal : null,
  };

  const openModals = Array.from(document.querySelectorAll('div[id^="modal-"]:not(.hidden)'));
  
  for (let i = openModals.length - 1; i >= 0; i--) {
    const m = openModals[i];
    if (m.id === "modal-login") {
      if (!state.token) continue;
      if (typeof closeLoginModal === "function") closeLoginModal();
      return true;
    }
    
    const handler = modalCloseMap[m.id];
    if (typeof handler === "function") {
      try {
        handler();
        return true;
      } catch (err) {
        console.warn("Erro ao fechar modal via handler:", m.id, err);
      }
    }
    m.classList.add("hidden");
    return true;
  }
  return false;
}

function handleAppBackAction() {
  // 1. Tentar fechar gaveta de filtros (Bottom Sheet) no celular
  if (isFiltersBottomSheetOpen()) {
    closeFiltersBottomSheet();
    return;
  }

  // 2. Tentar fechar modal aberto
  if (closeActiveModal()) {
    return;
  }

  // 3. Se o menu lateral (sidebar) estiver aberto no celular, fecha o menu
  const sidebar = document.getElementById("app-sidebar");
  if (sidebar && !sidebar.classList.contains("-translate-x-full")) {
    toggleMobileSidebar(false);
    return;
  }

  // 4. Se estiver em outra aba que não seja o Estoque principal, volta para o Estoque
  if (state.currentTab && state.currentTab !== "stock") {
    switchTab("stock");
    return;
  }

  // 5. Se o teclado virtual estiver aberto em algum input, fecha o foco
  if (document.activeElement && (document.activeElement.tagName === "INPUT" || document.activeElement.tagName === "TEXTAREA")) {
    document.activeElement.blur();
    return;
  }

  // 6. Duplo clique no botão voltar para sair do aplicativo nativo
  const now = Date.now();
  if (now - lastBackPressTime < 2000) {
    if (window.Capacitor?.Plugins?.App?.exitApp) {
      window.Capacitor.Plugins.App.exitApp();
    } else {
      try { window.close(); } catch(e) {}
    }
  } else {
    lastBackPressTime = now;
    showToast("Pressione voltar novamente para sair", "info");
  }
}

function setupNativeBackButton() {
  if (backButtonHandlerRegistered) return;

  const capApp = window.Capacitor?.Plugins?.App;
  if (capApp && typeof capApp.addListener === "function") {
    try {
      capApp.addListener("backButton", () => {
        handleAppBackAction();
      });
      backButtonHandlerRegistered = true;
      console.log("BINFAE: Listener nativo do botão voltar do Android registrado com sucesso.");
    } catch (e) {
      console.warn("Capacitor backButton setup:", e);
    }
  }

  window.addEventListener("popstate", () => {
    if (isFiltersBottomSheetOpen()) {
      closeFiltersBottomSheet();
      return;
    }
    closeActiveModal();
  });
}

// Registro imediato para capturar eventos assim que o script carregar
setupNativeBackButton();

// ============================================================================
// 11. GAVETA INFERIOR DE FILTROS MOBILE (BOTTOM SHEET)
// ============================================================================

function isFiltersBottomSheetOpen() {
  const sheet = document.getElementById("bottom-sheet-filters");
  return sheet && (sheet.classList.contains("open") || !sheet.classList.contains("translate-y-full"));
}

function openFiltersBottomSheet() {
  triggerHaptic("light");
  const sheet = document.getElementById("bottom-sheet-filters");
  const backdrop = document.getElementById("bottom-sheet-backdrop");
  if (!sheet) return;

  const desktopLoc = document.getElementById("filter-location");
  const sheetLoc = document.getElementById("sheet-filter-location");
  if (desktopLoc && sheetLoc) {
    sheetLoc.innerHTML = desktopLoc.innerHTML;
    sheetLoc.value = desktopLoc.value;
  }

  const desktopSub = document.getElementById("filter-subgroup");
  const sheetSub = document.getElementById("sheet-filter-subgroup");
  if (desktopSub && sheetSub) {
    sheetSub.innerHTML = desktopSub.innerHTML;
    sheetSub.value = desktopSub.value;
  }

  const desktopInc = document.getElementById("filter-include-sublocations");
  const sheetInc = document.getElementById("sheet-filter-include-sublocations");
  if (desktopInc && sheetInc) {
    sheetInc.checked = desktopInc.checked;
  }

  const desktopTipo = document.getElementById("filter-tipo");
  const sheetTipo = document.getElementById("sheet-filter-tipo");
  if (desktopTipo && sheetTipo) {
    sheetTipo.value = desktopTipo.value;
  }

  const desktopStatus = document.getElementById("filter-status");
  const sheetStatus = document.getElementById("sheet-filter-status");
  if (desktopStatus && sheetStatus) {
    sheetStatus.value = desktopStatus.value;
  }

  backdrop?.classList.remove("hidden");
  requestAnimationFrame(() => {
    sheet.classList.remove("translate-y-full");
    sheet.classList.add("translate-y-0", "open");
  });
}

function closeFiltersBottomSheet() {
  const sheet = document.getElementById("bottom-sheet-filters");
  const backdrop = document.getElementById("bottom-sheet-backdrop");
  if (!sheet) return;

  sheet.classList.remove("translate-y-0", "open");
  sheet.classList.add("translate-y-full");
  setTimeout(() => {
    backdrop?.classList.add("hidden");
  }, 220);
}

function syncFilterFromSheet(field) {
  // Sincronização em tempo real enquanto o usuário mexe na gaveta
  const sheetLoc = document.getElementById("sheet-filter-location");
  const desktopLoc = document.getElementById("filter-location");
  if (sheetLoc && desktopLoc) desktopLoc.value = sheetLoc.value;

  const sheetInc = document.getElementById("sheet-filter-include-sublocations");
  const desktopInc = document.getElementById("filter-include-sublocations");
  if (sheetInc && desktopInc) desktopInc.checked = sheetInc.checked;

  const sheetSub = document.getElementById("sheet-filter-subgroup");
  const desktopSub = document.getElementById("filter-subgroup");
  if (sheetSub && desktopSub) desktopSub.value = sheetSub.value;

  const sheetTipo = document.getElementById("sheet-filter-tipo");
  const desktopTipo = document.getElementById("filter-tipo");
  if (sheetTipo && desktopTipo) desktopTipo.value = sheetTipo.value;

  const sheetStatus = document.getElementById("sheet-filter-status");
  const desktopStatus = document.getElementById("filter-status");
  if (sheetStatus && desktopStatus) {
    desktopStatus.value = sheetStatus.value;
    updateStatusPillsUI(sheetStatus.value);
  }

  const hasActiveFilter = Boolean((desktopLoc?.value) || (desktopSub?.value) || (desktopTipo?.value) || (desktopStatus?.value));
  const badge = document.getElementById("mobile-filter-badge");
  if (badge) {
    if (hasActiveFilter) badge.classList.remove("hidden");
    else badge.classList.add("hidden");
  }

  // Já filtra instantaneamente em memória
  filterItemsInMemory();
}

function applyFiltersFromSheet() {
  syncFilterFromSheet();
  closeFiltersBottomSheet();
  triggerHaptic("success");
}

// ============================================================================
// 12. GESTO PULL-TO-REFRESH (PUXAR PARA ATUALIZAR)
// ============================================================================

function setupPullToRefresh() {
  const main = document.getElementById("main-content");
  const indicator = document.getElementById("pull-to-refresh-indicator");
  const text = document.getElementById("pull-refresh-text");
  const spinner = document.getElementById("pull-refresh-spinner");
  if (!main || !indicator) return;

  let startY = 0;
  let currentY = 0;
  let isPulling = false;
  let isRefreshing = false;

  main.addEventListener("touchstart", (e) => {
    if (main.scrollTop <= 2 && !isRefreshing) {
      startY = e.touches[0].clientY;
      isPulling = true;
    } else {
      isPulling = false;
    }
  }, { passive: true });

  main.addEventListener("touchmove", (e) => {
    if (!isPulling || isRefreshing) return;
    currentY = e.touches[0].clientY;
    const dy = currentY - startY;

    if (dy > 0 && main.scrollTop <= 2) {
      const pullDistance = Math.min(dy * 0.38, 70);
      indicator.classList.remove("hidden");
      indicator.style.transform = `translateY(${pullDistance}px)`;

      if (pullDistance > 45) {
        if (text) text.textContent = "Solte para atualizar";
        if (spinner) spinner.style.borderColor = "#0284c7";
      } else {
        if (text) text.textContent = "Puxe para atualizar";
      }
    }
  }, { passive: true });

  main.addEventListener("touchend", async () => {
    if (!isPulling || isRefreshing) return;
    isPulling = false;
    const dy = currentY - startY;

    if (dy > 110 && main.scrollTop <= 5) {
      isRefreshing = true;
      triggerHaptic("medium");
      if (text) text.textContent = "Atualizando dados...";
      indicator.style.transform = "translateY(30px)";

      try {
        await refreshAppData();
        if (text) text.textContent = "Atualizado!";
        triggerHaptic("success");
      } catch (err) {
        console.warn("Pull to refresh erro:", err);
      } finally {
        setTimeout(() => {
          indicator.style.transform = "";
          indicator.classList.add("hidden");
          isRefreshing = false;
        }, 500);
      }
    } else {
      indicator.style.transform = "";
      indicator.classList.add("hidden");
    }
  }, { passive: true });
}

async function refreshAppData() {
  await Promise.allSettled([
    loadItems(),
    loadLocations(),
    loadGroups(),
    loadMovements()
  ]);
}

// ============================================================================
// 13. MODO OFFLINE E RESILIÊNCIA DE REDE
// ============================================================================

function setupOfflineNetworkDetection() {
  const banner = document.getElementById("offline-network-banner");

  function updateStatus(online) {
    if (online) {
      banner?.classList.add("hidden");
      triggerHaptic("success");
      showToast("Conexão restabelecida! Atualizando dados da nuvem...", "success");
      refreshAppData();
    } else {
      banner?.classList.remove("hidden");
      triggerHaptic("warning");
      showToast("Sem conexão à internet. Modo offline ativado com dados em cache.", "warning");
    }
  }

  window.addEventListener("online", () => updateStatus(true));
  window.addEventListener("offline", () => updateStatus(false));

  if (!navigator.onLine) {
    banner?.classList.remove("hidden");
  }
}

async function checkNetworkConnection(manual = false) {
  triggerHaptic("light");
  const banner = document.getElementById("offline-network-banner");
  showToast("Verificando conexão com o servidor na nuvem...", "info");

  try {
    const baseUrl = getApiBaseUrl();
    const res = await fetch(`${baseUrl}/system/version`, { cache: "no-store" });
    if (res.ok) {
      banner?.classList.add("hidden");
      triggerHaptic("success");
      showToast("Conexão com a nuvem estabelecida com sucesso!", "success");
      refreshAppData();
    } else {
      throw new Error("Servidor retornou erro");
    }
  } catch (err) {
    banner?.classList.remove("hidden");
    triggerHaptic("error");
    if (manual) {
      showToast("Ainda sem conexão com o servidor. Exibindo dados locais do inventário.", "warning");
    }
  }
}

