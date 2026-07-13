package com.group45.backend.controller;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class HealthControllerTests {

    @Test
    void healthReturnsUp() {
        HealthController controller = new HealthController();

        assertEquals("UP", controller.health().status());
    }
}
