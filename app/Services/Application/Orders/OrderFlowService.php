<?php

namespace App\Services\Application\Orders;

use App\Models\Order;
use App\Models\OrderItem;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;

/**
 * Service responsible for order state transitions, KDS transformations, and event recording.
 */
class OrderFlowService
{
    public function __construct(
        private readonly OrderEventRecorder $eventRecorder,
    ) {}

    /**
     * Get active orders for KDS display at specific location
     *
     * @return Collection<int, array{
     *     id: string,
     *     displayId: int,
     *     status: string,
     *     customerName: string|null,
     *     notes: string|null,
     *     createdAt: int,
     *     startedAt: int|null,
     *     completedAt: int|null,
     *     canceledAt: int|null,
     *     items: array<int, array>
     * }>
     */
    public function getActiveOrdersForKDS(string $locationId): Collection
    {
        $orders = Order::with([
            'customer',
            'orderItems' => function ($query) {
                $query->whereNull('deleted_at')
                    ->with(['item', 'modifiers', 'exceptions', 'extras']);
            },
        ])
            ->where('location_id', $locationId)
            ->whereIn('status', ['paid', 'pending', 'in_progress', 'preparing', 'ready', 'completed'])
            ->where(function ($query) {
                $query->where('status', '!=', 'ready')
                    ->orWhere('completed_at', '>', now()->subMinutes(30));
            })
            ->orderBy('created_at', 'asc')
            ->get();

        return $orders->map(fn ($order) => $this->transformOrderForKDS($order));
    }

    /**
     * Get single order for KDS
     *
     * @return array{
     *     id: string,
     *     displayId: int,
     *     status: string,
     *     customerName: string|null,
     *     notes: string|null,
     *     createdAt: int,
     *     startedAt: int|null,
     *     completedAt: int|null,
     *     canceledAt: int|null,
     *     items: array<int, array>
     * }
     */
    public function getOrderForKDS(string $orderId): array
    {
        $order = Order::with([
            'customer',
            'orderItems' => function ($query) {
                $query->whereNull('deleted_at')
                    ->with(['item', 'modifiers', 'exceptions', 'extras']);
            },
        ])
            ->findOrFail($orderId);

        return $this->transformOrderForKDS($order);
    }

    /**
     * Start order preparation (PAID/PENDING → IN_PROGRESS)
     */
    public function startOrderPreparation(string $orderId, ?string $employeeId = null): Order
    {
        return DB::transaction(function () use ($orderId, $employeeId) {
            $order = Order::lockForUpdate()->findOrFail($orderId);

            // Validate transition
            if (! in_array(strtolower($order->status), ['paid', 'pending'])) {
                throw new InvalidArgumentException(
                    "Cannot start order with status: {$order->status}"
                );
            }

            $previousStatus = $order->status;

            // Update order
            $order->status = 'in_progress';
            if (! $order->started_at) {
                $order->started_at = now();
            }
            $order->save();

            // Record event
            $this->eventRecorder->record([
                'order_id' => $order->id,
                'event_type' => 'order_started',
                'from_status' => $previousStatus,
                'to_status' => 'in_progress',
                'actor' => 'kds',
                'actor_id' => $employeeId,
                'location_id' => $order->location_id,
                'company_id' => $order->company_id,
                'metadata' => [],
            ]);

            return $order->fresh();
        });
    }

    /**
     * Mark order ready (IN_PROGRESS → READY)
     */
    public function markOrderReady(string $orderId, ?string $employeeId = null): Order
    {
        return DB::transaction(function () use ($orderId, $employeeId) {
            $order = Order::lockForUpdate()->findOrFail($orderId);

            // Validate transition
            if (! in_array(strtolower($order->status), ['in_progress', 'preparing'])) {
                throw new InvalidArgumentException(
                    "Cannot mark ready order with status: {$order->status}"
                );
            }

            $previousStatus = $order->status;

            // Update order
            $order->status = 'ready';
            if (! $order->completed_at) {
                $order->completed_at = now();
            }
            $order->save();

            // Record event
            $this->eventRecorder->record([
                'order_id' => $order->id,
                'event_type' => 'order_ready',
                'from_status' => $previousStatus,
                'to_status' => 'ready',
                'actor' => 'kds',
                'actor_id' => $employeeId,
                'location_id' => $order->location_id,
                'company_id' => $order->company_id,
                'metadata' => [],
            ]);

            return $order->fresh();
        });
    }

    /**
     * Cancel order from kitchen
     */
    public function cancelOrderFromKitchen(
        string $orderId,
        string $reason,
        ?string $employeeId = null
    ): Order {
        return DB::transaction(function () use ($orderId, $reason, $employeeId) {
            $order = Order::lockForUpdate()->findOrFail($orderId);

            // Validate transition
            if (strtolower($order->status) === 'canceled') {
                throw new InvalidArgumentException('Order already canceled');
            }

            $previousStatus = $order->status;

            // Update order
            $order->status = 'canceled';
            if (! $order->canceled_at) {
                $order->canceled_at = now();
            }
            $order->save();

            // Record event with reason
            $this->eventRecorder->record([
                'order_id' => $order->id,
                'event_type' => 'order_canceled',
                'from_status' => $previousStatus,
                'to_status' => 'canceled',
                'actor' => 'kds',
                'actor_id' => $employeeId,
                'location_id' => $order->location_id,
                'company_id' => $order->company_id,
                'metadata' => ['reason' => $reason],
            ]);

            return $order->fresh();
        });
    }

    /**
     * Record that an order was created (called by CheckoutService)
     */
    public function recordOrderCreated(Order $order, string $actor = 'pos', ?string $actorId = null): void
    {
        $this->eventRecorder->record([
            'order_id' => $order->id,
            'event_type' => 'order_created',
            'from_status' => null,
            'to_status' => $order->status,
            'actor' => $actor,
            'actor_id' => $actorId,
            'location_id' => $order->location_id,
            'company_id' => $order->company_id,
            'metadata' => [],
        ]);
    }

    /**
     * Transform Order model to KDS JSON format
     *
     * @return array{
     *     id: string,
     *     displayId: int,
     *     status: string,
     *     customerName: string|null,
     *     notes: string|null,
     *     createdAt: int,
     *     startedAt: int|null,
     *     completedAt: int|null,
     *     canceledAt: int|null,
     *     items: array<int, array>
     * }
     */
    private function transformOrderForKDS(Order $order): array
    {
        return [
            'id' => $order->id,
            'displayId' => $order->order_number,
            'status' => $this->mapStatusToKDS($order->status),
            'customerName' => $order->customer
                ? trim($order->customer->first_name.' '.$order->customer->last_name)
                : null,
            'notes' => $order->note,
            'createdAt' => $order->created_at->timestamp,
            'startedAt' => $order->started_at?->timestamp,
            'completedAt' => $order->completed_at?->timestamp,
            'canceledAt' => $order->canceled_at?->timestamp,
            'items' => $order->orderItems->map(function ($orderItem) {
                return [
                    'id' => $orderItem->id,
                    'name' => $orderItem->item->name,
                    'quantity' => $orderItem->quantity,
                    'notes' => $orderItem->notes,
                    'modifiers' => $this->combineModifiers($orderItem),
                ];
            })->values()->toArray(),
        ];
    }

    /**
     * Combine modifiers, exceptions, extras into single array
     *
     * @return array<int, array{id: string, text: string}>
     */
    private function combineModifiers($orderItem): array
    {
        $modifiers = [];

        // Add modifiers
        foreach ($orderItem->modifiers as $modifier) {
            $modifiers[] = [
                'id' => $modifier->pivot->id,
                'text' => $modifier->pivot->modifier_name,
            ];
        }

        // Add exceptions (removals)
        foreach ($orderItem->exceptions as $exception) {
            $modifiers[] = [
                'id' => $exception->pivot->id,
                'text' => $exception->pivot->exception_name,
            ];
        }

        // Add extras (add-ons)
        foreach ($orderItem->extras as $extra) {
            $modifiers[] = [
                'id' => $extra->pivot->id,
                'text' => $extra->pivot->extra_name,
            ];
        }

        return $modifiers;
    }

    /**
     * Map database status to KDS status
     */
    private function mapStatusToKDS(string $dbStatus): string
    {
        return match (strtolower($dbStatus)) {
            'pending', 'paid' => 'PAID',
            'in_progress', 'preparing' => 'IN_PROGRESS',
            'ready', 'completed' => 'READY',
            'canceled', 'cancelled' => 'CANCELED',
            default => 'PAID'
        };
    }
}
