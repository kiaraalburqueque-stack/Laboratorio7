# Verificación del laboratorio

Fecha: **14 de octubre de 2026**. Entorno local: Windows, JDK 25, Maven 3.9.16, Chrome y **MySQL Community 8.4.11**. El código se compila para Java 17. Las verificaciones finales HTTP usaron MySQL en `127.0.0.1:3307`, base `securitydb`; las pruebas del backend usaron `securitydb_test`.

| Verificación | Resultado |
| --- | --- |
| Maven `verify` con MySQL | Compilación y empaquetado correctos; 32 pruebas, 0 fallos y 0 errores |
| Maven Wrapper | Descarga y ejecución verificadas; paquete ejecutable generado |
| Playwright / Chrome | 6 pruebas aprobadas |
| Colección Postman / Newman | 27 solicitudes, 42 aserciones; 0 fallos |
| JavaScript | Sintaxis comprobada con `node --check` |
| Frontend | Capturas reales de escritorio, sesión manager y móvil |
| Persistencia MySQL | Tres usuarios y tres roles conservados tras detener y reiniciar ambos procesos |
| Arranque completo | MySQL y aplicación inician juntos; una segunda ejecución reconoce la instancia existente |

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
- [Resultado de JUnit con MySQL](evidencias/junit-mysql.txt).
- [Versión, tablas, cuentas y persistencia de MySQL](evidencias/mysql.txt).
- [Resumen y estados reales de Newman](evidencias/postman-resumen.json).
- [Escritorio](capturas/escritorio.png), [manager con respuesta de reportes](capturas/manager.png) y [móvil](capturas/movil.png).

La colección se ejecutó mediante Newman, el ejecutor de colecciones Postman; no se afirma haber usado la interfaz gráfica de Postman. Backend, navegador y colección se comprobaron con MySQL real. Docker es una alternativa opcional no ejecutada; no se necesita para el arranque portable verificado.

## Reproducción

Terminal 1:

```powershell
.\scripts\start-lab.cmd
```

Terminal 2:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-mysql.ps1
npm.cmd ci
npx.cmd playwright install chromium
npm.cmd run test:e2e
npm.cmd run test:api
```

Desde Git Bash, el arranque equivalente es `cmd.exe //c scripts\\start-lab.cmd`. Las pruebas de navegador y Newman consultan el servidor que esté escuchando en `localhost:8080`. Para detener MySQL y la aplicación usa `scripts/stop-lab.cmd`; el próximo arranque reutiliza los datos.
