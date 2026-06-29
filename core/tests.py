import datetime
from django.test import TestCase
from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from django.utils import timezone
from datetime import timedelta
from .models import Cuenta, Transaccion, MetaAhorro, Deuda, ProyectoCompra, ItemProyecto

User = get_user_model()

class FitkiAPITests(APITestCase):
    """
    Suite de pruebas integradas para la API de Fitki (Sprints 1, 2 y 3).
    """

    def setUp(self):
        self.register_url = reverse('api_register')
        self.token_url = reverse('token_obtain_pair')
        self.dashboard_url = reverse('api_dashboard')
        self.asistente_url = reverse('api_asistente_consulta')
        
        self.user_data = {
            "username": "tester",
            "email": "tester@fitki.com",
            "password": "Password123!",
            "nombre": "Test User"
        }

        # Registrar usuario y obtener token
        User.objects.create_user(
            username="tester",
            email="tester@fitki.com",
            password="Password123!",
            nombre="Test User"
        )
        
        response = self.client.post(self.token_url, {
            "username": "tester",
            "password": "Password123!"
        }, format='json')
        
        self.access_token = response.data['access']
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.access_token}')

    def test_dashboard_y_flujo_financiero_base(self):
        cuenta_url = reverse('cuenta-list')
        cuenta_data = {
            "nombre_banco": "Bancolombia",
            "saldo_actual": 2000000.00,
            "tipo_cuenta": "AHORRO"
        }
        response = self.client.post(cuenta_url, cuenta_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        cuenta_id = response.data['id']
        
        transaccion_url = reverse('transaccion-list')
        transaccion_data = {
            "cuenta": cuenta_id,
            "monto": 50000.00,
            "tipo": "GASTO",
            "categoria": "Comida",
            "fecha": timezone.now().isoformat()
        }
        response = self.client.post(transaccion_url, transaccion_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        
        cuenta_detail_url = reverse('cuenta-detail', args=[cuenta_id])
        response = self.client.get(cuenta_detail_url)
        self.assertEqual(float(response.data['saldo_actual']), 1950000.00)

    def test_frentes_de_ahorro_metas_y_proyección(self):
        metas_url = reverse('meta-list')
        meta_data = {
            "nombre": "Viaje a Europa",
            "monto_objetivo": 10000000.00,
            "monto_ahorrado_actual": 1000000.00,
            "fecha_limite": (timezone.now().date() + timedelta(days=180)).isoformat()
        }
        response = self.client.post(metas_url, meta_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['porcentaje_progreso'], 10.0)
        self.assertGreater(response.data['meses_restantes_estimados'], 0)

    def test_simulacion_amortizacion_deudas(self):
        deudas_url = reverse('deuda-list')
        
        # CASO A: Cuota suficiente
        deuda_suficiente = {
            "nombre": "Préstamo Suficiente",
            "monto_total": 500000.00,
            "tasa_interes": 2.00,
            "cuota_mensual": 100000.00,
            "fecha_proximo_pago": timezone.now().date().isoformat()
        }
        resp_suf = self.client.post(deudas_url, deuda_suficiente, format='json')
        self.assertEqual(resp_suf.status_code, status.HTTP_201_CREATED)
        self.assertEqual(resp_suf.data['cuotas_pendientes_estimadas'], 6)

        # CASO B: Cuota insuficiente
        deuda_insuficiente = {
            "nombre": "Préstamo Insuficiente",
            "monto_total": 500000.00,
            "tasa_interes": 2.00,
            "cuota_mensual": 8000.00,
            "fecha_proximo_pago": timezone.now().date().isoformat()
        }
        resp_insuf = self.client.post(deudas_url, deuda_insuficiente, format='json')
        self.assertEqual(resp_insuf.status_code, status.HTTP_201_CREATED)
        self.assertEqual(resp_insuf.data['cuotas_pendientes_estimadas'], -1)

    def test_gestion_de_deudas_y_desplazamiento_fecha(self):
        deudas_url = reverse('deuda-list')
        proximo_pago = timezone.now().date() + timedelta(days=3)
        fecha_limite = timezone.now().date() + timedelta(days=365)
        
        deuda_data = {
            "nombre": "Tarjeta Visa",
            "monto_total": 500000.00,
            "tasa_interes": 2.50,
            "cuota_mensual": 100000.00,
            "fecha_proximo_pago": proximo_pago.isoformat(),
            "fecha_limite": fecha_limite.isoformat()
        }
        response = self.client.post(deudas_url, deuda_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        deuda_id = response.data['id']

        cuenta_url = reverse('cuenta-list')
        cuenta_resp = self.client.post(cuenta_url, {
            "nombre_banco": "Bancolombia",
            "saldo_actual": 1000000.00,
            "tipo_cuenta": "AHORRO"
        }, format='json')
        cuenta_id = cuenta_resp.data['id']

        transaccion_url = reverse('transaccion-list')
        self.client.post(transaccion_url, {
            "cuenta": cuenta_id,
            "monto": 100000.00,
            "tipo": "GASTO",
            "categoria": "Deudas",
            "deuda": deuda_id,
            "fecha": timezone.now().isoformat()
        }, format='json')

        response_deuda = self.client.get(reverse('deuda-detail', args=[deuda_id]))
        self.assertEqual(float(response_deuda.data['monto_total']), 400000.00)

    def test_sugerencias_diferenciadas_de_ahorro_por_categoria(self):
        metas_url = reverse('meta-list')
        self.client.post(metas_url, {
            "nombre": "Viaje",
            "monto_objetivo": 5000000.00,
            "fecha_limite": (timezone.now().date() + timedelta(days=100)).isoformat()
        }, format='json')
        
        self.client.post(metas_url, {
            "nombre": "Emergencia",
            "monto_objetivo": 2000000.00,
            "fecha_limite": (timezone.now().date() + timedelta(days=200)).isoformat()
        }, format='json')

        cuenta_url = reverse('cuenta-list')
        cuenta_response = self.client.post(cuenta_url, {
            "nombre_banco": "Bancolombia",
            "saldo_actual": 0.00,
            "tipo_cuenta": "AHORRO"
        }, format='json')
        cuenta_id = cuenta_response.data['id']

        transaccion_url = reverse('transaccion-list')

        salario_resp = self.client.post(transaccion_url, {
            "cuenta": cuenta_id,
            "monto": 3000000.00,
            "tipo": "INGRESO",
            "categoria": "Salario",
            "fecha": timezone.now().isoformat()
        }, format='json')
        self.assertIn("30% ($900.000)", salario_resp.data['sugerencia_ahorro'])

    def test_asistente_consulta_viabilidad(self):
        # 1. Crear Cuenta con $2.000.000
        cuenta_url = reverse('cuenta-list')
        cuenta_resp = self.client.post(cuenta_url, {
            "nombre_banco": "Bancolombia",
            "saldo_actual": 2000000.00,
            "tipo_cuenta": "AHORRO"
        }, format='json')
        cuenta_id = cuenta_resp.data['id']

        # 2. Crear Meta "Viaje" de $10.000.000 con $1.000.000 ahorrado, fecha límite en 10 meses
        # Aporte sugerido mensual = (10M - 1M) / 10 = 900.000
        metas_url = reverse('meta-list')
        self.client.post(metas_url, {
            "nombre": "Viaje",
            "monto_objetivo": 10000000.00,
            "monto_ahorrado_actual": 1000000.00,
            "fecha_limite": (timezone.now().date() + timedelta(days=300)).isoformat()
        }, format='json')

        # 3. Registrar Gasto Fijo de Servicios por $200.000
        transaccion_url = reverse('transaccion-list')
        self.client.post(transaccion_url, {
            "cuenta": cuenta_id,
            "monto": 200000.00,
            "tipo": "GASTO",
            "categoria": "Servicios",
            "fecha": timezone.now().isoformat()
        }, format='json')

        # 4. Registrar Deuda con cuota mensual de $100.000
        deudas_url = reverse('deuda-list')
        self.client.post(deudas_url, {
            "nombre": "Tarjeta",
            "monto_total": 500000.00,
            "tasa_interes": 2.00,
            "cuota_mensual": 100000.00,
            "fecha_proximo_pago": timezone.now().date().isoformat()
        }, format='json')

        # CGL calculado = 1.800.000 (saldo real tras gasto) - 200.000 (gastos fijos) - 100.000 (deudas) - 900.000 (metas) = 600.000 COP

        # Consulta A: Compra viable por $200.000 (Zapatos)
        resp_viable = self.client.post(self.asistente_url, {"monto": 200000.00}, format='json')
        self.assertEqual(resp_viable.status_code, status.HTTP_200_OK)
        self.assertTrue(resp_viable.data['aprobado'])
        self.assertIn("Te sobran $400.000", resp_viable.data['sugerencia'])

        # Consulta B: Compra inviable por $1.200.000 (Laptop)
        # Ritmo de ahorro real histórico meta "Viaje": $1.000.000 ahorrado. Asumiendo días=1, ritmo_mensual = 30.000.000.
        # Pero para que el ritmo sea más bajo en el test y de un retraso coherente,
        # la simulación de retraso debe calcularse.
        resp_inviable = self.client.post(self.asistente_url, {"monto": 1200000.00}, format='json')
        self.assertEqual(resp_inviable.status_code, status.HTTP_200_OK)
        self.assertFalse(resp_inviable.data['aprobado'])
        self.assertIn("retrasarás tu meta de 'Viaje'", resp_inviable.data['sugerencia'])




    def test_proyecto_compra_y_asistente_analisis(self):
        # 1. Crear Proyecto de Compra "Remodelación Cocina"
        proyectos_url = reverse('proyecto-compra-list')
        proyecto_data = {
            "nombre": "Remodelación Cocina",
            "descripcion": "Cosas para renovar la cocina",
            "proveedor": "Homecenter",
            "fecha_ejecucion": (timezone.now().date() + timedelta(days=20)).isoformat(),
            "prioridad": "MEDIA",
            "estado": "PENDIENTE",
            "notas": "Buscar descuentos"
        }
        resp_proj = self.client.post(proyectos_url, proyecto_data, format='json')
        self.assertEqual(resp_proj.status_code, status.HTTP_201_CREATED)
        proyecto_id = resp_proj.data['id']

        # 2. Agregar ítems al proyecto
        items_url = reverse('item-proyecto-list')
        item1_data = {
            "proyecto": proyecto_id,
            "articulo": "Nevera",
            "cantidad": 1,
            "precio_unitario": 2000000.00,
            "prioridad": "ALTA"
        }
        resp_item1 = self.client.post(items_url, item1_data, format='json')
        self.assertEqual(resp_item1.status_code, status.HTTP_201_CREATED)
        
        item2_data = {
            "proyecto": proyecto_id,
            "articulo": "Estufa",
            "cantidad": 1,
            "precio_unitario": 1000000.00,
            "prioridad": "BAJA"
        }
        self.client.post(items_url, item2_data, format='json')

        # Verificar que el costo_total del proyecto expuesto en la API se sume dinámicamente como propiedad
        resp_proj_get = self.client.get(f"{proyectos_url}{proyecto_id}/")
        self.assertEqual(float(resp_proj_get.data['costo_total']), 3000000.00)

        # 3. Test Asistente: Analizar el proyecto "Remodelación Cocina"
        # Usamos saldo_prueba de 4.000.000 (CGL = 4M, viable porque total = 3M)
        consulta_data = {
            "query": "Fitki, analiza mi proyecto 'Remodelación Cocina'",
            "saldo_prueba": 4000000.00
        }
        resp_asis = self.client.post(self.asistente_url, consulta_data, format='json')
        self.assertEqual(resp_asis.status_code, status.HTTP_200_OK)
        self.assertTrue(resp_asis.data['aprobado'])
        self.assertIn("VIABLE", resp_asis.data['sugerencia'])

        # 4. Test Asistente: Proyecto no viable pero con recomendación de alta prioridad
        # Usamos saldo_prueba de 2.500.000 (CGL = 2.5M, total = 3M, alta prioridad es 2M)
        consulta_data_inviable = {
            "query": "analiza el proyecto de Remodelación Cocina",
            "saldo_prueba": 2500000.00
        }
        resp_asis_inv = self.client.post(self.asistente_url, consulta_data_inviable, format='json')
        self.assertEqual(resp_asis_inv.status_code, status.HTTP_200_OK)
        self.assertFalse(resp_asis_inv.data['aprobado'])
        self.assertIn("priorizar los productos de 'Alta' prioridad", resp_asis_inv.data['sugerencia'])

        # 5. Test Asistente: Conflictos entre múltiples proyectos
        # Crear un segundo proyecto de 2.000.000
        proyecto2_data = {
            "nombre": "Proyecto Tecnología",
            "descripcion": "Celular y audífonos",
            "proveedor": "Amazon",
            "fecha_ejecucion": (timezone.now().date() + timedelta(days=25)).isoformat(),
            "prioridad": "MEDIA",
            "estado": "PENDIENTE"
        }
        resp_proj2 = self.client.post(proyectos_url, proyecto2_data, format='json')
        proyecto2_id = resp_proj2.data['id']
        self.client.post(items_url, {
            "proyecto": proyecto2_id,
            "articulo": "Celular",
            "cantidad": 1,
            "precio_unitario": 2000000.00,
            "prioridad": "MEDIA"
        }, format='json')

        # CGL = 4M, Proyecto1 = 3M, Proyecto2 = 2M. Total = 5M > 4M CGL.
        # Al preguntar por Proyecto1, debe alertar de conflicto con Proyecto2
        consulta_conflicto = {
            "query": "analiza el proyecto de Remodelación Cocina",
            "saldo_prueba": 4000000.00
        }
        resp_conf = self.client.post(self.asistente_url, consulta_conflicto, format='json')
        self.assertEqual(resp_conf.status_code, status.HTTP_200_OK)
        self.assertTrue(resp_conf.data['aprobado']) # Es viable individualmente
        self.assertIn("también tienes el proyecto 'Proyecto Tecnología' pendiente", resp_conf.data['sugerencia'])



