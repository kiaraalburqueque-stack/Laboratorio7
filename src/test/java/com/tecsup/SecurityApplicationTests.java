package com.tecsup;

import com.tecsup.model.User;
import com.tecsup.repository.RoleRepository;
import com.tecsup.repository.UserRepository;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.httpBasic;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("demo")
class SecurityApplicationTests {
    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired RoleRepository roles;
    @Autowired PasswordEncoder encoder;
    @Autowired CommandLineRunner initData;

    static Stream<Arguments> accessMatrix() {
        String[] paths = {"/api/free", "/client/home", "/management/dashboard", "/manager/reportes"};
        String[] names = {null, "user", "admin", "manager"};
        String[] passwords = {null, "UsuarioS07!2026", "AdminS07!2026", "ManagerS07!2026"};
        int[][] expected = {{200, 401, 401, 401}, {200, 200, 403, 403},
                {200, 200, 200, 200}, {200, 403, 403, 200}};
        var results = Stream.<Arguments>builder();
        for (int person = 0; person < names.length; person++) {
            for (int path = 0; path < paths.length; path++) {
                results.add(Arguments.of(paths[path], names[person], passwords[person], expected[person][path]));
            }
        }
        return results.build();
    }

    @ParameterizedTest(name = "{1} -> {0}: {3}")
    @MethodSource("accessMatrix")
    void enforcesAccessByRole(String path, String username, String password, int expected) throws Exception {
        var request = get(path);
        if (username != null) request.with(httpBasic(username, password));
        mvc.perform(request).andExpect(status().is(expected));
    }

    static Stream<Arguments> invalidCredentials() {
        return Stream.of(Arguments.of("user", "1234"), Arguments.of("admin", "123456"),
                Arguments.of("manager", "incorrecta"), Arguments.of("desconocido", "incorrecta"));
    }

    @ParameterizedTest
    @MethodSource("invalidCredentials")
    void rejectsOldOrInvalidPasswords(String username, String password) throws Exception {
        mvc.perform(get("/client/home").with(httpBasic(username, password)))
                .andExpect(status().isUnauthorized());
    }

    @ParameterizedTest
    @ValueSource(strings = {"/public/hello", "/user/dashboard", "/admin/panel"})
    void oldRoutesAreRemoved(String path) throws Exception {
        mvc.perform(get(path).with(httpBasic("admin", "AdminS07!2026")))
                .andExpect(status().isNotFound());
    }

    @Test
    void returnsExpectedMessages() throws Exception {
        mvc.perform(get("/api/free")).andExpect(content().string("Endpoint público funcionando"));
        mvc.perform(get("/client/home").with(httpBasic("user", "UsuarioS07!2026")))
                .andExpect(content().string("Bienvenido USER"));
        mvc.perform(get("/management/dashboard").with(httpBasic("admin", "AdminS07!2026")))
                .andExpect(content().string("Bienvenido ADMIN"));
        mvc.perform(get("/manager/reportes").with(httpBasic("manager", "ManagerS07!2026")))
                .andExpect(content().string("Reportes disponibles para MANAGER"));
    }

    @Test
    void profileRequiresAuthentication() throws Exception {
        mvc.perform(get("/api/me")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/me").with(httpBasic("manager", "ManagerS07!2026")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username").value("manager"))
                .andExpect(jsonPath("$.roles[0]").value("ROLE_MANAGER"))
                .andExpect(jsonPath("$.password").doesNotExist());
    }

    @ParameterizedTest
    @ValueSource(strings = {"/", "/index.html", "/assets/styles.css", "/assets/app.js", "/favicon.svg"})
    void frontendIsAvailableWithoutLogin(String path) throws Exception {
        mvc.perform(get(path)).andExpect(status().isOk());
    }

    @Test
    void savesBcryptPasswordsAndOneRolePerUser() {
        String[][] accounts = {{"user", "UsuarioS07!2026", "ROLE_USER"},
                {"admin", "AdminS07!2026", "ROLE_ADMIN"},
                {"manager", "ManagerS07!2026", "ROLE_MANAGER"}};
        for (String[] account : accounts) {
            User user = users.findByUsername(account[0]).orElseThrow();
            assertThat(user.getPassword()).startsWith("$2").isNotEqualTo(account[1]);
            assertThat(encoder.matches(account[1], user.getPassword())).isTrue();
            assertThat(user.getRoles()).extracting(role -> role.getName()).containsExactly(account[2]);
        }
    }

    @Test
    void loaderIsIdempotentAndUpdatesExistingPasswords() throws Exception {
        User user = users.findByUsername("user").orElseThrow();
        String originalHash = user.getPassword();
        initData.run();
        assertThat(users.findByUsername("user").orElseThrow().getPassword()).isEqualTo(originalHash);
        user.setPassword(encoder.encode("1234"));
        users.save(user);
        initData.run();
        assertThat(users.count()).isEqualTo(3);
        assertThat(roles.count()).isEqualTo(3);
        assertThat(encoder.matches("UsuarioS07!2026",
                users.findByUsername("user").orElseThrow().getPassword())).isTrue();
    }
}
