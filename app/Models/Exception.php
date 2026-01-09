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
 * Class Exception
 * 
 * @property uuid $id
 * @property string $name
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
 * @property Collection|Item[] $items
 * @property Collection|ExceptionIngredient[] $exception_ingredients
 * @property Collection|OrderItem[] $order_items
 *
 * @package App\Models
 */
class Exception extends Model
{
	use SoftDeletes;
	protected $table = 'exceptions';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';

	protected $casts = [
		'id' => 'string',
		'company_id' => 'string',
		'location_id' => 'string',
		'deleted_by' => 'string',
		'status' => 'int'
	];

	protected $fillable = [
		'name',
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

	public function items()
	{
		return $this->belongsToMany(Item::class, 'items_exceptions')
					->withPivot('id', 'deleted_at', 'deleted_by')
					->wherePivotNull('deleted_at')
					->withTimestamps();
	}

	public function exception_ingredients()
	{
		return $this->hasMany(ExceptionIngredient::class);
	}

	public function order_items()
	{
		return $this->belongsToMany(OrderItem::class, 'order_item_exceptions')
					->withPivot('id', 'exception_name', 'deleted_at', 'deleted_by');
	}
}
