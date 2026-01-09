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
 * Class Modifier
 * 
 * @property uuid $id
 * @property uuid $modifier_group_id
 * @property string $name
 * @property string|null $description
 * @property float|null $price_change
 * @property int|null $sort_order
 * @property uuid|null $company_id
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * @property int|null $status
 * 
 * @property ModifierGroup $modifier_group
 * @property Company|null $company
 * @property Collection|ModifierIngredient[] $modifier_ingredients
 * @property Collection|Item[] $items
 * @property Collection|OrderItem[] $order_items
 *
 * @package App\Models
 */
class Modifier extends Model
{
	use SoftDeletes;
	protected $table = 'modifiers';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';

	protected $casts = [
		'id' => 'string',
		'modifier_group_id' => 'string',
		'price_change' => 'float',
		'sort_order' => 'int',
		'company_id' => 'string',
		'deleted_by' => 'string',
		'status' => 'int'
	];

	protected $fillable = [
		'modifier_group_id',
		'name',
		'description',
		'price_change',
		'sort_order',
		'company_id',
		'deleted_by',
		'status'
	];

	public function modifier_group()
	{
		return $this->belongsTo(ModifierGroup::class);
	}

	public function company()
	{
		return $this->belongsTo(Company::class);
	}

	public function modifier_ingredients()
	{
		return $this->hasMany(ModifierIngredient::class);
	}

	public function items()
	{
		return $this->belongsToMany(Item::class, 'items_modifiers')
					->withPivot('id', 'deleted_at', 'deleted_by')
					->wherePivotNull('deleted_at')
					->withTimestamps();
	}

	public function order_items()
	{
		return $this->belongsToMany(OrderItem::class, 'order_item_modifiers')
					->withPivot('id', 'modifier_name', 'price_change', 'deleted_at', 'deleted_by');
	}
}
