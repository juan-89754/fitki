import datetime
from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone
from .models import Cuenta, Transaccion, MetaAhorro, Deuda, ProyectoCompra, ItemProyecto

User = get_user_model()

def _formatear_pesos(monto):
    """
    Formatea un número decimal como moneda con separación por miles usando puntos.
    Ej: 900000 -> "$900.000"
    """
    return f"{int(monto):,}".replace(",", ".")


def _avanzar_un_mes(fecha):
    """
    Calcula de forma segura el mismo día del mes siguiente.
    Si el día no existe (ej. 31 de febrero), retrocede hasta el último día válido de ese mes.
    """
    mes_siguiente = fecha.month + 1
    ano_siguiente = fecha.year
    if mes_siguiente > 12:
        mes_siguiente = 1
        ano_siguiente += 1
    dia = fecha.day
    nueva_fecha = None
    while nueva_fecha is None and dia >= 28:
        try:
            nueva_fecha = datetime.date(ano_siguiente, mes_siguiente, dia)
        except ValueError:
            dia -= 1
    if nueva_fecha is None:
        nueva_fecha = datetime.date(ano_siguiente, mes_siguiente, dia)
    return nueva_fecha


class UsuarioRegistroSerializer(serializers.ModelSerializer):
    """
    Serializador para registrar nuevos usuarios con contraseña hasheada.
    """
    password = serializers.CharField(write_only=True)
    nombre = serializers.CharField(required=True)

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'password', 'nombre']

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            first_name=validated_data['nombre'],
            nombre=validated_data['nombre']
        )
        return user


class CuentaSerializer(serializers.ModelSerializer):
    """
    Serializador para el CRUD de cuentas bancarias/billeteras.
    """
    usuario = serializers.PrimaryKeyRelatedField(read_only=True)

    class Meta:
        model = Cuenta
        fields = ['id', 'usuario', 'nombre_banco', 'saldo_actual', 'tipo_cuenta', 'fecha_actualizacion']
        read_only_fields = ['fecha_actualizacion']


class MetaAhorroSerializer(serializers.ModelSerializer):
    """
    Serializador para el CRUD de metas de ahorro/bolsillos.
    Incluye porcentaje de progreso y estimación de tiempo de consecución.
    """
    usuario = serializers.PrimaryKeyRelatedField(read_only=True)
    porcentaje_progreso = serializers.SerializerMethodField()
    meses_restantes_estimados = serializers.SerializerMethodField()

    class Meta:
        model = MetaAhorro
        fields = [
            'id', 'usuario', 'nombre', 'monto_objetivo', 'monto_ahorrado_actual', 
            'fecha_limite', 'porcentaje_progreso', 'meses_restantes_estimados', 'fecha_creacion'
        ]
        read_only_fields = ['fecha_creacion']

    def get_porcentaje_progreso(self, obj):
        if obj.monto_objetivo <= 0:
            return 0.0
        progreso = (float(obj.monto_ahorrado_actual) / float(obj.monto_objetivo)) * 100
        return min(round(progreso, 1), 100.0)

    def get_meses_restantes_estimados(self, obj):
        ahorrado = float(obj.monto_ahorrado_actual)
        objetivo = float(obj.monto_objetivo)
        
        if ahorrado >= objetivo:
            return 0.0
            
        dias_desde_creacion = (timezone.now() - obj.fecha_creacion).days
        if dias_desde_creacion <= 0:
            dias_desde_creacion = 1
            
        faltante = objetivo - ahorrado
        
        if ahorrado <= 0:
            return -1.0  # Indica que no se han hecho abonos aún para proyectar
            
        ritmo_diario = ahorrado / dias_desde_creacion
        ritmo_mensual = ritmo_diario * 30.0
        
        if ritmo_mensual <= 0:
            return -1.0
            
        meses = faltante / ritmo_mensual
        return round(meses, 1)


class DeudaSerializer(serializers.ModelSerializer):
    """
    Serializador para el CRUD de deudas (préstamos/tarjetas).
    Incluye campo dinámico para alertar sobre pagos próximos y simulación de amortización.
    """
    usuario = serializers.PrimaryKeyRelatedField(read_only=True)
    alerta_pago_proximo = serializers.SerializerMethodField()
    cuotas_pendientes_estimadas = serializers.SerializerMethodField()
    total_intereses_estimado = serializers.SerializerMethodField()
    total_a_pagar_estimado = serializers.SerializerMethodField()

    class Meta:
        model = Deuda
        fields = [
            'id', 'usuario', 'nombre', 'monto_total', 'tasa_interes', 
            'cuota_mensual', 'fecha_proximo_pago', 'fecha_limite', 
            'alerta_pago_proximo', 'cuotas_pendientes_estimadas',
            'total_intereses_estimado', 'total_a_pagar_estimado', 'fecha_creacion'
        ]
        read_only_fields = ['fecha_creacion']

    def get_alerta_pago_proximo(self, obj):
        if obj.monto_total <= 0:
            return False
        hoy = timezone.now().date()
        diferencia = obj.fecha_proximo_pago - hoy
        # Alerta activa si el pago vence en los próximos 5 días (y no ha pasado)
        return 0 <= diferencia.days <= 5

    def get_cuotas_pendientes_estimadas(self, obj):
        saldo = float(obj.monto_total)
        tasa = float(obj.tasa_interes) / 100.0
        cuota = float(obj.cuota_mensual)
        
        if saldo <= 0 or cuota <= 0:
            return 0
            
        if cuota <= saldo * tasa:
            return -1  # Cuota insuficiente, deuda crecería de forma indefinida
            
        cuotas = 0
        temp_saldo = saldo
        while temp_saldo > 0.01 and cuotas < 360:
            interes_mes = temp_saldo * tasa
            abono_capital = cuota - interes_mes
            if abono_capital <= 0:
                return -1
            if temp_saldo < cuota:
                temp_saldo = 0
            else:
                temp_saldo -= abono_capital
            cuotas += 1
        return cuotas

    def get_total_intereses_estimado(self, obj):
        saldo = float(obj.monto_total)
        tasa = float(obj.tasa_interes) / 100.0
        cuota = float(obj.cuota_mensual)
        
        if saldo <= 0 or cuota <= 0 or cuota <= saldo * tasa:
            return 0.0
            
        cuotas = 0
        interes_total = 0.0
        temp_saldo = saldo
        while temp_saldo > 0.01 and cuotas < 360:
            interes_mes = temp_saldo * tasa
            abono_capital = cuota - interes_mes
            if abono_capital <= 0:
                break
            interes_total += interes_mes
            if temp_saldo < cuota:
                temp_saldo = 0
            else:
                temp_saldo -= abono_capital
            cuotas += 1
        return round(interes_total, 2)

    def get_total_a_pagar_estimado(self, obj):
        saldo = float(obj.monto_total)
        interes = self.get_total_intereses_estimado(obj)
        return round(saldo + interes, 2)


class TransaccionSerializer(serializers.ModelSerializer):
    """
    Serializador para registrar movimientos financieros de ingresos o gastos.
    Incluye lógica de actualización de saldos, deudas y metas de forma automática.
    """
    usuario = serializers.PrimaryKeyRelatedField(read_only=True)
    cuenta_nombre = serializers.CharField(source='cuenta.nombre_banco', read_only=True)
    sugerencia_ahorro = serializers.SerializerMethodField()

    class Meta:
        model = Transaccion
        fields = [
            'id', 'usuario', 'cuenta', 'cuenta_nombre', 'monto', 
            'tipo', 'categoria', 'fecha', 'descripcion', 
            'meta_ahorro', 'deuda', 'sugerencia_ahorro'
        ]

    def validate_monto(self, value):
        if value <= 0:
            raise serializers.ValidationError("El monto de la transacción debe ser mayor a 0.")
        return value

    def validate(self, attrs):
        cuenta = attrs.get('cuenta')
        usuario = self.context['request'].user
        
        # Verificar que la cuenta pertenezca al usuario autenticado
        if cuenta.usuario != usuario:
            raise serializers.ValidationError({"cuenta": "La cuenta seleccionada no te pertenece."})
            
        # Verificar meta de ahorro si existe
        meta = attrs.get('meta_ahorro')
        if meta and meta.usuario != usuario:
            raise serializers.ValidationError({"meta_ahorro": "La meta de ahorro seleccionada no te pertenece."})

        # Verificar deuda si existe
        deuda = attrs.get('deuda')
        if deuda and deuda.usuario != usuario:
            raise serializers.ValidationError({"deuda": "La deuda seleccionada no te pertenece."})

        return attrs

    def get_sugerencia_ahorro(self, obj):
        """
        Retorna la sugerencia de Fitki inteligente según la categoría del ingreso y el estado de deudas.
        """
        if obj.tipo != 'INGRESO':
            return None

        # 1. Priorizar deudas urgentes
        hoy = timezone.now().date()
        deudas_urgentes = Deuda.objects.filter(
            usuario=obj.usuario,
            monto_total__gt=0,
            fecha_proximo_pago__gte=hoy,
            fecha_proximo_pago__lte=hoy + datetime.timedelta(days=5)
        ).order_by('fecha_proximo_pago')

        if deudas_urgentes.exists():
            deuda = deudas_urgentes.first()
            return f"¡Atención! Fitki sugiere priorizar el pago de tu deuda '{deuda.nombre}' por ${_formatear_pesos(deuda.monto_total)}. Considera abonar antes de ahorrar."

        # 2. Si no hay deudas urgentes, evaluar metas
        metas = MetaAhorro.objects.filter(usuario=obj.usuario).order_by('fecha_limite', 'id')
        if not metas.exists():
            return "Crea una meta de ahorro para sugerirte aportes."

        monto_ingreso = float(obj.monto)
        categoria = obj.categoria.upper()

        # REGLA SEGÚN CATEGORÍA DE INGRESO
        if categoria == 'SALARIO':
            # 30% a meta 1, 10% a meta 2
            if metas.count() >= 2:
                meta1 = metas[0]
                meta2 = metas[1]
                sug_meta1 = monto_ingreso * 0.30
                sug_meta2 = monto_ingreso * 0.10
                return f"Fitki sugiere: Destina el 30% (${_formatear_pesos(sug_meta1)}) a tu meta '{meta1.nombre}' y el 10% (${_formatear_pesos(sug_meta2)}) a '{meta2.nombre}' por ser tu salario mensual."
            else:
                meta = metas[0]
                sug_meta = monto_ingreso * 0.40
                return f"Fitki sugiere: Destina el 40% (${_formatear_pesos(sug_meta)}) a tu meta '{meta.nombre}' por ser tu salario mensual."

        elif categoria == 'FREELANCE':
            # 20% a meta 1, 10% a meta 2 (más moderado por ser ingresos variables)
            if metas.count() >= 2:
                meta1 = metas[0]
                meta2 = metas[1]
                sug_meta1 = monto_ingreso * 0.20
                sug_meta2 = monto_ingreso * 0.10
                return f"¡Buen trabajo en tu freelance! Fitki sugiere ahorrar un 30% total: destina 20% (${_formatear_pesos(sug_meta1)}) a '{meta1.nombre}' y 10% (${_formatear_pesos(sug_meta2)}) a '{meta2.nombre}'."
            else:
                meta = metas[0]
                sug_meta = monto_ingreso * 0.30
                return f"¡Buen trabajo en tu freelance! Fitki sugiere destinar el 30% (${_formatear_pesos(sug_meta)}) a tu meta '{meta.nombre}'."

        else:
            # Rendimientos, Donaciones, Otros (Dinero extra: 50% a meta principal)
            meta = metas[0]
            sug_meta = monto_ingreso * 0.50
            return f"¡Dinero extra! Fitki sugiere destinar el 50% (${_formatear_pesos(sug_meta)}) a tu meta '{meta.nombre}' para alcanzarla más rápido."

    @transaction.atomic
    def create(self, validated_data):
        request = self.context.get('request')
        user = request.user
        cuenta = validated_data['cuenta']
        monto = validated_data['monto']
        tipo = validated_data['tipo']

        # Crear la transacción asignándole el usuario autenticado
        transaccion = Transaccion.objects.create(usuario=user, **validated_data)

        # Actualizar el saldo de la cuenta
        if tipo == 'INGRESO':
            cuenta.saldo_actual += monto
        elif tipo == 'GASTO':
            cuenta.saldo_actual -= monto
        cuenta.save()

        # Lógica adicional si se asocia a metas de ahorro (destinar egresos a metas)
        meta = validated_data.get('meta_ahorro')
        if meta and tipo == 'GASTO':
            meta.monto_ahorrado_actual += monto
            meta.save()

        # Lógica adicional si se asocia a abono de deudas
        deuda = validated_data.get('deuda')
        if deuda and tipo == 'GASTO':
            # Restar abono al total debido
            deuda.monto_total -= monto
            if deuda.monto_total < 0:
                deuda.monto_total = 0

            # Desplazamiento automático del próximo pago en 1 mes si aún queda deuda por pagar
            if deuda.monto_total > 0 and deuda.fecha_proximo_pago:
                nueva_fecha = _avanzar_un_mes(deuda.fecha_proximo_pago)
                # Solo avanzamos si no excede la fecha límite (en caso de que la tenga registrada)
                if not deuda.fecha_limite or nueva_fecha <= deuda.fecha_limite:
                    deuda.fecha_proximo_pago = nueva_fecha

            deuda.save()

        return transaccion






class ItemProyectoSerializer(serializers.ModelSerializer):
    class Meta:
        model = ItemProyecto
        fields = [
            'id', 'proyecto', 'articulo', 'cantidad', 'precio_unitario', 
            'costo_total', 'prioridad', 'nota', 'fecha_creacion'
        ]
        read_only_fields = ['costo_total', 'fecha_creacion']


class ProyectoCompraSerializer(serializers.ModelSerializer):
    usuario = serializers.PrimaryKeyRelatedField(read_only=True)
    items = ItemProyectoSerializer(many=True, read_only=True)
    costo_total = serializers.ReadOnlyField()

    class Meta:
        model = ProyectoCompra
        fields = [
            'id', 'usuario', 'nombre', 'descripcion', 'proveedor', 
            'fecha_ejecucion', 'prioridad', 'estado', 'notas', 
            'etiquetas', 'items', 'costo_total', 'fecha_creacion'
        ]
        read_only_fields = ['fecha_creacion']




