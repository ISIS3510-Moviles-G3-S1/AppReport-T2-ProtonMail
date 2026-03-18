# 🔐 API Keys Setup Guide

Este documento explica cómo configurar las API keys de forma segura sin exponerlas en Git.

## ✅ Requisitorios de Seguridad

- ❌ **NUNCA** commitear API keys a Git
- ✅ **SIEMPRE** usar Variables de Build (Build Settings) en Xcode
- ✅ Usar archivo `.xcconfig` ignorado por git
- ✅ Incluir archivo `.example` como referencia

---

## 🛠️ Configuración en Mac (Para tu equipo)

### **Paso 1: Copiar archivo de configuración**

```bash
cd UniMarket-Swift
cp Config.xcconfig.example Config.xcconfig
```

### **Paso 2: Editar Config.xcconfig con valores reales**

Abre `Config.xcconfig` y reemplaza los valores:

```xcconfig
// Config.xcconfig
CLARIFAI_API_KEY = tu_api_key_real_aqui
CLARIFAI_BASE_URL = https://api.clarifai.com/v2
APPAREL_MODEL_ID = e0be3b9d6a454f0493ac3a30784001ff
```

### **Paso 3: Configurar Xcode**

1. Abre `UniMarket-Swift.xcodeproj` en Xcode
2. Selecciona el proyecto en el navegador
3. Selecciona **Build Settings**
4. Busca "Build Configuration File"
5. En el target `UniMarket-Swift`:
   - **Debug**: Asigna `Config.xcconfig`
   - **Release**: Asigna `Config.xcconfig`

O edita directamente `project.pbxproj`:

```bash
open -a Xcode UniMarket-Swift.xcodeproj
# Menu: Build Settings → Search "config"
# Build Configuration File → Select Config.xcconfig
```

### **Paso 4: Usar variables en Info.plist**

En lugar de valores hardcodeados, usa referencias a Build Settings:

```xml
<key>CLARIFAI_API_KEY</key>
<string>$(CLARIFAI_API_KEY)</string>
```

### **Paso 5: Verificar en APIConfig.swift**

El código ya lee desde Info.plist:

```swift
if let key = Bundle.main.infoDictionary?["CLARIFAI_API_KEY"] as? String {
    return key
}
```

---

## 📁 Estructura de Archivos

```
UniMarket-Swift/
├── .gitignore                    ← Ignora Config.xcconfig
├── Config.xcconfig.example       ← Plantilla (sí commitear)
├── Config.xcconfig               ← ⚠️ NO COMMITEAR (ignorado por git)
├── UniMarket-Swift.xcodeproj/
│   └── project.pbxproj          ← Referencia Config.xcconfig
└── UniMarket-Swift/
    └── Info.plist               ← Lee $(CLARIFAI_API_KEY)
```

---

## 🔑 Obtener tu API Key de Clarifai

1. Ve a https://clarifai.com/signup
2. Crea cuenta y verifica email
3. Inicia sesión
4. Vai a **Settings** → **API Keys**
5. Copia tu API Key
6. Pégala en `Config.xcconfig`

---

## ✔️ Verificar que funciona

En Xcode, abre:
- **Build Phases**
- Verifica que el archivo de configuración se cargó correctamente
- Compila y ejecuta la app

Si ves un error "Unauthorized API key", revisa:
- [ ] API key copiada correctamente en `Config.xcconfig`
- [ ] `Config.xcconfig` está asignado en Build Settings
- [ ] `Info.plist` usa `$(CLARIFAI_API_KEY)`

---

## 🚨 ¿Qué pasa si olvido commit Config.xcconfig?

✅ **Nada malo.** Está en `.gitignore`, así que Git lo ignorará automáticamente. Esto es lo correcto.

Cada desarrollador debe:
1. Clonar el repo
2. Copiar `Config.xcconfig.example` → `Config.xcconfig`
3. Agregar su propia API key
4. Empezar a desarrollar

---

## 📝 Para tu equipo (Dev Team)

1. **Solo el repo owner** (con acceso a secrets):
   - Mantiene las API keys secretas
   - No comparte `Config.xcconfig` en el repo

2. **Otros desarrolladores**:
   - Clonen el repo
   - Creen su propio `Config.xcconfig` con sus credenciales
   - Desarrollan localmente sin afectar a otros

---

## 🔒 Buenas Prácticas

| ✅ HACER | ❌ NO HACER |
|---------|----------|
| Ignorar `Config.xcconfig` en ``.gitignore`` | Commitear archivos con API keys |
| Usar Build Settings variables | Hardcodear valores en código |
| Incluir archivo `.example` | Dejar referencias que no funcionan |
| Comunicar cambios de arquitectura | Sorprender al equipo con requerimientos |

