<?php

namespace Database\Factories;

use App\Models\Company;
use Illuminate\Database\Eloquent\Factories\Factory;

class CompanyFactory extends Factory
{
    protected $model = Company::class;

    public function definition(): array
    {
        return [
            'id' => $this->faker->uuid(),
            'name' => $this->faker->company(),
            'legal_name' => $this->faker->company().' Inc.',
            'tax_id' => $this->faker->numerify('##-#######'),
            'email' => $this->faker->companyEmail(),
            'phone' => $this->faker->phoneNumber(),
            'address' => $this->faker->address(),
            'language' => 'en',
            'subscription_status' => 1,
            'status' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ];
    }
}
