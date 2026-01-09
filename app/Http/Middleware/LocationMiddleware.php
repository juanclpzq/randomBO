<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class LocationMiddleware
{
    public function handle(Request $request, Closure $next)
    {
        $locationId = $request->header('X-Location-Id');
        if (!$locationId) {
            return response()->json([
                'data' => [],
                'meta' => [],
                'errors' => ['Location header (X-Location-Id) is required']
            ], 400);
        }
        // Puedes guardar el locationId en el request para usarlo en controladores/services
        $request->attributes->set('location_id', $locationId);
        return $next($request);
    }
}
