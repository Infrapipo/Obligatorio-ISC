from django.conf import settings
from django.db import models
from django.contrib.auth.models import User


class Materia(models.Model):
    name = models.CharField(max_length=255)

    def __str__(self):
        return self.name

class Video(models.Model):
    title = models.CharField(max_length=255)
    file = models.FileField(upload_to="videos/", max_length=512)
    materia = models.ForeignKey(Materia, on_delete=models.CASCADE, related_name="videos", default=1)
    uploaded_at = models.DateTimeField(auto_now_add=True)
    class_number = models.IntegerField(null=True, blank=True)
    
    def __str__(self):
        return self.title

class Profile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    allowed_materias = models.ManyToManyField(Materia, blank=True)

    def __str__(self):
        return f"Perfil de {self.user.username}"
    