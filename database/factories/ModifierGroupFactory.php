<?php

namespace Database\Factories;

use App\Models\ModifierGroup;
use Illuminate\Database\Eloquent\Factories\Factory;

class ModifierGroupFactory extends Factory
{
    protected $model = ModifierGroup::class;

    public function definition(): array
    {
        return [
            'id' => $this->faker->uuid(),
            'name' => $this->faker->words(2, true),
            'description' => $this->faker->sentence(),
            'multiple_select' => $this->faker->boolean(),
            'required' => $this->faker->boolean(),
            'sort_order' => $this->faker->numberBetween(1, 100),
            'status' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ];
    }
}
