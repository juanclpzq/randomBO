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
 * Class PurchaseOrder
 * 
 * @property uuid $id
 * @property uuid $company_id
 * @property uuid|null $location_id
 * @property uuid|null $supplier_id
 * @property string|null $status
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * 
 * @property Company $company
 * @property Location|null $location
 * @property Supplier|null $supplier
 * @property Collection|PurchaseOrderItem[] $purchase_order_items
 *
 * @package App\Models
 */
class PurchaseOrder extends Model
{
	use SoftDeletes;
	protected $table = 'purchase_orders';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';

	protected $casts = [
		'id' => 'string',
		'location_id' => 'string',
		'supplier_id' => 'string',
		'deleted_by' => 'string'
	];

	protected $fillable = [
		'location_id',
		'supplier_id',
		'status',
		'deleted_by'
	];

	public function Company()
	{
		return $this->belongsTo(Company::class);
	}

	public function Location()
	{
		return $this->belongsTo(Location::class);
	}

	public function Supplier()
	{
		return $this->belongsTo(Supplier::class);
	}

	public function PurchaseOrderItems()
	{
		return $this->hasMany(PurchaseOrderItem::class);
	}

	public function Items()
	{
		return $this->hasMany(Item::class);
	}

	public function InventoryItems()
    {
        return $this->hasManyThrough(
            InventoryItem::class, 
            PurchaseOrderItem::class,
            'purchase_order_id', // Foreign key on purchase_order_items table
            'id', // Foreign key on inventory_items table
            'id', // Local key on recipes table
            'inventory_item_id' // Local key on purchase_order_items table
        );
    }
}
