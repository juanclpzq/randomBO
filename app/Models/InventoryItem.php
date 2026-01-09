<?php

/**
 * Created by Reliese Model.
 */

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Str;

/**
 * Class InventoryItem
 * 
 * @property uuid $id
 * @property uuid $company_id
 * @property uuid|null $location_id
 * @property string $name
 * @property string $purchase_unit
 * @property string $recipe_unit
 * @property float $qty_per_purchase_unit
 * @property float|null $current_stock
 * @property float|null $minimum_limit
 * @property string|null $notes
 * @property int|null $status
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * 
 * @property Company $company
 * @property Location|null $location
 * @property Collection|Supplier[] $suppliers
 * @property Collection|InventoryMovement[] $inventory_movements
 * @property Collection|PurchaseOrderItem[] $purchase_order_items
 * @property Collection|RecipeIngredient[] $recipe_ingredients
 * @property Collection|ModifierIngredient[] $modifier_ingredients
 * @property Collection|ExtraIngredient[] $extra_ingredients
 * @property Collection|ExceptionIngredient[] $exception_ingredients
 *
 * @package App\Models
 */
class InventoryItem extends Model
{
	use SoftDeletes;
	protected $table = 'inventory_items';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';

	protected $casts = [
		'id' => 'string',
		'company_id' => 'string',
		'location_id' => 'string',
		'purchase_unit_id' => 'string',
		'recipe_unit_id' => 'string',
		'qty_per_purchase_unit' => 'float',
		'minimum_limit' => 'float',
		'status' => 'int',
		'deleted_by' => 'string'
	];

	protected $fillable = [
		'company_id',
		'location_id',
		'name',
		'purchase_unit_id',
		'recipe_unit_id',
		'qty_per_purchase_unit',
		'minimum_limit',
		'notes',
		'status',
		'deleted_by'
	];

	protected static function boot()
    {
        parent::boot();
        static::creating(function ($model) {
            if (empty($model->{$model->getKeyName()})) {
                $model->{$model->getKeyName()} = (string) Str::uuid();
            }
        });
    }

	public function company()
	{
		return $this->belongsTo(Company::class);
	}

	public function location()
	{
		return $this->belongsTo(Location::class);
	}

	public function purchaseUnit()
	{
		return $this->belongsTo(Unit::class, 'purchase_unit_id');
	}

	public function recipeUnit()
	{
		return $this->belongsTo(Unit::class, 'recipe_unit_id');
	}

	public function suppliers()
	{
		return $this->belongsToMany(Supplier::class, 'inventory_item_suppliers')
					->withPivot('id', 'cost', 'last_purchase_date', 'deleted_at', 'deleted_by');
	}

	public function InventoryMovements()
	{
		return $this->hasMany(InventoryMovement::class);
	}

	public function PurchaseOrderItems()
	{
		return $this->hasMany(PurchaseOrderItem::class);
	}

	public function RecipeIngredients()
	{
		return $this->hasMany(RecipeIngredient::class);
	}

	public function ModifierIngredients()
	{
		return $this->hasMany(ModifierIngredient::class);
	}


	public function ExtraIngredients()
	{
		return $this->hasMany(ExtraIngredient::class);
	}

	public function ExceptionIngredients()
	{
		return $this->hasMany(ExceptionIngredient::class);
	}
}
