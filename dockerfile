# Étapa 1: Instalación de dependencias
FROM python:3.14.0b1-alpine3.21 AS installer
 
# Crea directorio para archivo de dependencias
RUN mkdir /app
 
# Utiliza el directorio
WORKDIR /app
 
# Establece variables de entorno para optimizar el funcionamiento del intérprete de Python
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1 
 
# Actualiza pip y sus dependencias
RUN pip install --upgrade pip 
 
# Copia archivo con dependencias para la app
COPY requirements.txt /app/
 
# Instala las dependencias a partir del archivo
RUN pip install --no-cache-dir -r requirements.txt
 
# Étapa 2: Producción
FROM python:3.14.0b1-alpine3.21
 
RUN useradd -m -r django-user && \
   mkdir /app && \
   chown -R django-user /app
 
# Copia las dependencias ya instaladas en étapa anterior
COPY --from=installer /usr/local/lib/python3.13/site-packages/ /usr/local/lib/python3.13/site-packages/
COPY --from=installer /usr/local/bin/ /usr/local/bin/
 
# Cambia al directorio de la app
WORKDIR /app
 
# Copia el código de la aplicación
COPY --chown=django-user:django-user . .
 
# Establece variables de entorno para optimizar el funcionamiento del intérprete de Python
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1 
 
# Cambia al usuario de la aplicación
USER django-user
 
# Corre la aplicación utilizando Gunicorn (Servidor de producción)
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "my_docker_django_app.wsgi:application"]