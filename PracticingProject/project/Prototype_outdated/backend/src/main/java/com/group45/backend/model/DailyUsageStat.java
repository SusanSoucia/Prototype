package com.group45.backend.model;

import java.time.LocalDate;

public record DailyUsageStat(
        LocalDate recordDate,
        Long totalAmount,
        Long totalRequestCount
) {
}