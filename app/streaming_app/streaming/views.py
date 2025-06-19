from django.shortcuts import render, get_object_or_404, redirect
from rest_framework import viewsets
from rest_framework.renderers import JSONRenderer
from .models import Video, Materia
from .serializers import VideoSerializer
import cv2
import random
import os
from django.conf import settings
from django.contrib import messages
from django.contrib.auth import login
from django.contrib.auth.decorators import login_required
from django.http import HttpResponse, JsonResponse
from .forms import CustomUserCreationForm

class VideoViewSet(viewsets.ModelViewSet):
    queryset = Video.objects.all()
    serializer_class = VideoSerializer
    renderer_classes = [JSONRenderer]

@login_required 
def video_materia_select(request):
    allowed_materias = request.user.profile.allowed_materias.all().order_by('name')
    return render(request, "video_materia_select.html", {"materias": allowed_materias})

@login_required
def video_list_by_materia(request, category_id):
    materia = get_object_or_404(Materia, id=category_id)
    if materia not in request.user.profile.allowed_materias.all():
        return HttpResponse("No tienes acceso a esta materia", status=403)
    videos = Video.objects.filter(materia=materia).order_by('class_number')
    return render(request, "video_list_by_materia.html", {"materia": materia, "videos": videos})

def register(request):
    if request.method == "POST":
        form = CustomUserCreationForm(request.POST)
        if form.is_valid():
            user = form.save()
            messages.success(request, "¡Registro exitoso!")
            return redirect("login")  # Redirige a la página principal o la que elijas
    else:
        form = CustomUserCreationForm()
    
    return render(request, "register.html", {"form": form})

def get_random_frame(video_path):
    video = cv2.VideoCapture(video_path)
    total_frames = int(video.get(cv2.CAP_PROP_FRAME_COUNT))
    random_frame = random.randint(0, total_frames)
    video.set(cv2.CAP_PROP_POS_FRAMES, random_frame)
    ret, frame = video.read()
    
    if not ret:
        return None
    
    _, img_encoded = cv2.imencode('.jpg', frame)
    return img_encoded.tobytes()

def video_thumbnail(request, video_id):
    video = get_object_or_404(Video, id=video_id)
    video_path = os.path.join(settings.MEDIA_ROOT, video.file.name)
    
    # Generar el fotograma aleatorio
    frame = get_random_frame(video_path)
    
    if not frame:
        return HttpResponse(status=404)
    
    return HttpResponse(frame, content_type="image/jpeg")