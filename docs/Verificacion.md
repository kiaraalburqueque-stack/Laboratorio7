# Verificación del laboratorio

Fecha: **14 de octubre de 2026**. Entorno local: Windows, JDK 25, Maven 3.9.16 y Chrome. El código se compila para Java 17. El servidor usado para las verificaciones HTTP arrancó con el perfil `demo` (H2 en memoria).

| Verificación | Resultado |
| --- | --- |
| Maven `verify` | Compilación y empaquetado correctos; 32 pruebas, 0 fallos y 0 errores |
| Maven Wrapper | Descarga y ejecución verificadas; paquete ejecutable generado |
| Playwright / Chrome | 6 pruebas aprobadas |
| Colección Postman / Newman | 27 solicitudes, 42 aserciones; 0 fallos |
| JavaScript | Sintaxis comprobada con `node --check` |
| Frontend | Capturas reales de escritorio, sesión manager y móvil |

## Qué se comprobó

- Cada una de las cuatro rutas con invitado, USER, ADMIN y MANAGER.
- Contraseñas originales de la guía rechazadas y cuentas nuevas autenticadas.
- Hashes BCrypt y carga inicial sin duplicación; cambio de contraseña en un usuario existente.
- Rutas anteriores eliminadas, con 404 cuando se consultan autenticadas.
- Perfil autenticado sin exponer la contraseña; recursos del frontend accesibles sin login.
- Formulario de login, credenciales incorrectas, reintento, permisos de los tres roles y logout.
- Credenciales ausentes de localStorage/sessionStorage; recargar elimina la sesión del frontend.
- Vista móvil de 390 × 844 sin desbordamiento horizontal.

## Evidencias

- [Resultado de JUnit](evidencias/junit.txt).
- [Resumen y estados reales de Newman](evidencias/postman-resumen.json).
- [Escritorio](capturas/escritorio.png), [manager con respuesta de reportes](capturas/manager.png) y [móvil](capturas/movil.png).

La colección se ejecutó mediante Newman, el ejecutor de colecciones Postman; no se afirma haber usado la interfaz gráfica de Postman. MySQL y Docker quedan configurados, pero no se ejecutaron en este equipo. La verificación de H2 no sustituye una prueba específica de MySQL.

## Reproducción

Terminal 1:

```powershell
.\mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=demo"
```

Terminal 2:

```powershell
.\mvnw.cmd verify
npm.cmd ci
npx.cmd playwright install chromium
npm.cmd run test:e2e
npm.cmd run test:api
```

Para repetir las comprobaciones con MySQL, inicia sin el perfil `demo` y configura las variables de conexión descritas en el README; las pruebas de navegador y Newman consultan el servidor que esté escuchando en `localhost:8080`.
