# Cambios

## [0.1.0] - 2026-10-13 - Primera versión

- Receptor HTTP en el puerto 10010 con lista de IPs permitidas, clave en cabecera, lista blanca de comandos y antirrepetición de 2 s.
- Comando `atem_auto`, que pega `{ATEM_AUTO}` en la Dealer App sin Enter, guardando y restaurando el portapapeles y el foco.
- Modos de prueba: `-TestCommand` sin red y `-DryRun` sin tocar ventanas.
- Instalador: carpeta, clave, reserva del puerto (urlacl), regla de firewall y tarea al iniciar sesión. `-Uninstall` lo deshace.
