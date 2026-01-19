# 📋 BUSINESS_LOGIC.md - SolarDesign Pro

> Generado por SaaS Factory | Fecha: 2025-12-20

---

## 1. Problema de Negocio

### Dolor
El diseño de sistemas fotovoltaicos conectados a la red es un proceso manual, lento y propenso a errores:
- Crear planos eléctricos (unifilares, multilínea, esquemas de conexión) toma de **2 días a 3 semanas**
- Muchas tareas son **repetitivas** (copiar/pegar para sistemas similares)
- Los diseñadores no están actualizados con las versiones del **NEC (2020/2023/2026)**
- Los software especializados (ej: Helioscope $60-100/mes) **no generan planos completos** para instalación
- Herramientas como AutoCAD son complejas; Excel + dibujos a mano son lentos y propensos a errores

### Costo Actual
| Métrica | Valor |
|---------|-------|
| Tiempo por diseño | 2 días - 3 semanas |
| Software especializado | $60-100/mes (incompleto) |
| Volumen típico empresa | 10-50 diseños/mes |
| Errores frecuentes | Rechazos por incumplimiento NEC |
| Costo oculto | Muchos diseños se regalan en ofertas comerciales |

---

## 2. Solución

### Propuesta de Valor
**"Una plataforma de diseño fotovoltaico con IA que genera diseños eléctricos y planos completos de instalación cumpliendo NEC para diseñadores solares"**

### Diferenciadores Clave
1. **IA experta en NEC** (2020/2023/2026) que asesora en tiempo real
2. **Planos completos para instalación** (no solo diagramas básicos)
3. **Canvas visual con librería de componentes** representativos (no solo cajas)
4. **Precio accesible** para democratizar el acceso
5. **Escalable y editable** - todo el proyecto puede modificarse en cualquier momento

---

## 3. Flujo Principal (Happy Path)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           FLUJO DEL USUARIO                                  │
└─────────────────────────────────────────────────────────────────────────────┘

1. CREAR PROYECTO
   └─► Usuario ingresa: nombre, ubicación (GPS/Google Maps), capacidad (kW)

2. DEFINIR ÁREA
   └─► Usuario mapea el área disponible desde Google Maps
   └─► Define orientación e inclinación

3. SELECCIONAR EQUIPOS
   └─► Elige módulos fotovoltaicos del catálogo (marca, modelo, specs)
   └─► Sistema valida si caben en el área definida
   └─► Elige inversor(es) compatible(s)

4. CÁLCULO AUTOMÁTICO (IA)
   └─► IA calcula configuración óptima de strings (serie/paralelo)
   └─► Calcula cableado, protecciones, conduits
   └─► Valida contra NEC en tiempo real
   └─► Muestra alertas y recomendaciones

5. DISEÑO EN CANVAS
   └─► Usuario ajusta layout visual (drag & drop)
   └─► Arrastra componentes de la librería
   └─► Edita cualquier parte del diseño
   └─► IA valida cambios en tiempo real

6. GENERACIÓN DE PLANOS
   └─► Sistema genera automáticamente:
       • Diagrama Unifilar
       • Diagrama Multilínea
       • Esquema de Conexión/Instalación
       • Plano de Sitio

7. DOCUMENTACIÓN
   └─► Lista de Materiales (BOM)
   └─► Memoria de Cálculo
   └─► Reporte de Cumplimiento NEC

8. EXPORTAR
   └─► Descarga PDF listo para instalar
   └─► Exporta DXF (opcional futuro)
   └─► Guarda proyecto editable
```

---

## 4. Usuario Objetivo

### Perfiles Confirmados

| Perfil | Descripción | Dolor Principal |
|--------|-------------|-----------------|
| **Ingeniero Freelance** | Cotiza 20-30 proyectos/mes | No tiene tiempo para AutoCAD |
| **Técnico de Instaladora** | Hace diseños rápidos para ofertas | Necesita velocidad y profesionalismo |
| **Diseñador Solar Independiente** | Compite con empresas grandes | No tiene recursos para software caro |

### Contexto Común
- Necesitan **velocidad** (entregar cotizaciones rápido)
- Necesitan **calidad profesional** (planos que un técnico pueda instalar)
- Necesitan **cumplimiento normativo** (evitar rechazos)
- Tienen **presupuesto limitado** (no pueden pagar $100/mes por herramientas incompletas)

---

## 5. Arquitectura de Datos

### 📥 INPUTS

#### A. Información del Proyecto
```typescript
interface Project {
  id: string;
  name: string;
  location: {
    address: string;
    coordinates: { lat: number; lng: number };
    googleMapsUrl?: string;
  };
  type: 'residential' | 'commercial' | 'industrial';
  targetCapacityKw: number;
  gridVoltage: 120 | 208 | 240 | 480;
  connectionType: 'grid-tied' | 'off-grid' | 'hybrid';
  necVersion: '2020' | '2023' | '2026';
  createdAt: Date;
  updatedAt: Date;
}
```

#### B. Información del Sitio
```typescript
interface Site {
  projectId: string;
  availableAreaM2: number;
  areaPolygon: { lat: number; lng: number }[]; // Polígono mapeado
  roofOrientation: number; // Azimut en grados
  roofTilt: number; // Inclinación en grados
  shadeAnalysis?: object; // Análisis de sombras (futuro)
}
```

#### C. Equipos Seleccionados
```typescript
interface PVModule {
  id: string;
  brand: string;
  model: string;
  powerW: number;
  dimensions: { lengthMm: number; widthMm: number; heightMm: number };
  voc: number; // Voltaje circuito abierto
  vmp: number; // Voltaje punto máxima potencia
  isc: number; // Corriente cortocircuito
  imp: number; // Corriente punto máxima potencia
  tempCoeffVoc: number;
  tempCoeffPmax: number;
}

interface Inverter {
  id: string;
  brand: string;
  model: string;
  powerKw: number;
  maxInputVoltage: number;
  mpptVoltageRange: { min: number; max: number };
  maxInputCurrent: number;
  numberOfMppts: number;
  stringsPerMppt: number;
}

interface ProjectEquipment {
  projectId: string;
  modules: { moduleId: string; quantity: number };
  inverters: { inverterId: string; quantity: number };
  mountingType: 'roof-pitched' | 'roof-flat' | 'ground';
}
```

#### D. Configuración de Diseño
```typescript
interface DesignConfig {
  projectId: string;
  stringConfig: {
    modulesInSeries: number;
    stringsInParallel: number;
    totalModules: number;
  };
  wiring: {
    dcCableType: string;
    dcCableGauge: string;
    acCableType: string;
    acCableGauge: string;
    conduitType: string;
    conduitSize: string;
  };
  protections: {
    dcDisconnect: { brand?: string; model?: string; rating: number };
    acBreaker: { brand?: string; model?: string; rating: number };
    fuses?: { brand?: string; model?: string; rating: number };
  };
}
```

---

### 📤 OUTPUTS

#### A. Cálculos Eléctricos
```typescript
interface ElectricalCalculations {
  projectId: string;
  systemVoltage: {
    maxVoc: number;
    operatingVmp: number;
  };
  systemCurrent: {
    maxIsc: number;
    operatingImp: number;
  };
  cablesizing: {
    dcCable: { gauge: string; ampacity: number; voltageDrop: number };
    acCable: { gauge: string; ampacity: number; voltageDrop: number };
  };
  protectionSizing: {
    dcDisconnect: number;
    acBreaker: number;
    fuseRating?: number;
  };
  conduitFill: {
    type: string;
    size: string;
    fillPercentage: number;
    cablesInside: number;
  };
  necCompliance: {
    articlesApplied: string[];
    warnings: string[];
    passed: boolean;
  };
}
```

#### B. Planos Generados
```typescript
interface GeneratedPlans {
  projectId: string;
  singleLineDiagram: { svgData: string; pdfUrl: string }; // Unifilar
  multiLineDiagram: { svgData: string; pdfUrl: string }; // Multilínea
  installationSchematic: { svgData: string; pdfUrl: string }; // Esquema conexión
  sitePlan: { svgData: string; pdfUrl: string }; // Plano de sitio
  generatedAt: Date;
}
```

#### C. Documentación Técnica
```typescript
interface Documentation {
  projectId: string;
  billOfMaterials: {
    item: string;
    description: string;
    quantity: number;
    unit: string;
  }[];
  calculationMemory: {
    section: string;
    calculation: string;
    result: string;
    necReference: string;
  }[];
  necComplianceReport: {
    article: string;
    requirement: string;
    designValue: string;
    status: 'pass' | 'fail' | 'warning';
  }[];
}
```

---

### 🎨 Librería Visual de Componentes

```typescript
interface ComponentLibrary {
  category: 'pv-modules' | 'inverters' | 'panels' | 'protections' |
            'conduits' | 'junction-boxes' | 'meters' | 'grid-connection';
  components: {
    id: string;
    name: string;
    svgIcon: string; // Icono para menú
    svgDetailed: string; // Dibujo detallado para planos
    defaultSize: { width: number; height: number };
    connectionPoints: { x: number; y: number; type: 'input' | 'output' }[];
    editableProperties: string[];
  }[];
}
```

**Componentes de la Librería:**
- Módulos fotovoltaicos (dibujo realista de panel)
- Inversores (representación de caja con etiquetas)
- Tableros eléctricos (panel con breakers visibles)
- Breakers y disconnects
- Fusibles
- Tuberías/Conduits (líneas con anotaciones de calibre)
- Cajas de conexión/Combiner boxes
- Medidor bidireccional
- Punto de conexión a red
- Banco de baterías (para sistemas híbridos)

---

## 6. KPIs de Éxito

### Métricas del MVP

| KPI | Meta | Plazo |
|-----|------|-------|
| **Proyectos procesados** | 100/semana sin errores NEC | Operación estable |
| **Adopción de usuarios** | 100 diseñadores activos | Primeros 3 meses |

### Métricas Secundarias
- Tiempo promedio de diseño: < 2 horas (vs 2-3 días actual)
- Tasa de cumplimiento NEC: 100%
- Satisfacción del usuario (NPS): > 50

---

## 7. Especificación Técnica (Para el Agente)

### Features a Implementar (Feature-First)

```
src/features/
├── auth/                    # Autenticación Email/Password (Supabase)
├── projects/                # CRUD de proyectos
├── site-mapping/            # Integración Google Maps + definición de área
├── equipment-catalog/       # Catálogo de módulos, inversores, etc.
├── electrical-calculator/   # Motor de cálculos eléctricos + validación NEC
├── design-canvas/           # Canvas visual drag & drop para diseño
├── component-library/       # Librería de componentes visuales
├── plan-generator/          # Generador de planos (unifilar, multilínea, etc.)
├── documentation/           # BOM, memoria de cálculo, reporte NEC
├── ai-assistant/            # Agente IA experto en NEC
└── export/                  # Exportación PDF, guardado de proyectos
```

### Stack Confirmado
- **Frontend:** Next.js 16 + React 19 + TypeScript + Tailwind 3.4 + shadcn/ui
- **Backend:** Supabase (Auth + Database + Storage)
- **Canvas:** React Flow o Konva.js (evaluación necesaria)
- **PDF Generation:** React-PDF o html2pdf
- **Maps:** Google Maps API
- **IA:** OpenAI GPT-4 / Claude API (para asistente NEC)
- **Validación:** Zod
- **State:** Zustand
- **MCPs:** Next.js DevTools + Playwright + Supabase

### Base de Datos (Supabase - Tablas Sugeridas)

```sql
-- Usuarios y Autenticación (manejado por Supabase Auth)

-- Proyectos
CREATE TABLE projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  name TEXT NOT NULL,
  location JSONB,
  type TEXT CHECK (type IN ('residential', 'commercial', 'industrial')),
  target_capacity_kw DECIMAL,
  grid_voltage INTEGER,
  connection_type TEXT,
  nec_version TEXT,
  status TEXT DEFAULT 'draft',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Sitios/Áreas
CREATE TABLE sites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
  available_area_m2 DECIMAL,
  area_polygon JSONB,
  roof_orientation DECIMAL,
  roof_tilt DECIMAL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Catálogo de Módulos PV
CREATE TABLE pv_modules_catalog (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  brand TEXT NOT NULL,
  model TEXT NOT NULL,
  power_w DECIMAL NOT NULL,
  dimensions JSONB,
  voc DECIMAL,
  vmp DECIMAL,
  isc DECIMAL,
  imp DECIMAL,
  datasheet_url TEXT,
  is_active BOOLEAN DEFAULT true
);

-- Catálogo de Inversores
CREATE TABLE inverters_catalog (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  brand TEXT NOT NULL,
  model TEXT NOT NULL,
  power_kw DECIMAL NOT NULL,
  max_input_voltage DECIMAL,
  mppt_voltage_range JSONB,
  max_input_current DECIMAL,
  number_of_mppts INTEGER,
  strings_per_mppt INTEGER,
  datasheet_url TEXT,
  is_active BOOLEAN DEFAULT true
);

-- Equipos del Proyecto
CREATE TABLE project_equipment (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
  module_id UUID REFERENCES pv_modules_catalog(id),
  module_quantity INTEGER,
  inverter_id UUID REFERENCES inverters_catalog(id),
  inverter_quantity INTEGER,
  mounting_type TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Configuración de Diseño
CREATE TABLE design_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
  string_config JSONB,
  wiring_config JSONB,
  protections_config JSONB,
  canvas_data JSONB, -- Estado del canvas visual
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Cálculos Generados
CREATE TABLE calculations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
  electrical_calculations JSONB,
  nec_compliance JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Planos Generados
CREATE TABLE generated_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
  plan_type TEXT, -- 'single-line', 'multi-line', 'installation', 'site'
  svg_data TEXT,
  pdf_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Documentación
CREATE TABLE documentation (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
  bill_of_materials JSONB,
  calculation_memory JSONB,
  nec_report JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Librería de Componentes Visuales
CREATE TABLE component_library (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category TEXT NOT NULL,
  name TEXT NOT NULL,
  svg_icon TEXT,
  svg_detailed TEXT,
  default_size JSONB,
  connection_points JSONB,
  editable_properties JSONB,
  is_active BOOLEAN DEFAULT true
);
```

### Próximos Pasos de Implementación

```
[ ] 1. Setup proyecto base (COMPLETADO)
[ ] 2. Configurar Supabase (crear proyecto + tablas)
[ ] 3. Implementar Auth (Email/Password)
[ ] 4. Feature: projects (CRUD básico)
[ ] 5. Feature: equipment-catalog (catálogo de módulos e inversores)
[ ] 6. Feature: site-mapping (Google Maps + área)
[ ] 7. Feature: electrical-calculator (motor de cálculos + NEC)
[ ] 8. Feature: design-canvas (canvas visual con drag & drop)
[ ] 9. Feature: component-library (librería de símbolos)
[ ] 10. Feature: plan-generator (generación de planos PDF)
[ ] 11. Feature: ai-assistant (agente IA experto NEC)
[ ] 12. Feature: documentation (BOM, memoria, reportes)
[ ] 13. Feature: export (PDF, guardar proyecto)
[ ] 14. Testing E2E con Playwright
[ ] 15. Deploy en Vercel
```

---

## 8. Principios de Desarrollo

### Escalabilidad
- Arquitectura Feature-First para agregar funcionalidades sin afectar existentes
- Base de datos normalizada con JSONB para flexibilidad
- API modular para futuras integraciones

### Editabilidad
- Todo el proyecto es editable en cualquier momento
- Cambios en equipos recalculan automáticamente el diseño
- Historial de versiones del proyecto
- Canvas visual con undo/redo

### Extensibilidad Futura
- Agregar más normativas (IEC, NOM mexicana, etc.)
- Análisis de sombras avanzado
- Simulación de producción energética
- Integración con proveedores de equipos
- App móvil para inspección en sitio
- Exportación DXF/DWG para AutoCAD

---

*"Primero entiende el negocio. Después escribe código."*

---

**Proyecto:** SolarDesign Pro
**Generado:** 2025-12-20
**Versión:** 1.0
