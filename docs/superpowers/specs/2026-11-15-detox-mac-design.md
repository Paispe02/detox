# Detox para Mac — Diseño

Fecha: 2026-11-15 · Estado: borrador para aprobación

## 1. Qué es y por qué

Una app de macOS para hacer *detox* de dopamina. El usuario crea **compromisos de bloqueo**: qué webs y apps bloquear, a qué horas, entre qué fechas y con qué tipo de cerradura. Mientras el compromiso está en marcha no se puede suavizar, y si intenta entrar en algo bloqueado le sale un vídeo motivador (suyo) o una pantalla propia de la app.

El caso que lo motiva: bloquear Instagram y YouTube de 22:30 a 6:00, de una fecha a otra, sin poder quitarlo; WhatsApp con una salida protegida por contraseña; otras cosas con una "llave" que guarda un amigo.

Más adelante habrá una versión para iPhone (fuera de este diseño, ver §11).

## 2. Objetivos, no objetivos y anti-objetivos

**Objetivos**
- Varios bloqueos independientes a la vez, cada uno con su propia cerradura.
- El bloqueo funciona en cualquier navegador instalado (hoy: Safari y Chrome) y en apps nativas (hoy: WhatsApp.app).
- Sobrevive a reinicios, a cerrar la app y a borrar la app.
- Al intentar entrar en algo bloqueado, salta una pantalla a pantalla completa que no se puede cerrar durante 60 s.
- Gratis: no requiere cuenta de desarrollador de Apple de pago.

**No objetivos**
- Ser imposible de saltar para un administrador decidido (ver §10, límites honestos).
- Sincronizar con el iPhone o con otros Macs.
- Estadísticas, rachas, notificar al amigo, historial detallado. (Quizá más adelante.)

**Anti-objetivos** (cosas que lo harían un fracaso aunque "funcione")
- Que exista cualquier camino *dentro de la app* para suavizar un bloqueo empezado sin su cerradura (editar horario, borrar, cambiar fecha…).
- Que cambiar la hora o la zona horaria del Mac termine un compromiso antes de tiempo.
- Que el bloqueo rompa cosas que no se pidieron (p. ej. bloquear IPs compartidas de Google y tumbar Gmail o Drive).
- Que la pantalla de interceptación salte sin parar por reintentos automáticos del navegador.

## 3. Conceptos

**Bloqueo** (compromiso). Tiene:
- **Nombre** (p. ej. "Noches limpias").
- **Objetivos**: servicios predefinidos (§7), dominios sueltos y/o apps (.app elegidas del disco).
- **Horario**: hora de inicio y hora de fin. Si la de fin es menor que la de inicio, la franja cruza la medianoche (22:30–6:00). También puede ser "todo el día".
- **Días**: días de la semana en que *empieza* la franja. Por defecto, todos. La interfaz lo muestra como "Noches de: L M X J V S D" cuando la franja cruza la medianoche para que quede claro (decisión mía).
- **Fechas**: fecha de inicio y fecha de fin, ambas incluidas. La franja que empieza el último día termina a su hora del día siguiente (decisión mía).
- **Zona horaria**: la del Mac en el momento de crearlo; las franjas se evalúan siempre en esa zona (decisión mía: evita escaparse cambiando la zona horaria; si el usuario viaja, el horario sigue el de casa).
- **Cerradura**: una de estas tres:
  - **Sin salida**: nada lo desbloquea antes de la fecha de fin.
  - **Contraseña**: la elige el propio usuario al crearlo.
  - **Llave de amigo**: la llave la tiene en su móvil un amigo registrado (ver **Amigos**, abajo). Para desbloquear, el usuario le llama y el amigo le dicta el código de 6 cifras que su móvil muestra en ese momento. El amigo no tiene que estar presente ni al crear el bloqueo ni al desbloquearlo.
- **Duración de la pausa** (solo con Contraseña o Llave de amigo): 15 min por defecto, ajustable entre 5 y 60 al crearlo.

**Amigos** (decidido por el usuario: desbloqueo a distancia con el móvil del amigo):
- Se registra un amigo **una sola vez**, con el amigo delante: la app genera un secreto de códigos temporales (TOTP estándar, RFC 6238: 6 cifras, cada 30 s, SHA-1) y muestra un código QR (`otpauth://totp/Detox:<nombre>?secret=…&issuer=Detox`). El amigo lo escanea con la app Contraseñas del iPhone, Google Authenticator o similar, y teclea el código que le sale para confirmar que lo ha guardado bien.
- El QR se muestra **una sola vez** y no se puede volver a ver. Si el amigo pierde el móvil, se registra de nuevo (como un amigo nuevo).
- Una vez registrado, el usuario puede poner la llave de ese amigo a cualquier bloqueo nuevo, o endurecer uno existente a esa llave, sin que el amigo esté presente.
- Un amigo solo se puede borrar si ningún bloqueo en marcha usa su llave.
- Cada código vale **una sola vez** (se guarda el último paso de tiempo usado) y se acepta el paso anterior y el siguiente para tolerar retrasos de la llamada. La verificación usa la hora de confianza (§7.6), no el reloj del Mac.

**Estados de un bloqueo**
- **Programado**: aún no ha llegado su fecha de inicio. Se puede editar o borrar libremente.
- **En marcha**: entre su fecha de inicio y su fecha de fin (incluidas las horas fuera de la franja). Solo se puede endurecer.
- **Activo ahora**: en marcha y dentro de su franja horaria → bloquea.
- **En pausa**: desbloqueado temporalmente con su cerradura; vuelve a bloquear al acabar la pausa.
- **Terminado**: ha pasado su fecha de fin, o el amigo lo ha cancelado.

## 4. Reglas

1. **Un bloqueo en marcha solo puede ir a más.** Se permite: añadir objetivos, alargar la fecha de fin, adelantar la hora de inicio, retrasar la de fin, añadir días, acortar la pausa, pasar a una cerradura más estricta (Contraseña → Llave de amigo → Sin salida). Todo lo demás se rechaza. Esta validación vive en el servicio de sistema (§6), no solo en la interfaz.
2. **Gana el más estricto.** Un objetivo está bloqueado si *cualquier* bloqueo activo ahora y no en pausa lo incluye. Pausar un bloqueo no desbloquea lo que también cubre otro.
3. **Desbloquear es pausar.** Con Contraseña: pausa de la duración configurada. Con Llave de amigo: al introducir el código se elige entre pausa o **cancelar** el bloqueo entero (pasa a Terminado). Quien teclea es el usuario; se confía en que pida el código para lo que le dice al amigo.
4. **Fallos de contraseña o código**: tras 5 intentos fallidos seguidos, esperar 10 minutos antes de poder volver a intentarlo (decisión mía).
5. **Crear un bloqueo Sin salida** pide confirmación explícita escribiendo una frase ("me comprometo"), porque no tiene vuelta atrás (decisión mía).

## 5. Pantalla de interceptación

**Qué cuenta como intento** (decisión mía, tras la revisión):
- **Webs**: solo cuando el usuario la abre de verdad, es decir, el navegador está en primer plano y su pestaña activa es de un dominio bloqueado. La app lo comprueba preguntando al navegador (Safari y Chrome) mediante el permiso de **Automatización** de macOS, que el usuario concede una vez por navegador. Las peticiones de fondo (píxeles de Facebook en otras webs, vídeos de YouTube incrustados, botones de "me gusta", pestañas en segundo plano que se reconectan) se bloquean **en silencio**, sin pantalla.
- **Sin el permiso de Automatización**: la pantalla solo salta si un navegador está en primer plano y el dominio es uno de los **principales** del servicio (marcados en el catálogo, §8); el resto, en silencio.
- **Apps**: abrir una app bloqueada siempre cuenta como intento.

Cuando hay un intento:

- Se abre una ventana a pantalla completa, por encima de todo, en todos los escritorios.
- **Si hay vídeos** en la carpeta elegida (por defecto `~/Movies/Detox`, se puede cambiar en Ajustes): reproduce uno al azar, con sonido.
- **Si no hay vídeos**: pantalla propia oscura con una frase motivadora (lista de frases originales escritas para la app, en español), el nombre del bloqueo, una cuenta atrás hasta el fin de la franja ("Se abre a las 6:00 · faltan 6 h 46 min"), el progreso del compromiso ("Noche 5 de 61") y una animación de respiración guiada.
- **No se puede cerrar** hasta que pasen 60 s o acabe el vídeo, lo que ocurra antes. Después aparece "Cerrar". Esc y Cmd+Q no la cierran antes de tiempo.
- **Una sola a la vez**, y tras cerrarla, 20 s de enfriamiento en los que nuevos intentos no la vuelven a abrir (los navegadores reintentan solos) (decisión mía).
- Si la app de interfaz no está en marcha, el bloqueo sigue funcionando; simplemente no hay pantalla.

## 6. Enfoques considerados

| Enfoque | A favor | En contra | Decisión |
|---|---|---|---|
| **A. Servicio de sistema (root) que modifica `/etc/hosts`, usa el cortafuegos `pf` y cierra apps** (el estilo de SelfControl) | Gratis, funciona hoy con Xcode y la cuenta actual; total control del comportamiento | Hay huecos conocidos que tapar uno a uno (DNS seguro de navegadores, iCloud Private Relay, registros HTTPS en Safari) | **Elegido** |
| B. Filtro de red oficial de Apple (Network Extension) | Lo más robusto; ve todas las conexiones de todas las apps | Requiere cuenta de desarrollador de pago (99 €/año), firma y notarización; más complejo | Futuro: se migrará cuando se haga el iPhone (la cuenta se pagará igualmente). La arquitectura aísla la pieza que corta la red para que el cambio sea local. |
| C. Extensión de navegador | Podría mostrar el vídeo dentro de la propia página | Se salta abriendo otro navegador o quitando la extensión | Descartado: incompatible con "sin salida" |
| D. Tiempo de uso de Apple con código | Robusto, ya existe | Sin fechas de inicio/fin, sin cerraduras por bloqueo, sin vídeo | Descartado |

También existe Cold Turkey Blocker Pro (de pago) que cubre gran parte de esto salvo el vídeo; el usuario prefiere construirlo.

## 7. Arquitectura (enfoque A)

### 7.1 Piezas

1. **DetoxCore** — biblioteca Swift sin dependencias del sistema: modelo de datos (Bloqueo, Horario, Cerradura…), evaluación de horarios (incl. franjas que cruzan medianoche y cambios de horario de verano), validación de "solo endurecer", cálculo de qué objetivos están bloqueados ahora, lógica de pausas, hash de contraseñas, catálogo de servicios predefinidos. Toda la lógica con reglas va aquí y se prueba con tests unitarios.
2. **detoxd** — servicio de sistema (LaunchDaemon, root, `KeepAlive`). Única fuente de verdad. Guarda el estado y lo hace cumplir. Expone una API local para la app.
3. **Detox.app** — app SwiftUI de barra de menú (sin icono en el Dock), lanzada por un LaunchAgent del usuario con `KeepAlive` para que vuelva si se cierra. Interfaz para crear y ver bloqueos, desbloquear, ajustes, y la pantalla de interceptación.
4. **Instalador / desinstalador** — scripts que el usuario ejecuta una vez con `sudo`.

### 7.2 Estado y API

- Estado en `/Library/Application Support/Detox/state.json`, propiedad de root, permisos 0600. Escritura atómica.
- La app habla con detoxd por un socket Unix (`/var/run/detox.sock`) con mensajes JSON. Operaciones: `status`, `createBlock`, `tightenBlock`, `deleteBlock` (solo Programados), `unlock` (contraseña + pausa/cancelar), `settings`, y un canal de eventos (intentos interceptados, cambios de estado).
- El socket es accesible para el usuario; es seguro porque la API, por diseño, solo permite endurecer o desbloquear con la contraseña correcta. Toda validación ocurre en detoxd.
- Contraseñas: nunca en claro. PBKDF2-SHA256 (CommonCrypto) con sal aleatoria y un número alto de iteraciones; comparación en tiempo constante.
- Secretos TOTP de los amigos: TOTP necesita el secreto original, así que se guarda tal cual en el estado de root (0600) y nunca sale por la API. Un administrador con `sudo` podría leerlo: está dentro de los límites de §10.
- Operaciones de API añadidas: `registerFriend` (devuelve el QR una sola vez), `confirmFriend` (verifica el primer código), `deleteFriend`.

### 7.3 Bucle de cumplimiento (cada ~5 s y al detectar cambios)

1. Calcula, con la **hora de confianza** (§7.6), el conjunto de dominios y apps que deben estar bloqueados ahora.
2. **Webs**: mantiene una sección delimitada en `/etc/hosts` (`# BEGIN DETOX` … `# END DETOX`) que apunta cada dominio a `127.0.0.1` y a `::1`. Si alguien la edita, la restaura (vigila el fichero además del sondeo). Tras cada cambio, vacía la caché DNS (`dscacheutil -flushcache` + `killall -HUP mDNSResponder`). Fuera de franja, la sección queda vacía. El resto de `/etc/hosts` no se toca nunca.
3. **Apps**: termina los procesos cuyo bundle id o ruta esté bloqueado (WhatsApp: `net.whatsapp.WhatsApp`) y emite un evento de intento.
4. **Huecos a tapar** durante las franjas activas (cada uno debe **verificarse en este Mac** durante la implementación, porque la documentación pública no es concluyente):
   - **DNS seguro del navegador (DoH)**: política de Chrome `DnsOverHttpsMode = off` aplicada a nivel de máquina; y reglas `pf` en un *anchor* propio que bloquean los resolvers DoH públicos conocidos (Cloudflare, Google, Quad9, NextDNS…) en los puertos 443 y 853.
   - **iCloud Private Relay**: añadir `mask.icloud.com`, `mask-h2.icloud.com` a la sección de hosts (lo que Apple indica para que una red desactive Private Relay). Si no basta con hosts, bloquear por `pf`.
   - **Registros HTTPS/SVCB en Safari** (casos reportados de Safari saltándose `/etc/hosts`): comprobar con Safari en macOS 26; si ocurre, como último recurso bloquear en `pf` las IPs resueltas **solo de dominios dedicados** (nunca IPs compartidas de Google/Meta que rompan otros servicios).
   - **VPN/proxy**: no se tapa; se documenta como límite.
5. Restaura las reglas `pf` del anchor si desaparecen; al terminar la franja las retira.

### 7.4 Detección de intentos (para la pantalla)

Como los dominios bloqueados apuntan a `127.0.0.1`/`::1`, detoxd escucha en esas direcciones en los puertos 80 y 443. Al recibir una conexión lee la cabecera `Host` (HTTP) o el SNI del ClientHello (HTTPS), cierra la conexión sin completar TLS y emite un evento "intento: instagram.com (bloqueo X)". La app recibe el evento y abre la pantalla de interceptación. No se instala ningún certificado ni se descifra nada: el navegador verá un error de conexión y la pantalla queda por encima.

### 7.5 Instalación y permanencia

- Sin cuenta de pago: se compila en local y se firma ad hoc. El instalador (con `sudo`) copia detoxd a `/Library/PrivilegedHelperTools/`, su plist a `/Library/LaunchDaemons/` (propiedad root), lo arranca con `launchctl bootstrap system`, copia la app a `/Applications` e instala el LaunchAgent del usuario.
- Borrar la app no detiene detoxd ni levanta bloqueos.
- **Desinstalar** solo es posible si no hay ningún bloqueo en marcha: el desinstalador lo consulta a detoxd y se niega si lo hay.
- Si la app detecta que detoxd no responde (p. ej. alguien lo desactivó en Ajustes), muestra un aviso persistente en la barra de menú: "El servicio de Detox está desactivado".

### 7.6 Hora de confianza

Para que cambiar la hora del Mac no termine un compromiso:
- detoxd obtiene la hora real de la red (p. ej. cabecera `Date` de una petición HTTPS a un servidor de Apple, o SNTP) al arrancar y periódicamente, y avanza entre medias con un reloj monótono que sigue contando en reposo.
- Si el reloj del sistema se desvía de la hora de confianza más de un minuto, se ignora el reloj del sistema.
- Sin red y sin hora de confianza todavía: se usa el reloj del sistema para **activar** franjas, pero un bloqueo **nunca pasa a Terminado** sin hora de confianza. (Sin red, además, no hay redes sociales que bloquear.)

### 7.7 Pestañas y sesiones ya abiertas (decisión mía, tras la revisión)

Cambiar `/etc/hosts` no corta conexiones ya abiertas: un vídeo de YouTube empezado a las 22:29 seguiría reproduciéndose (sus vídeos vienen de servidores `googlevideo.com` con nombres aleatorios que no se pueden listar), y una pestaña de Instagram o de WhatsApp Web abierta durante una pausa seguiría funcionando al acabar la pausa.

Por eso, **al empezar una franja y al terminar una pausa**, la app (con el permiso de Automatización) cierra en Safari y Chrome las pestañas cuyo dominio esté bloqueado, y detoxd cierra las apps bloqueadas. No se cierran navegadores enteros ni se cortan IPs compartidas (rompería Gmail, etc.). Además, mientras la franja está activa, la app revisa cada pocos segundos las pestañas abiertas y cierra las que sean de dominios bloqueados (cubre pestañas restauradas o cargadas desde caché).

Sin el permiso concedido esto no ocurre: es un límite conocido y la app muestra un aviso en la barra de menú pidiendo el permiso.

## 8. Servicios predefinidos (catálogo inicial)

Instagram, YouTube, TikTok, X/Twitter, Facebook, Reddit, WhatsApp (web + app). Cada uno con sus **dominios principales** (los que el usuario teclea o visita, p. ej. `instagram.com`, `www.youtube.com`; se usan para decidir la pantalla sin permiso de Automatización, §5), su lista de dominios y subdominios secundarios conocidos (hosts no admite comodines, así que hay que listarlos) y, si aplica, bundle ids de apps. Además, dominios sueltos y apps elegidas del disco. Compilar las listas es tarea del constructor; deben bloquear el servicio sin afectar a otros (p. ej. bloquear YouTube no debe romper Gmail).

## 9. Interfaz

- **Barra de menú**: icono que indica si hay algo activo ahora; lista de bloqueos activos con lo que falta para que se abran; botón "Desbloquear…" en los que tienen Contraseña o Llave de amigo; "Abrir Detox"; aviso si el servicio no responde.
- **Ventana principal**: lista de bloqueos con estado (Programado / En marcha / Activo / En pausa / Terminado); crear bloqueo paso a paso (qué → horario y días → fechas → cerradura → confirmación); endurecer un bloqueo en marcha (los controles que suavizarían aparecen deshabilitados); ajustes (carpeta de vídeos); sección **Amigos** (registrar con QR, ver quién tiene llave de qué bloqueos, borrar).
- **Desbloquear con llave de amigo**: campo de 6 cifras y elección pausa / cancelar el bloqueo, con el recordatorio "Llama a <amigo> y pídele el código".
- **Pantalla de interceptación**: §5.
- **Primer arranque**: explica y pide el permiso de Automatización para Safari y Chrome (necesario para §5 y §7.7).
- Idioma: español.
- El aspecto visual lo decide el constructor (con la skill de diseño de interfaces), con tono sobrio y calmado, coherente con un detox.

## 10. Límites honestos

- Un usuario **administrador** siempre puede saltárselo con esfuerzo deliberado: terminal con `sudo`, desactivar el servicio en Ajustes › General › Ítems de inicio (pide contraseña de admin), arrancar en modo recuperación, usar una VPN. La app lo hace incómodo, no imposible.
- Para quien quiera que sea de verdad inquebrantable: guía opcional (texto en la app/README) para pasar la cuenta del usuario a **estándar** y que el amigo guarde la contraseña de administrador. No requiere código extra.
- Al registrar un amigo, si el propio usuario fotografía el QR, se queda con una copia de la llave. La app no puede impedirlo; es cuestión de honestidad.
- No afecta al móvil ni a otros dispositivos.

## 11. Fuera de alcance / futuro

- **iPhone**: solo posible con la API de Tiempo de uso (FamilyControls, ManagedSettings, DeviceActivity), cuenta de desarrollador de pago y aprobación del permiso de Family Controls por Apple. La pantalla de bloqueo de iOS es estática: no puede reproducir vídeo (como mucho, mensaje y botones). DetoxCore debe quedar reutilizable (sin dependencias de macOS) para compartir modelo y reglas.
- Migrar el Mac al filtro de red oficial (enfoque B) cuando exista la cuenta de pago.
- Rachas, estadísticas, avisar al amigo si se rompe un compromiso.

## 12. Verificación

- **Tests unitarios (DetoxCore)**: franjas que cruzan medianoche, días de la semana, fechas inclusivas, horario de verano, zona horaria fija, regla "solo endurecer" (cada campo), "gana el más estricto", pausas y su caducidad, cancelar con llave, bloqueo de 5 intentos, hash y verificación de contraseñas, hora de confianza, TOTP con los vectores de prueba del RFC 6238, tolerancia de ±1 paso, rechazo de un código ya usado.
- **Tests de detoxd** contra un `/etc/hosts` y un directorio de estado temporales (modo de pruebas que no toca el sistema): escribir/restaurar la sección, preservar el resto del fichero, rechazar operaciones que suavizan, extraer SNI/Host de capturas reales.
- **Pruebas manuales en este Mac** (requieren que el usuario ejecute el instalador con `sudo`): Instagram y YouTube en Safari y Chrome; un vídeo de YouTube en reproducción se corta al empezar la franja; una web con píxel de Facebook o un vídeo de YouTube incrustado no abre la pantalla; WhatsApp.app se cierra; aparece la pantalla y no se cierra antes de 60 s; editar `/etc/hosts` a mano se revierte; reiniciar mantiene el bloqueo; cambiar la hora del Mac no termina el compromiso; Gmail y Google siguen funcionando con YouTube bloqueado.

## 13. Lo que queda al constructor

- Estructura del proyecto (Swift Package Manager y/o proyecto de Xcode) y cómo se empaqueta la `.app`.
- Formato exacto del JSON de estado y del protocolo del socket.
- Listas de dominios del catálogo.
- Diseño visual de las tres superficies y la lista de frases motivadoras.
- Mecanismo concreto de hora de red.
- Cómo aplicar la política de Chrome a nivel de máquina sin MDM, a verificar.
- Firmar la app con una identidad estable (p. ej. certificado de desarrollo gratuito o autofirmado) para que macOS no vuelva a pedir el permiso de Automatización en cada recompilación.
- Conflictos con otros programas que ya escuchen en los puertos 80/443 locales, otras cuentas de usuario del Mac y DNS cifrado a nivel de sistema: decidir y documentar.
