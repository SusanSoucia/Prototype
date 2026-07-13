package com.group45.backend.controller;

import com.group45.backend.exception.CustomException;
import com.group45.backend.model.FileUpload;
import com.group45.backend.model.User;
import com.group45.backend.repository.UserRepository;
import com.group45.backend.service.DocumentService;
import com.group45.backend.utils.JwtUtils;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AdminDocumentPermissionControllerTest {

    private AdminController adminController;
    private JwtUtils jwtUtils;
    private UserRepository userRepository;
    private DocumentService documentService;

    @BeforeEach
    void setUp() {
        adminController = new AdminController();
        jwtUtils = mock(JwtUtils.class);
        userRepository = mock(UserRepository.class);
        documentService = mock(DocumentService.class);

        ReflectionTestUtils.setField(adminController, "jwtUtils", jwtUtils);
        ReflectionTestUtils.setField(adminController, "userRepository", userRepository);
        ReflectionTestUtils.setField(adminController, "documentService", documentService);
    }

    @Test
    void updateDocumentOrgTagRejectsNonAdmin() {
        User user = user("alice", User.Role.USER);
        when(jwtUtils.extractUsernameFromToken("token")).thenReturn("alice");
        when(userRepository.findByUsername("alice")).thenReturn(Optional.of(user));

        ResponseEntity<?> response = adminController.updateDocumentOrgTag(
                "Bearer token",
                "abc123",
                new DocumentOrgTagUpdateRequest("engineering")
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(responseBody(response)).containsEntry("code", 403);
    }

    @Test
    void updateDocumentVisibilityCallsServiceForAdmin() {
        User admin = user("admin", User.Role.ADMIN);
        FileUpload updated = new FileUpload();
        updated.setFileMd5("abc123");
        updated.setPublic(true);

        when(jwtUtils.extractUsernameFromToken("token")).thenReturn("admin");
        when(userRepository.findByUsername("admin")).thenReturn(Optional.of(admin));
        when(documentService.updateDocumentVisibility("abc123", true)).thenReturn(updated);

        ResponseEntity<?> response = adminController.updateDocumentVisibility(
                "Bearer token",
                "abc123",
                new DocumentVisibilityUpdateRequest(true)
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        verify(documentService).updateDocumentVisibility("abc123", true);
    }

    @Test
    void updateDocumentVisibilityMapsDocumentNotFound() {
        User admin = user("admin", User.Role.ADMIN);

        when(jwtUtils.extractUsernameFromToken("token")).thenReturn("admin");
        when(userRepository.findByUsername("admin")).thenReturn(Optional.of(admin));
        when(documentService.updateDocumentVisibility("missing", true))
                .thenThrow(new CustomException("Document not found", HttpStatus.NOT_FOUND));

        ResponseEntity<?> response = adminController.updateDocumentVisibility(
                "Bearer token",
                "missing",
                new DocumentVisibilityUpdateRequest(true)
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(responseBody(response)).containsEntry("code", 404);
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> responseBody(ResponseEntity<?> response) {
        return (Map<String, Object>) response.getBody();
    }

    private User user(String username, User.Role role) {
        User user = new User();
        user.setUsername(username);
        user.setRole(role);
        return user;
    }
}
