declare namespace Api {
  /**
   * namespace OrgTag
   *
   * backend api module: "org-tag"
   */
  namespace OrgTag {
    interface Item {
      tagId: string;
      name: string;
      description: string;
      parentTag: string | null;
      uploadMaxSizeBytes: number | null;
      uploadMaxSizeMb: number | null;
      children?: Item[];
    }

    type List = Common.PaginatingQueryRecord<Item>;

    type Details = Pick<Item, 'tagId' | 'name' | 'description'>;

    interface Mine {
      orgTags: string[];
      primaryOrg: string;
      orgTagDetails: Details[];
    }
  }
}
