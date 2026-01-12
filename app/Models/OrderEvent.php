<?php

/**
 * Created by custom implementation.
 */

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;

/**
 * Class OrderEvent
 *
 * @property string $id
 * @property string $order_id
 * @property string $event_type
 * @property string|null $from_status
 * @property string $to_status
 * @property string $actor
 * @property string|null $actor_id
 * @property string $location_id
 * @property string $company_id
 * @property array|null $metadata
 * @property Carbon|null $created_at
 *
 * @package App\Models
 */
class OrderEvent extends Model
{
    protected $table = 'order_events';
    public $incrementing = false;
    protected $primaryKey = 'id';
    protected $keyType = 'string';
    public $timestamps = false; // only created_at is used

    protected $casts = [
        'id' => 'string',
        'order_id' => 'string',
        'actor_id' => 'string',
        'location_id' => 'string',
        'company_id' => 'string',
        'metadata' => 'array',
        'created_at' => 'datetime',
    ];

    protected $fillable = [
        'id',
        'order_id',
        'event_type',
        'from_status',
        'to_status',
        'actor',
        'actor_id',
        'location_id',
        'company_id',
        'metadata',
        'created_at',
    ];

    public function order()
    {
        return $this->belongsTo(Order::class);
    }
}
