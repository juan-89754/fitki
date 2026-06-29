from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    RegistroUsuarioView, 
    CuentaViewSet, 
    TransaccionViewSet, 
    DashboardView,
    MetaAhorroViewSet,
    DeudaViewSet,
    AsistenteConsultaView,
    ProyectoCompraViewSet,
    ItemProyectoViewSet
)

# Crear un router de DRF para registrar ViewSets
router = DefaultRouter()
router.register(r'cuentas', CuentaViewSet, basename='cuenta')
router.register(r'transacciones', TransaccionViewSet, basename='transaccion')
router.register(r'metas', MetaAhorroViewSet, basename='meta')
router.register(r'deudas', DeudaViewSet, basename='deuda')

router.register(r'proyectos-compra', ProyectoCompraViewSet, basename='proyecto-compra')
router.register(r'items-proyecto', ItemProyectoViewSet, basename='item-proyecto')


urlpatterns = [
    # Rutas para autenticación y perfil
    path('register/', RegistroUsuarioView.as_view(), name='api_register'),
    
    # Ruta consolidada para el Dashboard
    path('dashboard/', DashboardView.as_view(), name='api_dashboard'),

    # Asistente Inteligente
    path('asistente/consulta/', AsistenteConsultaView.as_view(), name='api_asistente_consulta'),
    
    # Rutas CRUD de recursos
    path('', include(router.urls)),
]
