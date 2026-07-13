declare namespace Api {
  /**
   * namespace Admin
   *
   * backend api module: "admin"
   */
  namespace Admin {
    /** Matches backend /admin/users/list response format */
    interface User {
      userId: number;
      username: string;
      role: string;
      /** Array of {tagId, name} objects from backend */
      orgTags: { tagId: string; name: string }[];
      primaryOrg: string | null;
      /** 0=ADMIN, 1=USER, 2=LIBRARY_ADMIN */
      status: number;
      createdAt: string;
    }

    interface UserListParams {
      keyword?: string;
      orgTag?: string;
      status?: number;
      userId?: number;
      page?: number;
      size?: number;
    }

    interface UserListResult {
      content: User[];
      totalElements: number;
      totalPages: number;
      number: number;
      size: number;
    }

    /** Paginated user list type compatible with TableApiFn<A> */
    type UserList = Common.PaginatingQueryRecord<User>;
  }
}
