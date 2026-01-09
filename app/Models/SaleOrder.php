<?php

/**
 * Created by Reliese Model.
 */

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Class SaleOrder
 * 
 * @property uuid $sale_id
 * @property uuid $order_id
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * 
 * @property Sale $sale
 * @property Order $order
 *
 * @package App\Models
 */
class SaleOrder extends Model
{
	use SoftDeletes;
	protected $table = 'sale_orders';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';
	public $timestamps = false;

	protected $casts = [
		'sale_id' => 'string',
		'order_id' => 'string',
		'deleted_by' => 'string'
	];

	protected $fillable = [
		'deleted_by'
	];

	public function sale()
	{
		return $this->belongsTo(Sale::class);
	}

	public function order()
	{
		return $this->belongsTo(Order::class);
	}
}
