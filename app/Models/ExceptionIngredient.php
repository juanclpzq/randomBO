<?php

/**
 * Created by Reliese Model.
 */

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Class ExceptionIngredient
 * 
 * @property uuid $id
 * @property uuid $exception_id
 * @property uuid $inventory_item_id
 * @property float $quantity
 * @property uuid|null $unit_id
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * 
 * @property Exception $exception
 * @property InventoryItem $inventory_item
 * @property Unit|null $unit
 *
 * @package App\Models
 */
class ExceptionIngredient extends Model
{
	use SoftDeletes;
	protected $table = 'exception_ingredients';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';

	protected $casts = [
		'id' => 'string',
		'exception_id' => 'string',
		'inventory_item_id' => 'string',
		'quantity' => 'float',
		'unit_id' => 'string',
		'deleted_by' => 'string'
	];

	protected $fillable = [
		'exception_id',
		'inventory_item_id',
		'quantity',
		'unit_id',
		'deleted_by'
	];

	public function exception()
	{
		return $this->belongsTo(Exception::class);
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
