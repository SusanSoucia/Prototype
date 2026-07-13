declare namespace Api {
  /**
   * namespace UserManagement
   *
   * backend api module: "admin"
   */
  namespace UserManagement {
    interface User {
      userId: number;
      username: string;
      /** 0=admin, 1=user */
      status: number;
      /** backend returns org tag objects with tagId + name */
      orgTags: { tagId: string; name: string }[];
      primaryOrg: string;
      createdAt: string;
    }

    type List = Common.PaginatingQueryRecord<User>;
  }
}
