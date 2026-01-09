<?php

/**
 * Created by Reliese Model.
 */

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Class InventoryItemSupplier
 * 
 * @property uuid $id
 * @property uuid $inventory_item_id
 * @property uuid $supplier_id
 * @property float $cost
 * @property Carbon|null $last_purchase_date
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * 
 * @property InventoryItem $inventory_item
 * @property Supplier $supplier
 *
 * @package App\Models
 */
class InventoryItemSupplier extends Model
{
	use SoftDeletes;
	protected $table = 'inventory_item_suppliers';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';
	public $timestamps = false;

	protected $casts = [
		'id' => 'string',
		'inventory_item_id' => 'string',
		'supplier_id' => 'string',
		'cost' => 'float',
		'last_purchase_date' => 'datetime',
		'deleted_by' => 'string'
	];

	protected $fillable = [
		'inventory_item_id',
		'supplier_id',
		'cost',
		'last_purchase_date',
		'deleted_by'
	];

	public function inventory_item()
	{
		return $this->belongsTo(InventoryItem::class);
	}

	public function supplier()
	{
		return $this->belongsTo(Supplier::class);
	}
}
