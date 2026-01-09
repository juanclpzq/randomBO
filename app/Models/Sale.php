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
 * Class Sale
 * 
 * @property uuid $id
 * @property float $total
 * @property float $subtotal
 * @property float|null $tax
 * @property float|null $discount
 * @property int $status
 * @property uuid|null $company_id
 * @property uuid|null $location_id
 * @property uuid|null $employee_id
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * 
 * @property Company|null $company
 * @property Location|null $location
 * @property Employee|null $employee
 * @property Collection|Payment[] $payments
 * @property Collection|Order[] $orders
 *
 * @package App\Models
 */
class Sale extends Model
{
	use SoftDeletes;
	protected $table = 'sales';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';

	protected $casts = [
		'id' => 'string',
		'total' => 'float',
		'subtotal' => 'float',
		'tax' => 'float',
		'discount' => 'float',
		'status' => 'int',
		'company_id' => 'string',
		'location_id' => 'string',
		'employee_id' => 'string',
		'deleted_by' => 'string'
	];

	protected $fillable = [
		'total',
		'subtotal',
		'tax',
		'discount',
		'status',
		'company_id',
		'location_id',
		'employee_id',
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

	public function payments()
	{
		return $this->hasMany(Payment::class);
	}

	public function orders()
	{
		return $this->belongsToMany(Order::class, 'sale_orders')
					->withPivot('deleted_at', 'deleted_by');
	}
}
