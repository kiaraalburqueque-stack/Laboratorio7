package com.tecsup.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class AdminController {
    @GetMapping("/management/dashboard")
    public String dashboard() { return "Bienvenido ADMIN"; }
}
