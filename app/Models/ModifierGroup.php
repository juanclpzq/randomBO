<?php

/**
 * Created by Reliese Model.
 */

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Class ModifierGroup
 * 
 * @property uuid $id
 * @property string $name
 * @property string|null $description
 * @property bool|null $multiple_select
 * @property bool|null $required
 * @property int|null $sort_order
 * @property uuid|null $company_id
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * @property int|null $status
 * 
 * @property Company|null $company
 * @property Collection|Modifier[] $modifiers
 * @property Collection|Item[] $items
 *
 * @package App\Models
 */
class ModifierGroup extends Model
{
	use SoftDeletes;
	protected $table = 'modifier_groups';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';

	protected $casts = [
		'id' => 'string',
		'multiple_select' => 'bool',
		'required' => 'bool',
		'sort_order' => 'int',
		'company_id' => 'string',
		'deleted_by' => 'string',
		'status' => 'int'
	];

	protected $fillable = [
		'name',
		'description',
		'multiple_select',
		'required',
		'sort_order',
		'company_id',
		'deleted_by',
		'status'
	];

	public function company()
	{
		return $this->belongsTo(Company::class);
	}

	public function modifiers()
	{
		return $this->hasMany(Modifier::class);
	}

	public function items()
	{
		return $this->belongsToMany(Item::class, 'items_modifier_groups')
					->withPivot('id', 'required', 'sort_order', 'deleted_at', 'deleted_by')
					->withTimestamps();
	}
}
