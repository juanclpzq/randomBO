<?php

/**
 * Created by Reliese Model.
 */

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Class Extra
 * 
 * @property uuid $id
 * @property string $name
 * @property float $price
 * @property uuid|null $company_id
 * @property uuid|null $location_id
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * @property int|null $status
 * 
 * @property Company|null $company
 * @property Location|null $location
 * @property Collection|ExtraIngredient[] $extra_ingredients
 * @property Collection|Item[] $items
 * @property Collection|OrderItem[] $order_items
 *
 * @package App\Models
 */
class Extra extends Model
{
	use HasFactory, SoftDeletes;
	protected $table = 'extras';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';

	protected $casts = [
		'id' => 'string',
		'price' => 'float',
		'company_id' => 'string',
		'location_id' => 'string',
		'deleted_by' => 'string',
		'status' => 'int'
	];

	protected $fillable = [
		'name',
		'price',
		'company_id',
		'location_id',
		'deleted_by',
		'status'
	];

	public function company()
	{
		return $this->belongsTo(Company::class);
	}

	public function location()
	{
		return $this->belongsTo(Location::class);
	}

	public function extra_ingredients()
	{
		return $this->hasMany(ExtraIngredient::class);
	}

	public function items()
	{
		return $this->belongsToMany(Item::class, 'items_extras')
					->withPivot('id', 'deleted_at', 'deleted_by')
					->wherePivotNull('deleted_at')
					->whereNull('items.deleted_at')
					->withoutGlobalScope(\Illuminate\Database\Eloquent\SoftDeletingScope::class)
					->withTimestamps();
	}

	public function order_items()
	{
		return $this->belongsToMany(OrderItem::class, 'order_item_extras')
					->withPivot('id', 'extra_name', 'price', 'deleted_at', 'deleted_by');
	}
}
