@extends('layouts.app')

@section('content')
<div class="container">
    <h1>Order #{{ $order->order_number }}</h1>
    <p><strong>Status:</strong> {{ strtoupper($order->status) }}</p>
    <p><strong>Customer:</strong> {{ $order->customer_name }}</p>
    <p><strong>Notes:</strong> {{ $order->note }}</p>
    <h2>Items</h2>
    <ul>
        @foreach($order->items as $item)
            <li>
                <strong>{{ $item->item?->name }}</strong> x {{ $item->quantity }}
                <br/>
                @if($item->modifiers->count())
                    <em>Modifiers:</em>
                    <ul>
                        @foreach($item->modifiers as $mod)
                            <li>{{ $mod->pivot->modifier_name ?? $mod->name }}</li>
                        @endforeach
                    </ul>
                @endif
                @if($item->extras->count())
                    <em>Extras:</em>
                    <ul>
                        @foreach($item->extras as $ex)
                            <li>{{ $ex->pivot->extra_name ?? $ex->name }}</li>
                        @endforeach
                    </ul>
                @endif
                @if($item->exceptions->count())
                    <em>Exceptions:</em>
                    <ul>
                        @foreach($item->exceptions as $ex)
                            <li>{{ $ex->pivot->exception_name ?? $ex->name }}</li>
                        @endforeach
                    </ul>
                @endif
            </li>
        @endforeach
    </ul>
</div>
@endsection
