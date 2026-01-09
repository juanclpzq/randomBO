<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class BypassAuthForToken
{
    /**
     * Handle an incoming request.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  \Closure  $next
     * @return mixed
     */
    public function handle(Request $request, Closure $next)
    {
        // Token hardcodeado temporal para pruebas
        $bypassToken = 'POS8-BYPASS-TOKEN';
        $headerToken = $request->header('X-Bypass-Token');

        // Si el header de bypass es correcto, simula usuario y permite el acceso
        if ($headerToken === $bypassToken) {
            $route = $request->route();
            $middlewares = $route?->gatherMiddleware() ?? [];
            if (in_array('auth:admin', $middlewares)) {
                $user = \App\Models\User::query()->first() ?? new \App\Models\User([
                    'id' => 1,
                    'name' => 'Bypass Admin',
                    'email' => 'bypass@admin.local',
                ]);
                auth('admin')->setUser($user);
            } elseif (in_array('auth:pos', $middlewares)) {
                $employee = \App\Models\Employee::query()->first() ?? new \App\Models\Employee([
                    'id' => 1,
                    'first_name' => 'Bypass',
                    'last_name' => 'POS',
                    'email' => 'bypass@pos.local',
                ]);
                auth('pos')->setUser($employee);
            }
            return $next($request);
        }

        // Si no hay header de bypass, verifica si hay token de autorización estándar
        $hasAuthHeader = $request->hasHeader('Authorization');
        if ($hasAuthHeader) {
            // Permite que el siguiente middleware (ej: Sanctum) valide el token
            return $next($request);
        }

        // Si no hay ninguno, rechaza la petición
        return response()->json([
            'message' => 'Unauthorized: Se requiere token de autorización o X-Bypass-Token.'
        ], 401);
    }
}
