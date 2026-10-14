# Laboratorio 07: Implementación de seguridad básica

**Estudiante:** Kiara Alburqueque  
**Curso:** Desarrollo de aplicaciones Web Avanzado  
**Fecha:** 14 de octubre de 2026  
**Repositorio:** https://github.com/kiaraalburqueque-stack/Laboratorio7

## Objetivo

Implementar autenticación y autorización por roles mediante Spring Security, persistir usuarios y roles, proteger contraseñas con BCrypt y comprobar los permisos mediante solicitudes HTTP. Se agregó un frontend integrado para realizar las mismas comprobaciones desde el navegador.

## Desarrollo de la actividad

1. Se creó un proyecto Maven con Java 17 como versión objetivo, Spring Boot 3.5.6, Spring Web, Spring Security, Spring Data JPA y el controlador de MySQL. H2 se usa exclusivamente en el perfil opcional de demostración y en las pruebas locales.
2. Se implementaron las entidades `User` y `Role`, relacionadas mediante la tabla `user_roles`, y los repositorios para buscar usuarios y roles por nombre. Las tablas se llaman `users` y `roles` para evitar conflictos con palabras reservadas.
3. `UserDetailsServiceImpl` consulta al usuario en la base de datos y convierte sus roles en autoridades de Spring Security.
4. Se cambiaron las rutas: `/admin/panel` pasó a `/management/dashboard`, `/user/dashboard` a `/client/home` y `/public/hello` a `/api/free`. Se actualizaron tanto los controladores como la configuración de seguridad.
5. Se creó `ROLE_MANAGER`, el usuario `manager` y el endpoint `/manager/reportes`. Se permitió el acceso a reportes a `MANAGER` y `ADMIN`; `MANAGER` no recibió permisos administrativos ni de cliente. Esta es una decisión explícita porque la actividad no especifica una jerarquía para el rol nuevo.
6. Se cambiaron las contraseñas de los usuarios: `user` utiliza `UsuarioS07!2026`, `admin` utiliza `AdminS07!2026` y `manager` utiliza `ManagerS07!2026`. Son claves de demostración. BCrypt almacena sus hashes; no se guardan en texto plano en las tablas.
7. El cargador inicial actualiza también las cuentas existentes del laboratorio cuando cambia la clave configurada y evita duplicar usuarios y roles al reiniciar. Se comprobó que las claves originales `1234` y `123456` se rechazan.
8. Se implementó un frontend adaptable con login, cierre de sesión, tarjetas de acceso y un historial de respuestas. `GET /api/me` devuelve exclusivamente el usuario autenticado y sus roles. Las credenciales del frontend se mantienen solo en memoria.
9. Se preparó una colección de Postman con 27 solicitudes para probar acceso público, autorizado, denegado, contraseñas inválidas y rutas anteriores eliminadas.

## Resultados esperados y comprobados

| Endpoint | Sin credenciales | USER | ADMIN | MANAGER |
| --- | --- | --- | --- | --- |
| `/api/free` | 200 | 200 | 200 | 200 |
| `/client/home` | 401 | 200 | 200 | 403 |
| `/management/dashboard` | 401 | 403 | 200 | 403 |
| `/manager/reportes` | 401 | 403 | 200 | 200 |

Las pruebas locales del backend y del navegador confirmaron la matriz anterior usando H2. Se ejecutaron 32 pruebas de backend y 6 pruebas de navegador sin fallos. Los resultados de la colección Postman ejecutada con Newman se registran en `docs/Verificacion.md`. No se atribuyen estos resultados a una ejecución gráfica en Postman.

MySQL se configura mediante `application.properties` y el script `sql/01-create-database.sql`. Como no había un servidor MySQL activo ni Docker disponible en el equipo, la conexión real a MySQL y el arranque con Docker quedan pendientes de comprobar en ese entorno. El perfil H2 permite ejecutar toda la aplicación inmediatamente para la demostración.

## Cinco observaciones

1. El documento repite `SecurityConfig` en dos pasos. Se mantuvo una sola clase para evitar duplicar la configuración y los beans de seguridad.
2. Cambiar únicamente las rutas en los controladores habría dejado reglas de acceso desactualizadas. Se modificaron conjuntamente los controladores, los filtros y las pruebas.
3. `hasRole("MANAGER")` requiere una autoridad denominada `ROLE_MANAGER`; conservar el prefijo en la base de datos evita denegaciones por nombres incompatibles.
4. Crear usuarios solamente cuando no existen no cambia sus contraseñas anteriores. El cargador compara y actualiza los hashes cuando cambia la contraseña configurada, sin duplicar las cuentas.
5. La ausencia de MySQL activo impidió comprobar localmente ese motor. Se separó un perfil H2 para probar autenticación y permisos, y se documentó esta limitación junto con el procedimiento de MySQL.

## Cinco conclusiones

1. La autenticación confirma la identidad del usuario y la autorización determina los recursos permitidos. Las respuestas 401 y 403 permiten verificar esa diferencia.
2. El control de acceso funciona porque se aplica en el backend; ocultar o marcar tarjetas en el frontend sirve para orientar al usuario, pero no sustituye las reglas de Spring Security.
3. BCrypt permite comprobar contraseñas sin almacenar el texto original. Las pruebas confirmaron los hashes y el rechazo de las contraseñas antiguas.
4. La matriz de pruebas por rol detecta tanto accesos permitidos como permisos excesivos. Ejecutarla junto con login, logout y errores del frontend aporta evidencia de que ambas partes están integradas.
5. La separación entre código, configuración, pruebas y documentación facilita reproducir el laboratorio. Para completar la validación específica del motor solicitado se debe ejecutar el mismo proyecto y la colección con MySQL; para un despliegue real también se requiere revisar HTTPS y credenciales de demostración.
