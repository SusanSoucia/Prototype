package com.group45.backend.controller;

import com.group45.backend.exception.CustomException;
import com.group45.backend.model.Conversation;
import com.group45.backend.model.ConversationSession;
import com.group45.backend.model.User;
import com.group45.backend.model.UserTokenRecord;
import com.group45.backend.repository.ConversationRepository;
import com.group45.backend.repository.ConversationSessionRepository;
import com.group45.backend.repository.UserRepository;
import com.group45.backend.repository.UserTokenRecordRepository;
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
 * 用户监控控制器，提供管理员查看全员用户信息、对话记录和 Token 用量的接口。
 * <p>
 * 仅 ADMIN 角色可访问。
 */
@RestController
@RequestMapping("/api/v1/admin/monitor")
public class UserMonitorController {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private JwtUtils jwtUtils;

    @Autowired
    private ConversationRepository conversationRepository;

    @Autowired
    private ConversationSessionRepository conversationSessionRepository;

    @Autowired
    private UserTokenRecordRepository userTokenRecordRepository;

    /**
     * 获取用户监控列表（含对话数、Token 用量、最后活跃时间）。
     */
    @GetMapping("/users")
    public ResponseEntity<?> getMonitorUsers(
            @RequestHeader("Authorization") String token,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size) {

        LogUtils.PerformanceMonitor monitor = LogUtils.startPerformanceMonitor("MONITOR_GET_USERS");
        String adminUsername = null;
        try {
            adminUsername = jwtUtils.extractUsernameFromToken(token.replace("Bearer ", ""));
            validateAdmin(adminUsername);

            List<User> allUsers = userRepository.findAll();
            List<Map<String, Object>> monitorUsers = new ArrayList<>();

            for (User user : allUsers) {
                Map<String, Object> userMap = new LinkedHashMap<>();
                userMap.put("id", user.getId());
                userMap.put("userName", user.getUsername());
                userMap.put("role", user.getRole().name());

                // 组织标签
                if (user.getOrgTags() != null && !user.getOrgTags().isEmpty()) {
                    userMap.put("orgTags", Arrays.asList(user.getOrgTags().split(",")));
                } else {
                    userMap.put("orgTags", List.of());
                }

                // 对话数（= 会话数）
                List<ConversationSession> sessions = conversationSessionRepository
                        .findByUserIdOrderByUpdatedAtDesc(user.getId());
                userMap.put("conversationCount", sessions.size());

                // Token 用量（LLM + Embedding 消耗总量）
                long llmTokens = userTokenRecordRepository
                        .sumAmountByUserIdAndTokenTypeAndChangeType(
                                user.getId().toString(),
                                UserTokenRecord.TokenType.LLM,
                                UserTokenRecord.ChangeType.CONSUME);
                long embeddingTokens = userTokenRecordRepository
                        .sumAmountByUserIdAndTokenTypeAndChangeType(
                                user.getId().toString(),
                                UserTokenRecord.TokenType.EMBEDDING,
                                UserTokenRecord.ChangeType.CONSUME);
                Map<String, Long> tokenUsage = new LinkedHashMap<>();
                tokenUsage.put("llm", llmTokens);
                tokenUsage.put("embedding", embeddingTokens);
                userMap.put("tokenUsage", tokenUsage);

                // 最后活跃时间
                if (!sessions.isEmpty()) {
                    userMap.put("lastActiveAt", sessions.get(0).getUpdatedAt().toString());
                } else {
                    userMap.put("lastActiveAt", user.getCreatedAt() != null
                            ? user.getCreatedAt().toString() : null);
                }

                monitorUsers.add(userMap);
            }

            // 分页
            int totalItems = monitorUsers.size();
            int fromIndex = Math.min((page - 1) * size, totalItems);
            int toIndex = Math.min(fromIndex + size, totalItems);
            List<Map<String, Object>> pagedUsers = monitorUsers.subList(fromIndex, toIndex);

            Map<String, Object> result = new LinkedHashMap<>();
            result.put("content", pagedUsers);
            result.put("totalElements", totalItems);
            result.put("totalPages", (int) Math.ceil((double) totalItems / size));
            result.put("number", page);
            result.put("size", size);

            LogUtils.logUserOperation(adminUsername, "MONITOR_GET_USERS", "user_monitor", "SUCCESS");
            monitor.end("获取用户监控列表成功，共 " + totalItems + " 个用户");

            return ResponseEntity.ok(Map.of(
                    "code", 200,
                    "message", "获取用户监控列表成功",
                    "data", result
            ));
        } catch (CustomException e) {
            LogUtils.logBusinessError("MONITOR_GET_USERS", adminUsername, "获取用户监控列表失败: %s", e, e.getMessage());
            monitor.end("获取用户监控列表失败: " + e.getMessage());
            return ResponseEntity.status(e.getStatus())
                    .body(Map.of("code", e.getStatus().value(), "message", e.getMessage()));
        } catch (Exception e) {
            LogUtils.logBusinessError("MONITOR_GET_USERS", adminUsername, "获取用户监控列表异常: %s", e, e.getMessage());
            monitor.end("获取用户监控列表异常: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("code", 500, "message", "服务器内部错误: " + e.getMessage()));
        }
    }

    /**
     * 获取指定用户的对话记录列表。
     */
    @GetMapping("/users/{id}/conversations")
    public ResponseEntity<?> getUserConversations(
            @RequestHeader("Authorization") String token,
            @PathVariable Long id) {

        LogUtils.PerformanceMonitor monitor = LogUtils.startPerformanceMonitor("MONITOR_GET_USER_CONVERSATIONS");
        String adminUsername = null;
        try {
            adminUsername = jwtUtils.extractUsernameFromToken(token.replace("Bearer ", ""));
            validateAdmin(adminUsername);

            User targetUser = userRepository.findById(id)
                    .orElseThrow(() -> new CustomException("用户不存在", HttpStatus.NOT_FOUND));

            // 获取用户所有会话
            List<ConversationSession> sessions = conversationSessionRepository
                    .findByUserIdOrderByUpdatedAtDesc(id);

            List<Map<String, Object>> conversationRecords = new ArrayList<>();
            for (ConversationSession session : sessions) {
                // 统计该会话中的消息数
                List<Conversation> messages = conversationRepository
                        .findByConversationIdOrderByTimestampAsc(session.getConversationId());

                Map<String, Object> record = new LinkedHashMap<>();
                record.put("id", session.getConversationId());
                record.put("title", session.getTitle() != null ? session.getTitle() : "新对话");
                record.put("messageCount", messages.size());
                record.put("createdAt", session.getCreatedAt().toString());
                conversationRecords.add(record);
            }

            LogUtils.logUserOperation(adminUsername, "MONITOR_GET_USER_CONVERSATIONS",
                    "user:" + targetUser.getUsername(), "SUCCESS");
            monitor.end("获取用户对话记录成功，共 " + conversationRecords.size() + " 个会话");

            return ResponseEntity.ok(Map.of(
                    "code", 200,
                    "message", "获取用户对话记录成功",
                    "data", conversationRecords
            ));
        } catch (CustomException e) {
            LogUtils.logBusinessError("MONITOR_GET_USER_CONVERSATIONS", adminUsername,
                    "获取用户对话记录失败: %s", e, e.getMessage());
            monitor.end("获取用户对话记录失败: " + e.getMessage());
            return ResponseEntity.status(e.getStatus())
                    .body(Map.of("code", e.getStatus().value(), "message", e.getMessage()));
        } catch (Exception e) {
            LogUtils.logBusinessError("MONITOR_GET_USER_CONVERSATIONS", adminUsername,
                    "获取用户对话记录异常: %s", e, e.getMessage());
            monitor.end("获取用户对话记录异常: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("code", 500, "message", "服务器内部错误: " + e.getMessage()));
        }
    }

    /**
     * 获取指定用户的 Token 用量明细（按日期）。
     */
    @GetMapping("/users/{id}/tokens")
    public ResponseEntity<?> getUserTokens(
            @RequestHeader("Authorization") String token,
            @PathVariable Long id,
            @RequestParam(defaultValue = "30") int days) {

        LogUtils.PerformanceMonitor monitor = LogUtils.startPerformanceMonitor("MONITOR_GET_USER_TOKENS");
        String adminUsername = null;
        try {
            adminUsername = jwtUtils.extractUsernameFromToken(token.replace("Bearer ", ""));
            validateAdmin(adminUsername);

            User targetUser = userRepository.findById(id)
                    .orElseThrow(() -> new CustomException("用户不存在", HttpStatus.NOT_FOUND));

            String userId = targetUser.getId().toString();

            // 获取最近 N 天的 LLM 和 Embedding 统计
            LocalDate endDate = LocalDate.now();
            LocalDate startDate = endDate.minusDays(days - 1);

            List<com.group45.backend.model.DailyUsageStat> llmStats =
                    userTokenRecordRepository.findDailyUsageStatsByDateRangeAndTokenType(
                            startDate, endDate, UserTokenRecord.TokenType.LLM);

            List<com.group45.backend.model.DailyUsageStat> embeddingStats =
                    userTokenRecordRepository.findDailyUsageStatsByDateRangeAndTokenType(
                            startDate, endDate, UserTokenRecord.TokenType.EMBEDDING);

            // 按日期聚合
            Map<LocalDate, Long> llmByDate = new LinkedHashMap<>();
            Map<LocalDate, Long> embeddingByDate = new LinkedHashMap<>();

            // 注意：findDailyUsageStatsByDateRangeAndTokenType 返回的是全局统计，
            // 需要额外筛选当前用户的记录。这里简化处理，直接从 UserTokenRecord 查。
            // 我们改用 findByUserId 分页查询然后手动聚合。

            // 手动聚合用户 Token 记录
            List<UserTokenRecord> allRecords = new java.util.ArrayList<>();
            int pageIndex = 0;
            int pageSize = 100;
            while (true) {
                var page = userTokenRecordRepository.findByUserIdOrderByRecordDateDesc(
                        userId,
                        org.springframework.data.domain.PageRequest.of(pageIndex, pageSize));
                List<UserTokenRecord> pageRecords = page.getContent().stream()
                        .filter(r -> !r.getRecordDate().isBefore(startDate) && !r.getRecordDate().isAfter(endDate))
                        .toList();
                allRecords.addAll(pageRecords);
                if (page.isLast()) break;
                pageIndex++;
            }

            for (UserTokenRecord record : allRecords) {
                if (record.getChangeType() != UserTokenRecord.ChangeType.CONSUME) continue;
                LocalDate date = record.getRecordDate();
                if (record.getTokenType() == UserTokenRecord.TokenType.LLM) {
                    llmByDate.merge(date, record.getAmount(), Long::sum);
                } else if (record.getTokenType() == UserTokenRecord.TokenType.EMBEDDING) {
                    embeddingByDate.merge(date, record.getAmount(), Long::sum);
                }
            }

            // 构建返回数据（填充所有日期，确保连续）
            List<Map<String, Object>> tokenRecords = new ArrayList<>();
            LocalDate current = startDate;
            while (!current.isAfter(endDate)) {
                Map<String, Object> record = new LinkedHashMap<>();
                record.put("date", current.toString());
                record.put("llmTokens", llmByDate.getOrDefault(current, 0L));
                record.put("embeddingTokens", embeddingByDate.getOrDefault(current, 0L));
                tokenRecords.add(record);
                current = current.plusDays(1);
            }

            LogUtils.logUserOperation(adminUsername, "MONITOR_GET_USER_TOKENS",
                    "user:" + targetUser.getUsername(), "SUCCESS");
            monitor.end("获取用户 Token 明细成功");

            return ResponseEntity.ok(Map.of(
                    "code", 200,
                    "message", "获取用户 Token 用量明细成功",
                    "data", tokenRecords
            ));
        } catch (CustomException e) {
            LogUtils.logBusinessError("MONITOR_GET_USER_TOKENS", adminUsername,
                    "获取用户 Token 明细失败: %s", e, e.getMessage());
            monitor.end("获取用户 Token 明细失败: " + e.getMessage());
            return ResponseEntity.status(e.getStatus())
                    .body(Map.of("code", e.getStatus().value(), "message", e.getMessage()));
        } catch (Exception e) {
            LogUtils.logBusinessError("MONITOR_GET_USER_TOKENS", adminUsername,
                    "获取用户 Token 明细异常: %s", e, e.getMessage());
            monitor.end("获取用户 Token 明细异常: " + e.getMessage());
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
