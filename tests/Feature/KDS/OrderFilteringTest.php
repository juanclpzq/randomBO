<?php

namespace Tests\Feature\KDS;

use App\Models\Company;
use App\Models\Location;
use App\Models\Order;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class OrderFilteringTest extends TestCase
{

    private Company $company;

    private Location $location1;

    private Location $location2;

    protected function setUp(): void
    {
        parent::setUp();

        DB::beginTransaction();

        $this->company = Company::factory()->create();
        $this->location1 = Location::factory()->create([
            'company_id' => $this->company->id,
            'name' => 'Kitchen 1',
        ]);
        $this->location2 = Location::factory()->create([
            'company_id' => $this->company->id,
            'name' => 'Kitchen 2',
        ]);

        $this->withHeaders([
            'X-Bypass-Token' => 'POS8-BYPASS-TOKEN',
            'X-Location-Id' => $this->location1->id,
        ]);
    }

    protected function tearDown(): void
    {
        DB::rollBack();
        parent::tearDown();
    }

    public function test_only_shows_orders_for_specified_location(): void
    {
        // Arrange - Create orders for different locations
        $order1 = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location1->id,
            'company_id' => $this->company->id,
            'order_number' => 1,
        ]);

        $order2 = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location2->id,
            'company_id' => $this->company->id,
            'order_number' => 2,
        ]);

        $order3 = Order::factory()->create([
            'status' => 'in_progress',
            'location_id' => $this->location1->id,
            'company_id' => $this->company->id,
            'order_number' => 3,
        ]);

        // Act - Request orders for location 1
        $response = $this->getJson("/api/kds/v1/orders?location_id={$this->location1->id}");

        // Assert - Should only see location 1 orders
        $response->assertOk();
        $orders = $response->json('data');

        $this->assertCount(2, $orders);
        $this->assertEquals(1, $orders[0]['displayId']);
        $this->assertEquals(3, $orders[1]['displayId']);
    }

    public function test_excludes_soft_deleted_orders(): void
    {
        // Arrange
        $activeOrder = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location1->id,
            'company_id' => $this->company->id,
            'deleted_at' => null,
        ]);

        $deletedOrder = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location1->id,
            'company_id' => $this->company->id,
            'deleted_at' => now(),
        ]);

        // Act
        $response = $this->getJson("/api/kds/v1/orders?location_id={$this->location1->id}");

        // Assert
        $response->assertOk();
        $orders = $response->json('data');

        $this->assertCount(1, $orders);
        $this->assertEquals($activeOrder->id, $orders[0]['id']);
    }

    public function test_excludes_canceled_orders(): void
    {
        // Arrange
        $activeOrder = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location1->id,
            'company_id' => $this->company->id,
        ]);

        $canceledOrder = Order::factory()->create([
            'status' => 'canceled',
            'location_id' => $this->location1->id,
            'company_id' => $this->company->id,
        ]);

        // Act
        $response = $this->getJson("/api/kds/v1/orders?location_id={$this->location1->id}");

        // Assert
        $response->assertOk();
        $orders = $response->json('data');

        $this->assertCount(1, $orders);
        $this->assertEquals($activeOrder->id, $orders[0]['id']);
    }

    public function test_shows_ready_orders_within_30_minutes(): void
    {
        // Arrange
        $recentReadyOrder = Order::factory()->create([
            'status' => 'ready',
            'location_id' => $this->location1->id,
            'company_id' => $this->company->id,
            'completed_at' => now()->subMinutes(20),
        ]);

        $oldReadyOrder = Order::factory()->create([
            'status' => 'ready',
            'location_id' => $this->location1->id,
            'company_id' => $this->company->id,
            'completed_at' => now()->subMinutes(40),
        ]);

        // Act
        $response = $this->getJson("/api/kds/v1/orders?location_id={$this->location1->id}");

        // Assert
        $response->assertOk();
        $orders = $response->json('data');

        $this->assertCount(1, $orders);
        $this->assertEquals($recentReadyOrder->id, $orders[0]['id']);
    }

    public function test_shows_all_active_status_orders(): void
    {
        // Arrange
        $paidOrder = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location1->id,
            'company_id' => $this->company->id,
        ]);

        $pendingOrder = Order::factory()->create([
            'status' => 'pending',
            'location_id' => $this->location1->id,
            'company_id' => $this->company->id,
        ]);

        $inProgressOrder = Order::factory()->create([
            'status' => 'in_progress',
            'location_id' => $this->location1->id,
            'company_id' => $this->company->id,
        ]);

        $preparingOrder = Order::factory()->create([
            'status' => 'preparing',
            'location_id' => $this->location1->id,
            'company_id' => $this->company->id,
        ]);

        $readyOrder = Order::factory()->create([
            'status' => 'ready',
            'location_id' => $this->location1->id,
            'company_id' => $this->company->id,
            'completed_at' => now(),
        ]);

        // Act
        $response = $this->getJson("/api/kds/v1/orders?location_id={$this->location1->id}");

        // Assert
        $response->assertOk();
        $orders = $response->json('data');

        $this->assertCount(5, $orders);
    }

    public function test_meta_includes_location_and_count(): void
    {
        // Arrange
        Order::factory()->count(3)->create([
            'status' => 'paid',
            'location_id' => $this->location1->id,
            'company_id' => $this->company->id,
        ]);

        // Act
        $response = $this->getJson("/api/kds/v1/orders?location_id={$this->location1->id}");

        // Assert
        $response->assertOk()
            ->assertJsonPath('meta.location_id', $this->location1->id)
            ->assertJsonPath('meta.count', 3)
            ->assertJsonStructure(['meta' => ['timestamp']]);
    }

    public function test_excludes_orders_from_different_companies(): void
    {
        // Arrange
        $otherCompany = Company::factory()->create();
        $otherLocation = Location::factory()->create(['company_id' => $otherCompany->id]);

        $myOrder = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location1->id,
            'company_id' => $this->company->id,
        ]);

        $otherOrder = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $otherLocation->id,
            'company_id' => $otherCompany->id,
        ]);

        // Act
        $response = $this->getJson("/api/kds/v1/orders?location_id={$this->location1->id}");

        // Assert
        $response->assertOk();
        $orders = $response->json('data');

        $this->assertCount(1, $orders);
        $this->assertEquals($myOrder->id, $orders[0]['id']);
    }
}
