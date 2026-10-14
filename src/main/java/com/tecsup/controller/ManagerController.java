package com.tecsup.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class ManagerController {
    @GetMapping("/manager/reportes")
    public String reportes() { return "Reportes disponibles para MANAGER"; }
}
