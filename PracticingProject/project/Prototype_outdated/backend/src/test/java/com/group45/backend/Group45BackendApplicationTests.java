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
                .run(
                        "--spring.main.banner-mode=off",
                        "--spring.datasource.url=jdbc:h2:mem:group45_test;MODE=MySQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1",
                        "--spring.datasource.driver-class-name=org.h2.Driver",
                        "--spring.datasource.username=sa",
                        "--spring.datasource.password=",
                        "--spring.jpa.hibernate.ddl-auto=update",
                        "--spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.H2Dialect",
                        "--jwt.secret-key=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=",
                        "--minio.endpoint=http://localhost:9000",
                        "--minio.publicUrl=http://localhost:9000",
                        "--minio.accessKey=test-access-key",
                        "--minio.secretKey=test-secret-key",
                        "--spring.kafka.listener.auto-startup=false",
                        "--spring.kafka.admin.auto-create=false",
                        "--elasticsearch.init.enabled=false",
                        "--knowledge.bootstrap.enabled=false",
                        "--admin.bootstrap.enabled=false"
                )) {
        }
    }
}
