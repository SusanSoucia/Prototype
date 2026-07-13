import { request } from '../request';

/**
 * Login
 *
 * @param userName User name
 * @param password Password
 */
export function fetchLogin(userName: string, password: string) {
  return request<Api.Auth.LoginToken>({
    url: '/users/login',
    method: 'post',
    data: {
      username: userName,
      password
    }
  });
}

export function fetchLogout() {
  return request({ url: '/users/logout', method: 'post' });
}

export function fetchRegister(userName: string, password: string) {
  return request({ url: '/users/register', method: 'post', data: { username: userName, password } });
}

export function fetchChangePassword(userName: string, oldPassword: string, newPassword: string) {
  return request({ url: '/users/changePassword', method: 'post', data: { userName, oldPassword, newPassword } });
}

/** Get user info */
export function fetchGetUserInfo() {
  return request<Api.Auth.UserInfo>({ url: '/users/me' });
}

/**
 * Refresh token
 *
 * @param refreshToken Refresh token
 */
export function fetchRefreshToken(refreshToken: string) {
  return request<Api.Auth.LoginToken>({
    url: '/auth/refreshToken',
    method: 'post',
    data: {
      refreshToken
    }
  });
}

/**
 * return custom backend error
 *
 * @param code error code
 * @param msg error message
 */
export function fetchCustomBackendError(code: string, msg: string) {
  return request({ url: '/auth/error', params: { code, msg } });
}
