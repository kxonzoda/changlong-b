import type { KpiSummary } from '@/types/database';
import { getTotalOutputKg } from './productionService';
import { getTotalEnergyKwh } from './energyService';
import { getEquipmentHealth } from './equipmentService';
import { getCriticalMaintenanceCount } from './maintenanceService';
import { getOpenIncidentCount } from './safetyService';
import { getLowStockCount } from './warehouseService';
import { getProductionEfficiency } from './analyticsService';

export async function getKpiSummary(days = 30): Promise<KpiSummary> {
  const [totalOutput, energyKwh, equipment, criticalMaint, openIncidents, lowStock, prodEfficiency] = await Promise.all([
    getTotalOutputKg(days),
    getTotalEnergyKwh(days),
    getEquipmentHealth(),
    getCriticalMaintenanceCount(),
    getOpenIncidentCount(),
    getLowStockCount(),
    getProductionEfficiency(days),
  ]);

  const energyIntensity = totalOutput > 0 ? energyKwh / (totalOutput / 1000) : 0;
  const equipmentAvailability = equipment.total > 0 ? (equipment.operational / equipment.total) * 100 : 0;

  return {
    totalOutputKg: totalOutput,
    energyConsumptionKwh: energyKwh,
    energyIntensity,
    equipmentAvailability,
    productionEfficiency: prodEfficiency,
    openSafetyIncidents: openIncidents,
    criticalMaintenance: criticalMaint,
    lowStockItems: lowStock,
  };
}
