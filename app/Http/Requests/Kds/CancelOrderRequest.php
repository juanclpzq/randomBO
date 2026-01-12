<?php

namespace App\Http\Requests\Kds;

use Illuminate\Foundation\Http\FormRequest;

class CancelOrderRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, array<int, string>>
     */
    public function rules(): array
    {
        return [
            'reason' => ['required', 'string', 'max:500'],
            'employee_id' => ['nullable', 'uuid', 'exists:employees,id'],
        ];
    }

    /**
     * Get custom error messages for validator errors.
     *
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'reason.required' => 'Cancellation reason is required',
            'reason.max' => 'Reason cannot exceed 500 characters',
            'employee_id.uuid' => 'Employee ID must be a valid UUID',
            'employee_id.exists' => 'Employee not found',
        ];
    }
}
