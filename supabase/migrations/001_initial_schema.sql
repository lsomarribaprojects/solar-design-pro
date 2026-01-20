-- ============================================
-- SolarDesign Pro - Initial Database Schema
-- Version: 1.0
-- Date: 2025-12-20
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- PROFILES (extends Supabase Auth)
-- ============================================
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  full_name TEXT,
  company_name TEXT,
  role TEXT DEFAULT 'designer', -- designer, admin, viewer
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trigger to create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- PROJECTS
-- ============================================
CREATE TABLE projects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  location JSONB, -- { address, coordinates: { lat, lng }, googleMapsUrl }
  type TEXT CHECK (type IN ('residential', 'commercial', 'industrial')) DEFAULT 'residential',
  target_capacity_kw DECIMAL,
  grid_voltage INTEGER DEFAULT 240, -- 120, 208, 240, 480
  connection_type TEXT CHECK (connection_type IN ('grid-tied', 'off-grid', 'hybrid')) DEFAULT 'grid-tied',
  nec_version TEXT CHECK (nec_version IN ('2020', '2023', '2026')) DEFAULT '2023',
  status TEXT CHECK (status IN ('draft', 'in_progress', 'completed', 'archived')) DEFAULT 'draft',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for faster queries
CREATE INDEX idx_projects_user_id ON projects(user_id);
CREATE INDEX idx_projects_status ON projects(status);

-- ============================================
-- SITES (Area definition for each project)
-- ============================================
CREATE TABLE sites (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE NOT NULL,
  available_area_m2 DECIMAL,
  area_polygon JSONB, -- Array of { lat, lng } coordinates
  roof_orientation DECIMAL, -- Azimuth in degrees (0-360)
  roof_tilt DECIMAL, -- Tilt angle in degrees (0-90)
  mounting_type TEXT CHECK (mounting_type IN ('roof-pitched', 'roof-flat', 'ground')) DEFAULT 'roof-pitched',
  shade_analysis JSONB, -- Future: shade analysis data
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sites_project_id ON sites(project_id);

-- ============================================
-- PV MODULES CATALOG
-- ============================================
CREATE TABLE pv_modules_catalog (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  brand TEXT NOT NULL,
  model TEXT NOT NULL,
  power_w DECIMAL NOT NULL,
  dimensions JSONB, -- { lengthMm, widthMm, heightMm }
  voc DECIMAL, -- Open circuit voltage
  vmp DECIMAL, -- Voltage at max power
  isc DECIMAL, -- Short circuit current
  imp DECIMAL, -- Current at max power
  temp_coeff_voc DECIMAL, -- Temperature coefficient Voc (%/C)
  temp_coeff_pmax DECIMAL, -- Temperature coefficient Pmax (%/C)
  efficiency DECIMAL, -- Module efficiency (%)
  datasheet_url TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for search
CREATE INDEX idx_pv_modules_brand ON pv_modules_catalog(brand);
CREATE INDEX idx_pv_modules_power ON pv_modules_catalog(power_w);

-- ============================================
-- INVERTERS CATALOG
-- ============================================
CREATE TABLE inverters_catalog (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  brand TEXT NOT NULL,
  model TEXT NOT NULL,
  power_kw DECIMAL NOT NULL,
  type TEXT CHECK (type IN ('string', 'micro', 'hybrid', 'off-grid')) DEFAULT 'string',
  max_input_voltage DECIMAL,
  mppt_voltage_range JSONB, -- { min, max }
  max_input_current DECIMAL,
  number_of_mppts INTEGER DEFAULT 1,
  strings_per_mppt INTEGER DEFAULT 2,
  max_efficiency DECIMAL, -- %
  output_voltage INTEGER, -- 120, 208, 240, 480
  datasheet_url TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_inverters_brand ON inverters_catalog(brand);
CREATE INDEX idx_inverters_power ON inverters_catalog(power_kw);

-- ============================================
-- PROJECT EQUIPMENT (Selected equipment for a project)
-- ============================================
CREATE TABLE project_equipment (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE NOT NULL,
  module_id UUID REFERENCES pv_modules_catalog(id),
  module_quantity INTEGER DEFAULT 0,
  inverter_id UUID REFERENCES inverters_catalog(id),
  inverter_quantity INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(project_id)
);

CREATE INDEX idx_project_equipment_project_id ON project_equipment(project_id);

-- ============================================
-- DESIGN CONFIGURATIONS
-- ============================================
CREATE TABLE design_configs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE NOT NULL,

  -- String configuration
  string_config JSONB, -- { modulesInSeries, stringsInParallel, totalModules }

  -- Wiring configuration
  wiring_config JSONB, -- { dcCableType, dcCableGauge, acCableType, acCableGauge, conduitType, conduitSize }

  -- Protections
  protections_config JSONB, -- { dcDisconnect, acBreaker, fuses }

  -- Canvas state (for visual editor)
  canvas_data JSONB, -- Full state of the visual canvas

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(project_id)
);

CREATE INDEX idx_design_configs_project_id ON design_configs(project_id);

-- ============================================
-- ELECTRICAL CALCULATIONS
-- ============================================
CREATE TABLE calculations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE NOT NULL,

  -- System voltages and currents
  electrical_calculations JSONB,
  /* Example structure:
  {
    systemVoltage: { maxVoc, operatingVmp },
    systemCurrent: { maxIsc, operatingImp },
    cableSizing: { dcCable: { gauge, ampacity, voltageDrop }, acCable: {...} },
    protectionSizing: { dcDisconnect, acBreaker, fuseRating },
    conduitFill: { type, size, fillPercentage, cablesInside }
  }
  */

  -- NEC compliance results
  nec_compliance JSONB,
  /* Example structure:
  {
    articlesApplied: ['690.8', '690.9', ...],
    warnings: [...],
    passed: true/false,
    details: [{ article, requirement, designValue, status }]
  }
  */

  calculated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(project_id)
);

CREATE INDEX idx_calculations_project_id ON calculations(project_id);

-- ============================================
-- GENERATED PLANS
-- ============================================
CREATE TABLE generated_plans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE NOT NULL,
  plan_type TEXT CHECK (plan_type IN ('single-line', 'multi-line', 'installation', 'site')) NOT NULL,
  svg_data TEXT, -- SVG content for rendering
  pdf_url TEXT, -- URL to stored PDF in Supabase Storage
  version INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_generated_plans_project_id ON generated_plans(project_id);
CREATE INDEX idx_generated_plans_type ON generated_plans(plan_type);

-- ============================================
-- DOCUMENTATION (BOM, Memory, Reports)
-- ============================================
CREATE TABLE documentation (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE NOT NULL,

  -- Bill of Materials
  bill_of_materials JSONB,
  /* Array of: { item, description, quantity, unit, unitPrice?, totalPrice? } */

  -- Calculation memory
  calculation_memory JSONB,
  /* Array of: { section, calculation, result, necReference } */

  -- NEC compliance report
  nec_report JSONB,
  /* Array of: { article, requirement, designValue, status: 'pass'|'fail'|'warning' } */

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(project_id)
);

CREATE INDEX idx_documentation_project_id ON documentation(project_id);

-- ============================================
-- COMPONENT LIBRARY (Visual symbols for canvas)
-- ============================================
CREATE TABLE component_library (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  category TEXT NOT NULL, -- 'pv-modules', 'inverters', 'panels', 'protections', 'conduits', etc.
  name TEXT NOT NULL,
  description TEXT,
  svg_icon TEXT, -- Small icon for toolbar
  svg_detailed TEXT, -- Detailed drawing for plans
  default_size JSONB, -- { width, height }
  connection_points JSONB, -- Array of { x, y, type: 'input'|'output' }
  editable_properties JSONB, -- Array of property names that can be edited
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_component_library_category ON component_library(category);

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_equipment ENABLE ROW LEVEL SECURITY;
ALTER TABLE design_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE calculations ENABLE ROW LEVEL SECURITY;
ALTER TABLE generated_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE documentation ENABLE ROW LEVEL SECURITY;

-- Catalog tables are public read
ALTER TABLE pv_modules_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE inverters_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE component_library ENABLE ROW LEVEL SECURITY;

-- ============================================
-- RLS POLICIES
-- ============================================

-- Profiles: users can only see/edit their own profile
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Projects: users can only access their own projects
CREATE POLICY "Users can view own projects" ON projects
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create own projects" ON projects
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own projects" ON projects
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own projects" ON projects
  FOR DELETE USING (auth.uid() = user_id);

-- Sites: through project ownership
CREATE POLICY "Users can manage sites of own projects" ON sites
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM projects WHERE projects.id = sites.project_id AND projects.user_id = auth.uid()
    )
  );

-- Project Equipment: through project ownership
CREATE POLICY "Users can manage equipment of own projects" ON project_equipment
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM projects WHERE projects.id = project_equipment.project_id AND projects.user_id = auth.uid()
    )
  );

-- Design Configs: through project ownership
CREATE POLICY "Users can manage design configs of own projects" ON design_configs
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM projects WHERE projects.id = design_configs.project_id AND projects.user_id = auth.uid()
    )
  );

-- Calculations: through project ownership
CREATE POLICY "Users can manage calculations of own projects" ON calculations
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM projects WHERE projects.id = calculations.project_id AND projects.user_id = auth.uid()
    )
  );

-- Generated Plans: through project ownership
CREATE POLICY "Users can manage plans of own projects" ON generated_plans
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM projects WHERE projects.id = generated_plans.project_id AND projects.user_id = auth.uid()
    )
  );

-- Documentation: through project ownership
CREATE POLICY "Users can manage documentation of own projects" ON documentation
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM projects WHERE projects.id = documentation.project_id AND projects.user_id = auth.uid()
    )
  );

-- Catalogs: public read access
CREATE POLICY "Anyone can view PV modules catalog" ON pv_modules_catalog
  FOR SELECT USING (true);

CREATE POLICY "Anyone can view inverters catalog" ON inverters_catalog
  FOR SELECT USING (true);

CREATE POLICY "Anyone can view component library" ON component_library
  FOR SELECT USING (true);

-- ============================================
-- FUNCTIONS FOR UPDATED_AT
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to tables with updated_at
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_projects_updated_at BEFORE UPDATE ON projects
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sites_updated_at BEFORE UPDATE ON sites
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_project_equipment_updated_at BEFORE UPDATE ON project_equipment
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_design_configs_updated_at BEFORE UPDATE ON design_configs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_documentation_updated_at BEFORE UPDATE ON documentation
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- SEED DATA: Sample PV Modules
-- ============================================
INSERT INTO pv_modules_catalog (brand, model, power_w, dimensions, voc, vmp, isc, imp, temp_coeff_voc, temp_coeff_pmax, efficiency) VALUES
('Canadian Solar', 'CS6W-545MS', 545, '{"lengthMm": 2261, "widthMm": 1134, "heightMm": 35}', 49.6, 41.7, 13.95, 13.07, -0.27, -0.34, 21.3),
('JinkoSolar', 'Tiger Neo N-type 545W', 545, '{"lengthMm": 2278, "widthMm": 1134, "heightMm": 30}', 49.62, 41.64, 13.98, 13.09, -0.26, -0.30, 21.38),
('LONGi', 'Hi-MO 5 LR5-72HBD 545W', 545, '{"lengthMm": 2256, "widthMm": 1133, "heightMm": 35}', 49.50, 41.50, 13.90, 13.13, -0.27, -0.34, 21.3),
('Trina Solar', 'Vertex S+ TSM-DE09R.08 430W', 430, '{"lengthMm": 1762, "widthMm": 1134, "heightMm": 30}', 43.8, 36.5, 12.56, 11.78, -0.26, -0.34, 21.5),
('QCells', 'Q.PEAK DUO ML-G11S+ 400W', 400, '{"lengthMm": 1722, "widthMm": 1134, "heightMm": 32}', 41.2, 34.3, 12.35, 11.66, -0.27, -0.34, 20.6);

-- ============================================
-- SEED DATA: Sample Inverters
-- ============================================
INSERT INTO inverters_catalog (brand, model, power_kw, type, max_input_voltage, mppt_voltage_range, max_input_current, number_of_mppts, strings_per_mppt, max_efficiency, output_voltage) VALUES
('SolarEdge', 'SE7600H-US', 7.6, 'string', 500, '{"min": 200, "max": 480}', 18, 1, 2, 99.0, 240),
('Enphase', 'IQ8A-72-M-US', 0.366, 'micro', 60, '{"min": 27, "max": 54}', 15, 1, 1, 97.5, 240),
('SMA', 'Sunny Boy 7.7-US', 7.7, 'string', 600, '{"min": 100, "max": 600}', 15, 2, 3, 97.5, 240),
('Fronius', 'Primo 8.2-1', 8.2, 'string', 600, '{"min": 80, "max": 600}', 27, 2, 3, 98.0, 240),
('Growatt', 'MIN 6000TL-XH', 6.0, 'hybrid', 550, '{"min": 100, "max": 550}', 13, 2, 1, 97.6, 240);

-- ============================================
-- SEED DATA: Component Library
-- ============================================
INSERT INTO component_library (category, name, description, default_size, connection_points, editable_properties) VALUES
('pv-modules', 'Solar Panel', 'Standard PV module representation', '{"width": 80, "height": 160}', '[{"x": 40, "y": 0, "type": "output"}]', '["label", "power", "quantity"]'),
('inverters', 'String Inverter', 'Grid-tied string inverter', '{"width": 100, "height": 80}', '[{"x": 0, "y": 40, "type": "input"}, {"x": 100, "y": 40, "type": "output"}]', '["label", "power", "brand", "model"]'),
('inverters', 'Microinverter', 'Module-level microinverter', '{"width": 60, "height": 40}', '[{"x": 0, "y": 20, "type": "input"}, {"x": 60, "y": 20, "type": "output"}]', '["label", "power"]'),
('panels', 'Main Panel', 'Electrical main service panel', '{"width": 120, "height": 160}', '[{"x": 60, "y": 0, "type": "input"}, {"x": 60, "y": 160, "type": "output"}]', '["label", "amperage"]'),
('panels', 'Subpanel', 'Electrical subpanel', '{"width": 80, "height": 120}', '[{"x": 40, "y": 0, "type": "input"}, {"x": 40, "y": 120, "type": "output"}]', '["label", "amperage"]'),
('protections', 'DC Disconnect', 'DC disconnect switch', '{"width": 60, "height": 60}', '[{"x": 30, "y": 0, "type": "input"}, {"x": 30, "y": 60, "type": "output"}]', '["label", "rating"]'),
('protections', 'AC Breaker', 'AC circuit breaker', '{"width": 40, "height": 50}', '[{"x": 20, "y": 0, "type": "input"}, {"x": 20, "y": 50, "type": "output"}]', '["label", "rating"]'),
('protections', 'Fuse', 'Inline fuse', '{"width": 30, "height": 40}', '[{"x": 15, "y": 0, "type": "input"}, {"x": 15, "y": 40, "type": "output"}]', '["label", "rating"]'),
('conduits', 'Conduit Run', 'EMT/PVC conduit', '{"width": 200, "height": 20}', '[{"x": 0, "y": 10, "type": "input"}, {"x": 200, "y": 10, "type": "output"}]', '["label", "size", "type", "length"]'),
('junction-boxes', 'Junction Box', 'Electrical junction box', '{"width": 50, "height": 50}', '[{"x": 25, "y": 0, "type": "input"}, {"x": 25, "y": 50, "type": "output"}, {"x": 0, "y": 25, "type": "input"}, {"x": 50, "y": 25, "type": "output"}]', '["label"]'),
('junction-boxes', 'Combiner Box', 'PV string combiner box', '{"width": 80, "height": 60}', '[{"x": 20, "y": 0, "type": "input"}, {"x": 40, "y": 0, "type": "input"}, {"x": 60, "y": 0, "type": "input"}, {"x": 40, "y": 60, "type": "output"}]', '["label", "inputs"]'),
('meters', 'Bidirectional Meter', 'Net metering meter', '{"width": 60, "height": 80}', '[{"x": 30, "y": 0, "type": "input"}, {"x": 30, "y": 80, "type": "output"}]', '["label"]'),
('grid-connection', 'Utility Grid', 'Grid connection point', '{"width": 100, "height": 60}', '[{"x": 50, "y": 60, "type": "input"}]', '["label", "voltage"]');
