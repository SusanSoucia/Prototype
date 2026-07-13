import { computed, reactive, ref } from 'vue';
import { useRoute } from 'vue-router';
import { defineStore } from 'pinia';
import { useLoading } from '@sa/hooks';
import { fetchGetUserInfo, fetchLogin, fetchLogout, fetchRegister, fetchChangePassword } from '@/service/api';
import { useRouterPush } from '@/hooks/common/router';
import { localStg } from '@/utils/storage';
import { SetupStoreId } from '@/enum';
import { $t } from '@/locales';
import { useRouteStore } from '../route';
import { useTabStore } from '../tab';
import { clearAuthStorage, getToken } from './shared';

export const useAuthStore = defineStore(SetupStoreId.Auth, () => {
  const route = useRoute();
  const routeStore = useRouteStore();
  const tabStore = useTabStore();
  const { toLogin, redirectFromLogin, toggleLoginModule } = useRouterPush(false);
  const { loading: loginLoading, startLoading: startLoginLoading, endLoading: endLoginLoading } = useLoading();
  const { loading: registerLoading, startLoading: startRegisterLoading, endLoading: endRegisterLoading } = useLoading();
  const {
    loading: changePasswordLoading,
    startLoading: startChangePasswordLoading,
    endLoading: endChangePasswordLoading
  } = useLoading();

  const token = ref(getToken());

  const defaultUserInfo: Api.Auth.UserInfo = {
    id: 0,
    userName: '',
    role: 'USER',
    orgTags: [],
    primaryOrg: ''
  };

  const userInfo = reactive<Api.Auth.UserInfo>({ ...defaultUserInfo });

  /** is super role in static route */
  const isStaticSuper = computed(() => {
    const { VITE_AUTH_ROUTE_MODE, VITE_STATIC_SUPER_ROLE } = import.meta.env;

    return VITE_AUTH_ROUTE_MODE === 'static' && userInfo.role === VITE_STATIC_SUPER_ROLE;
  });

  /** Is login */
  const isLogin = computed(() => Boolean(token.value));

  /** Is admin */
  const isAdmin = computed(() => userInfo.role === 'ADMIN');

  /** Reset auth store */
  async function resetStore() {
    recordUserId();

    clearAuthStorage();
    token.value = '';
    Object.assign(userInfo, defaultUserInfo);
    useChatStore().handleAuthReset();

    if (!route.meta.constant) {
      await toLogin();
    }

    tabStore.cacheTabs();
    routeStore.resetStore();
  }

  /** Record the user ID of the previous login session Used to compare with the current user ID on next login */
  function recordUserId() {
    if (!userInfo.id) {
      return;
    }

    // Store current user ID locally for next login comparison
    localStg.set('lastLoginUserId', userInfo.id);
  }

  /**
   * Check if current login user is different from previous login user If different, clear all tabs
   *
   * @returns {boolean} Whether to clear all tabs
   */
  function checkTabClear(): boolean {
    if (!userInfo.id) {
      return false;
    }

    const lastLoginUserId = localStg.get('lastLoginUserId');

    // Clear all tabs if current user is different from previous user
    if (!lastLoginUserId || lastLoginUserId !== userInfo.id) {
      localStg.remove('globalTabs');
      tabStore.clearTabs();

      localStg.remove('lastLoginUserId');
      return true;
    }

    localStg.remove('lastLoginUserId');
    return false;
  }

  /**
   * Login
   *
   * @param userName User name
   * @param password Password
   * @param [redirect=true] Whether to redirect after login. Default is `true`
   */
  async function login(userName: string, password: string, redirect = true) {
    startLoginLoading();

    const { data: loginToken, error } = await fetchLogin(userName, password);

    if (!error) {
      const pass = await loginByToken(loginToken);

      if (pass) {
        const isClear = checkTabClear();
        let needRedirect = redirect;

        if (isClear) {
          needRedirect = false;
        }
        await redirectFromLogin(needRedirect);

        window.$notification?.success({
          title: $t('page.login.common.loginSuccess'),
          content: $t('page.login.common.welcomeBack', { userName: userInfo.userName }),
          duration: 4500
        });
      }
    } else {
      resetStore();
    }

    endLoginLoading();
    return false;
  }

  async function register(userName: string, password: string) {
    startRegisterLoading();

    const { error } = await fetchRegister(userName, password);

    if (!error) {
      window.$message?.success($t('page.login.common.validateSuccess'));
      await toggleLoginModule('pwd-login');
    }

    endRegisterLoading();
  }

  async function changePassword(userName: string, oldPassword: string, newPassword: string) {
    startChangePasswordLoading();

    const { error } = await fetchChangePassword(userName, oldPassword, newPassword);

    if (!error) {
      window.$message?.success($t('page.login.common.validateSuccess'));
      await toggleLoginModule('pwd-login');
    }

    endChangePasswordLoading();
  }

  async function loginByToken(loginToken: Api.Auth.LoginToken) {
    // 1. stored in the localStorage, the later requests need it in headers
    localStg.set('token', loginToken.token);
    localStg.set('refreshToken', loginToken.refreshToken);

    // 2. get user info
    const pass = await getUserInfo();

    if (pass) {
      token.value = loginToken.token;

      return true;
    }

    return false;
  }

  async function getUserInfo() {
    const { data: info, error } = await fetchGetUserInfo();

    if (!error) {
      // Handle PaiSmart backend: username → userName
      const normalized = { ...info };
      if (normalized.username && !normalized.userName) {
        normalized.userName = normalized.username;
      }

      // update store
      Object.assign(userInfo, normalized);

      return true;
    }

    return false;
  }

  async function initUserInfo() {
    const maybeToken = getToken();

    if (maybeToken) {
      const pass = await getUserInfo();

      if (!pass) {
        resetStore();
      }
    }
  }

  function setToken(newToken: string) {
    token.value = newToken;
    localStg.set('token', newToken);
  }

  async function logout() {
    const { error } = await fetchLogout();

    if (!error) {
      resetStore();
      useKnowledgeBaseStore().$reset();
    }
  }

  return {
    token,
    userInfo,
    isStaticSuper,
    isLogin,
    isAdmin,
    loginLoading,
    registerLoading,
    changePasswordLoading,
    resetStore,
    login,
    register,
    changePassword,
    logout,
    initUserInfo,
    setToken
  };
});
