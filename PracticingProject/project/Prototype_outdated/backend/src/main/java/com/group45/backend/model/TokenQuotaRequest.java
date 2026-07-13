package com.group45.backend.model;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class TokenQuotaRequest {
    private Long llmToken;
    private Long embeddingToken;
    private String reason;
}
