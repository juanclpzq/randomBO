<?php

/**
 * Created by Reliese Model.
 */

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Class Log
 * 
 * @property uuid $id
 * @property string $action
 * @property string $entity
 * @property uuid|null $entity_id
 * @property string|null $description
 * @property uuid|null $company_id
 * @property uuid|null $employee_id
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * 
 * @property Company|null $company
 * @property Employee|null $employee
 *
 * @package App\Models
 */
class Log extends Model
{
	use SoftDeletes;
	protected $table = 'logs';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';
	public $timestamps = false;

	protected $casts = [
		'id' => 'string',
		'entity_id' => 'string',
		'company_id' => 'string',
		'employee_id' => 'string',
		'deleted_by' => 'string'
	];

	protected $fillable = [
		'action',
		'entity',
		'entity_id',
		'description',
		'company_id',
		'employee_id',
		'deleted_by'
	];

	public function company()
	{
		return $this->belongsTo(Company::class);
	}

	public function employee()
	{
		return $this->belongsTo(Employee::class);
	}
}
