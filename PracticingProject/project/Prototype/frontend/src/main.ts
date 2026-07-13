import { createApp } from 'vue';
import './plugins/assets';
import { setupVueRootValidator } from 'vite-plugin-vue-transition-root-validator/client';
import { setupAppVersionNotification, setupDayjs, setupIconifyOffline, setupLoading, setupNProgress } from './plugins';
import { setupStore } from './store';
import { setupRouter } from './router';
import { getLocale, setupI18n } from './locales';
import { localStg } from './utils/storage';
import App from './App.vue';

async function setupApp() {
  // Dev mock: skip login and auto-inject a mock user with the specified role
  const devMockRole = import.meta.env.VITE_DEV_MOCK_ROLE as string | undefined;
  const useDevMock = import.meta.env.DEV && devMockRole;

  if (useDevMock) {
    // Inject a mock token so the route guard sees a "logged in" user
    localStg.set('token', 'dev-mock-token');
    localStg.set('refreshToken', 'dev-mock-refresh-token');
    console.log(`[dev-mock] Auto-login enabled with role: ${devMockRole}`);
  } else if (import.meta.env.VITE_AUTO_LOGIN === 'N') {
    // Clear persisted auth tokens when auto-login is disabled,
    // so manual login is required each time the app starts
    localStg.remove('token');
    localStg.remove('refreshToken');
  }

  setupLoading();

  setupNProgress();

  setupIconifyOffline();

  setupDayjs();

  const app = createApp(App);

  setupStore(app);

  await setupRouter(app);

  setupI18n(app);

  setupAppVersionNotification();

  setupVueRootValidator(app, {
    lang: getLocale() === 'zh-CN' ? 'zh' : 'en'
  });

  app.mount('#app');
}

setupApp();
