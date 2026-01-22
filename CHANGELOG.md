# Changelog

Todos los cambios notables en este proyecto serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto se adhiere a [Semantic Versioning](https://semver.org/lang/es/).

## [1.2.0] - 2026-01-22
### Añadido
- Barra de progreso visual durante el proceso de clonado.
- Indicadores de tiempo transcurrido y estimación de tiempo restante (ETA).
- Monitorización en tiempo real del tamaño de la copia en destino.
- Optimización de rendimiento usando `Scripting.FileSystemObject` para cálculos de tamaño.

## [1.1.0] - 2026-01-21
### Añadido
- Soporte para caracteres UTF-8 en la salida de consola (soluciona problemas con acentos y caracteres especiales).
- Menú interactivo mejorado con navegación y opciones claras.
- Validación de `vmrun.exe` en rutas estándar (x64 y x86).

### Cambiado
- Refactorización de la lógica de detección de snapshots.
- Mejora en los mensajes de log y feedback visual para el usuario.

## [1.0.0] - 2026-01-20
### Añadido
- Versión inicial del script `Invoke-VMSnapshotCleanup.ps1`.
- Funcionalidad básica de clonado desde snapshot.
- Sistema de backup rotativo (`_Trash_`).
