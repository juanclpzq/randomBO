<?php

/**
 * Created by Reliese Model.
 */

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Class Unit
 * 
 * @property uuid $id
 * @property string $name
 * @property string|null $short_name
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * @property int|null $status
 * 
 * @property Collection|InventoryMovement[] $inventory_movements
 * @property Collection|PurchaseOrderItem[] $purchase_order_items
 * @property Collection|RecipeIngredient[] $recipe_ingredients
 * @property Collection|ModifierIngredient[] $modifier_ingredients
 * @property Collection|ExtraIngredient[] $extra_ingredients
 * @property Collection|ExceptionIngredient[] $exception_ingredients
 *
 * @package App\Models
 */
class Unit extends Model
{
	use SoftDeletes;
	protected $table = 'units';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';

	protected $casts = [
		'id' => 'string',
		'deleted_by' => 'string',
		'status' => 'int'
	];

	protected $fillable = [
		'name',
		'short_name',
		'deleted_by',
		'status'
	];

       public function inventory_movements()
       {
	       return $this->hasMany(InventoryMovement::class);
       }

       public function purchase_order_items()
       {
	       return $this->hasMany(PurchaseOrderItem::class);
       }

       public function recipe_ingredients()
       {
	       return $this->hasMany(RecipeIngredient::class);
       }

       public function inventoryItemsAsPurchaseUnit()
       {
	       return $this->hasMany(InventoryItem::class, 'purchase_unit_id');
       }

       public function inventoryItemsAsRecipeUnit()
       {
	       return $this->hasMany(InventoryItem::class, 'recipe_unit_id');
       }

	public function modifier_ingredients()
	{
		return $this->hasMany(ModifierIngredient::class);
	}

	public function extra_ingredients()
	{
		return $this->hasMany(ExtraIngredient::class);
	}

	public function exception_ingredients()
	{
		return $this->hasMany(ExceptionIngredient::class);
	}
}
