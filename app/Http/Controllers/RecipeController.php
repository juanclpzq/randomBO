<?php

namespace App\Http\Controllers;


use Illuminate\Http\Request;
use App\Models\Recipe;

class RecipeController extends Controller
{
    public function index(Request $request)
    {
        $query = Recipe::query();
        if ($request->filled('is_base')) {
            $query->where('is_base', $request->input('is_base'));
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
            'name' => 'required|string|max:100',
            'description' => 'nullable|string',
            'is_base' => 'nullable|boolean',
        ]);
        $item = Recipe::create($data);
        return response()->json(['data' => $item, 'meta' => [], 'errors' => []], 201);
    }

    public function show($id)
    {
        $item = Recipe::find($id);
        if (!$item) {
            return response()->json(['data' => null, 'meta' => [], 'errors' => ['Not found']], 404);
        }
        return response()->json(['data' => $item, 'meta' => [], 'errors' => []]);
    }

    public function update(Request $request, $id)
    {
        $item = Recipe::find($id);
        if (!$item) {
            return response()->json(['data' => null, 'meta' => [], 'errors' => ['Not found']], 404);
        }
        $data = $request->validate([
            'name' => 'sometimes|required|string|max:100',
            'description' => 'nullable|string',
            'is_base' => 'nullable|boolean',
        ]);
        $item->update($data);
        return response()->json(['data' => $item, 'meta' => [], 'errors' => []]);
    }

    public function destroy($id)
    {
        $item = Recipe::find($id);
        if (!$item) {
            return response()->json(['data' => null, 'meta' => [], 'errors' => ['Not found']], 404);
        }
        $item->delete();
        return response()->json(['data' => null, 'meta' => [], 'errors' => []], 204);
    }
}
