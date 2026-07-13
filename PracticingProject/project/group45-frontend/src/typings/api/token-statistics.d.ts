declare namespace Api {
  namespace TokenStatistics {
    interface DepartmentUsage {
      tagId: string;
      name: string;
      parentTag: string | null;
      children?: DepartmentUsage[];
      lastDay: number;
      lastWeek: number;
      lastMonth: number;
      lastYear: number;
      total: number;
    }

    interface Response {
      data: DepartmentUsage[];
      code: number;
      message: string;
    }
  }
}
