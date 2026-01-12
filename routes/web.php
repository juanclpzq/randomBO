<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// Backoffice order history detail (used by Filament Order History view action)
Route::middleware(['auth'])->group(function () {
    Route::get('order-history/{id}', [App\Http\Controllers\Backoffice\OrderHistoryController::class, 'show'])
        ->name('backoffice.order_history.show');
});
