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
 * Class OrderItem
 * 
 * @property uuid $id
 * @property int $quantity
 * @property float $price
 * @property float $total
 * @property string|null $notes
 * @property uuid|null $order_id
 * @property uuid|null $item_id
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * 
 * @property Order|null $order
 * @property Item|null $item
 * @property Collection|Modifier[] $modifiers
 * @property Collection|Extra[] $extras
 * @property Collection|Exception[] $exceptions
 *
 * @package App\Models
 */
class OrderItem extends Model
{
	use SoftDeletes;
	protected $table = 'order_items';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';

	protected static function boot()
	{
		parent::boot();
		static::creating(function ($model) {
			if (empty($model->{$model->getKeyName()})) {
				$model->{$model->getKeyName()} = (string) \Illuminate\Support\Str::uuid();
			}
		});
	}

	protected $casts = [
		'id' => 'string',
		'quantity' => 'int',
		'price' => 'float',
		'total' => 'float',
		'order_id' => 'string',
		'item_id' => 'string',
		'deleted_by' => 'string'
	];

	protected $fillable = [
		'quantity',
		'price',
		'total',
		'notes',
		'order_id',
		'item_id',
		'deleted_by'
	];

	public function order()
	{
		return $this->belongsTo(Order::class);
	}

	public function item()
	{
		return $this->belongsTo(Item::class);
	}

	public function modifiers()
	{
		return $this->belongsToMany(Modifier::class, 'order_item_modifiers', 'order_item_id', 'modifier_id')
					->withPivot('id', 'modifier_name', 'price_change', 'deleted_at', 'deleted_by');
	}

	public function extras()
	{
		return $this->belongsToMany(Extra::class, 'order_item_extras', 'order_item_id', 'extra_id')
					->withPivot('id', 'extra_name', 'price', 'deleted_at', 'deleted_by');
	}

	public function exceptions()
	{
		return $this->belongsToMany(Exception::class, 'order_item_exceptions', 'order_item_id', 'exception_id')
					->withPivot('id', 'exception_name', 'deleted_at', 'deleted_by');
	}
}
