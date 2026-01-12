<?php

namespace Database\Factories;

use App\Models\Item;
use Illuminate\Database\Eloquent\Factories\Factory;

class ItemFactory extends Factory
{
    protected $model = Item::class;

    public function definition(): array
    {
        return [
            'id' => $this->faker->uuid(),
            'name' => $this->faker->words(2, true),
            'description' => $this->faker->optional()->sentence(),
            'price' => $this->faker->randomFloat(2, 1, 50),
            'sku' => $this->faker->unique()->bothify('SKU-####-????'),
            'status' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ];
    }
}
