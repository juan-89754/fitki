from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import Usuario, Cuenta, MetaAhorro, Deuda, Transaccion

@admin.register(Usuario)
class CustomUserAdmin(UserAdmin):
    model = Usuario
    list_display = ['username', 'email', 'nombre', 'is_staff', 'fecha_creacion']
    fieldsets = UserAdmin.fieldsets + (
        ('Información Fitki', {'fields': ('nombre',)}),
    )
    add_fieldsets = UserAdmin.add_fieldsets + (
        ('Información Fitki', {'fields': ('email', 'nombre')}),
    )

@admin.register(Cuenta)
class CuentaAdmin(admin.ModelAdmin):
    list_display = ['nombre_banco', 'tipo_cuenta', 'saldo_actual', 'usuario', 'fecha_actualizacion']
    list_filter = ['tipo_cuenta']
    search_fields = ['nombre_banco', 'usuario__username']

@admin.register(MetaAhorro)
class MetaAhorroAdmin(admin.ModelAdmin):
    list_display = ['nombre', 'monto_objetivo', 'monto_ahorrado_actual', 'fecha_limite', 'usuario']
    list_filter = ['fecha_limite']
    search_fields = ['nombre', 'usuario__username']

@admin.register(Deuda)
class DeudaAdmin(admin.ModelAdmin):
    list_display = ['nombre', 'monto_total', 'tasa_interes', 'cuota_mensual', 'fecha_proximo_pago', 'usuario']
    list_filter = ['fecha_proximo_pago']
    search_fields = ['nombre', 'usuario__username']

@admin.register(Transaccion)
class TransaccionAdmin(admin.ModelAdmin):
    list_display = ['tipo', 'monto', 'categoria', 'cuenta', 'fecha', 'usuario']
    list_filter = ['tipo', 'categoria', 'fecha']
    search_fields = ['categoria', 'descripcion', 'usuario__username', 'cuenta__nombre_banco']
