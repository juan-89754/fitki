from django.contrib.auth.models import AbstractUser
from django.db import models

class Usuario(AbstractUser):
    """
    Modelo de usuario personalizado que extiende AbstractUser.
    Permite hacer el email único e indexado para búsquedas y autenticación rápidas.
    """
    email = models.EmailField(unique=True, db_index=True)
    nombre = models.CharField(max_length=150, blank=True)
    fecha_creacion = models.DateTimeField(auto_now_add=True)

    # Definir campos requeridos
    REQUIRED_FIELDS = ['email']

    def __str__(self):
        return self.username or self.email


class Cuenta(models.Model):
    """
    Representa las cuentas bancarias, billeteras virtuales o efectivo del usuario.
    """
    TIPO_CUENTA_CHOICES = [
        ('AHORRO', 'Ahorro'),
        ('CORRIENTE', 'Corriente'),
        ('EFECTIVO', 'Efectivo'),
    ]

    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, related_name='cuentas')
    nombre_banco = models.CharField(max_length=100, help_text="Ej: Bancolombia, Nequi, Efectivo")
    saldo_actual = models.DecimalField(max_digits=15, decimal_places=2, default=0.00, help_text="Saldo disponible")
    tipo_cuenta = models.CharField(max_length=50, choices=TIPO_CUENTA_CHOICES, default='AHORRO')
    fecha_actualizacion = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.nombre_banco} ({self.get_tipo_cuenta_display()}) - {self.usuario.username}"


class MetaAhorro(models.Model):
    """
    Representa los frentes de ahorro o bolsillos virtuales configurados por el usuario.
    """
    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, related_name='metas_ahorro')
    nombre = models.CharField(max_length=100, help_text="Ej: Viaje a Europa, Fondo de Emergencia")
    monto_objetivo = models.DecimalField(max_digits=15, decimal_places=2, help_text="Meta total a ahorrar")
    monto_ahorrado_actual = models.DecimalField(max_digits=15, decimal_places=2, default=0.00, help_text="Ahorrado acumulado")
    fecha_limite = models.DateField(help_text="Fecha máxima para alcanzar la meta")
    fecha_creacion = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.nombre} ({self.monto_ahorrado_actual} de {self.monto_objetivo})"


class Deuda(models.Model):
    """
    Representa las obligaciones financieras del usuario (tarjetas de crédito, préstamos).
    """
    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, related_name='deudas')
    nombre = models.CharField(max_length=100, help_text="Ej: Tarjeta Visa, Crédito de Estudio")
    monto_total = models.DecimalField(max_digits=15, decimal_places=2, help_text="Saldo total pendiente")
    tasa_interes = models.DecimalField(max_digits=5, decimal_places=2, help_text="Tasa de interés (%)")
    cuota_mensual = models.DecimalField(max_digits=15, decimal_places=2, help_text="Valor aproximado de la cuota mensual")
    fecha_proximo_pago = models.DateField(help_text="Fecha límite de pago más cercana")
    fecha_limite = models.DateField(null=True, blank=True, help_text="Fecha de finalización total del crédito o deuda")
    fecha_creacion = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.nombre} - Balance: {self.monto_total}"


class Transaccion(models.Model):
    """
    Registra todo movimiento de entrada (ingreso) o salida (gasto).
    Actualiza el saldo de la cuenta asociada y, opcionalmente, deudas o metas.
    """
    TIPO_TRANSACCION_CHOICES = [
        ('INGRESO', 'Ingreso'),
        ('GASTO', 'Gasto'),
    ]

    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, related_name='transacciones')
    cuenta = models.ForeignKey(Cuenta, on_delete=models.CASCADE, related_name='transacciones')
    monto = models.DecimalField(max_digits=15, decimal_places=2, help_text="Monto de la transacción")
    tipo = models.CharField(max_length=10, choices=TIPO_TRANSACCION_CHOICES)
    categoria = models.CharField(max_length=50, help_text="Ej: Comida, Transporte, Salario, Ocio")
    fecha = models.DateTimeField(help_text="Fecha del movimiento")
    descripcion = models.CharField(max_length=255, blank=True, null=True)
    
    # Opcionales para vinculación de movimientos a bolsillos o deudas
    meta_ahorro = models.ForeignKey(
        MetaAhorro, 
        on_delete=models.SET_NULL, 
        blank=True, 
        null=True, 
        related_name='transacciones',
        help_text="Vincular a un bolsillo de ahorro"
    )
    deuda = models.ForeignKey(
        Deuda, 
        on_delete=models.SET_NULL, 
        blank=True, 
        null=True, 
        related_name='transacciones',
        help_text="Vincular a abonos a deudas"
    )

    def __str__(self):
        return f"{self.tipo} - {self.monto} ({self.categoria}) en {self.cuenta.nombre_banco}"
