# Traspaso · Detox (15 nov 2026)

## Estado

- Rama `feature/detox-mac`: tareas 1–15 del plan (`docs/superpowers/plans/2026-11-15-detox-mac.md`) hechas, 184 tests en verde, revisión de código final y revisión de diseño aplicadas. Nada fusionado en `main` ni subido.
- **Instalado en este Mac** (15 nov, 16:38): `com.detox.daemon` corriendo como root, socket `/var/run/detox.sock` responde, `isTrustedTime: true`, app en la barra de menú. Sin bloqueos creados.
- Registro de avance y decisiones: `.superpowers/sdd/2026-11-15-detox-mac/progress.md` (líneas `Ruling:` y `minor (deferred)`).

## Siguiente: tarea 16, pruebas en el Mac

Usar **solo bloqueos con Contraseña**, fechas de hoy y franja que incluya ahora. Pasos del plan, ninguno hecho todavía:

1. Onboarding: conceder Automatización a Safari y Chrome.
2. Crear bloqueo Instagram + YouTube + WhatsApp → `grep -c DETOX /etc/hosts` = 2; `curl -sS -m 5 https://www.instagram.com` falla.
3. Safari y Chrome: aparece la pantalla, no se cierra antes de 60 s. Si Safari carga pese a hosts → plan B del spec §7.3.
4. Vídeo de YouTube en reproducción se cierra al empezar la franja.
5. Web con píxel de Facebook / YouTube incrustado → sin pantalla.
6. WhatsApp.app se cierra en ≤ 2 s.
7. Borrar la sección de `/etc/hosts` → vuelve en ≤ 2 s; `sudo pfctl -a com.apple/detox -F all` → vuelve en ≤ 30 s. Comprobar `sudo pfctl -sr` (que el anchor se evalúa).
8. `chrome://policy` muestra `DnsOverHttpsMode = off`; si no, probar `/Library/Preferences/com.google.Chrome.plist`.
9. Private Relay (si hay iCloud+) y DNS seguro de Chrome con Cloudflare.
10. Gmail/Drive/Google funcionan con YouTube bloqueado.
11. Reiniciar → sigue bloqueando.
12. Adelantar el reloj 3 días → no termina el bloque.
13. Desbloquear con contraseña (pausa 15 min, al acabar se cierran pestañas); amigo con el iPhone del propio usuario → cancelar.
14. `sudo scripts/uninstall.sh` se niega con bloque en marcha; sin bloques, desinstala limpio.

Abierto de la revisión de diseño: **comprobar con una captura real** que la barra de título y la selección de la barra lateral salen en azul noche / oro (offscreen no se puede).

Después: `superpowers:finishing-a-development-branch` (fusionar o PR), borrar `.superpowers/sdd/2026-11-15-detox-mac/`.

## Comandos útiles

```bash
printf '{"status":{}}\n' | nc -U -w 2 /var/run/detox.sock
```

```bash
tail -f /Library/Logs/Detox/detoxd.err.log
```

Recompilar e instalar tras cambios: `scripts/build.sh` y luego `sudo scripts/install.sh` (lanzarlo en un panel de Terminal para que el usuario escriba la contraseña).
