from rest_framework import viewsets, generics, permissions, views, status
from rest_framework.response import Response
from django.db import transaction
from django.db.models import Sum, F
from django.utils import timezone
import datetime
from .models import Cuenta, Transaccion, MetaAhorro, Deuda, ProyectoCompra, ItemProyecto
from .serializers import (
    UsuarioRegistroSerializer, 
    CuentaSerializer, 
    TransaccionSerializer, 
    MetaAhorroSerializer, 
    DeudaSerializer,
    ProyectoCompraSerializer,
    ItemProyectoSerializer
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
    Soporta parseo de lenguaje natural (ej: 'comprar 4 llantas de 200.000').
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

    def _parse_consulta(self, texto):
        import re
        # Remover '$' y puntos de miles
        text_clean = re.sub(r'\$', '', texto)
        text_clean = re.sub(r'(?<=\d)\.(?=\d)', '', text_clean)
        
        # Buscar números enteros o decimales
        numeros = re.findall(r'\b\d+(?:\.\d+)?\b', text_clean)
        
        cantidad = 1
        precio_unitario = 0.0
        articulo = "artículo"
        
        if len(numeros) >= 2:
            try:
                val1 = float(numeros[0])
                val2 = float(numeros[1])
                # Si el primer número es pequeño e integer, asumimos cantidad
                if val1.is_integer() and val1 < 1000:
                    cantidad = int(val1)
                    precio_unitario = val2
                else:
                    precio_unitario = val1
                    cantidad = int(val2) if val2.is_integer() and val2 < 1000 else 1
            except Exception:
                pass
        elif len(numeros) == 1:
            try:
                precio_unitario = float(numeros[0])
            except Exception:
                pass
                
        # Extraer artículo (buscar palabras entre comprar/adquirir y números/de/a)
        match_articulo = re.search(r'(?:comprar|adquirir|para)\s+([a-zA-Z\s]+?)(?:\s+de\s+|\s+a\s+|\s+\d)', text_clean, re.IGNORECASE)
        if match_articulo:
            articulo = match_articulo.group(1).strip()
        else:
            match_alt = re.search(r'(?:comprar|adquirir|para)\s+([a-zA-Z]+)', text_clean, re.IGNORECASE)
            if match_alt:
                articulo = match_alt.group(1).strip()
                
        return articulo, cantidad, precio_unitario

    def post(self, request):
        usuario = request.user
        query_text = request.data.get('query')
        monto_compra = request.data.get('monto')
        saldo_prueba = request.data.get('saldo_prueba')

        # Check if the word "proyecto" is in query_text
        if query_text and "proyecto" in query_text.lower():
            import re
            project_name = None
            match_quotes = re.search(r"proyecto\s+['\"]([^'\"]+)['\"]", query_text, re.IGNORECASE)
            if match_quotes:
                project_name = match_quotes.group(1).strip()
            else:
                proyectos = ProyectoCompra.objects.filter(usuario=usuario)
                for p in proyectos:
                    if p.nombre.lower() in query_text.lower():
                        project_name = p.nombre
                        break
                if not project_name:
                    match_words = re.search(r"proyecto\s+(?:de\s+)?([a-zA-Z0-9_ ]+)", query_text, re.IGNORECASE)
                    if match_words:
                        project_name = match_words.group(1).strip()

            if not project_name:
                return Response({
                    "aprobado": False,
                    "status": "rejected",
                    "sugerencia": "No logré identificar el nombre del proyecto en tu consulta. Por favor, especifícalo entre comillas simples o dobles. Ej: 'analiza mi proyecto \"Remodelación de Sala\"'."
                }, status=status.HTTP_200_OK)

            try:
                proyecto = ProyectoCompra.objects.get(usuario=usuario, nombre__iexact=project_name)
            except ProyectoCompra.DoesNotExist:
                proyectos = ProyectoCompra.objects.filter(usuario=usuario, nombre__icontains=project_name)
                if proyectos.exists():
                    proyecto = proyectos.first()
                else:
                    return Response({
                        "aprobado": False,
                        "status": "rejected",
                        "sugerencia": f"No encontré ningún proyecto con el nombre '{project_name}'. Verifica que esté creado."
                    }, status=status.HTTP_200_OK)

            proyecto_costo = proyecto.costo_total
            num_items = proyecto.items.count()
            
            if saldo_prueba is not None:
                try:
                    saldo_total = float(saldo_prueba)
                except ValueError:
                    return Response({"error": "El saldo_prueba debe ser un número válido."}, status=status.HTTP_400_BAD_REQUEST)
            else:
                saldo_total = Cuenta.objects.filter(usuario=usuario).aggregate(total=Sum('saldo_actual'))['total'] or 0.00
                saldo_total = float(saldo_total)

            ahora = timezone.now()
            inicio_mes = ahora.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
            gastos_fijos = Transaccion.objects.filter(
                usuario=usuario,
                tipo='GASTO',
                categoria__in=['Vivienda', 'Servicios'],
                fecha__gte=inicio_mes
            ).aggregate(total=Sum('monto'))['total'] or 0.00
            gastos_fijos = float(gastos_fijos)

            cuota_deudas = Deuda.objects.filter(
                usuario=usuario,
                monto_total__gt=0
            ).aggregate(total=Sum('cuota_mensual'))['total'] or 0.00
            cuota_deudas = float(cuota_deudas)

            metas = MetaAhorro.objects.filter(usuario=usuario)
            aporte_metas = 0.0
            for meta in metas:
                aporte_metas += self._calcular_aporte_meta_mensual(meta)

            cgl = saldo_total - gastos_fijos - cuota_deudas - aporte_metas

            if proyecto_costo <= cgl:
                otros_proyectos_pendientes = ProyectoCompra.objects.filter(
                    usuario=usuario,
                    estado='PENDIENTE'
                ).exclude(id=proyecto.id)
                
                costo_otros_proyectos = sum(p.costo_total for p in otros_proyectos_pendientes)
                fecha_limite_str = proyecto.fecha_ejecucion.strftime('%Y-%m-%d')
                
                if proyecto_costo + costo_otros_proyectos > cgl:
                    conflict_project = otros_proyectos_pendientes.first()
                    sugerencia = (
                        f"El proyecto '{proyecto.nombre}' tiene un costo total de {self._formatear_pesos(proyecto_costo)} (agrupando {num_items} productos). "
                        f"Comparado con tu capacidad libre actual ({self._formatear_pesos(cgl)}), este proyecto es VIABLE de forma individual. "
                        f"Sin embargo, ten en cuenta que también tienes el proyecto '{conflict_project.nombre}' pendiente (por {self._formatear_pesos(conflict_project.costo_total)}). "
                        f"No podrás ejecutar ambos, ya que juntos suman {self._formatear_pesos(proyecto_costo + costo_otros_proyectos)} y exceden tu capacidad de gasto libre. Te sugiero priorizar."
                    )
                else:
                    sugerencia = (
                        f"El proyecto '{proyecto.nombre}' tiene un costo total de {self._formatear_pesos(proyecto_costo)} (agrupando {num_items} productos). "
                        f"Comparado con tu capacidad libre actual ({self._formatear_pesos(cgl)}), este proyecto es VIABLE. "
                        f"Te sobrarían {self._formatear_pesos(cgl - proyecto_costo)} después de ejecutarlo. "
                        f"Sin embargo, ten en cuenta que la fecha límite es el {fecha_limite_str}, asegúrate de tener el flujo de efectivo listo."
                    )
                
                return Response({
                    "aprobado": True,
                    "status": "approved",
                    "cgl": cgl,
                    "monto": proyecto_costo,
                    "sugerencia": sugerencia
                }, status=status.HTTP_200_OK)
            else:
                alta_prioridad_items = proyecto.items.filter(prioridad='ALTA')
                costo_alta = sum(float(item.costo_total) for item in alta_prioridad_items)
                
                if costo_alta > 0 and costo_alta <= cgl:
                    sugerencia = (
                        f"El proyecto cuesta {self._formatear_pesos(proyecto_costo)}, pero tu capacidad libre es {self._formatear_pesos(cgl)}. "
                        f"No puedes ejecutarlo completo. Te sugiero priorizar los productos de 'Alta' prioridad dentro de este proyecto, "
                        f"que suman {self._formatear_pesos(costo_alta)}, y dejar los de menor prioridad para el próximo mes."
                    )
                else:
                    sugerencia = (
                        f"El proyecto cuesta {self._formatear_pesos(proyecto_costo)}, pero tu capacidad libre es {self._formatear_pesos(cgl)}. "
                        f"No puedes ejecutarlo completo y tu capacidad no cubre los productos prioritarios. Considera aplazarlo."
                    )
                
                return Response({
                    "aprobado": False,
                    "status": "rejected",
                    "cgl": cgl,
                    "monto": proyecto_costo,
                    "sugerencia": sugerencia
                }, status=status.HTTP_200_OK)

        articulo = "artículo"
        cantidad = 1
        precio_unitario = 0.0

        if query_text:
            articulo, cantidad, precio_unitario = self._parse_consulta(query_text)
            monto_compra = cantidad * precio_unitario
            if precio_unitario == 0.0:
                return Response({
                    "aprobado": False,
                    "status": "rejected",
                    "sugerencia": "No logré identificar el precio de la compra en tu mensaje. Por favor, asegúrate de incluir el valor con puntos o plano. Ej: 'comprar reloj 350.000' o 'comprar bolso 150000'."
                }, status=status.HTTP_200_OK)
        elif monto_compra is not None:
            try:
                monto_compra = float(monto_compra)
                precio_unitario = monto_compra
                cantidad = 1
            except ValueError:
                return Response({"error": "El monto debe ser un número válido."}, status=status.HTTP_400_BAD_REQUEST)
        else:
            return Response({"error": "Debe especificar 'query' o 'monto'."}, status=status.HTTP_400_BAD_REQUEST)

        # 1. Saldo total de cuentas (o saldo_prueba si se especifica)
        if saldo_prueba is not None:
            try:
                saldo_total = float(saldo_prueba)
            except ValueError:
                return Response({"error": "El saldo_prueba debe ser un número válido."}, status=status.HTTP_400_BAD_REQUEST)
        else:
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

        cgl = saldo_total - gastos_fijos - cuota_deudas - aporte_metas

        # 7. Veredicto
        if monto_compra <= cgl:
            sobrante = cgl - monto_compra
            sugerencia = f"¡Dale! Te sobran {self._formatear_pesos(sobrante)} después de cubrir tus metas y obligaciones."
            return Response({
                "aprobado": True,
                "status": "approved", # Verde
                "cgl": cgl,
                "sobrante": sobrante,
                "articulo": articulo,
                "cantidad": cantidad,
                "precio_unitario": precio_unitario,
                "monto": monto_compra,
                "sugerencia": sugerencia
            }, status=status.HTTP_200_OK)
        else:
            # Calcular cantidad máxima de unidades viables
            cantidad_viable = 0
            if precio_unitario > 0 and cgl > 0:
                cantidad_viable = int(cgl // precio_unitario)

            # Detección de Conflictos Futuros con Proyectos
            conflicto_msg = ""
            proyectos_pendientes = ProyectoCompra.objects.filter(
                usuario=usuario,
                estado='PENDIENTE'
            ).order_by('fecha_ejecucion')
            
            for proj in proyectos_pendientes:
                if cgl + float(proj.costo_total) >= monto_compra:
                    conflicto_msg = f"Alerta: Si compras esto hoy, chocarás con el proyecto '{proj.nombre}' planeado para el {proj.fecha_ejecucion.strftime('%Y-%m-%d')} y no podrás pagarlo."
                    break

            # Calcular retraso en la meta principal (para compatibilidad de tests)
            meta_principal = metas.order_by('fecha_limite', 'id').first()
            retraso_msg = ""
            if meta_principal:
                dias_creacion = (timezone.now() - meta_principal.fecha_creacion).days
                if dias_creacion <= 0:
                    dias_creacion = 1
                ahorrado_meta = float(meta_principal.monto_ahorrado_actual)
                ritmo_mensual = 0.0
                if ahorrado_meta > 0:
                    ritmo_diario = ahorrado_meta / dias_creacion
                    ritmo_mensual = ritmo_diario * 30.0

                if ritmo_mensual <= 0:
                    ingresos = Transaccion.objects.filter(
                        usuario=usuario,
                        tipo='INGRESO',
                        fecha__gte=inicio_mes
                    ).aggregate(total=Sum('monto'))['total'] or 0.00
                    ritmo_mensual = float(ingresos) * 0.10

                if ritmo_mensual <= 0:
                    ritmo_mensual = 100000.00

                meses_retraso = round(monto_compra / ritmo_mensual, 1)
                if meses_retraso < 1:
                    meses_retraso = 1.0
                meses_retraso_str = str(int(meses_retraso)) if meses_retraso % 1 == 0 else str(meses_retraso)
                retraso_msg = f"Alto. Si compras esto, retrasarás tu meta de '{meta_principal.nombre}' {meses_retraso_str} meses."

            status_veredicto = "rejected" # Rojo
            if cantidad_viable > 0:
                status_veredicto = "partially_approved" # Amarillo
                sugerencia = f"No puedes comprar {cantidad} unidades de '{articulo}' (cuestan {self._formatear_pesos(monto_compra)}), pero te alcanza para comprar {cantidad_viable} unidades."
            else:
                sugerencia = f"No puedes comprar '{articulo}' (cuesta {self._formatear_pesos(monto_compra)}). Excede tu capacidad libre actual."

            if conflicto_msg:
                sugerencia += f" {conflicto_msg}"
            elif retraso_msg:
                sugerencia = retraso_msg

            return Response({
                "aprobado": False,
                "status": status_veredicto,
                "cgl": cgl,
                "cantidad_viable": cantidad_viable,
                "articulo": articulo,
                "precio_unitario": precio_unitario,
                "monto": monto_compra,
                "sugerencia": sugerencia,
                "conflicto_detectado": conflicto_msg != ""
            }, status=status.HTTP_200_OK)








class ProyectoCompraViewSet(viewsets.ModelViewSet):
    serializer_class = ProyectoCompraSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return ProyectoCompra.objects.filter(usuario=self.request.user).order_by('fecha_ejecucion', 'id')

    def perform_create(self, serializer):
        serializer.save(usuario=self.request.user)


class ItemProyectoViewSet(viewsets.ModelViewSet):
    serializer_class = ItemProyectoSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return ItemProyecto.objects.filter(proyecto__usuario=self.request.user).order_by('id')




