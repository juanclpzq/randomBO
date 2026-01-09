<?php

/**
 * Created by Reliese Model.
 */

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Class OrderItemModifier
 * 
 * @property uuid $id
 * @property uuid $order_item_id
 * @property uuid|null $modifier_id
 * @property string|null $modifier_name
 * @property float|null $price_change
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * 
 * @property OrderItem $order_item
 * @property Modifier|null $modifier
 *
 * @package App\Models
 */
class OrderItemModifier extends Model
{
	use SoftDeletes;
	protected $table = 'order_item_modifiers';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';
	public $timestamps = false;

	protected $casts = [
		'id' => 'string',
		'order_item_id' => 'string',
		'modifier_id' => 'string',
		'price_change' => 'float',
		'deleted_by' => 'string'
	];

	protected $fillable = [
		'order_item_id',
		'modifier_id',
		'modifier_name',
		'price_change',
		'deleted_by'
	];

	public function order_item()
	{
		return $this->belongsTo(OrderItem::class);
	}

	public function modifier()
	{
		return $this->belongsTo(Modifier::class);
	}
}
