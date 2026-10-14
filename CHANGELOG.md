# Cambios

## [0.1.2] - 2026-10-14 - Rangos de IP permitidos

- `allow` acepta rangos además de IPs sueltas, por ejemplo `192.168.0.0/22` para toda la red del casino. La clave y la lista blanca de comandos siguen siendo obligatorias.
- Lo integra Kerma PC Setup 5.10.0 en las mesas.

## [0.1.1] - 2026-10-13 - Portapapeles ocupado

- Si el portapapeles esta ocupado (por ejemplo por RustDesk), reintenta durante unos 2 s y, si sigue ocupado, escribe el comando tecla a tecla en vez de dar error interno. La respuesta y el registro dicen `via=paste` o `via=type`.
- Probado en Blackjack 01: el pegado deja exactamente `{ATEM_AUTO}`, sin salto de linea.

## [0.1.0] - 2026-10-13 - Primera versión

- Receptor HTTP en el puerto 10010 con lista de IPs permitidas, clave en cabecera, lista blanca de comandos y antirrepetición de 2 s.
- Comando `atem_auto`, que pega `{ATEM_AUTO}` en la Dealer App sin Enter, guardando y restaurando el portapapeles y el foco.
- Modos de prueba: `-TestCommand` sin red y `-DryRun` sin tocar ventanas.
- Conocido: tras pegar, devolver el foco a la ventana anterior puede no funcionar siempre. En las mesas no importa porque la Dealer App se queda delante. Con el Bloc de notas, el plan B de foco (Alt) puede activar su menú y perderse el pegado.
- Instalador: carpeta, clave, reserva del puerto (urlacl), regla de firewall y tarea al iniciar sesión. `-Uninstall` lo deshace.
