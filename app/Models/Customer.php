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
 * Class Customer
 * 
 * @property uuid $id
 * @property uuid $company_id
 * @property uuid|null $location_id
 * @property string $first_name
 * @property string $last_name
 * @property string|null $email
 * @property string $phone
 * @property string|null $tax_id
 * @property string|null $business_name
 * @property string|null $address
 * @property string|null $city
 * @property string|null $state
 * @property string|null $postal_code
 * @property string|null $country
 * @property USER-DEFINED $customer_type
 * @property string|null $notes
 * @property int|null $loyalty_points
 * @property int|null $total_orders
 * @property float|null $total_spent
 * @property int $status
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * 
 * @property Company $company
 * @property Location|null $location
 * @property Collection|Order[] $orders
 *
 * @package App\Models
 */
class Customer extends Model
{
	use SoftDeletes;
	protected $table = 'customers';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';

	protected $casts = [
		'id' => 'string',
		'company_id' => 'string',
		'location_id' => 'string',
		'customer_type' => 'USER-DEFINED',
		'loyalty_points' => 'int',
		'total_orders' => 'int',
		'total_spent' => 'float',
		'status' => 'int',
		'deleted_by' => 'string'
	];

	protected $fillable = [
		'company_id',
		'location_id',
		'first_name',
		'last_name',
		'email',
		'phone',
		'tax_id',
		'business_name',
		'address',
		'city',
		'state',
		'postal_code',
		'country',
		'customer_type',
		'notes',
		'loyalty_points',
		'total_orders',
		'total_spent',
		'status',
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

	public function orders()
	{
		return $this->hasMany(Order::class);
	}
}
