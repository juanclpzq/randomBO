<?php

namespace Tests\Feature\KDS;

use App\Models\Company;
use App\Models\Customer;
use App\Models\Employee;
use App\Models\Item;
use App\Models\Location;
use App\Models\Order;
use App\Models\OrderItem;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class OrderRetrievalTest extends TestCase
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

    public function test_can_retrieve_active_orders_for_location(): void
    {
        // Arrange
        $customer = Customer::factory()->create([
            'company_id' => $this->company->id,
            'location_id' => $this->location->id,
        ]);

        $order = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
            'customer_id' => $customer->id,
            'order_number' => 42,
            'note' => 'Extra napkins please',
        ]);

        $item = Item::factory()->create([
            'company_id' => $this->company->id,
            'location_id' => $this->location->id,
            'name' => 'Cappuccino',
        ]);

        OrderItem::create([
            'order_id' => $order->id,
            'item_id' => $item->id,
            'quantity' => 2,
            'price' => 5.00,
            'total' => 10.00,
            'notes' => 'Extra hot',
        ]);

        // Act
        $response = $this->getJson("/api/kds/v1/orders?location_id={$this->location->id}");

        // Assert
        $response->assertOk()
            ->assertJsonStructure([
                'data' => [
                    '*' => [
                        'id',
                        'displayId',
                        'status',
                        'customerName',
                        'notes',
                        'createdAt',
                        'startedAt',
                        'completedAt',
                        'canceledAt',
                        'items' => [
                            '*' => [
                                'id',
                                'name',
                                'quantity',
                                'notes',
                                'modifiers',
                            ],
                        ],
                    ],
                ],
                'meta',
                'errors',
            ]);

        $data = $response->json('data.0');
        $this->assertEquals($order->id, $data['id']);
        $this->assertEquals(42, $data['displayId']);
        $this->assertEquals('PAID', $data['status']);
        $this->assertEquals('Cappuccino', $data['items'][0]['name']);
        $this->assertEquals(2, $data['items'][0]['quantity']);
    }

    public function test_cannot_retrieve_orders_without_location_id(): void
    {
        // Act - Remove the X-Location-Id header set in setUp by calling withoutHeader
        $response = $this->withoutHeader('X-Location-Id')
            ->getJson('/api/kds/v1/orders');

        // Assert
        $response->assertStatus(400)
            ->assertJsonFragment(['errors' => ['Location header (X-Location-Id) is required']]);
    }

    public function test_can_retrieve_single_order(): void
    {
        // Arrange
        $order = Order::factory()->create([
            'status' => 'in_progress',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
            'order_number' => 123,
        ]);

        $item = Item::factory()->create([
            'company_id' => $this->company->id,
            'location_id' => $this->location->id,
            'name' => 'Latte',
        ]);

        OrderItem::create([
            'order_id' => $order->id,
            'item_id' => $item->id,
            'quantity' => 1,
            'price' => 4.50,
            'total' => 4.50,
        ]);

        // Act
        $response = $this->getJson("/api/kds/v1/orders/{$order->id}");

        // Assert
        $response->assertOk()
            ->assertJsonStructure([
                'data' => [
                    'id',
                    'displayId',
                    'status',
                    'items',
                ],
                'meta',
                'errors',
            ]);

        $data = $response->json('data');
        $this->assertEquals($order->id, $data['id']);
        $this->assertEquals('IN_PROGRESS', $data['status']);
    }

    public function test_returns_404_for_nonexistent_order(): void
    {
        // Act
        $response = $this->getJson('/api/kds/v1/orders/00000000-0000-0000-0000-000000000000');

        // Assert
        $response->assertNotFound()
            ->assertJsonFragment(['errors' => ['Order not found']]);
    }

    public function test_orders_are_sorted_by_creation_time(): void
    {
        // Arrange
        $order1 = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
            'order_number' => 1,
            'created_at' => now()->subMinutes(10),
        ]);

        $order2 = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
            'order_number' => 2,
            'created_at' => now()->subMinutes(5),
        ]);

        $order3 = Order::factory()->create([
            'status' => 'paid',
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
            'order_number' => 3,
            'created_at' => now(),
        ]);

        // Act
        $response = $this->getJson("/api/kds/v1/orders?location_id={$this->location->id}");

        // Assert
        $response->assertOk();
        $orders = $response->json('data');

        $this->assertEquals(1, $orders[0]['displayId']);
        $this->assertEquals(2, $orders[1]['displayId']);
        $this->assertEquals(3, $orders[2]['displayId']);
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
        $response = $this->getJson("/api/kds/v1/orders/{$order->id}");

        // Assert
        $response->assertOk();
        $data = $response->json('data');

        $this->assertIsInt($data['createdAt']);
        $this->assertGreaterThan(1000000000, $data['createdAt']);
        $this->assertLessThan(2000000000, $data['createdAt']);
    }
}
