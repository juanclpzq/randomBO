<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class InventoryLotStock extends Model
{
    protected $table = 'inventory_lot_stocks';
    public $incrementing = false;
    public $timestamps = false;
    protected $primaryKey = ['location_id', 'lot_id'];
    protected $keyType = 'string';
    protected $fillable = [
        'location_id', 'lot_id', 'on_hand', 'reserved', 'updated_at'
    ];

    public function location()
    {
        return $this->belongsTo(Location::class);
    }
    public function lot()
    {
        return $this->belongsTo(InventoryLot::class, 'lot_id');
    }
}
