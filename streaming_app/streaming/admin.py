from django.contrib import admin
from .models import Video, Profile, Materia

admin.site.register(Video)

class ProfileAdmin(admin.ModelAdmin):
    list_display = ['user']
    filter_horizontal = ['allowed_materias']

admin.site.register(Profile, ProfileAdmin)
admin.site.register(Materia)