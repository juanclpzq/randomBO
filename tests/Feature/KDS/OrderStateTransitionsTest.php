<?php

namespace Tests\Feature\KDS;

use App\Models\Company;
use App\Models\Employee;
use App\Models\Location;
use App\Models\Order;
use App\Models\OrderEvent;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class OrderStateTransitionsTest extends TestCase
{

    private Company $company;

    private Location $location;

    private Employee $employee;

    protected function setUp(): void
    {
        parent::setUp();

        DB::beginTransaction();

        $this->company = Company::factory()->create();
        $this->location = Location::factory()->create(['company_id' => $this->company->id]);
        $this->employee = Employee::factory()->create([
            'company_id' => $this->company->id,
            'location_id' => $this->location->id,
        ]);

        $this->withHeaders([
            'X-Bypass-Token' => 'POS8-BYPASS-TOKEN',
            'X-Location-Id' => $this->location->id,
        ]);
    }

    protected function tearDown(): void
    {
        DB::rollBack();
        parent::tearDown();
    }

    public function test_can_start_order_preparation(): void
    {
        // Arrange
        $order = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
            'started_at' => null,
        ]);

        // Act
        $response = $this->postJson("/api/kds/v1/orders/{$order->id}/start", [
            'employee_id' => $this->employee->id,
        ]);

        // Assert
        $response->assertOk()
            ->assertJsonStructure([
                'data' => ['id', 'status', 'startedAt'],
                'meta' => ['message'],
                'errors',
            ]);

        $order->refresh();
        $this->assertEquals('in_progress', $order->status);
        $this->assertNotNull($order->started_at);

        // Verify event was recorded
        $this->assertDatabaseHas('order_events', [
            'order_id' => $order->id,
            'event_type' => 'order_started',
            'from_status' => 'paid',
            'to_status' => 'in_progress',
            'actor' => 'kds',
            'actor_id' => $this->employee->id,
        ]);
    }

    public function test_cannot_start_already_started_order(): void
    {
        // Arrange
        $order = Order::factory()->create([
            'status' => 'in_progress',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
        ]);

        // Act
        $response = $this->postJson("/api/kds/v1/orders/{$order->id}/start");

        // Assert
        $response->assertStatus(422)
            ->assertJsonStructure(['data', 'meta', 'errors']);
    }

    public function test_can_mark_order_ready(): void
    {
        // Arrange
        $order = Order::factory()->create([
            'status' => 'in_progress',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
            'started_at' => now()->subMinutes(5),
            'completed_at' => null,
        ]);

        // Act
        $response = $this->postJson("/api/kds/v1/orders/{$order->id}/ready", [
            'employee_id' => $this->employee->id,
        ]);

        // Assert
        $response->assertOk()
            ->assertJsonStructure([
                'data' => ['id', 'status', 'completedAt'],
                'meta' => ['message'],
                'errors',
            ]);

        $order->refresh();
        $this->assertEquals('ready', $order->status);
        $this->assertNotNull($order->completed_at);

        // Verify event was recorded
        $this->assertDatabaseHas('order_events', [
            'order_id' => $order->id,
            'event_type' => 'order_ready',
            'from_status' => 'in_progress',
            'to_status' => 'ready',
            'actor' => 'kds',
        ]);
    }

    public function test_cannot_mark_ready_order_that_is_not_in_progress(): void
    {
        // Arrange
        $order = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
        ]);

        // Act
        $response = $this->postJson("/api/kds/v1/orders/{$order->id}/ready");

        // Assert
        $response->assertStatus(422);
    }

    public function test_can_cancel_paid_order(): void
    {
        // Arrange
        $order = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
            'canceled_at' => null,
        ]);

        // Act
        $response = $this->postJson("/api/kds/v1/orders/{$order->id}/cancel", [
            'reason' => 'Customer requested cancellation',
            'employee_id' => $this->employee->id,
        ]);

        // Assert
        $response->assertOk()
            ->assertJsonStructure([
                'data' => ['id', 'status', 'canceledAt'],
                'meta' => ['message'],
                'errors',
            ]);

        $order->refresh();
        $this->assertEquals('canceled', $order->status);
        $this->assertNotNull($order->canceled_at);

        // Verify event was recorded with reason
        $event = OrderEvent::where('order_id', $order->id)
            ->where('event_type', 'order_canceled')
            ->first();

        $this->assertNotNull($event);
        $this->assertEquals('Customer requested cancellation', $event->metadata['reason']);
    }

    public function test_can_cancel_in_progress_order(): void
    {
        // Arrange
        $order = Order::factory()->create([
            'status' => 'in_progress',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
        ]);

        // Act
        $response = $this->postJson("/api/kds/v1/orders/{$order->id}/cancel", [
            'reason' => 'Ingredient shortage',
        ]);

        // Assert
        $response->assertOk();
        $order->refresh();
        $this->assertEquals('canceled', $order->status);
    }

    public function test_cannot_cancel_already_canceled_order(): void
    {
        // Arrange
        $order = Order::factory()->create([
            'status' => 'canceled',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
        ]);

        // Act
        $response = $this->postJson("/api/kds/v1/orders/{$order->id}/cancel", [
            'reason' => 'Duplicate cancellation',
        ]);

        // Assert
        $response->assertStatus(422);
    }

    public function test_cancel_requires_reason(): void
    {
        // Arrange
        $order = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
        ]);

        // Act
        $response = $this->postJson("/api/kds/v1/orders/{$order->id}/cancel", [
            // Missing reason
        ]);

        // Assert
        $response->assertStatus(422)
            ->assertJsonValidationErrors(['reason']);
    }

    public function test_started_at_not_overwritten_if_already_set(): void
    {
        // Arrange
        $originalStartTime = now()->subMinutes(10);
        $order = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
            'started_at' => $originalStartTime,
        ]);

        // Act
        $response = $this->postJson("/api/kds/v1/orders/{$order->id}/start");

        // Assert
        $response->assertOk();
        $order->refresh();
        $this->assertEquals($originalStartTime->timestamp, $order->started_at->timestamp);
    }

    public function test_complete_workflow_paid_to_ready(): void
    {
        // Arrange
        $order = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
        ]);

        // Act - Start
        $this->postJson("/api/kds/v1/orders/{$order->id}/start")
            ->assertOk();

        // Act - Ready
        $this->postJson("/api/kds/v1/orders/{$order->id}/ready")
            ->assertOk();

        // Assert
        $order->refresh();
        $this->assertEquals('ready', $order->status);
        $this->assertNotNull($order->started_at);
        $this->assertNotNull($order->completed_at);
        $this->assertNull($order->canceled_at);

        // Verify both events were recorded
        $this->assertEquals(2, OrderEvent::where('order_id', $order->id)->count());
    }
}
