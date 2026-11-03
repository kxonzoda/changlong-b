// Database type definitions for CHANGLONG INTELLIGENCE platform

export type UserRole =
  | 'admin'
  | 'plant_director'
  | 'manager'
  | 'production_manager'
  | 'engineer'
  | 'energy_manager'
  | 'maintenance_manager'
  | 'safety_officer'
  | 'warehouse_manager'
  | 'operator'
  | 'viewer';

export type EmployeeStatus = 'active' | 'on_leave' | 'inactive';
export type BatchStatus = 'planned' | 'in_progress' | 'completed' | 'on_hold' | 'cancelled';
export type EnergyType = 'electricity' | 'natural_gas' | 'water' | 'steam' | 'compressed_air';
export type ReadingQuality = 'good' | 'suspect' | 'estimated' | 'invalid';
export type EquipmentStatus = 'operational' | 'under_maintenance' | 'idle' | 'fault' | 'decommissioned';
export type MaintenanceType = 'preventive' | 'corrective' | 'predictive' | 'inspection';
export type PriorityLevel = 'low' | 'medium' | 'high' | 'critical';
export type WorkOrderStatus = 'open' | 'in_progress' | 'completed' | 'cancelled' | 'overdue';
export type MovementType = 'incoming' | 'outgoing' | 'adjustment';
export type IncidentSeverity = 'minor' | 'moderate' | 'serious' | 'critical';
export type IncidentStatus = 'reported' | 'investigating' | 'resolved' | 'closed';
export type NotificationSeverity = 'info' | 'warning' | 'critical';

export interface Department {
  id: string;
  name: string;
  code: string;
  description: string | null;
  is_active: boolean;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export interface Profile {
  id: string;
  full_name: string | null;
  email: string | null;
  phone: string | null;
  department_id: string | null;
  role: UserRole;
  language: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface Shift {
  id: string;
  name: string;
  start_time: string;
  end_time: string;
  description: string | null;
  is_active: boolean;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export interface Employee {
  id: string;
  employee_number: string;
  full_name: string;
  department_id: string | null;
  position: string | null;
  shift_id: string | null;
  hire_date: string | null;
  status: EmployeeStatus;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export interface ProductionLine {
  id: string;
  name: string;
  code: string;
  department_id: string | null;
  is_active: boolean;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export interface ProductionBatch {
  id: string;
  batch_number: string;
  heat_number: string | null;
  steel_grade: string;
  production_line_id: string | null;
  status: BatchStatus;
  start_time: string | null;
  end_time: string | null;
  input_weight_kg: number | null;
  output_weight_kg: number | null;
  rejected_weight_kg: number;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export interface ProductionRecord {
  id: string;
  batch_id: string | null;
  production_line_id: string | null;
  shift_id: string | null;
  record_date: string;
  steel_grade: string | null;
  output_weight_kg: number;
  rejected_weight_kg: number;
  target_weight_kg: number | null;
  operator_id: string | null;
  notes: string | null;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export interface ProductionTarget {
  id: string;
  production_line_id: string;
  target_date: string;
  target_weight_kg: number;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export interface EnergyMeter {
  id: string;
  meter_code: string;
  name: string;
  energy_type: EnergyType;
  department_id: string | null;
  equipment_id: string | null;
  unit: string;
  is_active: boolean;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export interface EnergyReading {
  id: string;
  meter_id: string;
  reading_time: string;
  value: number;
  unit: string;
  quality: ReadingQuality;
  is_demo: boolean;
  created_at: string;
}

export interface EnergyConsumptionDaily {
  id: string;
  meter_id: string;
  consumption_date: string;
  total_value: number;
  unit: string;
  is_demo: boolean;
  created_at: string;
}

export interface EquipmentCategory {
  id: string;
  name: string;
  code: string;
  description: string | null;
  created_at: string;
  updated_at: string;
}

export interface Equipment {
  id: string;
  equipment_code: string;
  name: string;
  category_id: string | null;
  department_id: string | null;
  production_line_id: string | null;
  status: EquipmentStatus;
  health_score: number;
  operating_hours: number;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export interface EquipmentTelemetry {
  id: string;
  equipment_id: string;
  reading_time: string;
  metric: string;
  value: number;
  unit: string;
  quality: ReadingQuality;
  is_demo: boolean;
  created_at: string;
}

export interface MaintenanceWorkOrder {
  id: string;
  work_order_number: string;
  equipment_id: string | null;
  type: MaintenanceType;
  priority: PriorityLevel;
  status: WorkOrderStatus;
  assigned_to: string | null;
  description: string | null;
  scheduled_date: string | null;
  completed_date: string | null;
  downtime_hours: number;
  cost: number;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export interface WarehouseCategory {
  id: string;
  name: string;
  code: string;
  description: string | null;
  created_at: string;
  updated_at: string;
}

export interface WarehouseItem {
  id: string;
  item_code: string;
  name: string;
  category_id: string | null;
  unit: string;
  current_stock: number;
  min_stock: number;
  max_stock: number;
  unit_cost: number;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export interface SafetyIncident {
  id: string;
  incident_number: string;
  title: string;
  description: string | null;
  severity: IncidentSeverity;
  status: IncidentStatus;
  department_id: string | null;
  reported_by: string | null;
  incident_date: string;
  resolution_date: string | null;
  resolution_notes: string | null;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export type CorrectiveActionStatus = 'open' | 'in_progress' | 'completed' | 'verified';

export interface CorrectiveAction {
  id: string;
  incident_id: string | null;
  description: string;
  assigned_to: string | null;
  due_date: string | null;
  status: CorrectiveActionStatus;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export interface SafetyInspection {
  id: string;
  inspection_number: string;
  department_id: string | null;
  inspector_id: string | null;
  inspection_date: string;
  result: QualityResult;
  findings: string | null;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export interface Notification {
  id: string;
  user_id: string;
  title: string;
  message: string | null;
  severity: NotificationSeverity;
  category: string | null;
  is_read: boolean;
  created_at: string;
}

// Dashboard aggregate types
export interface KpiSummary {
  totalOutputKg: number;
  energyConsumptionKwh: number;
  energyIntensity: number;
  equipmentAvailability: number;
  productionEfficiency: number;
  openSafetyIncidents: number;
  criticalMaintenance: number;
  lowStockItems: number;
}

export interface ProductionTrendPoint {
  date: string;
  output_kg: number;
  target_kg: number;
}

export interface EnergyTrendPoint {
  date: string;
  electricity: number;
  gas: number;
  water: number;
}

// Quality Control
export type QualityResult = 'pass' | 'fail' | 'conditional';
export type DefectSeverity = 'minor' | 'major' | 'critical';

export interface QualityStandard {
  id: string;
  name: string;
  steel_grade: string;
  parameter: string;
  min_value: number | null;
  max_value: number | null;
  unit: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface QualityInspection {
  id: string;
  inspection_number: string;
  batch_id: string | null;
  steel_grade: string | null;
  inspector_id: string | null;
  inspection_date: string;
  result: QualityResult;
  notes: string | null;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export interface QualityMeasurement {
  id: string;
  inspection_id: string;
  parameter: string;
  value: number;
  unit: string;
  min_value: number | null;
  max_value: number | null;
  result: QualityResult;
  is_demo: boolean;
  created_at: string;
}

export interface QualityDefect {
  id: string;
  inspection_id: string;
  defect_type: string;
  severity: DefectSeverity;
  description: string | null;
  count: number;
  is_demo: boolean;
  created_at: string;
}

// Environmental
export type EnvironmentalReadingType = 'air_quality' | 'water_quality' | 'noise' | 'dust';
export type EmissionType = 'co2' | 'sox' | 'nox' | 'pm';
export type EmissionSource = 'measured' | 'estimated';

export interface EnvironmentalReading {
  id: string;
  reading_type: EnvironmentalReadingType;
  reading_time: string;
  value: number;
  unit: string;
  department_id: string | null;
  equipment_id: string | null;
  quality: ReadingQuality;
  is_demo: boolean;
  created_at: string;
}

export interface EmissionRecord {
  id: string;
  emission_type: EmissionType;
  emission_date: string;
  value: number;
  unit: string;
  source_type: EmissionSource;
  department_id: string | null;
  is_demo: boolean;
  created_at: string;
}

export interface WasteRecord {
  id: string;
  waste_type: string;
  waste_date: string;
  quantity: number;
  unit: string;
  disposal_method: string | null;
  department_id: string | null;
  is_demo: boolean;
  created_at: string;
}

// Workforce
export type AttendanceStatus = 'present' | 'absent' | 'late' | 'leave';
export type TrainingStatus = 'completed' | 'in_progress' | 'scheduled';

export interface AttendanceRecord {
  id: string;
  employee_id: string;
  record_date: string;
  status: AttendanceStatus;
  hours_worked: number;
  is_demo: boolean;
  created_at: string;
}

export interface Qualification {
  id: string;
  employee_id: string;
  name: string;
  issued_date: string | null;
  expiry_date: string | null;
  issuer: string | null;
  is_demo: boolean;
  created_at: string;
}

export interface TrainingRecord {
  id: string;
  employee_id: string;
  course_name: string;
  completion_date: string | null;
  status: TrainingStatus;
  is_demo: boolean;
  created_at: string;
}

// Supplementary
export interface Supplier {
  id: string;
  name: string;
  code: string;
  contact_name: string | null;
  contact_phone: string | null;
  contact_email: string | null;
  address: string | null;
  is_active: boolean;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export interface PurchaseRequest {
  id: string;
  request_number: string;
  item_id: string | null;
  supplier_id: string | null;
  quantity: number;
  unit: string;
  status: 'pending' | 'approved' | 'ordered' | 'received' | 'cancelled';
  requested_by: string | null;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export interface WarehouseLocation {
  id: string;
  name: string;
  code: string;
  description: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

// Extended tables (migration 0011)

export interface EquipmentComponent {
  id: string;
  equipment_id: string;
  name: string;
  component_code: string | null;
  serial_number: string | null;
  installed_date: string | null;
  status: string;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export interface MaintenanceProcedure {
  id: string;
  name: string;
  equipment_category_id: string | null;
  type: MaintenanceType;
  description: string | null;
  estimated_duration_hours: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface MaintenancePart {
  id: string;
  work_order_id: string;
  warehouse_item_id: string | null;
  part_name: string;
  quantity: number;
  unit_cost: number;
  is_demo: boolean;
  created_at: string;
}

export interface RiskAssessment {
  id: string;
  area: string;
  hazard_description: string;
  likelihood: 'low' | 'medium' | 'high';
  severity: 'low' | 'medium' | 'high' | 'critical';
  risk_score: number;
  mitigation_plan: string | null;
  assessor_id: string | null;
  assessment_date: string;
  next_review_date: string | null;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export interface SafetyTrainingRecord {
  id: string;
  employee_id: string;
  course_name: string;
  trainer: string | null;
  training_date: string;
  completion_status: 'scheduled' | 'in_progress' | 'completed' | 'failed';
  expiry_date: string | null;
  is_demo: boolean;
  created_at: string;
}

export interface WaterUsageRecord {
  id: string;
  department_id: string | null;
  usage_date: string;
  source: string | null;
  intake_volume: number;
  discharge_volume: number;
  unit: string;
  recycling_rate: number;
  is_demo: boolean;
  created_at: string;
}

export interface SystemEvent {
  id: string;
  event_type: string;
  severity: NotificationSeverity;
  message: string;
  source: string | null;
  metadata: Record<string, unknown> | null;
  created_at: string;
}

export interface EnergyAnomaly {
  id: string;
  meter_id: string | null;
  anomaly_date: string;
  detected_value: number;
  expected_value: number | null;
  deviation_pct: number | null;
  anomaly_type: 'peak' | 'dip' | 'usage_spike' | 'meter_fault';
  description: string | null;
  is_resolved: boolean;
  is_demo: boolean;
  created_at: string;
}

// Analytics result types
export interface MtbfResult {
  equipment_id: string;
  equipment_code: string;
  equipment_name: string;
  failure_count: number;
  total_operating_hours: number;
  mtbf_hours: number | null;
}

export interface MttrResult {
  equipment_id: string;
  equipment_code: string;
  equipment_name: string;
  repair_count: number;
  total_downtime_hours: number;
  mttr_hours: number | null;
}

// Final spec completion tables (migration 0014)

export interface EquipmentEvent {
  id: string;
  equipment_id: string;
  event_type: 'startup' | 'shutdown' | 'fault' | 'maintenance_start' | 'maintenance_end' | 'status_change';
  event_time: string;
  description: string | null;
  old_status: EquipmentStatus | null;
  new_status: EquipmentStatus | null;
  is_demo: boolean;
  created_at: string;
}

export interface EquipmentOperatingHours {
  id: string;
  equipment_id: string;
  record_date: string;
  operating_hours: number;
  idle_hours: number;
  downtime_hours: number;
  is_demo: boolean;
  created_at: string;
}

export interface MaintenanceHistory {
  id: string;
  work_order_id: string;
  equipment_id: string | null;
  technician: string | null;
  completion_notes: string | null;
  parts_used: string | null;
  labor_hours: number;
  completed_at: string;
  is_demo: boolean;
  created_at: string;
}

export interface QualityParameter {
  id: string;
  name: string;
  category: 'chemical' | 'mechanical' | 'dimensional' | 'surface';
  unit: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface QualityBatch {
  id: string;
  batch_id: string;
  quality_status: 'pending' | 'in_progress' | 'passed' | 'failed' | 'conditional';
  overall_grade: 'A' | 'B' | 'C' | 'reject' | null;
  inspection_count: number;
  defect_count: number;
  inspector_id: string | null;
  completed_at: string | null;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export interface LaboratoryResult {
  id: string;
  batch_id: string | null;
  test_name: string;
  test_method: string | null;
  result_value: number | null;
  unit: string | null;
  specification_min: number | null;
  specification_max: number | null;
  pass_fail: 'pass' | 'fail' | 'conditional';
  lab_technician: string | null;
  test_date: string;
  is_demo: boolean;
  created_at: string;
}

export interface StockTransaction {
  id: string;
  item_id: string;
  transaction_type: 'receipt' | 'issue' | 'transfer' | 'adjustment' | 'return';
  quantity: number;
  unit: string | null;
  from_location_id: string | null;
  to_location_id: string | null;
  reference_number: string | null;
  transaction_date: string;
  performed_by: string | null;
  is_demo: boolean;
  created_at: string;
}

export interface WorkforceAssignment {
  id: string;
  employee_id: string;
  department_id: string | null;
  production_line_id: string | null;
  role_title: string | null;
  start_date: string;
  end_date: string | null;
  is_active: boolean;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

export interface EmployeeShift {
  id: string;
  employee_id: string;
  shift_id: string;
  effective_date: string;
  end_date: string | null;
  is_active: boolean;
  is_demo: boolean;
  created_at: string;
}

export interface EnvironmentalAlert {
  id: string;
  alert_type: string;
  severity: NotificationSeverity;
  reading_type: EnvironmentalReadingType | null;
  threshold_value: number | null;
  actual_value: number | null;
  unit: string | null;
  department_id: string | null;
  triggered_at: string;
  resolved_at: string | null;
  resolution_notes: string | null;
  is_demo: boolean;
  created_at: string;
}

export interface EnergySource {
  id: string;
  name: string;
  source_type: EnergyType;
  supplier: string | null;
  unit: string;
  conversion_factor_kwh: number;
  co2_emission_factor: number;
  co2_emission_unit: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface ProductionShift {
  id: string;
  production_line_id: string;
  shift_id: string;
  record_date: string;
  output_weight_kg: number;
  rejected_weight_kg: number;
  target_weight_kg: number | null;
  operator_id: string | null;
  is_demo: boolean;
  created_at: string;
}

// Equipment downtime (spec section E)
export interface EquipmentDowntime {
  id: string;
  equipment_id: string;
  work_order_id: string | null;
  start_time: string;
  end_time: string | null;
  duration_hours: number | null;
  reason: string | null;
  category: string;
  is_demo: boolean;
  created_at: string;
  updated_at: string;
}

// Maintenance completion rate result
export interface MaintenanceCompletionRate {
  total_work_orders: number;
  completed_work_orders: number;
  completion_rate: number;
  overdue_count: number;
}
