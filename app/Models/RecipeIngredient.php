<?php

/**
 * Created by Reliese Model.
 */

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Class RecipeIngredient
 * 
 * @property uuid $id
 * @property uuid $recipe_id
 * @property uuid $inventory_item_id
 * @property float $quantity
 * @property uuid|null $unit_id
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * 
 * @property Recipe $recipe
 * @property InventoryItem $inventory_item
 * @property Unit|null $unit
 *
 * @package App\Models
 */
class RecipeIngredient extends Model
{
	use SoftDeletes;
	protected $table = 'recipe_ingredients';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';

	protected $casts = [
		'id' => 'string',
		'recipe_id' => 'string',
		'inventory_item_id' => 'string',
		'quantity' => 'float',
		'unit_id' => 'string',
		'deleted_by' => 'string'
	];

	protected $fillable = [
		'recipe_id',
		'inventory_item_id',
		'quantity',
		'unit_id',
		'deleted_by'
	];

	public function recipe()
	{
		return $this->belongsTo(Recipe::class);
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
