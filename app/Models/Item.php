<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Str;


class Item extends Model
{
    use HasFactory, SoftDeletes;

    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = [
        'id',
        'name',
        'description',
        'sku',
        'price',
        'status',
        'company_id',
        'location_id',
        'category_id',
        'recipe_id',
        'deleted_at',
        'deleted_by',
        'created_at',
        'updated_at',
    ];

    protected static function boot()
    {
        parent::boot();
        static::creating(function ($model) {
            if (empty($model->{$model->getKeyName()})) {
                $model->{$model->getKeyName()} = (string) Str::uuid();
            }
        });
    }

    public function category()
    {
        return $this->belongsTo(Category::class);
    }

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

    public function modifierGroups()
    {
        return $this->belongsToMany(ModifierGroup::class, 'items_modifier_groups')
            ->wherePivotNull('deleted_at')
            ->whereNull('modifier_groups.deleted_at')
            ->withoutGlobalScope(\Illuminate\Database\Eloquent\SoftDeletingScope::class);
    }

    public function modifiers()
    {
        return $this->belongsToMany(Modifier::class, 'items_modifiers')
            ->wherePivotNull('deleted_at')
            ->whereNull('modifiers.deleted_at')
            ->withoutGlobalScope(\Illuminate\Database\Eloquent\SoftDeletingScope::class);
    }

    public function exceptions()
    {
        return $this->belongsToMany(Exception::class, 'items_exceptions')
            ->wherePivotNull('deleted_at')
            ->whereNull('exceptions.deleted_at')
            ->withoutGlobalScope(\Illuminate\Database\Eloquent\SoftDeletingScope::class);
    }

    public function extras()
    {
        return $this->belongsToMany(Extra::class, 'items_extras')
            ->wherePivotNull('deleted_at')
            ->whereNull('extras.deleted_at')
            ->withoutGlobalScope(\Illuminate\Database\Eloquent\SoftDeletingScope::class);
    }

    protected $casts = [
        'id' => 'string',
        'name' => 'string',
        'description' => 'string',
        'sku' => 'string',
        'price' => 'decimal:2',
        'status' => 'integer',
        'company_id' => 'string',
        'location_id' => 'string',
        'category_id' => 'string',
        'recipe_id' => 'string',
        'deleted_at' => 'datetime',
        'deleted_by' => 'string',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    protected $dates = [
        'deleted_at',
        'created_at',
        'updated_at',
    ];
}