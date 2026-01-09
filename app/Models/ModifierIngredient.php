<?php

/**
 * Created by Reliese Model.
 */

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Class ModifierIngredient
 * 
 * @property uuid $id
 * @property uuid $modifier_id
 * @property uuid $inventory_item_id
 * @property float|null $quantity_change
 * @property uuid|null $unit_id
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * 
 * @property Modifier $modifier
 * @property InventoryItem $inventory_item
 * @property Unit|null $unit
 *
 * @package App\Models
 */
class ModifierIngredient extends Model
{
	use SoftDeletes;
	protected $table = 'modifier_ingredients';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';

	protected $casts = [
		'id' => 'string',
		'modifier_id' => 'string',
		'inventory_item_id' => 'string',
		'quantity_change' => 'float',
		'unit_id' => 'string',
		'deleted_by' => 'string'
	];

	protected $fillable = [
		'modifier_id',
		'inventory_item_id',
		'quantity_change',
		'unit_id',
		'deleted_by'
	];

	public function modifier()
	{
		return $this->belongsTo(Modifier::class);
	}

	public function inventory_item()
	{
		return $this->belongsTo(InventoryItem::class);
	}

	public function unit()
	{
		return $this->belongsTo(Unit::class);
	}
}
