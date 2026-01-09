<?php

/**
 * Created by Reliese Model.
 */

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Class InventoryMovement
 * 
 * @property uuid $id
 * @property uuid $inventory_item_id
 * @property uuid $location_id
 * @property float $quantity
 * @property uuid|null $unit_id
 * @property string $movement_type
 * @property uuid|null $reference_id
 * @property string|null $notes
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * 
 * @property InventoryItem $inventory_item
 * @property Location $location
 * @property Unit|null $unit
 *
 * @package App\Models
 */
class InventoryMovement extends Model
{
	use SoftDeletes;
	protected $table = 'inventory_movements';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';

	protected $casts = [
		'id' => 'string',
		'inventory_item_id' => 'string',
		'location_id' => 'string',
		'quantity' => 'float',
		'unit_id' => 'string',
		'reference_id' => 'string',
		'deleted_by' => 'string'
	];

	protected $fillable = [
		'inventory_item_id',
		'location_id',
		'quantity',
		'unit_id',
		'movement_type',
		'reference_id',
		'notes',
		'deleted_by'
	];

	public function inventory_item()
	{
		return $this->belongsTo(InventoryItem::class);
	}

	public function location()
	{
		return $this->belongsTo(Location::class);
	}

	public function unit()
	{
		return $this->belongsTo(Unit::class);
	}
}
