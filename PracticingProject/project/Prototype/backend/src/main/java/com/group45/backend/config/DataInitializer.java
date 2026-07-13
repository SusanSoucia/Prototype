package com.group45.backend.config;

import com.group45.backend.model.OrganizationTag;
import com.group45.backend.model.User;
import com.group45.backend.repository.OrganizationTagRepository;
import com.group45.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class DataInitializer implements CommandLineRunner {
    
    private final UserRepository userRepository;
    private final OrganizationTagRepository organizationTagRepository;
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();
    
    @Override
    public void run(String... args) throws Exception {
        // 检查是否已有数据
        if (userRepository.count() > 0) {
            return;
        }
        
        // 创建测试组织标签
        OrganizationTag tag1 = new OrganizationTag();
        tag1.setTagId("tech");
        tag1.setName("技术部");
        tag1.setDescription("技术研发部门");
        tag1.setParentTag(null);

        OrganizationTag tag2 = new OrganizationTag();
        tag2.setTagId("product");
        tag2.setName("产品部");
        tag2.setDescription("产品设计部门");
        tag2.setParentTag(null);
        
        organizationTagRepository.save(tag1);
        organizationTagRepository.save(tag2);
        
        // 创建测试用户
        User user = new User();
        user.setUsername("testuser");
        user.setPassword(passwordEncoder.encode("test123")); // 加密密码
        user.setRole(User.Role.USER);
        user.setOrgTags("tech,product");
        user.setPrimaryOrg("tech");
        
        userRepository.save(user);
        
        // 创建管理员用户
        User admin = new User();
        admin.setUsername("admin");
        admin.setPassword(passwordEncoder.encode("admin123"));
        admin.setRole(User.Role.ADMIN);
        admin.setOrgTags("tech,product");
        admin.setPrimaryOrg("tech");
        
        userRepository.save(admin);
        
        System.out.println("测试数据初始化完成!");
        System.out.println("普通用户: testuser/test123");
        System.out.println("管理员: admin/admin123");
    }
}
