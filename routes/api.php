<?php

use Illuminate\Support\Facades\Route;

Route::prefix('pos/v1')->middleware(['bypass.token', 'auth.sanctum', 'location'])->group(function () {
    // Autenticación
    Route::post('auth/login', [\App\Http\Controllers\POS\AuthController::class, 'login']);
    Route::post('auth/logout', [\App\Http\Controllers\POS\AuthController::class, 'logout']);
    Route::get('auth/session', [\App\Http\Controllers\POS\AuthController::class, 'session']);

    // Catálogo
    Route::get('catalog/items', [\App\Http\Controllers\POS\CatalogController::class, 'items']);
    Route::get('catalog/items/{id}', [\App\Http\Controllers\POS\CatalogController::class, 'showItem']);
    Route::get('catalog/modifiers', [\App\Http\Controllers\POS\CatalogController::class, 'modifiers']);
    Route::get('catalog/extras', [\App\Http\Controllers\POS\CatalogController::class, 'extras']);
    Route::get('catalog/recipes', [\App\Http\Controllers\POS\CatalogController::class, 'recipes']);
    Route::get('catalog/exceptions', [\App\Http\Controllers\POS\CatalogController::class, 'exceptions']);
    Route::get('catalog/group-modifiers', [\App\Http\Controllers\POS\CatalogController::class, 'groupModifiers']);

    // Inventario
    Route::get('inventory/stocks', [\App\Http\Controllers\POS\InventoryController::class, 'stocks']);
    Route::get('inventory/lots', [\App\Http\Controllers\POS\InventoryController::class, 'lots']);

    // Ventas
    Route::post('sales/checkout', [\App\Http\Controllers\POS\SalesController::class, 'checkout']);
    Route::get('sales', [\App\Http\Controllers\POS\SalesController::class, 'index']);
    Route::get('sales/{id}', [\App\Http\Controllers\POS\SalesController::class, 'show']);

    // Settings y perfil
    Route::get('settings', [\App\Http\Controllers\POS\SettingsController::class, 'index']);
    Route::get('profile', [\App\Http\Controllers\POS\ProfileController::class, 'index']);
});

// Alias para compatibilidad con JSON server (sin prefijo 'api')
Route::prefix('v1')->middleware(['bypass.token', 'auth.sanctum', 'location'])->group(function () {
    Route::get('items', [\App\Http\Controllers\POS\CatalogController::class, 'items']);
    Route::get('modifiers', [\App\Http\Controllers\POS\CatalogController::class, 'modifiers']);
    Route::get('extras', [\App\Http\Controllers\POS\CatalogController::class, 'extras']);
    Route::get('recipes', [\App\Http\Controllers\POS\CatalogController::class, 'recipes']);
    Route::get('exceptions', [\App\Http\Controllers\POS\CatalogController::class, 'exceptions']);
    Route::get('group-modifiers', [\App\Http\Controllers\POS\CatalogController::class, 'groupModifiers']);
});

// API Backoffice v1
Route::prefix('backoffice/v1')->middleware(['bypass.token', 'auth.sanctum'])->group(function () {
    // Inventario y catálogo
    Route::apiResource('inventory-items', App\Http\Controllers\Backoffice\InventoryItemController::class);
    Route::apiResource('items', App\Http\Controllers\Backoffice\ItemController::class);
    Route::apiResource('modifier-groups', App\Http\Controllers\Backoffice\ModifierGroupController::class);
    Route::apiResource('modifiers', App\Http\Controllers\Backoffice\ModifierController::class);
    Route::apiResource('extras', App\Http\Controllers\Backoffice\ExtraController::class);
    Route::apiResource('exceptions', App\Http\Controllers\Backoffice\ExceptionController::class);
    Route::apiResource('recipes', App\Http\Controllers\Backoffice\RecipeController::class);
    Route::apiResource('units', App\Http\Controllers\Backoffice\UnitController::class);
    Route::apiResource('locations', App\Http\Controllers\Backoffice\LocationController::class);
    // Otros endpoints de inventario (movimientos, traspasos, etc.) se agregarán aquí
});
