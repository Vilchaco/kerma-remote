# Kerma Remote

Receptor pequeño para los PCs de mesa. Desde un Stream Deck con Companion, en la Tech Room o en MCR, pulsas una tecla y el comando se pega en la Dealer App de esa mesa, igual que si el dealer lo pulsara en su propio Stream Deck.

Por ahora solo hay un comando permitido: **`atem_auto`**, que pega `{ATEM_AUTO}`. En Craps reintenta la secuencia automática de cámaras y en Ruleta devuelve las cámaras a automático.

## Cómo funciona

- `KermaRemote.ps1` escucha en el puerto **10010** y se ejecuta en la sesión del usuario de la mesa. Lo arranca una tarea al iniciar sesión.
- Por la red solo viaja el **nombre** del comando, por ejemplo `atem_auto`. El texto real sale de la lista `commands` del `config.json` de ese PC. Lo que no está en la lista se rechaza, así que a una mesa nunca puede llegar un comando de resultado, como dados, números o `{SUBMIT_DICE}`.
- Antes de pegar nada se comprueban cuatro cosas:
  - Que la IP de quien envía esté en `allow` del config.
  - Que esa IP también la deje pasar la regla del firewall de Windows.
  - Que la petición lleve la clave de `remote.key` en la cabecera `X-Kerma-Key`.
  - Que no sea el mismo comando repetido en menos de 2 segundos.
- Para ejecutar el comando, pone delante la ventana de la Dealer App, que es el proceso `dealer-control`. Pega el texto sin Enter, deja el portapapeles como estaba y devuelve el foco a la ventana que había delante.
- Todo queda en `remote.log`: hora, IP, puesto según la cabecera `X-Kerma-Station`, comando, ventana y resultado.

Todo vive en `C:\ProgramData\Kerma\remote`: `KermaRemote.ps1`, `config.json`, `remote.key` y `remote.log`.

## Instalar en una mesa

**Con doble clic, lo más fácil.** Descomprime el zip y abre el `.bat` que toque. Piden permisos de administrador y dejan la ventana abierta al terminar:

| Archivo | Para qué |
|---|---|
| `1 Instalar PRUEBA Bloc de notas.bat` | Prueba: pega en el Bloc de notas y solo acepta al PC de MCR |
| `2 Probar en local.bat` | Pega `{ATEM_AUTO}` sin usar la red, en la app configurada |
| `3 Instalar MESA Dealer App.bat` | Mesa real: pega en la Dealer App y solo acepta al PC de MCR |
| `Desinstalar.bat` | Lo quita todo |

Al terminar, la ventana muestra la clave. Cópiala en Companion. Reinstalar mantiene la misma clave; para cambiarla, usa `-NewKey`.

**Desde PowerShell**, para elegir otras opciones:

Ejecuta esto en PowerShell como administrador, desde la carpeta que tiene los dos scripts:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-KermaRemote.ps1 -Allow 192.168.1.79
```

Windows bloquea los scripts por defecto: por eso va `-ExecutionPolicy Bypass`.

- Si no pasas `-Key`, te la pide. Si la dejas en blanco, genera una al azar y la muestra para que la copies en Companion.
- `-TargetProcess notepad` apunta al Bloc de notas en lugar de la Dealer App, para pruebas.
- `-Mode type` escribe el texto en lugar de pegarlo. Es el plan B por si la app no acepta pegar.
- Para desinstalar: `powershell -ExecutionPolicy Bypass -File .\Install-KermaRemote.ps1 -Uninstall`.

## Escalera de pruebas

Haz los pasos en orden. Cada uno prueba una capa más.

1. **En la mesa, sin red**, contra el Bloc de notas:
   ```powershell
   powershell -STA -ExecutionPolicy Bypass -File C:\ProgramData\Kerma\remote\KermaRemote.ps1 -TestCommand atem_auto -Target notepad
   ```
2. **Solo la red, sin tocar ventanas.** En la mesa:
   ```powershell
   powershell -STA -ExecutionPolicy Bypass -File C:\ProgramData\Kerma\remote\KermaRemote.ps1 -DryRun
   ```
   Antes, para la tarea **Kerma - Remote**, porque usa el mismo puerto.
   Y desde el PC de MCR:
   ```powershell
   Invoke-RestMethod http://192.168.0.151:10010/cmd/atem_auto -Method Post -Body '' -Headers @{ 'X-Kerma-Key' = '<clave>'; 'X-Kerma-Station' = 'MCR' }
   ```
3. **Companion**, con la tecla que se describe más abajo.
4. **Craps 01 con la Dealer App de verdad** y el comando real.

## Companion

1. Añade la conexión **Generic: HTTP Requests**. Deja vacía la URL base.
2. Crea una tecla con la acción **POST**:
   - URL: `http://<IP-de-la-mesa>:10010/cmd/atem_auto`
   - Body: vacío
   - Header (JSON): `{"X-Kerma-Key": "<clave>", "X-Kerma-Station": "MCR"}`
3. Si la tecla devuelve 411 (Length Required), cambia la acción a **GET** con la misma URL y cabeceras: también vale.
4. Crea una tecla por mesa: Craps 01 es `192.168.1.86` y Ruleta 01 es `192.168.0.156`.

La respuesta es un JSON con `ok: true` si ha ido bien, o con `ok: false` y un campo `error` si algo falla.

| Código | Significado |
|---|---|
| 401 | Clave incorrecta |
| 403 | IP no permitida |
| 404 | El comando no está en la lista |
| 409 | La Dealer App no está abierta, o no se pudo poner delante |
| 429 | Repetido en menos de 2 segundos |

## Añadir comandos

Añade el comando a `commands` en el `config.json` de cada mesa, por ejemplo `"pause": "{PAUSE}"`, y reinicia la tarea **Kerma - Remote**. Antes de añadir cualquier comando, comprueba que no mete ni cambia un resultado de juego.
