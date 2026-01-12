<?php

namespace App\Services\Application\Orders;

use App\Models\OrderEvent;
use Illuminate\Support\Str;

/**
 * Service responsible for recording order events for audit trail
 */
class OrderEventRecorder
{
    /**
     * Record order event
     *
     * @param  array{
     *     order_id: string,
     *     event_type: string,
     *     from_status: string|null,
     *     to_status: string|null,
     *     actor: string,
     *     actor_id: string|null,
     *     location_id: string,
     *     company_id: string,
     *     metadata: array
     * }  $data
     */
    public function record(array $data): OrderEvent
    {
        return OrderEvent::create([
            'id' => (string) Str::uuid(),
            'order_id' => $data['order_id'],
            'event_type' => $data['event_type'],
            'from_status' => $data['from_status'] ?? null,
            'to_status' => $data['to_status'] ?? null,
            'actor' => $data['actor'],
            'actor_id' => $data['actor_id'] ?? null,
            'location_id' => $data['location_id'],
            'company_id' => $data['company_id'],
            'metadata' => $data['metadata'] ?? [],
            'created_at' => now(),
        ]);
    }
}
