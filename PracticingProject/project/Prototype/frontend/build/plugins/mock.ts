import { viteMockServe } from 'vite-plugin-mock';

/**
 * Setup mock plugin — only enable when no real backend URL is configured.
 * When VITE_SERVICE_BASE_URL is set, requests are proxied to the real backend.
 */
export function setupMockPlugin(viteEnv: Env.ImportMeta) {
  // Enable mocks when:
  // 1. No real backend URL is configured, OR
  // 2. VITE_ENABLE_MOCK is explicitly set to Y (e.g. for role-switching debug)
  const enableMock = !viteEnv.VITE_SERVICE_BASE_URL || viteEnv.VITE_ENABLE_MOCK === 'Y';

  return viteMockServe({
    mockPath: 'mock',
    enable: enableMock
  });
}
