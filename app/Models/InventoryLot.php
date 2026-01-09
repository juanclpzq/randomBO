<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class InventoryLot extends Model
{
    protected $table = 'inventory_lots';
    public $incrementing = false;
    protected $keyType = 'string';
    protected $fillable = [
        'id', 'company_id', 'inventory_item_id', 'lot_code', 'received_date', 'expiry_date', 'unit_cost', 'supplier_id', 'source_type', 'source_id', 'notes', 'created_at', 'updated_at'
    ];

    public function company()
    {
        return $this->belongsTo(Company::class);
    }
    public function inventoryItem()
    {
        return $this->belongsTo(InventoryItem::class);
    }
    public function supplier()
    {
        return $this->belongsTo(Supplier::class);
    }
    public function lotStocks()
    {
        return $this->hasMany(InventoryLotStock::class, 'lot_id');
    }
}
