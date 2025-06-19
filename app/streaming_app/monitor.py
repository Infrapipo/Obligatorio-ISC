import time
import os
import re
import logging
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from django.core.wsgi import get_wsgi_application
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "main_project.settings")
django.setup()
from streaming.models import Video, Materia

# Configuración de logs
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

# Manejador de archivo (para guardar los logs en un archivo)
file_handler = logging.FileHandler('video_processing.log')
file_handler.setLevel(logging.DEBUG)

# Formato de los logs
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
file_handler.setFormatter(formatter)

# Añadir manejador de archivo al logger
logger.addHandler(file_handler)

class Watcher:
    DIRECTORY_TO_WATCH = os.getenv("DIRECTORY_TO_WATCH", "/home/juan/streaming_platform/streaming/media/videos/")

    def __init__(self):
        self.observer = Observer()

    def run(self):
        event_handler = Handler()
        self.observer.schedule(event_handler, self.DIRECTORY_TO_WATCH, recursive=True)
        self.observer.start()
        try:
            while True:
                time.sleep(10)
        except KeyboardInterrupt:
            self.observer.stop()
        self.observer.join()

class Handler(FileSystemEventHandler):
    def extract_class_number(self, video_title):
        """ Extrae el número de la clase del título del video (formato: 'Clase{número}_texto') """
        match = re.search(r"Clase\s*(\d+)", video_title, re.IGNORECASE)
        if match:
            class_number = int(match.group(1))  # Devuelve el número de la clase como entero
            logger.debug(f"Número de clase extraído: {class_number}")
            return class_number
        else:
            logger.warning(f"No se pudo extraer número de clase del título: {video_title}")
        return None  # Si no se encuentra el formato esperado, devuelve None

    def on_created(self, event):
        """ Maneja la creación de archivos en la carpeta monitoreada """
        if not event.is_directory:
            try:
                file_path = event.src_path
                rel_path = os.path.relpath(file_path, Watcher.DIRECTORY_TO_WATCH)

                parts = rel_path.split(os.sep)
                if len(parts) == 3:
                    materia_name, video_title, video_file = parts
                    if video_file.startswith('video') and video_file.endswith(('.mp4', '.avi', '.mkv')):

                        # Crear o obtener la materia
                        materia, _ = Materia.objects.get_or_create(name=materia_name)

                        # Extraer el número de clase
                        class_number = self.extract_class_number(video_title)

                        # Crear la entrada de video en la base de datos
                        video_instance = Video.objects.create(
                            title=video_title,
                            file=f'videos/{materia_name}/{video_title}/{video_file}',
                            materia=materia,
                            class_number=class_number  # Guardar el número de clase
                        )

            except Exception as e:
                logger.error(f"Error al crear archivo: {e}")

    def on_deleted(self, event):
        """ Maneja la eliminación de archivos en la carpeta monitoreada """
        if not event.is_directory:
            try:
                file_path = event.src_path
                rel_path = os.path.relpath(file_path, Watcher.DIRECTORY_TO_WATCH)

                parts = rel_path.split(os.sep)
                if len(parts) == 3:
                    materia_name, video_title, video_file = parts
                    if video_file.startswith('video') and video_file.endswith(('.mp4', '.avi', '.mkv')):

                        # Buscar y eliminar la entrada en la base de datos
                        try:
                            video_instance = Video.objects.get(
                                title=video_title,
                                file=f'videos/{materia_name}/{video_title}/{video_file}'
                            )
                            video_instance.delete()

                            # Verificar si la categoría está vacía
                            materia = video_instance.materia
                            if not Video.objects.filter(materia=materia).exists():
                                materia.delete()  # Eliminar la materia si no tiene videos

                        except Video.DoesNotExist:
                            logger.error(f"Video no encontrado para eliminar: {video_title}")
                        except Exception as e:
                            logger.error(f"Error al eliminar archivo: {e}")

            except Exception as e:
                logger.error(f"Error en on_deleted: {e}")

if __name__ == "__main__":
    w = Watcher()
    w.run()
