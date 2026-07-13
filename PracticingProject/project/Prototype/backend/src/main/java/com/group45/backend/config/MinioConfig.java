package com.group45.backend.config;

import io.minio.MinioClient;
import lombok.Getter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Getter
@Configuration
public class MinioConfig {

    @Value("${minio.endpoint}")
    private String endpoint;

    @Value("${minio.accessKey}")
    private String accessKey;

    @Value("${minio.secretKey}")
    private String secretKey;

    @Value("${minio.publicUrl}")
    private String publicUrl;


    @Bean
    public MinioClient minioClient() {
        // 使用 publicUrl 作为 endpoint，这样生成的预签名URL可以直接被外部访问
        // 内部连接也通过这个地址（Docker端口映射确保可达）
        return MinioClient.builder()
                .endpoint(publicUrl)
                .credentials(accessKey, secretKey)
                .build();
    }

    @Bean
    public String minioPublicUrl() {
        return publicUrl;
    }
}

