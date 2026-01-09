<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ProductionBatch extends Model
{
    protected $table = 'production_batches';
    public $incrementing = false;
    protected $keyType = 'string';
    protected $fillable = [
        'id', 'company_id', 'location_id', 'recipe_id', 'produced_quantity', 'produced_unit_id', 'notes', 'created_at'
    ];

    public function company()
    {
        return $this->belongsTo(Company::class);
    }
    public function location()
    {
        return $this->belongsTo(Location::class);
    }
    public function recipe()
    {
        return $this->belongsTo(Recipe::class);
    }
    public function producedUnit()
    {
        return $this->belongsTo(Unit::class, 'produced_unit_id');
    }
}
