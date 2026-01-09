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
 * Class Company
 * 
 * @property uuid $id
 * @property string $name
 * @property string|null $legal_name
 * @property string|null $tax_id
 * @property string|null $email
 * @property string|null $phone
 * @property string|null $address
 * @property string|null $language
 * @property int|null $membership_plan_id
 * @property Carbon|null $subscription_start
 * @property Carbon|null $subscription_end
 * @property int $subscription_status
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * @property int|null $status
 * 
 * @property Collection|Location[] $locations
 * @property Collection|Employee[] $employees
 * @property Collection|InventoryItem[] $inventory_items
 * @property Collection|Supplier[] $suppliers
 * @property Collection|Customer[] $customers
 * @property Collection|PurchaseOrder[] $purchase_orders
 * @property Collection|Category[] $categories
 * @property Collection|ModifierGroup[] $modifier_groups
 * @property Collection|Modifier[] $modifiers
 * @property Collection|Exception[] $exceptions
 * @property Collection|Order[] $orders
 * @property Collection|Item[] $items
 * @property Collection|Extra[] $extras
 * @property Collection|Sale[] $sales
 * @property Collection|Log[] $logs
 *
 * @package App\Models
 */
class Company extends Model
{
	use SoftDeletes;
	protected $table = 'companies';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';

	protected $casts = [
		'id' => 'string',
		'membership_plan_id' => 'int',
		'subscription_start' => 'datetime',
		'subscription_end' => 'datetime',
		'subscription_status' => 'int',
		'deleted_by' => 'string',
		'status' => 'int'
	];

	protected $fillable = [
		'name',
		'legal_name',
		'tax_id',
		'email',
		'phone',
		'address',
		'language',
		'membership_plan_id',
		'subscription_start',
		'subscription_end',
		'subscription_status',
		'deleted_by',
		'status'
	];

	public function locations()
	{
		return $this->hasMany(Location::class);
	}

	public function employees()
	{
		return $this->hasMany(Employee::class);
	}

	public function inventory_items()
	{
		return $this->hasMany(InventoryItem::class);
	}

	public function suppliers()
	{
		return $this->hasMany(Supplier::class);
	}

	public function customers()
	{
		return $this->hasMany(Customer::class);
	}

	public function purchase_orders()
	{
		return $this->hasMany(PurchaseOrder::class);
	}

	public function categories()
	{
		return $this->hasMany(Category::class);
	}

	public function ModifierGroup()
	{
		return $this->hasMany(ModifierGroup::class);
	}

	public function modifiers()
	{
		return $this->hasMany(Modifier::class);
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

	public function logs()
	{
		return $this->hasMany(Log::class);
	}
}
