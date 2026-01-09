<?php

/**
 * Created by Reliese Model.
 */

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Class Payment
 * 
 * @property uuid $id
 * @property string $method
 * @property float $amount
 * @property string|null $reference
 * @property uuid|null $sale_id
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * 
 * @property Sale|null $sale
 *
 * @package App\Models
 */
class Payment extends Model
{
	use SoftDeletes;
	protected $table = 'payments';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';

	protected $casts = [
		'id' => 'string',
		'amount' => 'float',
		'sale_id' => 'string',
		'deleted_by' => 'string'
	];

	protected $fillable = [
		'method',
		'amount',
		'reference',
		'sale_id',
		'deleted_by'
	];

	public function sale()
	{
		return $this->belongsTo(Sale::class);
	}
}
