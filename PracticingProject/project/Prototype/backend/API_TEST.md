# API 测试指南

## 已实现的接口

### 1. 用户登录 (POST /api/auth/login)

**请求:**
```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "test123"
  }'
```

**响应:**
```json
{
  "code": 200,
  "message": "Login successful",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "refreshToken": "",
    "userInfo": {
      "id": 1,
      "username": "testuser",
      "role": "USER",
      "orgTags": [
        {"tagId": "tech", "name": "技术部", "description": "技术研发部门"},
        {"tagId": "product", "name": "产品部", "description": "产品设计部门"}
      ],
      "primaryOrg": "tech"
    }
  }
}
```

---

### 2. 获取当前用户信息 (GET /api/users/me)

**请求:**
```bash
curl -X GET http://localhost:8080/api/users/me \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

**响应:**
```json
{
  "code": 200,
  "message": "Get current user successful",
  "data": {
    "id": 1,
    "username": "testuser",
    "role": "USER",
    "orgTags": [...],
    "primaryOrg": "tech"
  }
}
```

---

### 3. 获取用户组织标签 (GET /api/users/org-tags)

**请求:**
```bash
curl -X GET http://localhost:8080/api/users/org-tags \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

**响应:**
```json
{
  "code": 200,
  "message": "Get user organization tags successful",
  "data": {
    "orgTags": [...],
    "primaryOrg": "tech"
  }
}
```

---

### 4. 设置主组织标签 (PUT /api/users/primary-org)

**请求:**
```bash
curl -X PUT http://localhost:8080/api/users/primary-org \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "primaryOrg": "product"
  }'
```

**响应:**
```json
{
  "code": 200,
  "message": "Primary organization set successfully"
}
```

---

## 启动步骤

1. **确保MySQL已启动**
   ```bash
   # 创建数据库
   mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS group45_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
   ```

2. **启动后端应用**
   ```bash
   cd group45-backend
   mvn spring-boot:run
   ```

3. **测试接口**
   - 先调用登录接口获取token
   - 使用token访问其他接口

---

## 测试账号

### 普通用户
- 用户名: `testuser`
- 密码: `test123`

### 管理员
- 用户名: `admin`
- 密码: `admin123`

自动创建的测试数据:
- 组织标签: 技术部(tech), 产品部(product)
- 用户主组织: tech

---

## 管理员接口测试

### 5. 获取用户列表 (GET /api/admin/users/list)

**请求:**
```bash
curl -X GET "http://localhost:8080/api/admin/users/list?page=1&size=10" \
  -H "Authorization: Bearer ADMIN_TOKEN_HERE"
```

**响应:**
```json
{
  "code": 200,
  "message": "获取用户列表成功",
  "data": {
    "data": [
      {
        "id": 1,
        "username": "testuser",
        "role": "USER",
        "orgTags": [...],
        "primaryOrg": "tech",
        "createdAt": "2026-06-30T..."
      }
    ],
    "total": 2,
    "page": 1,
    "size": 10
  }
}
```

---

### 6. 为用户分配组织标签 (PUT /api/admin/users/{userId}/org-tags)

**请求:**
```bash
curl -X PUT http://localhost:8080/api/admin/users/1/org-tags \
  -H "Authorization: Bearer ADMIN_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "orgTags": ["tech", "product"]
  }'
```

**响应:**
```json
{
  "code": 200,
  "message": "组织标签分配成功"
}
```

---

### 7. 创建组织标签 (POST /api/admin/org-tags)

**请求:**
```bash
curl -X POST http://localhost:8080/api/admin/org-tags \
  -H "Authorization: Bearer ADMIN_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "tagId": "marketing",
    "name": "市场部",
    "description": "市场营销部门",
    "parentTag": null,
    "uploadMaxSizeMb": 50
  }'
```

**响应:**
```json
{
  "code": 200,
  "message": "组织标签创建成功",
  "data": {
    "tagId": "marketing",
    "name": "市场部",
    "description": "市场营销部门",
    "parentTag": null,
    "uploadMaxSizeBytes": 52428800,
    "createdBy": "admin",
    "createdAt": "2026-06-30T..."
  }
}
```

---

### 8. 获取组织标签树 (GET /api/admin/org-tags/tree)

**请求:**
```bash
curl -X GET http://localhost:8080/api/admin/org-tags/tree \
  -H "Authorization: Bearer ADMIN_TOKEN_HERE"
```

**响应:**
```json
{
  "code": 200,
  "message": "获取组织标签树成功",
  "data": [
    {
      "tagId": "tech",
      "name": "技术部",
      "description": "技术研发部门",
      "parentTag": null,
      "uploadMaxSizeBytes": 104857600,
      "createdBy": "admin",
      "createdAt": "2026-06-30T...",
      "children": []
    },
    {
      "tagId": "product",
      "name": "产品部",
      "description": "产品设计部门",
      "parentTag": null,
      "uploadMaxSizeBytes": 52428800,
      "createdBy": "admin",
      "createdAt": "2026-06-30T...",
      "children": []
    }
  ]
}
```

---

### 9. 更新组织标签 (PUT /api/admin/org-tags/{tagId})

**请求:**
```bash
curl -X PUT http://localhost:8080/api/admin/org-tags/tech \
  -H "Authorization: Bearer ADMIN_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "技术研发部",
    "description": "技术研发与创新部门",
    "parentTag": null,
    "uploadMaxSizeMb": 200
  }'
```

**响应:**
```json
{
  "code": 200,
  "message": "组织标签更新成功",
  "data": {...}
}
```

---

### 10. 删除组织标签 (DELETE /api/admin/org-tags/{tagId})

**请求:**
```bash
curl -X DELETE http://localhost:8080/api/admin/org-tags/marketing \
  -H "Authorization: Bearer ADMIN_TOKEN_HERE"
```

**响应:**
```json
{
  "code": 200,
  "message": "组织标签删除成功"
}
```
