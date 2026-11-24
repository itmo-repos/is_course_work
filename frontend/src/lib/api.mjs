export class ApiError extends Error {
  /** @param {number} status */
  constructor(status) {
    super(`HTTP ${status}`);
    this.name = 'ApiError';
    this.status = status;
  }
}

/** @param {typeof fetch} transport */
export function createApi(transport = globalThis.fetch.bind(globalThis)) {
  /** @type {{headerName: string, token: string} | null} */
  let csrf = null;

  async function refreshCsrf() {
    const response = await transport('/api/auth/csrf', { credentials: 'include', cache: 'no-store' });
    if (!response.ok) throw new ApiError(response.status);
    const data = await response.json();
    if (typeof data.headerName !== 'string' || typeof data.token !== 'string') {
      throw new Error('Invalid CSRF response');
    }
    csrf = data;
    return data;
  }

  /** @param {string} path @param {RequestInit} options */
  async function request(path, options = {}) {
    const method = (options.method || 'GET').toUpperCase();
    const headers = new Headers(options.headers);
    if (!['GET', 'HEAD', 'OPTIONS'].includes(method)) {
      const token = csrf ?? await refreshCsrf();
      headers.set(token.headerName, token.token);
    }
    if (typeof options.body === 'string' && !headers.has('Content-Type')) {
      headers.set('Content-Type', 'application/json');
    }
    const response = await transport('/api' + path, {
      ...options, method, headers, credentials: 'include', cache: 'no-store',
    });
    if (!response.ok) throw new ApiError(response.status);
    return response.status === 204 ? undefined : response.json();
  }

  /** @param {string} email @param {string} password */
  async function login(email, password) {
    const user = await request('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    });
    csrf = null;
    await refreshCsrf();
    return user;
  }

  async function logout() {
    await request('/auth/logout', { method: 'POST' });
    csrf = null;
  }

  return { request, login, logout, refreshCsrf };
}

export const api = createApi();
