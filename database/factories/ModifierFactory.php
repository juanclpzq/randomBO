<?php

namespace Database\Factories;

use App\Models\Modifier;
use Illuminate\Database\Eloquent\Factories\Factory;

class ModifierFactory extends Factory
{
    protected $model = Modifier::class;

    public function definition(): array
    {
        return [
            'id' => $this->faker->uuid(),
            'modifier_group_id' => \App\Models\ModifierGroup::factory(),
            'name' => $this->faker->words(2, true),
            'price_change' => $this->faker->randomFloat(2, 0, 5),
            'created_at' => now(),
            'updated_at' => now(),
        ];
    }
}
