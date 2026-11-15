# Detox

Una app de macOS para tu detox de dopamina. Eliges qué bloquear (Instagram, YouTube, WhatsApp, cualquier web o app), a qué horas y entre qué fechas. Mientras dura, el compromiso solo puede ir a más. Si intentas entrar, en vez de la web te sale uno de tus vídeos o una pausa para respirar.

## Instalar

Necesitas Xcode (ya lo tienes). En una terminal, dentro de esta carpeta:

```bash
scripts/build.sh
```

```bash
sudo scripts/install.sh
```

El segundo paso pide tu contraseña de administrador: instala el servicio que hace cumplir los bloqueos y la app de la barra de menú. Al abrirse por primera vez, Detox te pedirá permiso para controlar Safari y Chrome (para detener las pestañas bloqueadas sin cerrarlas y saber qué pestaña tienes delante).

## Cómo funciona

- **Bloqueos:** cada uno tiene sus webs, servicios y apps, un horario (por ejemplo 22:30–6:00), los días de la semana en que empieza la franja y unas fechas de inicio y fin, ambas incluidas.
- **Solo puede ir a más:** cuando un bloqueo empieza, puedes añadir webs, alargar fechas o ampliar el horario, pero no suavizarlo.
- **Cerraduras:**
  - **Sin salida:** nada lo desbloquea antes de la fecha final.
  - **Contraseña:** la eliges tú; desbloquear da una pausa (15 min por defecto).
  - **Llave de amigo:** un amigo escanea una vez un QR con su iPhone (app Contraseñas o Google Authenticator). Cuando lo necesites, le llamas y te dicta el código de 6 cifras del momento. Con su código puedes pausar o cancelar el bloqueo. Cada código vale una sola vez.
- **Si gana el más estricto:** si algo está en dos bloqueos, pausar uno no lo libera.
- **Cinco fallos seguidos** de contraseña o código bloquean los intentos durante 10 minutos.
- **La hora de internet manda:** cambiar el reloj del Mac no termina un compromiso.

## Vídeos

Pon tus vídeos (`.mp4`, `.mov` o `.m4v`) en `~/Movies/Detox`, o elige otra carpeta en Ajustes. En cada intento sale uno al azar, a pantalla completa. Si no hay vídeos, sale una pausa de respiración con una frase y la cuenta atrás. La pantalla no se puede cerrar hasta que pasan 60 segundos o acaba el vídeo.

## Límites honestos

- Si eres administrador del Mac, puedes saltártelo con esfuerzo deliberado: la terminal con `sudo`, desactivar el servicio en Ajustes del Sistema › General › Ítems de inicio, el modo de recuperación o una VPN. Detox lo hace incómodo, no imposible.
- No afecta a tu móvil ni a otros dispositivos.
- Si al registrar a tu amigo fotografías tú el QR, te quedas con una copia de su llave.

### Si lo quieres inquebrantable

1. Crea una cuenta de administrador nueva para tu amigo (Ajustes del Sistema › Usuarios y grupos) y que elija él la contraseña.
2. Entra en esa cuenta y, en Usuarios y grupos, quita a tu cuenta el permiso de administrador.
3. Vuelve a tu cuenta. A partir de ahí, desactivar Detox o instalar cosas necesita la contraseña de tu amigo.

## Desinstalar

```bash
sudo scripts/uninstall.sh
```

Se niega mientras haya algún bloqueo en marcha y te dice hasta cuándo. Al desinstalar, `/etc/hosts` queda como estaba.

## Para desarrollo

- `swift test` ejecuta todos los tests.
- `swift run detoxd --root /tmp/dx` arranca el servicio en modo de pruebas: usa un `hosts` y un estado dentro de esa carpeta y no toca el sistema.
- `DETOX_SOCKET=/tmp/dx/detox.sock swift run Detox` abre la app contra ese servicio de pruebas.
- `swift run detox-snapshots <carpeta>` guarda capturas de todas las pantallas con datos de ejemplo.
- Diseño: `docs/superpowers/specs/2026-11-15-detox-mac-design.md`. Plan: `docs/superpowers/plans/2026-11-15-detox-mac.md`.
