<?php

/**
 * Created by Reliese Model.
 */

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Class ItemsModifierGroup
 * 
 * @property uuid $id
 * @property uuid $item_id
 * @property uuid $modifier_group_id
 * @property bool|null $required
 * @property int|null $sort_order
 * @property string|null $deleted_at
 * @property uuid|null $deleted_by
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * 
 * @property Item $item
 * @property ModifierGroup $modifier_group
 *
 * @package App\Models
 */
class ItemsModifierGroup extends Model
{
	use SoftDeletes;
	protected $table = 'items_modifier_groups';
	public $incrementing = false;
	protected $primaryKey = 'id';
	protected $keyType = 'string';

	protected $casts = [
		'id' => 'string',
		'item_id' => 'string',
		'modifier_group_id' => 'string',
		'required' => 'bool',
		'sort_order' => 'int',
		'deleted_by' => 'string'
	];

	protected $fillable = [
		'item_id',
		'modifier_group_id',
		'required',
		'sort_order',
		'deleted_by'
	];

	public function item()
	{
		return $this->belongsTo(Item::class);
	}

	public function modifier_group()
	{
		return $this->belongsTo(ModifierGroup::class);
	}
}
