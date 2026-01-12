<?php

/**
 * Created by Reliese Model.
 */

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Class Location
 * 
 * @property uuid $id
 * @property string $name
 * @property string|null $code
 * @property string|null $phone
 * @property string|null $email
 * @property string|null $address
 * @property string|null $timezone
 * @property int|null $status
 * @property uuid $company_id
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * 
 * @property Company $company
 * @property Collection|Employee[] $employees
 * @property Collection|InventoryItem[] $inventory_items
 * @property Collection|Customer[] $customers
 * @property Collection|InventoryMovement[] $inventory_movements
 * @property Collection|PurchaseOrder[] $purchase_orders
 * @property Collection|Exception[] $exceptions
 * @property Collection|Order[] $orders
 * @property Collection|Item[] $items
 * @property Collection|Extra[] $extras
 * @property Collection|Sale[] $sales
 *
 * @package App\Models
 */
class Location extends Model
{
	use HasFactory, SoftDeletes;
	protected $table = 'locations';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';

	protected $casts = [
		'id' => 'string',
		'status' => 'boolean',
		'company_id' => 'string',
		'deleted_by' => 'string'
	];

	protected $fillable = [
		'name',
		'code',
		'phone',
		'email',
		'address',
		'timezone',
		'status',
		'company_id',
		'deleted_by'
	];

	public function company()
	{
		return $this->belongsTo(Company::class);
	}

	public function employees()
	{
		return $this->hasMany(Employee::class);
	}

	public function inventory_items()
	{
		return $this->hasMany(InventoryItem::class);
	}

	public function customers()
	{
		return $this->hasMany(Customer::class);
	}

	public function inventory_movements()
	{
		return $this->hasMany(InventoryMovement::class);
	}

	public function purchase_orders()
	{
		return $this->hasMany(PurchaseOrder::class);
	}

	public function exceptions()
	{
		return $this->hasMany(Exception::class);
	}

	public function orders()
	{
		return $this->hasMany(Order::class);
	}

	public function items()
	{
		return $this->hasMany(Item::class);
	}

	public function extras()
	{
		return $this->hasMany(Extra::class);
	}

	public function sales()
	{
		return $this->hasMany(Sale::class);
	}
}
