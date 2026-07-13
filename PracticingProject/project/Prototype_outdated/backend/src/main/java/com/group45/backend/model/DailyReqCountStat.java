package com.group45.backend.model;

import java.time.LocalDate;

public record DailyReqCountStat(
        LocalDate recordDate,
        Long totalRequestCount
) {
}