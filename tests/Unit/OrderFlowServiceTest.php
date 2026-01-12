<?php

namespace Tests\Unit;

use App\Models\Company;
use App\Models\Customer;
use App\Models\Extra;
use App\Models\Item;
use App\Models\Location;
use App\Models\Modifier;
use App\Models\Order;
use App\Models\OrderEvent;
use App\Models\OrderItem;
use App\Services\Application\Orders\OrderEventRecorder;
use App\Services\Application\Orders\OrderFlowService;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;
use Tests\TestCase;

class OrderFlowServiceTest extends TestCase
{

    private OrderFlowService $service;

    private Company $company;

    private Location $location;

    protected function setUp(): void
    {
        parent::setUp();

        DB::beginTransaction();

        $this->company = Company::factory()->create();
        $this->location = Location::factory()->create(['company_id' => $this->company->id]);

        $eventRecorder = new OrderEventRecorder;
        $this->service = new OrderFlowService($eventRecorder);
    }

    protected function tearDown(): void
    {
        DB::rollBack();
        parent::tearDown();
    }

    public function test_start_order_preparation_updates_status_and_timestamp(): void
    {
        // Arrange
        $order = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
            'started_at' => null,
        ]);

        // Act
        $result = $this->service->startOrderPreparation($order->id);

        // Assert
        $this->assertEquals('in_progress', $result->status);
        $this->assertNotNull($result->started_at);
    }

    public function test_start_order_throws_exception_for_invalid_status(): void
    {
        // Arrange
        $order = Order::factory()->create([
            'status' => 'ready',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
        ]);

        // Act & Assert
        $this->expectException(InvalidArgumentException::class);
        $this->expectExceptionMessage('Cannot start order with status: ready');

        $this->service->startOrderPreparation($order->id);
    }

    public function test_start_order_does_not_overwrite_existing_started_at(): void
    {
        // Arrange
        $originalTime = now()->subMinutes(10);
        $order = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
            'started_at' => $originalTime,
        ]);

        // Act
        $result = $this->service->startOrderPreparation($order->id);

        // Assert
        $this->assertEquals($originalTime->timestamp, $result->started_at->timestamp);
    }

    public function test_mark_order_ready_updates_status_and_timestamp(): void
    {
        // Arrange
        $order = Order::factory()->create([
            'status' => 'in_progress',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
            'completed_at' => null,
        ]);

        // Act
        $result = $this->service->markOrderReady($order->id);

        // Assert
        $this->assertEquals('ready', $result->status);
        $this->assertNotNull($result->completed_at);
    }

    public function test_mark_ready_throws_exception_for_invalid_status(): void
    {
        // Arrange
        $order = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
        ]);

        // Act & Assert
        $this->expectException(InvalidArgumentException::class);
        $this->expectExceptionMessage('Cannot mark ready order with status: paid');

        $this->service->markOrderReady($order->id);
    }

    public function test_cancel_order_updates_status_and_timestamp(): void
    {
        // Arrange
        $order = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
            'canceled_at' => null,
        ]);

        // Act
        $result = $this->service->cancelOrderFromKitchen($order->id, 'Test reason');

        // Assert
        $this->assertEquals('canceled', $result->status);
        $this->assertNotNull($result->canceled_at);
    }

    public function test_cancel_order_records_reason_in_metadata(): void
    {
        // Arrange
        $order = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
        ]);

        // Act
        $this->service->cancelOrderFromKitchen($order->id, 'Ingredient shortage');

        // Assert
        $event = OrderEvent::where('order_id', $order->id)
            ->where('event_type', 'order_canceled')
            ->first();

        $this->assertNotNull($event);
        $this->assertEquals('Ingredient shortage', $event->metadata['reason']);
    }

    public function test_cancel_throws_exception_for_already_canceled_order(): void
    {
        // Arrange
        $order = Order::factory()->create([
            'status' => 'canceled',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
        ]);

        // Act & Assert
        $this->expectException(InvalidArgumentException::class);
        $this->expectExceptionMessage('Order already canceled');

        $this->service->cancelOrderFromKitchen($order->id, 'Duplicate');
    }

    public function test_get_active_orders_filters_by_location(): void
    {
        // Arrange
        $location2 = Location::factory()->create(['company_id' => $this->company->id]);

        Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
        ]);

        Order::factory()->create([
            'status' => 'paid',
            'location_id' => $location2->id,
            'company_id' => $this->company->id,
        ]);

        // Act
        $orders = $this->service->getActiveOrdersForKDS($this->location->id);

        // Assert
        $this->assertCount(1, $orders);
    }

    public function test_get_order_for_kds_includes_all_modifiers(): void
    {
        // Arrange
        $customer = Customer::factory()->create([
            'company_id' => $this->company->id,
            'location_id' => $this->location->id,
            'first_name' => 'John',
            'last_name' => 'Doe',
        ]);

        $order = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
            'customer_id' => $customer->id,
            'order_number' => 42,
            'note' => 'Extra napkins',
        ]);

        $item = Item::factory()->create([
            'company_id' => $this->company->id,
            'location_id' => $this->location->id,
            'name' => 'Cappuccino',
        ]);

        $orderItem = OrderItem::create([
            'order_id' => $order->id,
            'item_id' => $item->id,
            'quantity' => 2,
            'price' => 5.00,
            'total' => 10.00,
            'notes' => 'Extra hot',
        ]);

        $modifier = Modifier::factory()->create([
            'company_id' => $this->company->id,
            'name' => 'Oat Milk',
        ]);

        $orderItem->modifiers()->attach($modifier->id, [
            'modifier_name' => 'Oat Milk',
            'price_change' => 0.50,
        ]);

        $extra = Extra::factory()->create([
            'company_id' => $this->company->id,
            'location_id' => $this->location->id,
            'name' => 'Extra Shot',
        ]);

        $orderItem->extras()->attach($extra->id, [
            'extra_name' => 'Extra Shot',
            'price' => 1.00,
        ]);

        // Act
        $result = $this->service->getOrderForKDS($order->id);

        // Assert
        $this->assertEquals($order->id, $result['id']);
        $this->assertEquals(42, $result['displayId']);
        $this->assertEquals('PAID', $result['status']);
        $this->assertEquals('John Doe', $result['customerName']);
        $this->assertEquals('Extra napkins', $result['notes']);

        $this->assertCount(1, $result['items']);
        $this->assertEquals('Cappuccino', $result['items'][0]['name']);
        $this->assertEquals(2, $result['items'][0]['quantity']);
        $this->assertEquals('Extra hot', $result['items'][0]['notes']);

        $this->assertCount(2, $result['items'][0]['modifiers']);
        $this->assertEquals('Oat Milk', $result['items'][0]['modifiers'][0]['text']);
        $this->assertEquals('Extra Shot', $result['items'][0]['modifiers'][1]['text']);
    }

    public function test_timestamps_are_in_unix_seconds(): void
    {
        // Arrange
        $order = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
            'created_at' => now(),
        ]);

        // Act
        $result = $this->service->getOrderForKDS($order->id);

        // Assert
        $this->assertIsInt($result['createdAt']);
        $this->assertGreaterThan(1000000000, $result['createdAt']);
        $this->assertLessThan(2000000000, $result['createdAt']);
    }

    public function test_record_order_created_event(): void
    {
        // Arrange
        $order = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
        ]);

        $employee = \App\Models\Employee::factory()->create([
            'company_id' => $this->company->id,
            'location_id' => $this->location->id,
        ]);

        // Act
        $this->service->recordOrderCreated($order, 'pos', $employee->id);

        // Assert
        $this->assertDatabaseHas('order_events', [
            'order_id' => $order->id,
            'event_type' => 'order_created',
            'from_status' => null,
            'to_status' => 'paid',
            'actor' => 'pos',
            'actor_id' => $employee->id,
        ]);
    }
}
