declare namespace Api {
  /**
   * namespace Auth
   *
   * backend api module: "auth"
   */
  namespace Auth {
    interface LoginToken {
      token: string;
      refreshToken: string;
    }

    interface UserInfo {
      id: number;
      userName: string;
      role: 'USER' | 'ADMIN';
      orgTags: string[];
      primaryOrg: string;
    }
  }
}
