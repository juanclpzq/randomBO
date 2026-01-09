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
 * Class Order
 * 
 * @property uuid $id
 * @property int|null $device_id
 * @property string|null $table_number
 * @property string $status
 * @property float|null $total
 * @property uuid|null $company_id
 * @property uuid|null $location_id
 * @property uuid|null $employee_id
 * @property uuid|null $customer_id
 * @property string|null $discount_type
 * @property float|null $discount_value
 * @property float|null $discount_amount
 * @property string|null $discount_label
 * @property string|null $public_id
 * @property int|null $order_number
 * @property string|null $note
 * @property string|null $order_type
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * 
 * @property Company|null $company
 * @property Location|null $location
 * @property Employee|null $employee
 * @property Customer|null $customer
 * @property Collection|Item[] $items
 * @property Collection|Sale[] $sales
 *
 * @package App\Models
 */
class Order extends Model
{
	use SoftDeletes;
	protected $table = 'orders';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';

	protected $casts = [
		'id' => 'string',
		'device_id' => 'int',
		'total' => 'float',
		'company_id' => 'string',
		'location_id' => 'string',
		'employee_id' => 'string',
		'customer_id' => 'string',
		'discount_value' => 'float',
		'discount_amount' => 'float',
		'order_number' => 'int',
		'deleted_by' => 'string'
	];

	protected $fillable = [
		'device_id',
		'table_number',
		'status',
		'total',
		'company_id',
		'location_id',
		'employee_id',
		'customer_id',
		'discount_type',
		'discount_value',
		'discount_amount',
		'discount_label',
		'public_id',
		'order_number',
		'note',
		'order_type',
		'deleted_by'
	];

	public function company()
	{
		return $this->belongsTo(Company::class);
	}

	public function location()
	{
		return $this->belongsTo(Location::class);
	}

	public function employee()
	{
		return $this->belongsTo(Employee::class);
	}

	public function customer()
	{
		return $this->belongsTo(Customer::class);
	}

	public function items()
	{
		return $this->belongsToMany(Item::class, 'order_items')
					->withPivot('id', 'quantity', 'price', 'total', 'notes', 'deleted_at', 'deleted_by')
					->withTimestamps();
	}

	public function sales()
	{
		return $this->belongsToMany(Sale::class, 'sale_orders')
					->withPivot('deleted_at', 'deleted_by');
	}
}
