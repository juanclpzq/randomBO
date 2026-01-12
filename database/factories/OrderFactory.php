<?php

namespace Database\Factories;

use App\Models\Order;
use Illuminate\Database\Eloquent\Factories\Factory;

class OrderFactory extends Factory
{
    protected $model = Order::class;

    public function definition(): array
    {
        return [
            'id' => $this->faker->uuid(),
            'order_number' => $this->faker->unique()->numberBetween(1, 999999),
            'status' => 'paid',
            'order_type' => 'pos',
            'total' => $this->faker->randomFloat(2, 5, 100),
            'note' => $this->faker->optional()->sentence(),
            'table_number' => $this->faker->optional()->numerify('T-##'),
            'created_at' => now(),
            'updated_at' => now(),
        ];
    }
}
