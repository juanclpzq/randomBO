<?php

/**
 * Created by Reliese Model.
 */

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Class PurchaseOrderItem
 * 
 * @property uuid $id
 * @property uuid $purchase_order_id
 * @property uuid $inventory_item_id
 * @property float $quantity
 * @property uuid|null $unit_id
 * @property float|null $cost
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * 
 * @property PurchaseOrder $purchase_order
 * @property InventoryItem $inventory_item
 * @property Unit|null $unit
 *
 * @package App\Models
 */
class PurchaseOrderItem extends Model
{
	use SoftDeletes;
	protected $table = 'purchase_order_items';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';
	public $timestamps = false;

	protected $casts = [
		'id' => 'string',
		'purchase_order_id' => 'string',
		'inventory_item_id' => 'string',
		'quantity' => 'float',
		'unit_id' => 'string',
		'cost' => 'float',
		'deleted_by' => 'string'
	];

	protected $fillable = [
		'purchase_order_id',
		'inventory_item_id',
		'quantity',
		'unit_id',
		'cost',
		'deleted_by'
	];

	public function purchase_order()
	{
		return $this->belongsTo(PurchaseOrder::class);
	}

	public function inventoryItem()
    {
        return $this->belongsTo(InventoryItem::class, 'inventory_item_id');
    }

	public function unit()
	{
		return $this->belongsTo(Unit::class);
	}
}
