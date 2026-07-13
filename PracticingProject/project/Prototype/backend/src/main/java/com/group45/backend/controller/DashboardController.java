package com.group45.backend.controller;

import com.group45.backend.exception.CustomException;
import com.group45.backend.model.User;
import com.group45.backend.model.UserTokenRecord;
import com.group45.backend.repository.UserRepository;
import com.group45.backend.service.UsageQuotaService;
import com.group45.backend.service.UserTokenService;
import com.group45.backend.utils.JwtUtils;
import com.group45.backend.utils.LogUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

/**
 * API 用量仪表盘控制器，提供 Token 用量统计、用户排名和配额告警接口。
 * <p>
 * 仅 ADMIN 角色可访问。
 */
@RestController
@RequestMapping("/api/v1/admin/dashboard")
public class DashboardController {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private JwtUtils jwtUtils;

    @Autowired
    private UserTokenService userTokenService;

    @Autowired
    private UsageQuotaService usageQuotaService;

    /**
     * 获取用量摘要（今日/本周 LLM + Embedding + 配额信息）。
     */
    @GetMapping("/usage")
    public ResponseEntity<?> getUsageSummary(@RequestHeader("Authorization") String token) {
        LogUtils.PerformanceMonitor monitor = LogUtils.startPerformanceMonitor("DASHBOARD_GET_USAGE");
        String adminUsername = null;
        try {
            adminUsername = jwtUtils.extractUsernameFromToken(token.replace("Bearer ", ""));
            validateAdmin(adminUsername);

            LocalDate today = LocalDate.now();
            LocalDate weekStart = today.minusDays(6); // 最近 7 天（含今天）

            // 获取全局每日统计数据
            List<com.group45.backend.model.DailyUsageStat> llmStats =
                    userTokenService.getDailyStatsByType(
                            weekStart, today, UserTokenRecord.TokenType.LLM);
            List<com.group45.backend.model.DailyUsageStat> embeddingStats =
                    userTokenService.getDailyStatsByType(
                            weekStart, today, UserTokenRecord.TokenType.EMBEDDING);

            // 计算今日用量
            long todayLLM = llmStats.stream()
                    .filter(s -> s.recordDate().equals(today))
                    .mapToLong(com.group45.backend.model.DailyUsageStat::totalAmount)
                    .sum();
            long todayEmbedding = embeddingStats.stream()
                    .filter(s -> s.recordDate().equals(today))
                    .mapToLong(com.group45.backend.model.DailyUsageStat::totalAmount)
                    .sum();

            // 计算本周用量
            long weekLLM = llmStats.stream()
                    .mapToLong(com.group45.backend.model.DailyUsageStat::totalAmount)
                    .sum();
            long weekEmbedding = embeddingStats.stream()
                    .mapToLong(com.group45.backend.model.DailyUsageStat::totalAmount)
                    .sum();

            // 获取所有用户的配额快照并汇总
            List<User> allUsers = userRepository.findAll();
            List<String> allUserIds = allUsers.stream()
                    .map(u -> u.getId().toString())
                    .toList();

            Map<String, UsageQuotaService.UserUsageSnapshot> snapshots =
                    usageQuotaService.getSnapshots(allUserIds);

            long quotaTotal = 0;
            long quotaUsed = 0;
            for (var snapshot : snapshots.values()) {
                if (snapshot.llm().enabled()) {
                    quotaTotal += snapshot.llm().limitTokens();
                    quotaUsed += snapshot.llm().usedTokens();
                }
                if (snapshot.embedding().enabled()) {
                    quotaTotal += snapshot.embedding().limitTokens();
                    quotaUsed += snapshot.embedding().usedTokens();
                }
            }

            int quotaRemainingPercent = quotaTotal > 0
                    ? (int) Math.max(0, 100 - (quotaUsed * 100 / quotaTotal))
                    : 100;

            Map<String, Object> data = new LinkedHashMap<>();
            data.put("todayLLM", todayLLM);
            data.put("todayEmbedding", todayEmbedding);
            data.put("weekLLM", weekLLM);
            data.put("weekEmbedding", weekEmbedding);
            data.put("quotaTotal", quotaTotal);
            data.put("quotaUsed", quotaUsed);
            data.put("quotaRemainingPercent", quotaRemainingPercent);

            LogUtils.logUserOperation(adminUsername, "DASHBOARD_GET_USAGE", "usage_summary", "SUCCESS");
            monitor.end("获取用量摘要成功");

            return ResponseEntity.ok(Map.of(
                    "code", 200,
                    "message", "获取用量摘要成功",
                    "data", data
            ));
        } catch (CustomException e) {
            LogUtils.logBusinessError("DASHBOARD_GET_USAGE", adminUsername,
                    "获取用量摘要失败: %s", e, e.getMessage());
            monitor.end("获取用量摘要失败: " + e.getMessage());
            return ResponseEntity.status(e.getStatus())
                    .body(Map.of("code", e.getStatus().value(), "message", e.getMessage()));
        } catch (Exception e) {
            LogUtils.logBusinessError("DASHBOARD_GET_USAGE", adminUsername,
                    "获取用量摘要异常: %s", e, e.getMessage());
            monitor.end("获取用量摘要异常: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("code", 500, "message", "服务器内部错误: " + e.getMessage()));
        }
    }

    /**
     * 获取用户 Token 用量排行。
     */
    @GetMapping("/rankings")
    public ResponseEntity<?> getRankings(
            @RequestHeader("Authorization") String token,
            @RequestParam(defaultValue = "10") int limit) {

        LogUtils.PerformanceMonitor monitor = LogUtils.startPerformanceMonitor("DASHBOARD_GET_RANKINGS");
        String adminUsername = null;
        try {
            adminUsername = jwtUtils.extractUsernameFromToken(token.replace("Bearer ", ""));
            validateAdmin(adminUsername);

            int safeLimit = Math.min(limit, 50);

            // 获取 LLM 和 Embedding 消费排行
            List<UserTokenRecord> llmTop = userTokenService.getTodayTopConsumers(
                    UserTokenRecord.TokenType.LLM, safeLimit);
            List<UserTokenRecord> embeddingTop = userTokenService.getTodayTopConsumers(
                    UserTokenRecord.TokenType.EMBEDDING, safeLimit);

            // 按 totalTokens 聚合排名
            Map<String, Long> userTotalTokens = new LinkedHashMap<>();
            for (UserTokenRecord r : llmTop) {
                userTotalTokens.merge(r.getUserId(), r.getAmount(), Long::sum);
            }
            for (UserTokenRecord r : embeddingTop) {
                userTotalTokens.merge(r.getUserId(), r.getAmount(), Long::sum);
            }

            // 获取用户信息并构建排行
            List<Map<String, Object>> rankings = new ArrayList<>();
            List<Map.Entry<String, Long>> sorted = userTotalTokens.entrySet().stream()
                    .sorted(Map.Entry.<String, Long>comparingByValue().reversed())
                    .limit(safeLimit)
                    .toList();

            for (var entry : sorted) {
                Optional<User> userOpt = userRepository.findById(Long.parseLong(entry.getKey()));
                if (userOpt.isEmpty()) continue;

                User user = userOpt.get();
                Map<String, Object> ranking = new LinkedHashMap<>();
                ranking.put("userName", user.getUsername());
                ranking.put("role", user.getRole().name());
                ranking.put("totalTokens", entry.getValue());
                ranking.put("conversationCount",
                        userTokenService.getUserTotalRequestCount("llm", entry.getKey()));
                rankings.add(ranking);
            }

            LogUtils.logUserOperation(adminUsername, "DASHBOARD_GET_RANKINGS", "rankings", "SUCCESS");
            monitor.end("获取用量排行成功，共 " + rankings.size() + " 条");

            return ResponseEntity.ok(Map.of(
                    "code", 200,
                    "message", "获取用量排行成功",
                    "data", rankings
            ));
        } catch (CustomException e) {
            LogUtils.logBusinessError("DASHBOARD_GET_RANKINGS", adminUsername,
                    "获取用量排行失败: %s", e, e.getMessage());
            monitor.end("获取用量排行失败: " + e.getMessage());
            return ResponseEntity.status(e.getStatus())
                    .body(Map.of("code", e.getStatus().value(), "message", e.getMessage()));
        } catch (Exception e) {
            LogUtils.logBusinessError("DASHBOARD_GET_RANKINGS", adminUsername,
                    "获取用量排行异常: %s", e, e.getMessage());
            monitor.end("获取用量排行异常: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("code", 500, "message", "服务器内部错误: " + e.getMessage()));
        }
    }

    /**
     * 获取配额告警列表。
     */
    @GetMapping("/alerts")
    public ResponseEntity<?> getAlerts(@RequestHeader("Authorization") String token) {
        LogUtils.PerformanceMonitor monitor = LogUtils.startPerformanceMonitor("DASHBOARD_GET_ALERTS");
        String adminUsername = null;
        try {
            adminUsername = jwtUtils.extractUsernameFromToken(token.replace("Bearer ", ""));
            validateAdmin(adminUsername);

            List<Map<String, Object>> alerts = new ArrayList<>();

            // 检查 LLM Token 余额不足的用户
            List<UserTokenRecord> lowLlmUsers = userTokenService.getLowBalanceUsers(
                    UserTokenRecord.TokenType.LLM, 1000L);
            for (UserTokenRecord record : lowLlmUsers) {
                Optional<User> userOpt = userRepository.findById(Long.parseLong(record.getUserId()));
                String userName = userOpt.map(User::getUsername).orElse(record.getUserId());
                Map<String, Object> alert = new LinkedHashMap<>();
                alert.put("type", record.getBalanceAfter() <= 0 ? "error" : "warning");
                alert.put("message", "用户 " + userName + " LLM Token 余额不足（剩余: "
                        + record.getBalanceAfter() + "）");
                alert.put("time", record.getCreatedAt() != null
                        ? record.getCreatedAt().toString() : LocalDate.now().toString());
                alerts.add(alert);
            }

            // 检查 Embedding Token 余额不足的用户
            List<UserTokenRecord> lowEmbeddingUsers = userTokenService.getLowBalanceUsers(
                    UserTokenRecord.TokenType.EMBEDDING, 1000L);
            for (UserTokenRecord record : lowEmbeddingUsers) {
                Optional<User> userOpt = userRepository.findById(Long.parseLong(record.getUserId()));
                String userName = userOpt.map(User::getUsername).orElse(record.getUserId());
                Map<String, Object> alert = new LinkedHashMap<>();
                alert.put("type", record.getBalanceAfter() <= 0 ? "error" : "warning");
                alert.put("message", "用户 " + userName + " Embedding Token 余额不足（剩余: "
                        + record.getBalanceAfter() + "）");
                alert.put("time", record.getCreatedAt() != null
                        ? record.getCreatedAt().toString() : LocalDate.now().toString());
                alerts.add(alert);
            }

            // 如果无告警，返回空列表加一条正常状态
            if (alerts.isEmpty()) {
                Map<String, Object> okAlert = new LinkedHashMap<>();
                okAlert.put("type", "info");
                okAlert.put("message", "所有用户 Token 配额正常");
                okAlert.put("time", LocalDate.now().toString());
                alerts.add(okAlert);
            }

            LogUtils.logUserOperation(adminUsername, "DASHBOARD_GET_ALERTS", "alerts", "SUCCESS");
            monitor.end("获取配额告警成功，共 " + alerts.size() + " 条");

            return ResponseEntity.ok(Map.of(
                    "code", 200,
                    "message", "获取配额告警成功",
                    "data", alerts
            ));
        } catch (CustomException e) {
            LogUtils.logBusinessError("DASHBOARD_GET_ALERTS", adminUsername,
                    "获取配额告警失败: %s", e, e.getMessage());
            monitor.end("获取配额告警失败: " + e.getMessage());
            return ResponseEntity.status(e.getStatus())
                    .body(Map.of("code", e.getStatus().value(), "message", e.getMessage()));
        } catch (Exception e) {
            LogUtils.logBusinessError("DASHBOARD_GET_ALERTS", adminUsername,
                    "获取配额告警异常: %s", e, e.getMessage());
            monitor.end("获取配额告警异常: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("code", 500, "message", "服务器内部错误: " + e.getMessage()));
        }
    }

    /**
     * 验证用户是否为管理员（仅 ADMIN）。
     */
    private User validateAdmin(String username) {
        if (username == null || username.isEmpty()) {
            throw new CustomException("Invalid token", HttpStatus.UNAUTHORIZED);
        }

        User admin = userRepository.findByUsername(username)
                .orElseThrow(() -> new CustomException("User not found", HttpStatus.NOT_FOUND));

        if (admin.getRole() != User.Role.ADMIN) {
            throw new CustomException("Unauthorized access: Admin role required", HttpStatus.FORBIDDEN);
        }

        return admin;
    }
}
