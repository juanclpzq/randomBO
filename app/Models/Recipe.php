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
 * Class Recipe
 * 
 * @property uuid $id
 * @property string $name
 * @property string|null $description
 * @property bool|null $is_base
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * 
 * @property Collection|RecipeIngredient[] $recipe_ingredients
 * @property Collection|Item[] $items
 *
 * @package App\Models
 */
class Recipe extends Model
{
	use SoftDeletes;
	protected $table = 'recipes';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';

	protected $casts = [
		'id' => 'string',
		'is_base' => 'bool',
		'deleted_by' => 'string'
	];

	protected $fillable = [
		'name',
		'description',
		'is_base',
		'deleted_by'
	];

	public function RecipeIngredients()
	{
		return $this->hasMany(RecipeIngredient::class);
	}

	public function items()
	{
		return $this->hasMany(Item::class);
	}

    public function InventoryItems()
    {
        return $this->hasManyThrough(
            InventoryItem::class, 
            RecipeIngredient::class,
            'recipe_id', // Foreign key on recipe_ingredients table
            'id', // Foreign key on inventory_items table
            'id', // Local key on recipes table
            'inventory_item_id' // Local key on recipe_ingredients table
        );
    }
}
