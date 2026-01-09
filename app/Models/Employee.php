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
 * Class Employee
 * 
 * @property uuid $id
 * @property string $first_name
 * @property string $last_name
 * @property string $email
 * @property string|null $phone
 * @property string $password_hash
 * @property int|null $status
 * @property uuid $company_id
 * @property uuid|null $location_id
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * 
 * @property Company $company
 * @property Location|null $location
 * @property Collection|Order[] $orders
 * @property Collection|Sale[] $sales
 * @property Collection|Log[] $logs
 *
 * @package App\Models
 */
use Laravel\Sanctum\HasApiTokens;

class Employee extends Model
{
	use HasApiTokens, SoftDeletes;
	protected $table = 'employees';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';

	protected $casts = [
		'id' => 'string',
		'status' => 'int',
		'company_id' => 'string',
		'location_id' => 'string',
		'deleted_by' => 'string'
	];

	protected $fillable = [
		'first_name',
		'last_name',
		'email',
		'phone',
		'password_hash',
		'status',
		'company_id',
		'location_id',
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

	public function sales()
	{
		return $this->hasMany(Sale::class);
	}

	public function logs()
	{
		return $this->hasMany(Log::class);
	}
}
