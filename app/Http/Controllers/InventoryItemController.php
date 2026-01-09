<?php

namespace App\Http\Controllers;


use Illuminate\Http\Request;
use App\Models\InventoryItem;


class InventoryItemController extends Controller
{
    public function index(Request $request)
    {
        $query = InventoryItem::query();

        // Filtros
        if ($request->filled('status')) {
            $query->where('status', $request->input('status'));
        }
        if ($request->filled('company_id')) {
            $query->where('company_id', $request->input('company_id'));
        }
        if ($request->filled('location_id')) {
            $query->where('location_id', $request->input('location_id'));
        }
        if ($request->filled('search')) {
            $search = $request->input('search');
            $query->where(function($q) use ($search) {
                $q->where('name', 'ilike', "%$search%")
                  ->orWhere('notes', 'ilike', "%$search%")
                  ->orWhere('id', $search);
            });
        }

        // Paginación
        $perPage = min($request->input('per_page', 20), 100);
        $items = $query->orderBy('name')->paginate($perPage);

        return response()->json([
            'data' => $items->items(),
            'meta' => [
                'current_page' => $items->currentPage(),
                'last_page' => $items->lastPage(),
                'per_page' => $items->perPage(),
                'total' => $items->total(),
            ],
            'errors' => []
        ]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'company_id' => 'required|uuid',
            'location_id' => 'nullable|uuid',
            'name' => 'required|string|max:100',
            'qty_per_purchase_unit' => 'required|numeric|min:0',
            'minimum_limit' => 'nullable|numeric|min:0',
            'notes' => 'nullable|string',
            'status' => 'nullable|integer',
            'purchase_unit_id' => 'required|uuid',
            'recipe_unit_id' => 'required|uuid',
            'item_kind' => 'nullable|string|max:30',
            'stock_policy' => 'nullable|string|max:15',
            'producible_recipe_id' => 'nullable|uuid',
            'stock_unit_id' => 'nullable|uuid',
            'is_lot_tracked' => 'boolean',
        ]);
        $item = InventoryItem::create($data);
        return response()->json(['data' => $item, 'meta' => [], 'errors' => []], 201);
    }

    public function show($id)
    {
        $item = InventoryItem::find($id);
        if (!$item) {
            return response()->json(['data' => null, 'meta' => [], 'errors' => ['Not found']], 404);
        }
        return response()->json(['data' => $item, 'meta' => [], 'errors' => []]);
    }

    public function update(Request $request, $id)
    {
        $item = InventoryItem::find($id);
        if (!$item) {
            return response()->json(['data' => null, 'meta' => [], 'errors' => ['Not found']], 404);
        }
        $data = $request->validate([
            'name' => 'sometimes|required|string|max:100',
            'qty_per_purchase_unit' => 'sometimes|required|numeric|min:0',
            'minimum_limit' => 'nullable|numeric|min:0',
            'notes' => 'nullable|string',
            'status' => 'nullable|integer',
            'purchase_unit_id' => 'sometimes|required|uuid',
            'recipe_unit_id' => 'sometimes|required|uuid',
            'item_kind' => 'nullable|string|max:30',
            'stock_policy' => 'nullable|string|max:15',
            'producible_recipe_id' => 'nullable|uuid',
            'stock_unit_id' => 'nullable|uuid',
            'is_lot_tracked' => 'boolean',
        ]);
        $item->update($data);
        return response()->json(['data' => $item, 'meta' => [], 'errors' => []]);
    }

    public function destroy($id)
    {
        $item = InventoryItem::find($id);
        if (!$item) {
            return response()->json(['data' => null, 'meta' => [], 'errors' => ['Not found']], 404);
        }
        $item->delete();
        return response()->json(['data' => null, 'meta' => [], 'errors' => []], 204);
    }
}
