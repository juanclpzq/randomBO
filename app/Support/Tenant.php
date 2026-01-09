<?php

namespace App\Support;

use Illuminate\Support\Str;

class Tenant
{
    public static function companyId(): string
    {
        return (string) config('tenant.single_company_id');
    }
}
