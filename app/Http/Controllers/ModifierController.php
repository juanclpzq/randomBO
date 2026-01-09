<?php

namespace App\Http\Controllers;


use Illuminate\Http\Request;
use App\Models\Modifier;


class ModifierController extends Controller
{
    public function index(Request $request)
    {
        $query = Modifier::query();
        if ($request->filled('status')) {
            $query->where('status', $request->input('status'));
        }
        if ($request->filled('company_id')) {
            $query->where('company_id', $request->input('company_id'));
        }
        if ($request->filled('modifier_group_id')) {
            $query->where('modifier_group_id', $request->input('modifier_group_id'));
        }
        if ($request->filled('search')) {
            $search = $request->input('search');
            $query->where(function($q) use ($search) {
                $q->where('name', 'ilike', "%$search%")
                  ->orWhere('description', 'ilike', "%$search%")
                  ->orWhere('id', $search);
            });
        }
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
            'modifier_group_id' => 'required|uuid',
            'name' => 'required|string|max:100',
            'description' => 'nullable|string',
            'price_change' => 'nullable|numeric',
            'sort_order' => 'nullable|integer',
            'company_id' => 'nullable|uuid',
            'status' => 'nullable|integer',
        ]);
        $item = Modifier::create($data);
        return response()->json(['data' => $item, 'meta' => [], 'errors' => []], 201);
    }

    public function show($id)
    {
        $item = Modifier::find($id);
        if (!$item) {
            return response()->json(['data' => null, 'meta' => [], 'errors' => ['Not found']], 404);
        }
        return response()->json(['data' => $item, 'meta' => [], 'errors' => []]);
    }

    public function update(Request $request, $id)
    {
        $item = Modifier::find($id);
        if (!$item) {
            return response()->json(['data' => null, 'meta' => [], 'errors' => ['Not found']], 404);
        }
        $data = $request->validate([
            'modifier_group_id' => 'sometimes|required|uuid',
            'name' => 'sometimes|required|string|max:100',
            'description' => 'nullable|string',
            'price_change' => 'nullable|numeric',
            'sort_order' => 'nullable|integer',
            'company_id' => 'nullable|uuid',
            'status' => 'nullable|integer',
        ]);
        $item->update($data);
        return response()->json(['data' => $item, 'meta' => [], 'errors' => []]);
    }

    public function destroy($id)
    {
        $item = Modifier::find($id);
        if (!$item) {
            return response()->json(['data' => null, 'meta' => [], 'errors' => ['Not found']], 404);
        }
        $item->delete();
        return response()->json(['data' => null, 'meta' => [], 'errors' => []], 204);
    }
}
