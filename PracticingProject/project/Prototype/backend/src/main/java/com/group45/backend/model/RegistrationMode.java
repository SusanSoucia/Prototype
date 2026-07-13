package com.group45.backend.model;

/**
 * 用户注册模式
 */
public enum RegistrationMode {
    /** 开放注册，任何人可注册 */
    OPEN,
    /** 仅限邀请，需要邀请码 */
    INVITE_ONLY,
    /** 关闭注册 */
    CLOSED
}
