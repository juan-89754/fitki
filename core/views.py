from rest_framework import viewsets, generics, permissions, views, status
from rest_framework.response import Response
from django.db import transaction
from django.db.models import Sum, F
from django.utils import timezone
import datetime
from .models import Cuenta, Transaccion, MetaAhorro, Deuda
from .serializers import (
    UsuarioRegistroSerializer, 
    CuentaSerializer, 
    TransaccionSerializer, 
    MetaAhorroSerializer, 
    DeudaSerializer
)

class RegistroUsuarioView(generics.CreateAPIView):
    """
    Endpoint para que un nuevo usuario se registre.
    Es público (AllowAny).
    """
    serializer_class = UsuarioRegistroSerializer
    permission_classes = [permissions.AllowAny]


class CuentaViewSet(viewsets.ModelViewSet):
    """
    ViewSet para listar, crear, ver, editar y borrar cuentas del usuario autenticado.
    """
    serializer_class = CuentaSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Cuenta.objects.filter(usuario=self.request.user).order_by('-fecha_actualizacion')

    def perform_create(self, serializer):
        serializer.save(usuario=self.request.user)


class MetaAhorroViewSet(viewsets.ModelViewSet):
    """
    ViewSet para gestionar metas de ahorro del usuario autenticado.
    """
    serializer_class = MetaAhorroSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return MetaAhorro.objects.filter(usuario=self.request.user).order_by('fecha_limite', 'id')

    def perform_create(self, serializer):
        serializer.save(usuario=self.request.user)


class DeudaViewSet(viewsets.ModelViewSet):
    """
    ViewSet para gestionar deudas/obligaciones del usuario autenticado.
    """
    serializer_class = DeudaSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Deuda.objects.filter(usuario=self.request.user).order_by('fecha_proximo_pago', 'id')

    def perform_create(self, serializer):
        serializer.save(usuario=self.request.user)


class TransaccionViewSet(viewsets.ModelViewSet):
    """
    ViewSet para gestionar movimientos (transacciones) del usuario autenticado.
    """
    serializer_class = TransaccionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Transaccion.objects.filter(usuario=self.request.user).order_by('-fecha', '-id')

    @transaction.atomic
    def perform_destroy(self, instance):
        cuenta = instance.cuenta
        monto = instance.monto
        tipo = instance.tipo

        if tipo == 'INGRESO':
            cuenta.saldo_actual -= monto
        elif tipo == 'GASTO':
            cuenta.saldo_actual += monto
        cuenta.save()

        if instance.meta_ahorro and tipo == 'GASTO':
            instance.meta_ahorro.monto_ahorrado_actual -= monto
            if instance.meta_ahorro.monto_ahorrado_actual < 0:
                instance.meta_ahorro.monto_ahorrado_actual = 0
            instance.meta_ahorro.save()

        if instance.deuda and tipo == 'GASTO':
            instance.deuda.monto_total += monto
            instance.deuda.save()

        instance.delete()


class DashboardView(views.APIView):
    """
    APIView que devuelve un resumen financiero consolidado del usuario autenticado.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        usuario = request.user

        cuentas_queryset = Cuenta.objects.filter(usuario=usuario)
        cuentas_data = CuentaSerializer(cuentas_queryset, many=True).data

        suma_cuentas = cuentas_queryset.aggregate(total=Sum('saldo_actual'))['total'] or 0.00
        suma_deudas = Deuda.objects.filter(usuario=usuario).aggregate(total=Sum('monto_total'))['total'] or 0.00
        patrimonio_neto = float(suma_cuentas) - float(suma_deudas)

        metas_queryset = MetaAhorro.objects.filter(usuario=usuario).order_by('fecha_limite', 'id')
        metas_data = MetaAhorroSerializer(metas_queryset, many=True).data

        deudas_queryset = Deuda.objects.filter(usuario=usuario).order_by('fecha_proximo_pago', 'id')
        deudas_data = DeudaSerializer(deudas_queryset, many=True).data

        ultimas_transacciones_queryset = Transaccion.objects.filter(usuario=usuario).order_by('-fecha', '-id')[:10]
        transacciones_data = TransaccionSerializer(ultimas_transacciones_queryset, many=True).data

        ahora = timezone.now()
        inicio_mes = ahora.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        
        ingresos_mes = Transaccion.objects.filter(
            usuario=usuario,
            tipo='INGRESO',
            fecha__gte=inicio_mes
        ).aggregate(total=Sum('monto'))['total'] or 0.00

        gastos_mes = Transaccion.objects.filter(
            usuario=usuario,
            tipo='GASTO',
            fecha__gte=inicio_mes
        ).aggregate(total=Sum('monto'))['total'] or 0.00

        return Response({
            'patrimonio_neto': patrimonio_neto,
            'saldo_total_cuentas': float(suma_cuentas),
            'total_deudas': float(suma_deudas),
            'ingresos_mes_actual': float(ingresos_mes),
            'gastos_mes_actual': float(gastos_mes),
            'cuentas': cuentas_data,
            'metas': metas_data,
            'deudas': deudas_data,
            'ultimas_transacciones': transacciones_data
        }, status=status.HTTP_200_OK)


class AsistenteConsultaView(views.APIView):
    """
    APIView que procesa las consultas de compras del usuario analizando su
    Capacidad de Gasto Libre (CGL) e indicando el impacto de forma matemática.
    """
    permission_classes = [permissions.IsAuthenticated]

    def _formatear_pesos(self, monto):
        return f"${int(monto):,}".replace(",", ".")

    def _calcular_aporte_meta_mensual(self, meta):
        objetivo = float(meta.monto_objetivo)
        ahorrado = float(meta.monto_ahorrado_actual)
        faltante = objetivo - ahorrado
        if faltante <= 0:
            return 0.0

        hoy = timezone.now().date()
        limite = meta.fecha_limite
        if not limite or limite <= hoy:
            return faltante  # Requiere ahorrar el faltante en el mes actual

        # Calcular diferencia en meses
        meses = (limite.year - hoy.year) * 12 + (limite.month - hoy.month)
        if meses <= 0:
            meses = 1
        return round(faltante / meses, 2)

    def post(self, request):
        usuario = request.user
        monto_compra = request.data.get('monto')

        if monto_compra is None:
            return Response({"error": "Debe especificar el monto de la compra."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            monto_compra = float(monto_compra)
        except ValueError:
            return Response({"error": "El monto debe ser un número válido."}, status=status.HTTP_400_BAD_REQUEST)

        # 1. Saldo total de cuentas (Activos disponibles)
        saldo_total = Cuenta.objects.filter(usuario=usuario).aggregate(total=Sum('saldo_actual'))['total'] or 0.00
        saldo_total = float(saldo_total)

        # 2. Gastos fijos del mes actual (Vivienda + Servicios de este mes)
        ahora = timezone.now()
        inicio_mes = ahora.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        gastos_fijos = Transaccion.objects.filter(
            usuario=usuario,
            tipo='GASTO',
            categoria__in=['Vivienda', 'Servicios'],
            fecha__gte=inicio_mes
        ).aggregate(total=Sum('monto'))['total'] or 0.00
        gastos_fijos = float(gastos_fijos)

        # 3. Cuotas mínimas de deudas vigentes
        cuota_deudas = Deuda.objects.filter(
            usuario=usuario,
            monto_total__gt=0
        ).aggregate(total=Sum('cuota_mensual'))['total'] or 0.00
        cuota_deudas = float(cuota_deudas)

        # 4. Aportes sugeridos para las metas de ahorro activas
        metas = MetaAhorro.objects.filter(usuario=usuario)
        aporte_metas = 0.0
        for meta in metas:
            aporte_metas += self._calcular_aporte_meta_mensual(meta)

        # 5. Capacidad de Gasto Libre (CGL)
        cgl = saldo_total - gastos_fijos - cuota_deudas - aporte_metas

        # 6. Responder según viabilidad
        if monto_compra <= cgl:
            sobrante = cgl - monto_compra
            sugerencia = f"¡Dale! Te sobran {self._formatear_pesos(sobrante)} después de cubrir tus metas."
            return Response({
                "aprobado": True,
                "cgl": cgl,
                "sobrante": sobrante,
                "sugerencia": sugerencia
            }, status=status.HTTP_200_OK)
        else:
            # Calcular retraso en la meta principal
            meta_principal = metas.order_by('fecha_limite', 'id').first()
            
            # Obtener ritmo mensual de ahorro real
            ritmo_mensual = 0.0
            if meta_principal:
                dias_creacion = (timezone.now() - meta_principal.fecha_creacion).days
                if dias_creacion <= 0:
                    dias_creacion = 1
                ahorrado_meta = float(meta_principal.monto_ahorrado_actual)
                if ahorrado_meta > 0:
                    ritmo_diario = ahorrado_meta / dias_creacion
                    ritmo_mensual = ritmo_diario * 30.0

            # Fallback del ritmo: 10% de ingresos de este mes
            if ritmo_mensual <= 0:
                ingresos = Transaccion.objects.filter(
                    usuario=usuario,
                    tipo='INGRESO',
                    fecha__gte=inicio_mes
                ).aggregate(total=Sum('monto'))['total'] or 0.00
                ritmo_mensual = float(ingresos) * 0.10

            # Fallback definitivo (100.000 COP)
            if ritmo_mensual <= 0:
                ritmo_mensual = 100000.00

            # Calcular meses de retraso
            meses_retraso = round(monto_compra / ritmo_mensual, 1)
            # Asegurar mínimo de 1 mes
            if meses_retraso < 1:
                meses_retraso = 1.0

            # Formatear el retraso quitando el decimal si es entero
            meses_retraso_str = str(int(meses_retraso)) if meses_retraso % 1 == 0 else str(meses_retraso)

            nombre_meta = meta_principal.nombre if meta_principal else "Ahorros"
            sugerencia = f"Alto. Si compras esto, retrasarás tu meta de '{nombre_meta}' {meses_retraso_str} meses."

            return Response({
                "aprobado": False,
                "cgl": cgl,
                "meta_afectada": nombre_meta,
                "meses_retraso": meses_retraso,
                "sugerencia": sugerencia
            }, status=status.HTTP_200_OK)
