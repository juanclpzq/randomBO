<?php

namespace Tests\Unit;

use App\Models\Company;
use App\Models\Location;
use App\Models\Order;
use App\Services\Application\Orders\OrderEventRecorder;
use App\Services\Application\Orders\OrderFlowService;
use Illuminate\Support\Facades\DB;
use ReflectionClass;
use Tests\TestCase;

class OrderStatusMappingTest extends TestCase
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

    public function test_maps_pending_status_to_paid(): void
    {
        $this->assertStatusMapsTo('pending', 'PAID');
    }

    public function test_maps_paid_status_to_paid(): void
    {
        $this->assertStatusMapsTo('paid', 'PAID');
    }

    public function test_maps_in_progress_status_to_in_progress(): void
    {
        $this->assertStatusMapsTo('in_progress', 'IN_PROGRESS');
    }

    public function test_maps_preparing_status_to_in_progress(): void
    {
        $this->assertStatusMapsTo('preparing', 'IN_PROGRESS');
    }

    public function test_maps_ready_status_to_ready(): void
    {
        $this->assertStatusMapsTo('ready', 'READY');
    }

    public function test_maps_completed_status_to_ready(): void
    {
        $this->assertStatusMapsTo('completed', 'READY');
    }

    public function test_maps_canceled_status_to_canceled(): void
    {
        $this->assertStatusMapsTo('canceled', 'CANCELED');
    }

    public function test_maps_cancelled_status_to_canceled(): void
    {
        $this->assertStatusMapsTo('cancelled', 'CANCELED');
    }

    public function test_maps_unknown_status_to_paid_as_default(): void
    {
        $this->assertStatusMapsTo('unknown_status', 'PAID');
    }

    public function test_mapping_is_case_insensitive(): void
    {
        $this->assertStatusMapsTo('PAID', 'PAID');
        $this->assertStatusMapsTo('Paid', 'PAID');
        $this->assertStatusMapsTo('IN_PROGRESS', 'IN_PROGRESS');
        $this->assertStatusMapsTo('In_Progress', 'IN_PROGRESS');
    }

    /**
     * Helper method to test status mapping
     */
    private function assertStatusMapsTo(string $dbStatus, string $expectedKdsStatus): void
    {
        // Create order with specific status
        $order = Order::factory()->create([
            'status' => $dbStatus,
            'location_id' => $this->location->id,
            'company_id' => $this->company->id,
        ]);

        // Get order through service
        $result = $this->service->getOrderForKDS($order->id);

        // Assert the status mapping
        $this->assertEquals(
            $expectedKdsStatus,
            $result['status'],
            "Database status '{$dbStatus}' should map to KDS status '{$expectedKdsStatus}'"
        );
    }

    /**
     * Test the private mapStatusToKDS method directly using reflection
     */
    public function test_map_status_to_kds_method_directly(): void
    {
        $reflection = new ReflectionClass($this->service);
        $method = $reflection->getMethod('mapStatusToKDS');
        $method->setAccessible(true);

        // Test all mappings
        $mappings = [
            'pending' => 'PAID',
            'paid' => 'PAID',
            'in_progress' => 'IN_PROGRESS',
            'preparing' => 'IN_PROGRESS',
            'ready' => 'READY',
            'completed' => 'READY',
            'canceled' => 'CANCELED',
            'cancelled' => 'CANCELED',
            'unknown' => 'PAID',
        ];

        foreach ($mappings as $input => $expected) {
            $result = $method->invoke($this->service, $input);
            $this->assertEquals(
                $expected,
                $result,
                "Status '{$input}' should map to '{$expected}'"
            );
        }
    }

    public function test_all_valid_statuses_have_mappings(): void
    {
        $validStatuses = [
            'paid',
            'pending',
            'in_progress',
            'preparing',
            'ready',
            'completed',
            'canceled',
            'cancelled',
        ];

        foreach ($validStatuses as $status) {
            $order = Order::factory()->create([
                'status' => $status,
                'location_id' => $this->location->id,
                'company_id' => $this->company->id,
            ]);

            $result = $this->service->getOrderForKDS($order->id);

            $this->assertContains(
                $result['status'],
                ['PAID', 'IN_PROGRESS', 'READY', 'CANCELED'],
                "Status '{$status}' should map to a valid KDS status"
            );
        }
    }
}
