<?php

namespace Database\Factories;

use App\Models\Extra;
use Illuminate\Database\Eloquent\Factories\Factory;

class ExtraFactory extends Factory
{
    protected $model = Extra::class;

    public function definition(): array
    {
        return [
            'id' => $this->faker->uuid(),
            'name' => $this->faker->words(2, true),
            'price' => $this->faker->randomFloat(2, 0.5, 3),
            'created_at' => now(),
            'updated_at' => now(),
        ];
    }
}
