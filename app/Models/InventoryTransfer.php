<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class InventoryTransfer extends Model
{
    protected $table = 'inventory_transfers';
    public $incrementing = false;
    protected $keyType = 'string';
    protected $fillable = [
        'id', 'company_id', 'from_location_id', 'to_location_id', 'status', 'notes', 'created_at', 'updated_at',
        'shipped_at', 'received_at', 'shipped_by_employee_id', 'received_by_employee_id', 'ship_idempotency_key', 'receive_idempotency_key'
    ];

    public function company()
    {
        return $this->belongsTo(Company::class);
    }
    public function fromLocation()
    {
        return $this->belongsTo(Location::class, 'from_location_id');
    }
    public function toLocation()
    {
        return $this->belongsTo(Location::class, 'to_location_id');
    }
    public function shippedBy()
    {
        return $this->belongsTo(Employee::class, 'shipped_by_employee_id');
    }
    public function receivedBy()
    {
        return $this->belongsTo(Employee::class, 'received_by_employee_id');
    }
    public function items()
    {
        return $this->hasMany(InventoryTransferItem::class, 'transfer_id');
    }
}
