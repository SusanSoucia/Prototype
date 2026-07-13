package com.group45.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "app.auth")
public class AppAuthProperties {

    private final Registration registration = new Registration();

    public Registration getRegistration() {
        return registration;
    }

    public static class Registration {
        private boolean inviteRequired = true;

        public boolean isInviteRequired() {
            return inviteRequired;
        }

        public void setInviteRequired(boolean inviteRequired) {
            this.inviteRequired = inviteRequired;
        }
    }
}
