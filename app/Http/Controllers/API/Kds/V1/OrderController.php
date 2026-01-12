<?php

namespace App\Http\Controllers\Api\Kds\V1;

use App\Http\Controllers\Controller;
use App\Services\Application\Orders\OrderFlowService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class OrderController extends Controller
{
    public function __construct(
        private readonly OrderFlowService $orderFlowService,
    ) {}

    /**
     * Get active orders for KDS display
     *
     * GET /api/kds/v1/orders
     */
    public function index(Request $request): JsonResponse
    {
        // Location ID is set by LocationMiddleware
        $locationId = $request->attributes->get('location_id');

        $orders = $this->orderFlowService->getActiveOrdersForKDS($locationId);

        return response()->json([
            'data' => $orders->toArray(),
            'meta' => [
                'location_id' => $locationId,
                'count' => $orders->count(),
                'timestamp' => now()->timestamp,
            ],
            'errors' => [],
        ]);
    }

    /**
     * Get single order for KDS
     *
     * GET /api/kds/v1/orders/{orderId}
     */
    public function show(Request $request, string $orderId): JsonResponse
    {
        try {
            $order = $this->orderFlowService->getOrderForKDS($orderId);

            return response()->json([
                'data' => $order,
                'meta' => [],
                'errors' => [],
            ]);
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'data' => null,
                'meta' => [],
                'errors' => ['Order not found'],
            ], 404);
        }
    }
}
