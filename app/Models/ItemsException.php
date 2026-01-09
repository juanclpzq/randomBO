<?php

/**
 * Created by Reliese Model.
 */

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Class ItemsException
 * 
 * @property uuid $id
 * @property uuid $item_id
 * @property uuid $exception_id
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * 
 * @property Item $item
 * @property Exception $exception
 *
 * @package App\Models
 */
class ItemsException extends Model
{
	use SoftDeletes;
	protected $table = 'items_exceptions';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';

	protected $casts = [
		'id' => 'string',
		'item_id' => 'string',
		'exception_id' => 'string',
		'deleted_by' => 'string'
	];

	protected $fillable = [
		'item_id',
		'exception_id',
		'deleted_by'
	];

	public function item()
	{
		return $this->belongsTo(Item::class);
	}

	public function exception()
	{
		return $this->belongsTo(Exception::class);
	}
}
