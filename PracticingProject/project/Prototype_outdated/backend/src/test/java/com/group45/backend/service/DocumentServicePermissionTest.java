package com.group45.backend.service;

import com.group45.backend.exception.CustomException;
import com.group45.backend.model.FileUpload;
import com.group45.backend.model.OrganizationTag;
import com.group45.backend.model.User;
import com.group45.backend.repository.DocumentVectorRepository;
import com.group45.backend.repository.FileUploadRepository;
import com.group45.backend.repository.OrganizationTagRepository;
import com.group45.backend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class DocumentServicePermissionTest {

    private DocumentService documentService;
    private FileUploadRepository fileUploadRepository;
    private UserRepository userRepository;
    private OrganizationTagRepository organizationTagRepository;
    private DocumentVectorRepository documentVectorRepository;
    private ElasticsearchService elasticsearchService;

    @BeforeEach
    void setUp() {
        documentService = new DocumentService();
        fileUploadRepository = mock(FileUploadRepository.class);
        userRepository = mock(UserRepository.class);
        organizationTagRepository = mock(OrganizationTagRepository.class);
        documentVectorRepository = mock(DocumentVectorRepository.class);
        elasticsearchService = mock(ElasticsearchService.class);

        OrgTagCacheService orgTagCacheService = new OrgTagCacheService();
        ReflectionTestUtils.setField(orgTagCacheService, "organizationTagRepository", organizationTagRepository);

        ReflectionTestUtils.setField(documentService, "fileUploadRepository", fileUploadRepository);
        ReflectionTestUtils.setField(documentService, "userRepository", userRepository);
        ReflectionTestUtils.setField(documentService, "organizationTagRepository", organizationTagRepository);
        ReflectionTestUtils.setField(documentService, "documentVectorRepository", documentVectorRepository);
        ReflectionTestUtils.setField(documentService, "elasticsearchService", elasticsearchService);
        ReflectionTestUtils.setField(documentService, "orgTagCacheService", orgTagCacheService);
    }

    @Test
    void parentTagUserCanSeeChildPrivateDocumentsButChildCannotSeeParentPrivateDocuments() {
        User parentUser = user(1L, "parent", User.Role.USER, "engineering");
        User childUser = user(2L, "child", User.Role.USER, "frontend");
        List<FileUpload> allFiles = List.of(
                file("parent-md5", "1", "engineering", false),
                file("child-md5", "3", "frontend", false),
                file("public-md5", "4", "hr", true)
        );

        when(userRepository.findById(1L)).thenReturn(Optional.of(parentUser));
        when(userRepository.findById(2L)).thenReturn(Optional.of(childUser));
        when(organizationTagRepository.findByParentTag("engineering")).thenReturn(List.of(tag("frontend", "engineering")));
        when(organizationTagRepository.findByParentTag("frontend")).thenReturn(List.of());
        when(organizationTagRepository.findByParentTag("hr")).thenReturn(List.of());
        when(fileUploadRepository.findAccessibleFilesWithTags(eq("1"), anyList())).thenAnswer(invocation ->
                accessibleFiles(allFiles, "1", invocation.getArgument(1)));
        when(fileUploadRepository.findAccessibleFilesWithTags(eq("2"), anyList())).thenAnswer(invocation ->
                accessibleFiles(allFiles, "2", invocation.getArgument(1)));

        List<FileUpload> parentVisible = documentService.getAccessibleFiles("1", null);
        List<FileUpload> childVisible = documentService.getAccessibleFiles("2", null);

        assertThat(parentVisible).extracting(FileUpload::getFileMd5)
                .containsExactlyInAnyOrder("parent-md5", "child-md5", "public-md5");
        assertThat(childVisible).extracting(FileUpload::getFileMd5)
                .containsExactlyInAnyOrder("child-md5", "public-md5");
    }

    @Test
    void adminCanSeeAllDocuments() {
        User admin = user(9L, "admin", User.Role.ADMIN, "engineering");
        List<FileUpload> allFiles = List.of(
                file("parent-md5", "1", "engineering", false),
                file("child-md5", "3", "frontend", false),
                file("public-md5", "4", "hr", true)
        );

        when(userRepository.findById(9L)).thenReturn(Optional.of(admin));
        when(fileUploadRepository.findAll()).thenReturn(allFiles);

        List<FileUpload> visible = documentService.getAccessibleFiles("9", null);

        assertThat(visible).extracting(FileUpload::getFileMd5)
                .containsExactlyInAnyOrder("parent-md5", "child-md5", "public-md5");
    }

    @Test
    void updateDocumentOrgTagSynchronizesDocumentVectorsAndElasticsearchMetadata() {
        FileUpload file = file("abc123", "1", "old-tag", false);

        when(organizationTagRepository.existsByTagId("engineering")).thenReturn(true);
        when(fileUploadRepository.findAllByFileMd5("abc123")).thenReturn(new ArrayList<>(List.of(file)));
        when(documentVectorRepository.updatePermissionMetadataByFileMd5("abc123", "engineering", false)).thenReturn(2);

        FileUpload updated = documentService.updateDocumentOrgTag("abc123", "engineering");

        assertThat(updated.getOrgTag()).isEqualTo("engineering");
        verify(fileUploadRepository).saveAll(anyList());
        verify(documentVectorRepository).updatePermissionMetadataByFileMd5("abc123", "engineering", false);
        verify(elasticsearchService).updatePermissionMetadataByFileMd5("abc123", "engineering", false);
    }

    @Test
    void updateDocumentOrgTagRejectsUnknownTag() {
        when(organizationTagRepository.existsByTagId("missing")).thenReturn(false);

        assertThatThrownBy(() -> documentService.updateDocumentOrgTag("abc123", "missing"))
                .isInstanceOf(CustomException.class)
                .hasMessage("Organization tag not found");
    }

    @Test
    void updateDocumentVisibilitySynchronizesDocumentVectorsAndElasticsearchMetadata() {
        FileUpload file = file("abc123", "1", "engineering", false);

        when(fileUploadRepository.findAllByFileMd5("abc123")).thenReturn(new ArrayList<>(List.of(file)));
        when(documentVectorRepository.updatePermissionMetadataByFileMd5("abc123", "engineering", true)).thenReturn(2);

        FileUpload updated = documentService.updateDocumentVisibility("abc123", true);

        assertThat(updated.isPublic()).isTrue();
        verify(fileUploadRepository).saveAll(anyList());
        verify(documentVectorRepository).updatePermissionMetadataByFileMd5("abc123", "engineering", true);
        verify(elasticsearchService).updatePermissionMetadataByFileMd5("abc123", "engineering", true);
    }

    private List<FileUpload> accessibleFiles(List<FileUpload> allFiles, String userId, List<String> orgTags) {
        return allFiles.stream()
                .filter(file -> userId.equals(file.getUserId())
                        || file.isPublic()
                        || (!file.isPublic() && orgTags.contains(file.getOrgTag())))
                .toList();
    }

    private User user(Long id, String username, User.Role role, String orgTags) {
        User user = new User();
        user.setId(id);
        user.setUsername(username);
        user.setRole(role);
        user.setOrgTags(orgTags);
        return user;
    }

    private OrganizationTag tag(String tagId, String parentTag) {
        OrganizationTag tag = new OrganizationTag();
        tag.setTagId(tagId);
        tag.setParentTag(parentTag);
        return tag;
    }

    private FileUpload file(String fileMd5, String userId, String orgTag, boolean isPublic) {
        FileUpload file = new FileUpload();
        file.setFileMd5(fileMd5);
        file.setUserId(userId);
        file.setOrgTag(orgTag);
        file.setPublic(isPublic);
        file.setStatus(FileUpload.STATUS_COMPLETED);
        return file;
    }
}
