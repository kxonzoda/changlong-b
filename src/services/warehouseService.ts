import { supabase } from '@/lib/supabase';
import type { WarehouseItem, StockTransaction } from '@/types/database';
import { ServiceError } from './serviceError';

export async function getWarehouseItems(): Promise<WarehouseItem[]> {
  const { data, error } = await supabase
    .from('warehouse_items')
    .select('*')
    .order('name');
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as WarehouseItem[];
}

export async function getLowStockCount(): Promise<number> {
  const { data, error } = await supabase
    .from('warehouse_items')
    .select('id')
    .filter('current_stock', 'lte', 'min_stock');
  if (error) throw ServiceError.fromSupabaseError(error);
  return data?.length ?? 0;
}

export async function getStockTransactions(days = 30, limit = 100): Promise<StockTransaction[]> {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);
  const { data, error } = await supabase
    .from('stock_transactions')
    .select('*')
    .gte('transaction_date', startDate.toISOString().split('T')[0])
    .order('transaction_date', { ascending: false })
    .limit(limit);
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

export async function getInventoryMovements(days = 30, limit = 100): Promise<Array<{
  id: string;
  item_id: string;
  movement_type: string;
  quantity: number;
  reference: string | null;
  performed_by: string | null;
  created_at: string;
}>> {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);
  const { data, error } = await supabase
    .from('inventory_movements')
    .select('*')
    .gte('created_at', startDate.toISOString())
    .order('created_at', { ascending: false })
    .limit(limit);
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

/**
 * Atomically record an inventory movement via the SECURITY DEFINER RPC.
 * Validates stock sufficiency and prevents negative stock.
 */
export async function recordStockMovement(payload: {
  p_item_id: string;
  p_movement_type: 'incoming' | 'outgoing' | 'adjustment';
  p_quantity: number;
  p_reference?: string | null;
  p_is_demo?: boolean;
}): Promise<{ success: boolean; new_stock: number; message: string }> {
  if (!payload.p_item_id) throw new ServiceError('Item ID is required', 'VALIDATION_ERROR');
  if (!payload.p_movement_type) throw new ServiceError('Movement type is required', 'VALIDATION_ERROR');
  if (payload.p_quantity <= 0) throw new ServiceError('Quantity must be positive', 'VALIDATION_ERROR');

  const { data: userData } = await supabase.auth.getUser();
  const performedBy = userData.user?.id ?? null;

  const { data, error } = await supabase.rpc('record_inventory_movement', {
    p_item_id: payload.p_item_id,
    p_movement_type: payload.p_movement_type,
    p_quantity: payload.p_quantity,
    p_reference: payload.p_reference ?? null,
    p_performed_by: performedBy,
    p_is_demo: payload.p_is_demo ?? false,
  });
  if (error) throw ServiceError.fromSupabaseError(error);
  return { success: true, new_stock: data as unknown as number, message: 'Movement recorded' };
}

export async function createWarehouseItem(payload: {
  name: string;
  item_code: string;
  category_id?: string | null;
  unit: string;
  current_stock: number;
  min_stock: number;
  max_stock?: number | null;
  unit_cost?: number | null;
}): Promise<WarehouseItem> {
  if (!payload.name?.trim()) throw new ServiceError('Item name is required', 'VALIDATION_ERROR');
  if (!payload.item_code?.trim()) throw new ServiceError('Item code is required', 'VALIDATION_ERROR');
  if (!payload.unit?.trim()) throw new ServiceError('Unit is required', 'VALIDATION_ERROR');
  if (payload.current_stock < 0) throw new ServiceError('Current stock cannot be negative', 'VALIDATION_ERROR');
  if (payload.min_stock < 0) throw new ServiceError('Minimum stock cannot be negative', 'VALIDATION_ERROR');

  const { data, error } = await supabase
    .from('warehouse_items')
    .insert({
      name: payload.name.trim(),
      item_code: payload.item_code.trim(),
      category_id: payload.category_id ?? null,
      unit: payload.unit,
      current_stock: payload.current_stock,
      min_stock: payload.min_stock,
      max_stock: payload.max_stock ?? 0,
      unit_cost: payload.unit_cost ?? 0,
      is_demo: false,
    })
    .select('*')
    .single();
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as WarehouseItem;
}

export async function updateWarehouseItem(
  id: string,
  updates: Partial<Pick<WarehouseItem, 'name' | 'min_stock' | 'max_stock' | 'unit_cost'>>,
): Promise<void> {
  if (!id) throw new ServiceError('Item ID is required', 'VALIDATION_ERROR');
  if (updates.min_stock !== undefined && updates.min_stock < 0) {
    throw new ServiceError('Minimum stock cannot be negative', 'VALIDATION_ERROR');
  }
  if (updates.max_stock !== undefined && updates.max_stock < 0) {
    throw new ServiceError('Maximum stock cannot be negative', 'VALIDATION_ERROR');
  }
  if (updates.unit_cost !== undefined && updates.unit_cost < 0) {
    throw new ServiceError('Unit cost cannot be negative', 'VALIDATION_ERROR');
  }

  const { error } = await supabase.from('warehouse_items').update(updates).eq('id', id);
  if (error) throw ServiceError.fromSupabaseError(error);
}

/**
 * Adjust stock atomically using the SECURITY DEFINER RPC.
 * For 'adjustment', the quantity IS the new absolute stock level.
 */
export async function adjustStock(
  itemId: string,
  movementType: 'incoming' | 'outgoing' | 'adjustment',
  quantity: number,
  reference?: string | null,
): Promise<number> {
  const result = await recordStockMovement({
    p_item_id: itemId,
    p_movement_type: movementType,
    p_quantity: quantity,
    p_reference: reference,
  });
  return result.new_stock;
}
