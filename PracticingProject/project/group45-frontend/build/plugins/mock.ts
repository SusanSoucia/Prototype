import { viteMockServe } from 'vite-plugin-mock';

/**
 * Setup mock plugin — only enable when no real backend URL is configured.
 * When VITE_SERVICE_BASE_URL is set, requests are proxied to the real backend.
 */
export function setupMockPlugin(viteEnv: Env.ImportMeta) {
  const enableMock = !viteEnv.VITE_SERVICE_BASE_URL;

  return viteMockServe({
    mockPath: 'mock',
    enable: enableMock
  });
}
