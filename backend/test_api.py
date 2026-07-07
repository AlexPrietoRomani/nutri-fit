import io
import sys
from fastapi.testclient import TestClient

# Asegurar que el directorio actual esté en el path para poder importar app.main
sys.path.insert(0, ".")
from app.main import app

client = TestClient(app)

def run_tests():
    """
    Ejecuta pruebas sobre los endpoints del API de Nutri-Fit AI Backend.
    """
    print("=== INICIANDO PRUEBAS DE ENDPOINTS DE IA ===")
    
    # 1. Probar endpoint raíz
    print("\n[Test 1] Probando GET / (Raíz)...")
    response = client.get("/")
    assert response.status_code == 200, f"Error en GET /: {response.text}"
    print(f"Respuesta GET /: {response.json()}")
    print("-> GET / PASADO.")

    # 2. Probar endpoint de salud
    print("\n[Test 2] Probando GET /health...")
    response = client.get("/health")
    assert response.status_code == 200, f"Error en GET /health: {response.text}"
    print(f"Respuesta GET /health: {response.json()}")
    print("-> GET /health PASADO.")

    # Datos simulados de imagen (bytes ficticios)
    dummy_image = io.BytesIO(b"dummy_image_binary_content_for_testing_purposes")
    
    # 3. Probar /analyze-meal con subida de archivo
    print("\n[Test 3] Probando POST /analyze-meal con archivo de imagen...")
    files = {"file": ("meal.jpg", dummy_image, "image/jpeg")}
    response = client.post("/analyze-meal", files=files)
    assert response.status_code == 200, f"Error en POST /analyze-meal (archivo): {response.text}"
    result = response.json()
    print("Respuesta de análisis de comida:")
    print(f"  - Alimentos: {result.get('food_items')}")
    print(f"  - Calorías: {result.get('calories')} kcal")
    print(f"  - Proteínas: {result.get('protein')}g, Carbohidratos: {result.get('carbohydrates')}g, Grasas: {result.get('fat')}g")
    print(f"  - Nota: {result.get('notes')}")
    print("-> POST /analyze-meal (archivo) PASADO.")

    # 4. Probar /analyze-meal con URL
    print("\n[Test 4] Probando POST /analyze-meal con URL de imagen (mock)...")
    form_data = {"image_url": "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png"}
    response = client.post("/analyze-meal", data=form_data)
    assert response.status_code == 200, f"Error en POST /analyze-meal (URL): {response.text}"
    print("-> POST /analyze-meal (URL) PASADO.")

    # 5. Probar /identify-machine con subida de archivo
    print("\n[Test 5] Probando POST /identify-machine con archivo de imagen...")
    dummy_image.seek(0)
    files = {"file": ("gym_machine.jpg", dummy_image, "image/jpeg")}
    response = client.post("/identify-machine", files=files)
    assert response.status_code == 200, f"Error en POST /identify-machine (archivo): {response.text}"
    result = response.json()
    print("Respuesta de identificación de máquina:")
    print(f"  - Nombre de máquina: {result.get('machine_name')}")
    print(f"  - Músculos objetivos: {result.get('target_muscles')}")
    print(f"  - Ejercicios asociados: {result.get('associated_exercises')}")
    print(f"  - Consejos de seguridad: {result.get('safety_tips')}")
    print("-> POST /identify-machine (archivo) PASADO.")

    # 6. Probar /identify-machine con URL
    print("\n[Test 6] Probando POST /identify-machine con URL de imagen (mock)...")
    form_data = {"image_url": "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png"}
    response = client.post("/identify-machine", data=form_data)
    assert response.status_code == 200, f"Error en POST /identify-machine (URL): {response.text}"
    print("-> POST /identify-machine (URL) PASADO.")
    
    print("\n=== TODAS LAS PRUEBAS COMPLETADAS CON ÉXITO ===")

if __name__ == "__main__":
    run_tests()
