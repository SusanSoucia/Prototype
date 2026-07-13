package com.group45.backend;

import org.junit.jupiter.api.Test;
import org.springframework.boot.WebApplicationType;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.context.ConfigurableApplicationContext;

class Group45BackendApplicationTests {

    @Test
    void contextLoads() {
        try (ConfigurableApplicationContext ignored = new SpringApplicationBuilder(Group45BackendApplication.class)
                .web(WebApplicationType.NONE)
                .run("--spring.main.banner-mode=off")) {
        }
    }
}
