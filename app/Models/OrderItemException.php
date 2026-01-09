<?php

/**
 * Created by Reliese Model.
 */

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Class OrderItemException
 * 
 * @property uuid $id
 * @property uuid|null $order_item_id
 * @property uuid|null $exception_id
 * @property string|null $exception_name
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * 
 * @property OrderItem|null $order_item
 * @property Exception|null $exception
 *
 * @package App\Models
 */
class OrderItemException extends Model
{
	use SoftDeletes;
	protected $table = 'order_item_exceptions';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';
	public $timestamps = false;

	protected $casts = [
		'id' => 'string',
		'order_item_id' => 'string',
		'exception_id' => 'string',
		'deleted_by' => 'string'
	];

	protected $fillable = [
		'order_item_id',
		'exception_id',
		'exception_name',
		'deleted_by'
	];

	public function order_item()
	{
		return $this->belongsTo(OrderItem::class);
	}

	public function exception()
	{
		return $this->belongsTo(Exception::class);
	}
}
