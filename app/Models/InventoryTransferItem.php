<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class InventoryTransferItem extends Model
{
    protected $table = 'inventory_transfer_items';
    public $incrementing = false;
    protected $keyType = 'string';
    protected $fillable = [
        'id', 'transfer_id', 'inventory_item_id', 'quantity', 'unit_id'
    ];

    public function transfer()
    {
        return $this->belongsTo(InventoryTransfer::class, 'transfer_id');
    }
    public function inventoryItem()
    {
        return $this->belongsTo(InventoryItem::class);
    }
    public function unit()
    {
        return $this->belongsTo(Unit::class);
    }
}
