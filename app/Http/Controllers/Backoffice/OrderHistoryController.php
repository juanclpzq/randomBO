<?php

namespace App\Http\Controllers\Backoffice;

use App\Http\Controllers\Controller;
use App\Models\Order;
use Illuminate\Http\Request;

class OrderHistoryController extends Controller
{
    public function show($orderId)
    {
        $order = Order::with(['items.item', 'items.modifiers', 'items.extras', 'items.exceptions'])
            ->findOrFail($orderId);

        return view('order_history.show', compact('order'));
    }
}
