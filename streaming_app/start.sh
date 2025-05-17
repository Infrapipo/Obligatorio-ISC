#!/bin/bash

# Activar el entorno virtual
source /home/juan/streaming_platform/venv/bin/activate

# Ejecutar el script de monitoreo
exec /home/juan/streaming_platform/venv/bin/python3.12 /home/juan/streaming_platform/monitor.py
