<?php

namespace Database\Factories;

use App\Models\Location;
use Illuminate\Database\Eloquent\Factories\Factory;

class LocationFactory extends Factory
{
    protected $model = Location::class;

    public function definition(): array
    {
        return [
            'id' => $this->faker->uuid(),
            'name' => $this->faker->city().' Branch',
            'code' => $this->faker->unique()->lexify('LOC-???'),
            'phone' => $this->faker->phoneNumber(),
            'email' => $this->faker->email(),
            'address' => $this->faker->address(),
            'timezone' => 'America/New_York',
            'status' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ];
    }
}
