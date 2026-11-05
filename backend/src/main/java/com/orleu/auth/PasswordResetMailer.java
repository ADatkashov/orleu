package com.orleu.auth;

/**
 * Delivers the password-reset link/token to the user. Real e-mail/SMS providers are NOT implemented
 * (they need provider accounts); implement this interface and register the bean to enable delivery.
 */
public interface PasswordResetMailer {
    void send(String email, String token);
}
