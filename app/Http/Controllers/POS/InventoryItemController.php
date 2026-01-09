<?php

namespace App\Http\Controllers\POS;

use Illuminate\Http\Request;
use App\Models\InventoryItem;
use App\Http\Controllers\Controller;

class InventoryItemController extends Controller
{
    public function index(Request $request)
    {
        return response()->json(['data' => [], 'meta' => [], 'errors' => []]);
    }
}
