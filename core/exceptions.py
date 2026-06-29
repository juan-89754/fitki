from rest_framework.views import exception_handler
from rest_framework.exceptions import ValidationError

def custom_exception_handler(exc, context):
    """
    Exception handler personalizado para unificar el formato de error retornado por la API.
    Envuelve las respuestas en una estructura JSON legible y fácil de consumir en el cliente.
    """
    response = exception_handler(exc, context)

    if response is not None:
        message = "Ocurrió un error al procesar tu solicitud."
        
        # Estructurar detalles si es un error de validación
        details = None
        if isinstance(exc, ValidationError):
            details = response.data
            # Intentar generar un mensaje general amigable a partir de los detalles
            if isinstance(details, dict):
                first_key = list(details.keys())[0]
                first_val = details[first_key]
                val_str = first_val[0] if isinstance(first_val, list) else str(first_val)
                message = f"Dato inválido en '{first_key}': {val_str}"
            elif isinstance(details, list):
                message = details[0]
        else:
            # Para otros errores con detalle string
            if isinstance(response.data, dict) and "detail" in response.data:
                message = response.data["detail"]
            elif isinstance(response.data, list):
                message = ", ".join(response.data)

        # Reemplazar el data de la respuesta con el formato unificado
        response.data = {
            "error": {
                "code": exc.__class__.__name__,
                "message": message,
                "details": details
            }
        }

    return response
