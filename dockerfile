# Étapa 1: Instalación de dependencias
FROM python:3.12 AS installer

RUN apt-get update && apt-get install -y \
      libgl1-mesa-glx \
      libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Crea directorio para archivo de dependencias
RUN mkdir /app
 
# Utiliza el directorio
WORKDIR /app
 
# Establece variables de entorno para optimizar el funcionamiento del intérprete de Python
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1 

# Copia archivo con dependencias para la app
COPY streaming_app/requirements.txt /app/
 
# Instala las dependencias a partir del archivo
RUN pip install --upgrade pip && \
   pip install --no-cache-dir -r requirements.txt

# Étapa 2: Producción
FROM python:3.12

RUN apt-get update && apt-get install -y \
      libgl1-mesa-glx \
      libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/* &&\
    useradd -m -r django-user && \
    mkdir /app && \
    chown -R django-user /app
 
# Copia las dependencias ya instaladas en étapa anterior
COPY --from=installer /usr/local/lib/python3.12/site-packages/ /usr/local/lib/python3.12/site-packages/
COPY --from=installer /usr/local/bin/ /usr/local/bin/
 
# Cambia al directorio de la app
WORKDIR /app
 
# Copia el código de la aplicación
COPY --chown=django-user:django-user ./streaming_app .
 
# Establece variables de entorno para optimizar el funcionamiento del intérprete de Python
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1 
 
# Cambia al usuario de la aplicación
USER django-user

# Corre la aplicación utilizando Gunicorn (Servidor de producción)
CMD ["gunicorn", "--bind", "0.0.0.0:6969", "--workers", "4", "main_project.wsgi:application"]