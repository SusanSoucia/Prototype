package com.group45.backend.controller;

import com.group45.backend.model.User;
import com.group45.backend.repository.UserRepository;
import com.group45.backend.utils.JwtUtils;
import com.group45.backend.utils.LogUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;

/**
 * 路由控制器，为前端动态路由模式提供菜单和路由数据。
 * 当前默认使用静态路由模式（VITE_AUTH_ROUTE_MODE=static），
 * 前端仅在 mode=dynamic 时调用这些接口。
 */
@RestController
@RequestMapping("/api/v1/route")
public class RouteController {

    @Autowired
    private JwtUtils jwtUtils;

    @Autowired
    private UserRepository userRepository;

    /**
     * 获取常量路由（无需登录的基础路由，如 403/404/500 页）
     */
    @GetMapping("/getConstantRoutes")
    public ResponseEntity<?> getConstantRoutes() {
        // 常量路由由前端 filesystem router 自动生成，
        // 后端只需返回空数组，前端会回退到静态生成。
        return ResponseEntity.ok(Map.of(
                "code", 200,
                "message", "ok",
                "data", List.of()
        ));
    }

    /**
     * 获取当前用户可访问的动态路由
     */
    @GetMapping("/getUserRoutes")
    public ResponseEntity<?> getUserRoutes(@RequestHeader("Authorization") String token) {
        String username = null;
        try {
            username = jwtUtils.extractUsernameFromToken(token.replace("Bearer ", ""));
            if (username == null || username.isEmpty()) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(Map.of("code", 401, "message", "Invalid token"));
            }

            User user = userRepository.findByUsername(username).orElse(null);
            if (user == null) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(Map.of("code", 404, "message", "User not found"));
            }

            String role = user.getRole().name();

            // 角色 → 路由策略：
            // ADMIN: chats, knowledge-base, org-tag, chat-history, user-monitor, api-usage
            // LIBRARY_ADMIN: chats, knowledge-base, chat-history
            // USER: chats, chat-history
            List<Map<String, Object>> routes = buildRoutesForRole(role);

            return ResponseEntity.ok(Map.of(
                    "code", 200,
                    "message", "ok",
                    "data", Map.of(
                            "routes", routes,
                            "home", "chats"
                    )
            ));
        } catch (Exception e) {
            LogUtils.logBusinessError("GET_USER_ROUTES", username,
                    "获取用户路由失败: %s", e, e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("code", 500, "message", "Internal server error"));
        }
    }

    /**
     * 检查某个路由名称是否存在
     */
    @GetMapping("/isRouteExist")
    public ResponseEntity<?> isRouteExist(@RequestParam String routeName) {
        // 已知的那些页面路由名称
        Set<String> knownRoutes = Set.of(
                "chats", "knowledge-base", "org-tag",
                "chat-history", "user-monitor", "api-usage",
                "login", "403", "404", "500", "root",
                "iframe-page"
        );
        boolean exists = routeName != null && knownRoutes.contains(routeName);
        return ResponseEntity.ok(Map.of(
                "code", 200,
                "message", "ok",
                "data", exists
        ));
    }

    // ---- helper ----

    private List<Map<String, Object>> buildRoutesForRole(String role) {
        List<Map<String, Object>> routes = new ArrayList<>();

        // 聊天页 — 所有角色
        routes.add(menuRoute("chats", "/chats", "chats",
                "mdi:chat", List.of("USER", "LIBRARY_ADMIN", "ADMIN")));

        // 聊天记录 — 所有角色
        routes.add(menuRoute("chat-history", "/chat-history", "chat-history",
                "mdi:history", List.of("USER", "LIBRARY_ADMIN", "ADMIN")));

        if ("LIBRARY_ADMIN".equals(role) || "ADMIN".equals(role)) {
            // 知识库管理 — 库管和管理员
            routes.add(menuRoute("knowledge-base", "/knowledge-base", "knowledge-base",
                    "mdi:bookshelf", List.of("LIBRARY_ADMIN", "ADMIN")));
        }

        if ("ADMIN".equals(role)) {
            // 组织标签管理 — 仅超级管理员
            routes.add(menuRoute("org-tag", "/org-tag", "org-tag",
                    "mdi:tag", List.of("ADMIN")));
            // 用户监控 — 仅超级管理员
            routes.add(menuRoute("user-monitor", "/user-monitor", "user-monitor",
                    "mdi:monitor-dashboard", List.of("ADMIN")));
            // API 用量 — 仅超级管理员
            routes.add(menuRoute("api-usage", "/api-usage", "api-usage",
                    "mdi:chart-line", List.of("ADMIN")));
        }

        return routes;
    }

    private Map<String, Object> menuRoute(String name, String path, String component,
                                          String icon, List<String> roles) {
        Map<String, Object> route = new LinkedHashMap<>();
        route.put("id", name);
        route.put("name", name);
        route.put("path", path);
        route.put("component", "layout.base$view." + component);
        Map<String, Object> meta = new LinkedHashMap<>();
        meta.put("title", name);
        meta.put("icon", icon);
        meta.put("roles", roles);
        route.put("meta", meta);
        return route;
    }
}
