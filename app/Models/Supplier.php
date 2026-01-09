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
 * Class Supplier
 * 
 * @property uuid $id
 * @property uuid $company_id
 * @property string $name
 * @property string|null $email
 * @property string|null $phone
 * @property string|null $address
 * @property string|null $notes
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * 
 * @property Company $company
 * @property Collection|InventoryItem[] $inventory_items
 * @property Collection|PurchaseOrder[] $purchase_orders
 *
 * @package App\Models
 */
class Supplier extends Model
{
	use SoftDeletes;
	protected $table = 'suppliers';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';

	protected $casts = [
		'id' => 'string',
		'company_id' => 'string',
		'deleted_by' => 'string'
	];

	protected $fillable = [
		'company_id',
		'name',
		'email',
		'phone',
		'address',
		'notes',
		'deleted_by'
	];

	public function company()
	{
		return $this->belongsTo(Company::class);
	}

	public function inventory_items()
	{
		return $this->belongsToMany(InventoryItem::class, 'inventory_item_suppliers')
					->withPivot('id', 'cost', 'last_purchase_date', 'deleted_at', 'deleted_by');
	}

	public function purchase_orders()
	{
		return $this->hasMany(PurchaseOrder::class);
	}
}
