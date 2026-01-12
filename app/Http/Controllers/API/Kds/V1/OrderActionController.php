<?php

namespace App\Http\Controllers\Api\Kds\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Kds\CancelOrderRequest;
use App\Http\Requests\Kds\ReadyOrderRequest;
use App\Http\Requests\Kds\StartOrderRequest;
use App\Services\Application\Orders\OrderFlowService;
use Illuminate\Http\JsonResponse;
use InvalidArgumentException;

class OrderActionController extends Controller
{
    public function __construct(
        private readonly OrderFlowService $orderFlowService,
    ) {}

    /**
     * Start order preparation
     *
     * POST /api/kds/v1/orders/{orderId}/start
     */
    public function start(StartOrderRequest $request, string $orderId): JsonResponse
    {
        try {
            $order = $this->orderFlowService->startOrderPreparation(
                orderId: $orderId,
                employeeId: $request->validated('employee_id')
            );

            return response()->json([
                'data' => $this->orderFlowService->getOrderForKDS($order->id),
                'meta' => ['message' => 'Order started successfully'],
                'errors' => [],
            ]);
        } catch (InvalidArgumentException $e) {
            return response()->json([
                'data' => null,
                'meta' => [],
                'errors' => [$e->getMessage()],
            ], 422);
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'data' => null,
                'meta' => [],
                'errors' => ['Order not found'],
            ], 404);
        }
    }

    /**
     * Mark order ready
     *
     * POST /api/kds/v1/orders/{orderId}/ready
     */
    public function ready(ReadyOrderRequest $request, string $orderId): JsonResponse
    {
        try {
            $order = $this->orderFlowService->markOrderReady(
                orderId: $orderId,
                employeeId: $request->validated('employee_id')
            );

            return response()->json([
                'data' => $this->orderFlowService->getOrderForKDS($order->id),
                'meta' => ['message' => 'Order marked ready'],
                'errors' => [],
            ]);
        } catch (InvalidArgumentException $e) {
            return response()->json([
                'data' => null,
                'meta' => [],
                'errors' => [$e->getMessage()],
            ], 422);
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'data' => null,
                'meta' => [],
                'errors' => ['Order not found'],
            ], 404);
        }
    }

    /**
     * Cancel order
     *
     * POST /api/kds/v1/orders/{orderId}/cancel
     */
    public function cancel(CancelOrderRequest $request, string $orderId): JsonResponse
    {
        try {
            $order = $this->orderFlowService->cancelOrderFromKitchen(
                orderId: $orderId,
                reason: $request->validated('reason'),
                employeeId: $request->validated('employee_id')
            );

            return response()->json([
                'data' => $this->orderFlowService->getOrderForKDS($order->id),
                'meta' => ['message' => 'Order canceled'],
                'errors' => [],
            ]);
        } catch (InvalidArgumentException $e) {
            return response()->json([
                'data' => null,
                'meta' => [],
                'errors' => [$e->getMessage()],
            ], 422);
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'data' => null,
                'meta' => [],
                'errors' => ['Order not found'],
            ], 404);
        }
    }
}
