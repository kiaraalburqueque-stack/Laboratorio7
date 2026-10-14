package com.tecsup.util;

import com.tecsup.model.Role;
import com.tecsup.model.User;
import com.tecsup.repository.RoleRepository;
import com.tecsup.repository.UserRepository;
import java.util.Set;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
public class DataLoader {
    @Bean
    CommandLineRunner initData(UserRepository userRepo, RoleRepository roleRepo,
            PasswordEncoder encoder,
            @Value("${lab.users.user-password}") String userPassword,
            @Value("${lab.users.admin-password}") String adminPassword,
            @Value("${lab.users.manager-password}") String managerPassword) {
        return args -> {
            Role roleUser = findOrCreateRole(roleRepo, "ROLE_USER");
            Role roleAdmin = findOrCreateRole(roleRepo, "ROLE_ADMIN");
            Role roleManager = findOrCreateRole(roleRepo, "ROLE_MANAGER");
            // Sincroniza también usuarios existentes: cambia las claves antiguas del laboratorio.
            synchronizeUser(userRepo, encoder, "user", userPassword, roleUser);
            synchronizeUser(userRepo, encoder, "admin", adminPassword, roleAdmin);
            synchronizeUser(userRepo, encoder, "manager", managerPassword, roleManager);
        };
    }

    private Role findOrCreateRole(RoleRepository repository, String name) {
        return repository.findByName(name).orElseGet(() -> {
            Role role = new Role();
            role.setName(name);
            return repository.save(role);
        });
    }

    private void synchronizeUser(UserRepository repository, PasswordEncoder encoder,
            String username, String password, Role role) {
        User user = repository.findByUsername(username).orElseGet(User::new);
        user.setUsername(username);
        if (user.getPassword() == null || !encoder.matches(password, user.getPassword())) {
            user.setPassword(encoder.encode(password));
        }
        user.setRoles(Set.of(role));
        repository.save(user);
    }
}
