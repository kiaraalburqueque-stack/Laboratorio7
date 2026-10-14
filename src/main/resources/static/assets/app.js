'use strict';

const $ = (selector) => document.querySelector(selector);
const state = { authorization: null, account: null, requests: 0, history: [] };
const demoPasswords = { user: 'UsuarioS07!2026', admin: 'AdminS07!2026', manager: 'ManagerS07!2026' };
const messages = { 401: 'Inicia sesión con credenciales válidas para acceder a este recurso.',
  403: 'Tu cuenta está autenticada, pero tu rol no tiene permiso para este recurso.',
  404: 'La ruta solicitada no existe.' };

function setConnection(online) {
  $('#connection-dot').className = `status-dot ${online ? 'online' : 'offline'}`;
  $('#connection-label').textContent = online ? 'Servidor conectado' : 'Sin conexión';
}

async function request(path, authorization = state.authorization) {
  const started = performance.now();
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10000);
  try {
    const headers = { Accept: 'application/json, text/plain' };
    if (authorization) headers.Authorization = authorization;
    const response = await fetch(path, { headers, cache: 'no-store', credentials: 'omit', signal: controller.signal });
    const body = await response.text();
    setConnection(true);
    return { status: response.status, body, duration: Math.round(performance.now() - started) };
  } catch (error) {
    setConnection(false);
    return { status: 0, body: error.name === 'AbortError' ? 'El servidor tardó demasiado en responder. Vuelve a intentarlo.' : 'No se pudo conectar con el servidor. Comprueba que la aplicación esté iniciada.', duration: Math.round(performance.now() - started) };
  } finally { clearTimeout(timeout); }
}

function renderSession() {
  const account = state.account;
  $('#guest-session').hidden = Boolean(account);
  $('#authenticated-session').hidden = !account;
  $('#session-badge').textContent = account ? 'ACTIVA' : 'INVITADO';
  if (account) {
    $('#account-name').textContent = account.username;
    $('#account-avatar').textContent = account.username.slice(0, 2).toUpperCase();
    $('#account-roles').replaceChildren(...account.roles.map((role) => {
      const badge = document.createElement('span');
      badge.className = `role-badge ${role.replace('ROLE_', '').toLowerCase()}`;
      badge.textContent = role.replace('ROLE_', '');
      return badge;
    }));
  }
  const has = (...roles) => account && account.roles.some((role) => roles.includes(role));
  const permissions = { public: true, client: has('ROLE_USER', 'ROLE_ADMIN'),
    admin: has('ROLE_ADMIN'), manager: has('ROLE_MANAGER', 'ROLE_ADMIN') };
  document.querySelectorAll('[data-permission]').forEach((element) => {
    const allowed = permissions[element.dataset.permission];
    element.textContent = allowed ? 'Disponible' : account ? 'Sin permiso' : 'Requiere sesión';
    element.className = `permission ${allowed ? 'allowed' : account ? 'denied' : ''}`;
  });
}

function renderHistory() {
  $('#request-count').textContent = String(state.requests).padStart(2, '0');
  $('#empty-history').hidden = state.history.length > 0;
  $('#history-body').replaceChildren(...state.history.map((entry) => {
    const row = document.createElement('tr');
    [entry.path, entry.username, entry.status || 'Red', `${entry.duration} ms`].forEach((value, index) => {
      const cell = document.createElement('td');
      if (index === 2) {
        const badge = document.createElement('span');
        badge.className = `response-status ${entry.status >= 400 || !entry.status ? 'error' : ''}`;
        badge.textContent = String(value);
        cell.append(badge);
      } else { cell.textContent = String(value); }
      row.append(cell);
    });
    return row;
  }));
}

function showResult(path, result, username) {
  state.requests++;
  state.history.unshift({ path, username, ...result });
  state.history = state.history.slice(0, 12);
  const badge = document.createElement('span');
  badge.className = `response-status ${result.status >= 400 || !result.status ? 'error' : ''}`;
  badge.textContent = result.status ? `HTTP ${result.status}` : 'SIN RED';
  const message = document.createElement('span');
  message.className = 'response-message';
  message.textContent = messages[result.status] || result.body;
  $('#response-preview').replaceChildren(badge, message);
  renderHistory();
}

$('#login-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const username = $('#username').value.trim();
  const password = $('#password').value;
  if (!username || !password) return;
  const bytes = new TextEncoder().encode(`${username}:${password}`);
  const authorization = `Basic ${btoa(Array.from(bytes, (byte) => String.fromCharCode(byte)).join(''))}`;
  $('#login-error').hidden = true;
  $('#login-button').disabled = true;
  $('#login-button').textContent = 'Verificando…';
  const result = await request('/api/me', authorization);
  showResult('/api/me', result, username);
  if (result.status === 200) {
    try {
      const account = JSON.parse(result.body);
      if (typeof account.username !== 'string' || !Array.isArray(account.roles)) throw new Error('Invalid account');
      state.account = account;
      state.authorization = authorization;
      $('#password').value = '';
      $('#password').type = 'password';
      $('#toggle-password').textContent = 'Ver';
      $('#toggle-password').setAttribute('aria-label', 'Mostrar contraseña');
      $('#toggle-password').setAttribute('aria-pressed', 'false');
      renderSession();
    } catch {
      $('#login-error').textContent = 'El servidor devolvió una respuesta inesperada.';
      $('#login-error').hidden = false;
    }
  } else {
    $('#login-error').textContent = result.status === 401 ? 'Usuario o contraseña incorrectos. Inténtalo de nuevo.' : messages[result.status] || result.body;
    $('#login-error').hidden = false;
  }
  $('#login-button').disabled = false;
  $('#login-button').textContent = 'Iniciar sesión →';
});

$('#logout-button').addEventListener('click', () => {
  state.authorization = null;
  state.account = null;
  $('#login-form').reset();
  $('#login-error').hidden = true;
  renderSession();
  $('#username').focus();
});

$('#toggle-password').addEventListener('click', () => {
  const show = $('#password').type === 'password';
  $('#password').type = show ? 'text' : 'password';
  $('#toggle-password').textContent = show ? 'Ocultar' : 'Ver';
  $('#toggle-password').setAttribute('aria-label', show ? 'Ocultar contraseña' : 'Mostrar contraseña');
  $('#toggle-password').setAttribute('aria-pressed', String(show));
});

document.querySelectorAll('[data-demo]').forEach((button) => button.addEventListener('click', () => {
  $('#username').value = button.dataset.demo;
  $('#password').value = demoPasswords[button.dataset.demo];
  $('#login-error').hidden = true;
  $('#login-button').focus();
}));

document.querySelectorAll('[data-path]').forEach((button) => button.addEventListener('click', async () => {
  const username = state.account?.username || 'Invitado';
  button.disabled = true;
  button.textContent = 'Consultando…';
  try {
    const result = await request(button.dataset.path);
    showResult(button.dataset.path, result, username);
  } finally {
    button.disabled = false;
    button.textContent = 'Probar acceso →';
  }
}));

$('#clear-history').addEventListener('click', () => {
  state.history = [];
  const placeholder = document.createElement('span');
  placeholder.className = 'response-placeholder';
  placeholder.textContent = 'Historial limpio. Prueba otro acceso para continuar.';
  $('#response-preview').replaceChildren(placeholder);
  renderHistory();
});

document.querySelectorAll('.nav-link').forEach((link) => link.addEventListener('click', () => {
  document.querySelectorAll('.nav-link').forEach((item) => item.classList.toggle('active', item === link));
}));

renderSession();
request('/api/free', null);
