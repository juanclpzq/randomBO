<?php

/**
 * Created by Reliese Model.
 */

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Class OrderItemExtra
 * 
 * @property uuid $id
 * @property uuid|null $order_item_id
 * @property uuid|null $extra_id
 * @property string|null $extra_name
 * @property float|null $price
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * 
 * @property OrderItem|null $order_item
 * @property Extra|null $extra
 *
 * @package App\Models
 */
class OrderItemExtra extends Model
{
	use SoftDeletes;
	protected $table = 'order_item_extras';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';
	public $timestamps = false;

	protected $casts = [
		'id' => 'string',
		'order_item_id' => 'string',
		'extra_id' => 'string',
		'price' => 'float',
		'deleted_by' => 'string'
	];

	protected $fillable = [
		'order_item_id',
		'extra_id',
		'extra_name',
		'price',
		'deleted_by'
	];

	public function order_item()
	{
		return $this->belongsTo(OrderItem::class);
	}

	public function extra()
	{
		return $this->belongsTo(Extra::class);
	}
}
