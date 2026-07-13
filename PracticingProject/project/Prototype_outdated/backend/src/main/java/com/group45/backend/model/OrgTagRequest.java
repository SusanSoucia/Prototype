package com.group45.backend.model;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class OrgTagRequest {
    private String tagId;
    private String name;
    private String description;
    private String parentTag;
    private Long uploadMaxSizeMb;
}
