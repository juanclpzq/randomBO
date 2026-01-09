<?php

namespace App\Http\Controllers\POS;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class CatalogController extends Controller
{
    public function items(Request $request)
    {
        $query = \App\Models\Item::query();
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
                  ->orWhere('sku', 'ilike', "%$search%")
                  ->orWhere('description', 'ilike', "%$search%")
                  ->orWhere('id', $search);
            });
        }
        $perPage = min($request->input('per_page', 100), 200);
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

    public function showItem($id)
    {
        $item = \App\Models\Item::with([
            'category',
            'modifiers',
            'modifierGroups',
            'extras',
            'exceptions',
            'recipe',
        ])->find($id);
        if (!$item) {
            return response()->json([
                'data' => null,
                'meta' => [],
                'errors' => ['Not found']
            ], 404);
        }
        return response()->json([
            'data' => $item,
            'meta' => [],
            'errors' => []
        ]);
    }

    public function modifiers(Request $request)
    {
        $query = \App\Models\Modifier::query();
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
        $perPage = min($request->input('per_page', 100), 200);
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


    public function extras(Request $request)
    {
        $query = \App\Models\Extra::query();
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
                  ->orWhere('id', $search);
            });
        }
        $perPage = min($request->input('per_page', 100), 200);
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


    public function recipes(Request $request)
    {
        $query = \App\Models\Recipe::query();
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
        $perPage = min($request->input('per_page', 100), 200);
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


    public function exceptions(Request $request)
    {
        $query = \App\Models\Exception::query();
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
                  ->orWhere('id', $search);
            });
        }
        $perPage = min($request->input('per_page', 100), 200);
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

    public function groupModifiers(Request $request)
    {
        $query = \App\Models\ModifierGroup::query();
        if ($request->filled('status')) {
            $query->where('status', $request->input('status'));
        }
        if ($request->filled('company_id')) {
            $query->where('company_id', $request->input('company_id'));
        }
        if ($request->filled('search')) {
            $search = $request->input('search');
            $query->where(function($q) use ($search) {
                $q->where('name', 'ilike', "%$search%")
                  ->orWhere('description', 'ilike', "%$search%")
                  ->orWhere('id', $search);
            });
        }
        $perPage = min($request->input('per_page', 100), 200);
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
}
