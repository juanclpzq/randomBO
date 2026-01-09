<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class InventoryReservation extends Model
{
    protected $table = 'inventory_reservations';
    public $incrementing = false;
    protected $keyType = 'string';
    protected $fillable = [
        'id', 'company_id', 'location_id', 'status', 'reference_type', 'reference_id', 'notes', 'created_at', 'updated_at'
    ];

    public function company()
    {
        return $this->belongsTo(Company::class);
    }
    public function location()
    {
        return $this->belongsTo(Location::class);
    }
    public function items()
    {
        return $this->hasMany(InventoryReservationItem::class, 'reservation_id');
    }
}
