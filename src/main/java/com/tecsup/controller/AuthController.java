package com.tecsup.controller;

import java.util.List;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class AuthController {
    public record Account(String username, List<String> roles) {}

    @GetMapping("/api/me")
    public Account me(Authentication authentication) {
        return new Account(authentication.getName(), authentication.getAuthorities().stream()
                .map(authority -> authority.getAuthority()).sorted().toList());
    }
}
