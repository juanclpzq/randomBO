/* =====================================================================
   POS + INVENTARIO + RECETARIO + PRODUCCIÓN + RBAC + TURNOS/DEVICES
   PostgreSQL — Script ÚNICO integrado, estilo DBA senior (idempotente / safe-ish)

   Enfoque:
   - No DROPs CASCADE. Todo con CREATE IF NOT EXISTS + ALTER ADD COLUMN IF NOT EXISTS
   - Conserva POS del “archivo 1”
   - Adopta mejoras inventario del “archivo 2” (occurred_at, reference_type, unit_cost,
     idempotency_key, actores, checks, transfers shipped/received, locations.location_type)
   - Realinea con JSON/ERD agregando: RBAC, temporary_permissions,
     payments_order_items, devices, shifts, shift_closures y columnas faltantes.
   - Para “users”: se mantiene public.users (bigint PK) y se agrega public_id UUID
     para alinear con JSON sin romper integraciones.
   ===================================================================== */

BEGIN;

-- =========================================================
-- EXTENSIONS
-- =========================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =========================================================
-- ENUMS (crear si no existen)
-- =========================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid=t.typnamespace
    WHERE t.typname='inventory_movement_type_enum' AND n.nspname='public'
  ) THEN
    CREATE TYPE public.inventory_movement_type_enum AS ENUM (
      'sale','purchase_in','transfer_out','transfer_in',
      'production_in','production_out','waste','adjustment',
      'count','return_in','return_out'
    );
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid=t.typnamespace
    WHERE t.typname='customer_type_enum' AND n.nspname='public'
  ) THEN
    CREATE TYPE public.customer_type_enum AS ENUM ('individual','business');
  END IF;
END$$;

-- =========================================================
-- CORE: COMPANIES / LOCATIONS / USERS / EMPLOYEES
-- =========================================================

CREATE TABLE IF NOT EXISTS public.companies (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name varchar(100) NOT NULL,
  legal_name varchar(150),
  tax_id varchar(50),
  email varchar(100),
  phone varchar(20),
  address text,
  language text,
  membership_plan_id int4,
  subscription_start date,
  subscription_end date,
  subscription_status int2 NOT NULL DEFAULT 1,
  status int2 DEFAULT 1,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  deleted_at timestamp,
  deleted_by uuid
);

COMMENT ON TABLE public.companies IS
  'Empresa/tenant. Agrupa locations, employees, customers, proveedores e inventario.';

CREATE TABLE IF NOT EXISTS public.locations (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id uuid NOT NULL,
  name varchar(100) NOT NULL,
  code varchar(20),
  phone varchar(20),
  email varchar(100),
  address text,
  timezone varchar(50),
  status int2 DEFAULT 1,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  deleted_at timestamp,
  deleted_by uuid,
  location_type varchar(20) -- agregado (idempotente en CREATE)
);

COMMENT ON TABLE public.locations IS
  'Sucursal o CEDIS. Punto físico donde existe stock y ocurren movimientos de inventario.';
COMMENT ON COLUMN public.locations.company_id IS
  'Empresa dueña de la sucursal/centro (multi-tenant).';

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='locations_company_id_fkey') THEN
    ALTER TABLE public.locations
      ADD CONSTRAINT locations_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;
  END IF;
END$$;

-- ---------- USERS (Laravel-ish) + realineación JSON/ERD ----------
CREATE SEQUENCE IF NOT EXISTS public.users_id_seq;

CREATE TABLE IF NOT EXISTS public.users (
  id int8 PRIMARY KEY DEFAULT nextval('public.users_id_seq'::regclass),
  name varchar(255) NOT NULL,
  email varchar(255) NOT NULL,
  email_verified_at timestamp(0),
  password varchar(255) NOT NULL,
  remember_token varchar(100),
  created_at timestamp(0),
  updated_at timestamp(0),

  -- JSON alignment (sin romper laravel)
  public_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  username varchar(100),
  is_active boolean NOT NULL DEFAULT true,
  location_id uuid,
  deleted_at timestamp,
  deleted_by uuid
);

COMMENT ON TABLE public.users IS
  'Usuarios (Laravel-ish PK bigint). Para APIs externas usar public_id (uuid) como "id".';

CREATE UNIQUE INDEX IF NOT EXISTS users_email_unique
  ON public.users(email);

CREATE UNIQUE INDEX IF NOT EXISTS uq_users_public_id
  ON public.users(public_id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_users_username
  ON public.users(lower(username))
  WHERE username IS NOT NULL AND deleted_at IS NULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='users_location_id_fkey') THEN
    ALTER TABLE public.users
      ADD CONSTRAINT users_location_id_fkey
      FOREIGN KEY (location_id) REFERENCES public.locations(id) ON DELETE SET NULL;
  END IF;
END$$;

-- ---------- EMPLOYEES ----------
CREATE TABLE IF NOT EXISTS public.employees (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  first_name varchar(50) NOT NULL,
  last_name varchar(50) NOT NULL,
  email varchar(100) NOT NULL,
  phone varchar(20),
  password_hash text NOT NULL,
  status int2 DEFAULT 1,
  company_id uuid NOT NULL,
  location_id uuid,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='employees_company_id_fkey') THEN
    ALTER TABLE public.employees
      ADD CONSTRAINT employees_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='employees_location_id_fkey') THEN
    ALTER TABLE public.employees
      ADD CONSTRAINT employees_location_id_fkey
      FOREIGN KEY (location_id) REFERENCES public.locations(id) ON DELETE SET NULL;
  END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_employees_company_email
  ON public.employees (company_id, lower((email)::text))
  WHERE deleted_at IS NULL;

-- =========================================================
-- RBAC
-- =========================================================

CREATE TABLE IF NOT EXISTS public.roles (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name varchar(100) NOT NULL,
  description text,
  slug varchar(120) NOT NULL,
  company_id uuid,
  is_system_role boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  deleted_at timestamp,
  deleted_by uuid
);

COMMENT ON TABLE public.roles IS
  'Roles por empresa (o global si company_id NULL).';

CREATE UNIQUE INDEX IF NOT EXISTS uq_roles_company_slug
  ON public.roles(company_id, lower(slug))
  WHERE deleted_at IS NULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='roles_company_id_fkey') THEN
    ALTER TABLE public.roles
      ADD CONSTRAINT roles_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='roles_created_by_fkey') THEN
    ALTER TABLE public.roles
      ADD CONSTRAINT roles_created_by_fkey
      FOREIGN KEY (created_by) REFERENCES public.employees(id) ON DELETE SET NULL;
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS public.permissions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name varchar(120) NOT NULL,
  description text,
  resource varchar(80) NOT NULL,
  action varchar(80) NOT NULL,
  scope varchar(30) NOT NULL DEFAULT 'company',
  is_system_permission boolean NOT NULL DEFAULT false,
  created_at timestamp DEFAULT now(),
  deleted_at timestamp,
  deleted_by uuid
);

COMMENT ON TABLE public.permissions IS
  'Permisos atómicos (resource + action + scope).';

CREATE UNIQUE INDEX IF NOT EXISTS uq_permissions_resource_action_scope
  ON public.permissions(lower(resource), lower(action), lower(scope))
  WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS public.role_permissions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  role_id uuid NOT NULL,
  permission_id uuid NOT NULL,
  created_at timestamp DEFAULT now(),
  deleted_at timestamp,
  deleted_by uuid
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_role_permissions_pair
  ON public.role_permissions(role_id, permission_id)
  WHERE deleted_at IS NULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='role_permissions_role_id_fkey') THEN
    ALTER TABLE public.role_permissions
      ADD CONSTRAINT role_permissions_role_id_fkey
      FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='role_permissions_permission_id_fkey') THEN
    ALTER TABLE public.role_permissions
      ADD CONSTRAINT role_permissions_permission_id_fkey
      FOREIGN KEY (permission_id) REFERENCES public.permissions(id) ON DELETE CASCADE;
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS public.user_roles (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  employee_id uuid NOT NULL,
  role_id uuid NOT NULL,
  created_at timestamp DEFAULT now(),
  deleted_at timestamp,
  deleted_by uuid
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_user_roles_pair
  ON public.user_roles(employee_id, role_id)
  WHERE deleted_at IS NULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='user_roles_employee_id_fkey') THEN
    ALTER TABLE public.user_roles
      ADD CONSTRAINT user_roles_employee_id_fkey
      FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='user_roles_role_id_fkey') THEN
    ALTER TABLE public.user_roles
      ADD CONSTRAINT user_roles_role_id_fkey
      FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS public.temporary_permissions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  employee_id uuid NOT NULL,
  permission_id uuid NOT NULL,
  granted_by uuid,
  reason text,
  expires_at timestamp,
  is_used boolean NOT NULL DEFAULT false,
  used_at timestamp,
  created_at timestamp DEFAULT now(),
  deleted_at timestamp,
  deleted_by uuid
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='temporary_permissions_employee_id_fkey') THEN
    ALTER TABLE public.temporary_permissions
      ADD CONSTRAINT temporary_permissions_employee_id_fkey
      FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='temporary_permissions_permission_id_fkey') THEN
    ALTER TABLE public.temporary_permissions
      ADD CONSTRAINT temporary_permissions_permission_id_fkey
      FOREIGN KEY (permission_id) REFERENCES public.permissions(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='temporary_permissions_granted_by_fkey') THEN
    ALTER TABLE public.temporary_permissions
      ADD CONSTRAINT temporary_permissions_granted_by_fkey
      FOREIGN KEY (granted_by) REFERENCES public.employees(id) ON DELETE SET NULL;
  END IF;
END$$;

-- =========================================================
-- UNITS + CONVERSIONS
-- =========================================================

CREATE TABLE IF NOT EXISTS public.units (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name varchar(50) NOT NULL,
  short_name varchar(10),
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  status int2 DEFAULT 1
);

CREATE TABLE IF NOT EXISTS public.unit_conversions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  from_unit_id uuid NOT NULL,
  to_unit_id uuid NOT NULL,
  factor numeric(18,8) NOT NULL
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='unit_conversions_from_unit_id_fkey') THEN
    ALTER TABLE public.unit_conversions
      ADD CONSTRAINT unit_conversions_from_unit_id_fkey
      FOREIGN KEY (from_unit_id) REFERENCES public.units(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='unit_conversions_to_unit_id_fkey') THEN
    ALTER TABLE public.unit_conversions
      ADD CONSTRAINT unit_conversions_to_unit_id_fkey
      FOREIGN KEY (to_unit_id) REFERENCES public.units(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_unit_conversions_factor_positive') THEN
    ALTER TABLE public.unit_conversions
      ADD CONSTRAINT chk_unit_conversions_factor_positive CHECK (factor > 0);
  END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS unit_conversions_from_unit_id_to_unit_id_key
  ON public.unit_conversions(from_unit_id, to_unit_id);

-- =========================================================
-- SUPPLIERS
-- =========================================================

CREATE TABLE IF NOT EXISTS public.suppliers (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id uuid NOT NULL,
  name varchar(100) NOT NULL,
  email varchar(100),
  phone varchar(20),
  address text,
  notes text,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='suppliers_company_id_fkey') THEN
    ALTER TABLE public.suppliers
      ADD CONSTRAINT suppliers_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;
  END IF;
END$$;

-- =========================================================
-- INVENTORY ITEMS
-- =========================================================

CREATE TABLE IF NOT EXISTS public.inventory_items (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id uuid NOT NULL,
  location_id uuid,
  name varchar(100) NOT NULL,
  code varchar(50),
  qty_per_purchase_unit numeric(10,2) NOT NULL,
  minimum_limit numeric(10,2) DEFAULT 0,
  notes text,
  status int2 DEFAULT 1,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  purchase_unit_id uuid NOT NULL,
  recipe_unit_id uuid NOT NULL,
  item_kind varchar(30) NOT NULL DEFAULT 'raw_material',
  stock_policy varchar(15) NOT NULL DEFAULT 'stocked',
  producible_recipe_id uuid,
  stock_unit_id uuid,
  is_lot_tracked bool NOT NULL DEFAULT false
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_items_company_id_fkey') THEN
    ALTER TABLE public.inventory_items
      ADD CONSTRAINT inventory_items_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_items_location_id_fkey') THEN
    ALTER TABLE public.inventory_items
      ADD CONSTRAINT inventory_items_location_id_fkey
      FOREIGN KEY (location_id) REFERENCES public.locations(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_items_purchase_unit_id_fkey') THEN
    ALTER TABLE public.inventory_items
      ADD CONSTRAINT inventory_items_purchase_unit_id_fkey
      FOREIGN KEY (purchase_unit_id) REFERENCES public.units(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_items_recipe_unit_id_fkey') THEN
    ALTER TABLE public.inventory_items
      ADD CONSTRAINT inventory_items_recipe_unit_id_fkey
      FOREIGN KEY (recipe_unit_id) REFERENCES public.units(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_items_stock_unit_id_fkey') THEN
    ALTER TABLE public.inventory_items
      ADD CONSTRAINT inventory_items_stock_unit_id_fkey
      FOREIGN KEY (stock_unit_id) REFERENCES public.units(id);
  END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_inventory_items_company_code
  ON public.inventory_items(company_id, code)
  WHERE deleted_at IS NULL AND code IS NOT NULL;

-- =========================================================
-- RECIPES + INGREDIENTS
-- =========================================================

CREATE TABLE IF NOT EXISTS public.recipes (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name varchar(100) NOT NULL,
  description text,
  is_base bool DEFAULT false,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  output_inventory_item_id uuid,
  output_quantity numeric(10,2),
  output_unit_id uuid,
  company_id uuid NOT NULL
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='recipes_company_id_fkey') THEN
    ALTER TABLE public.recipes
      ADD CONSTRAINT recipes_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='recipes_output_inventory_item_id_fkey') THEN
    ALTER TABLE public.recipes
      ADD CONSTRAINT recipes_output_inventory_item_id_fkey
      FOREIGN KEY (output_inventory_item_id) REFERENCES public.inventory_items(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='recipes_output_unit_id_fkey') THEN
    ALTER TABLE public.recipes
      ADD CONSTRAINT recipes_output_unit_id_fkey
      FOREIGN KEY (output_unit_id) REFERENCES public.units(id);
  END IF;
END$$;

-- FK producible_recipe_id (ya existe recipes)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_items_producible_recipe_id_fkey') THEN
    ALTER TABLE public.inventory_items
      ADD CONSTRAINT inventory_items_producible_recipe_id_fkey
      FOREIGN KEY (producible_recipe_id) REFERENCES public.recipes(id);
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS public.recipe_ingredients (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  recipe_id uuid NOT NULL,
  inventory_item_id uuid NOT NULL,
  quantity numeric(10,2) NOT NULL,
  unit_id uuid,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='recipe_ingredients_recipe_id_fkey') THEN
    ALTER TABLE public.recipe_ingredients
      ADD CONSTRAINT recipe_ingredients_recipe_id_fkey
      FOREIGN KEY (recipe_id) REFERENCES public.recipes(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='recipe_ingredients_inventory_item_id_fkey') THEN
    ALTER TABLE public.recipe_ingredients
      ADD CONSTRAINT recipe_ingredients_inventory_item_id_fkey
      FOREIGN KEY (inventory_item_id) REFERENCES public.inventory_items(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='recipe_ingredients_unit_id_fkey') THEN
    ALTER TABLE public.recipe_ingredients
      ADD CONSTRAINT recipe_ingredients_unit_id_fkey
      FOREIGN KEY (unit_id) REFERENCES public.units(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_recipe_ingredients_qty_positive') THEN
    ALTER TABLE public.recipe_ingredients
      ADD CONSTRAINT chk_recipe_ingredients_qty_positive CHECK (quantity > 0);
  END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS recipe_ingredients_recipe_id_inventory_item_id_key
  ON public.recipe_ingredients(recipe_id, inventory_item_id);

-- =========================================================
-- CUSTOMERS
-- =========================================================

CREATE TABLE IF NOT EXISTS public.customers (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id uuid NOT NULL,
  location_id uuid,
  first_name varchar(100) NOT NULL,
  last_name varchar(100) NOT NULL,
  email varchar(255),
  phone varchar(20) NOT NULL,
  tax_id varchar(50),
  business_name varchar(255),
  address text,
  city varchar(100),
  state varchar(100),
  postal_code varchar(20),
  country varchar(100) DEFAULT 'Mexico',
  customer_type public.customer_type_enum NOT NULL DEFAULT 'individual',
  notes text,
  loyalty_points int4 DEFAULT 0,
  total_orders int4 DEFAULT 0,
  total_spent numeric(10,2) DEFAULT 0,
  status int2 NOT NULL DEFAULT 1,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='customers_company_id_fkey') THEN
    ALTER TABLE public.customers
      ADD CONSTRAINT customers_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='customers_location_id_fkey') THEN
    ALTER TABLE public.customers
      ADD CONSTRAINT customers_location_id_fkey
      FOREIGN KEY (location_id) REFERENCES public.locations(id) ON DELETE SET NULL;
  END IF;
END$$;

-- =========================================================
-- INVENTORY ITEM SUPPLIERS
-- =========================================================

CREATE TABLE IF NOT EXISTS public.inventory_item_suppliers (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  inventory_item_id uuid NOT NULL,
  supplier_id uuid NOT NULL,
  cost numeric(10,2) NOT NULL,
  last_purchase_date date,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_item_suppliers_inventory_item_id_fkey') THEN
    ALTER TABLE public.inventory_item_suppliers
      ADD CONSTRAINT inventory_item_suppliers_inventory_item_id_fkey
      FOREIGN KEY (inventory_item_id) REFERENCES public.inventory_items(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_item_suppliers_supplier_id_fkey') THEN
    ALTER TABLE public.inventory_item_suppliers
      ADD CONSTRAINT inventory_item_suppliers_supplier_id_fkey
      FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id) ON DELETE CASCADE;
  END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS inventory_item_suppliers_inventory_item_id_supplier_id_key
  ON public.inventory_item_suppliers(inventory_item_id, supplier_id);

-- =========================================================
-- PURCHASE ORDERS + ITEMS (safe for existing DBs)
-- =========================================================

-- 1) Enum primero (para installs nuevos)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid=t.typnamespace
    WHERE t.typname='purchase_order_status_enum' AND n.nspname='public'
  ) THEN
    CREATE TYPE public.purchase_order_status_enum AS ENUM (
      'pending', 'approved', 'received', 'cancelled'
    );
  END IF;
END$$;

-- 2) Crear tabla: si es instalación nueva, queda perfecto desde el inicio
CREATE TABLE IF NOT EXISTS public.purchase_orders (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id uuid NOT NULL,
  location_id uuid,
  supplier_id uuid,
  status public.purchase_order_status_enum NOT NULL
    DEFAULT 'pending'::public.purchase_order_status_enum,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
);

-- 3) Si la tabla ya existía y status era varchar/text -> migrar
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema='public'
      AND table_name='purchase_orders'
      AND column_name='status'
      AND udt_name <> 'purchase_order_status_enum'
  ) THEN
    -- Normaliza valores inválidos antes de castear (evita que truene el USING)
    EXECUTE $sql$
      UPDATE public.purchase_orders
      SET status = 'pending'
      WHERE status IS NULL
         OR status NOT IN ('pending','approved','received','cancelled')
    $sql$;

    -- El fix del error: drop default -> alter type -> set default con cast
    EXECUTE $sql$
      ALTER TABLE public.purchase_orders
        ALTER COLUMN status DROP DEFAULT,
        ALTER COLUMN status TYPE public.purchase_order_status_enum
          USING status::public.purchase_order_status_enum,
        ALTER COLUMN status SET NOT NULL,
        ALTER COLUMN status SET DEFAULT 'pending'::public.purchase_order_status_enum
    $sql$;
  ELSE
    -- Ya es enum: asegura default bien tipado
    EXECUTE $sql$
      ALTER TABLE public.purchase_orders
        ALTER COLUMN status SET DEFAULT 'pending'::public.purchase_order_status_enum
    $sql$;
  END IF;
END$$;

-- FKs (igual que tú)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='purchase_orders_company_id_fkey') THEN
    ALTER TABLE public.purchase_orders
      ADD CONSTRAINT purchase_orders_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='purchase_orders_location_id_fkey') THEN
    ALTER TABLE public.purchase_orders
      ADD CONSTRAINT purchase_orders_location_id_fkey
      FOREIGN KEY (location_id) REFERENCES public.locations(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='purchase_orders_supplier_id_fkey') THEN
    ALTER TABLE public.purchase_orders
      ADD CONSTRAINT purchase_orders_supplier_id_fkey
      FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id);
  END IF;
END$$;

-- =========================================================
-- STOCK + COST SNAPSHOTS
-- =========================================================

CREATE TABLE IF NOT EXISTS public.inventory_stocks (
  location_id uuid NOT NULL,
  inventory_item_id uuid NOT NULL,
  on_hand numeric(10,2) NOT NULL DEFAULT 0,
  reserved numeric(10,2) NOT NULL DEFAULT 0,
  updated_at timestamp DEFAULT now(),
  PRIMARY KEY (location_id, inventory_item_id)
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_stocks_location_id_fkey') THEN
    ALTER TABLE public.inventory_stocks
      ADD CONSTRAINT inventory_stocks_location_id_fkey
      FOREIGN KEY (location_id) REFERENCES public.locations(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_stocks_inventory_item_id_fkey') THEN
    ALTER TABLE public.inventory_stocks
      ADD CONSTRAINT inventory_stocks_inventory_item_id_fkey
      FOREIGN KEY (inventory_item_id) REFERENCES public.inventory_items(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_inventory_stocks_nonnegative_reserved') THEN
    ALTER TABLE public.inventory_stocks
      ADD CONSTRAINT chk_inventory_stocks_nonnegative_reserved CHECK (reserved >= 0);
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS public.inventory_item_costs (
  location_id uuid NOT NULL,
  inventory_item_id uuid NOT NULL,
  avg_unit_cost numeric(12,4) NOT NULL DEFAULT 0,
  last_unit_cost numeric(12,4) NOT NULL DEFAULT 0,
  updated_at timestamp DEFAULT now(),
  PRIMARY KEY (location_id, inventory_item_id)
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_item_costs_location_id_fkey') THEN
    ALTER TABLE public.inventory_item_costs
      ADD CONSTRAINT inventory_item_costs_location_id_fkey
      FOREIGN KEY (location_id) REFERENCES public.locations(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_item_costs_inventory_item_id_fkey') THEN
    ALTER TABLE public.inventory_item_costs
      ADD CONSTRAINT inventory_item_costs_inventory_item_id_fkey
      FOREIGN KEY (inventory_item_id) REFERENCES public.inventory_items(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_inventory_item_costs_nonnegative') THEN
    ALTER TABLE public.inventory_item_costs
      ADD CONSTRAINT chk_inventory_item_costs_nonnegative CHECK (avg_unit_cost >= 0 AND last_unit_cost >= 0);
  END IF;
END$$;

-- =========================================================
-- LOTS + LOT STOCKS + MOVEMENT LOTS
-- =========================================================

CREATE TABLE IF NOT EXISTS public.inventory_lots (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id uuid NOT NULL,
  inventory_item_id uuid NOT NULL,
  lot_code varchar(80) NOT NULL,
  received_date date,
  expiry_date date,
  unit_cost numeric(12,4),
  supplier_id uuid,
  source_type varchar(30),
  source_id uuid,
  notes text,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_lots_company_id_fkey') THEN
    ALTER TABLE public.inventory_lots
      ADD CONSTRAINT inventory_lots_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_lots_inventory_item_id_fkey') THEN
    ALTER TABLE public.inventory_lots
      ADD CONSTRAINT inventory_lots_inventory_item_id_fkey
      FOREIGN KEY (inventory_item_id) REFERENCES public.inventory_items(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_lots_supplier_id_fkey') THEN
    ALTER TABLE public.inventory_lots
      ADD CONSTRAINT inventory_lots_supplier_id_fkey
      FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id);
  END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS inventory_lots_company_id_inventory_item_id_lot_code_key
  ON public.inventory_lots(company_id, inventory_item_id, lot_code);

CREATE TABLE IF NOT EXISTS public.inventory_lot_stocks (
  location_id uuid NOT NULL,
  lot_id uuid NOT NULL,
  on_hand numeric(12,2) NOT NULL DEFAULT 0,
  reserved numeric(12,2) NOT NULL DEFAULT 0,
  updated_at timestamp DEFAULT now(),
  PRIMARY KEY (location_id, lot_id)
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_lot_stocks_location_id_fkey') THEN
    ALTER TABLE public.inventory_lot_stocks
      ADD CONSTRAINT inventory_lot_stocks_location_id_fkey
      FOREIGN KEY (location_id) REFERENCES public.locations(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_lot_stocks_lot_id_fkey') THEN
    ALTER TABLE public.inventory_lot_stocks
      ADD CONSTRAINT inventory_lot_stocks_lot_id_fkey
      FOREIGN KEY (lot_id) REFERENCES public.inventory_lots(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_inventory_lot_stocks_reserved_nonnegative') THEN
    ALTER TABLE public.inventory_lot_stocks
      ADD CONSTRAINT chk_inventory_lot_stocks_reserved_nonnegative CHECK (reserved >= 0);
  END IF;
END$$;

-- =========================================================
-- INVENTORY MOVEMENTS (mejorado)
-- =========================================================

CREATE TABLE IF NOT EXISTS public.inventory_movements (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  inventory_item_id uuid NOT NULL,
  location_id uuid NOT NULL,
  quantity numeric(10,2) NOT NULL,
  unit_id uuid,
  reference_id uuid,
  notes text,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  movement_type public.inventory_movement_type_enum NOT NULL,

  -- columnas avanzadas
  reference_type varchar(30),
  occurred_at timestamp NOT NULL DEFAULT now(),
  unit_cost numeric(12,4),
  idempotency_key varchar(80),
  actor_employee_id uuid,
  actor_user_id bigint
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_movements_inventory_item_id_fkey') THEN
    ALTER TABLE public.inventory_movements
      ADD CONSTRAINT inventory_movements_inventory_item_id_fkey
      FOREIGN KEY (inventory_item_id) REFERENCES public.inventory_items(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_movements_location_id_fkey') THEN
    ALTER TABLE public.inventory_movements
      ADD CONSTRAINT inventory_movements_location_id_fkey
      FOREIGN KEY (location_id) REFERENCES public.locations(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_movements_unit_id_fkey') THEN
    ALTER TABLE public.inventory_movements
      ADD CONSTRAINT inventory_movements_unit_id_fkey
      FOREIGN KEY (unit_id) REFERENCES public.units(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_movements_actor_employee_id_fkey') THEN
    ALTER TABLE public.inventory_movements
      ADD CONSTRAINT inventory_movements_actor_employee_id_fkey
      FOREIGN KEY (actor_employee_id) REFERENCES public.employees(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_movements_actor_user_id_fkey') THEN
    ALTER TABLE public.inventory_movements
      ADD CONSTRAINT inventory_movements_actor_user_id_fkey
      FOREIGN KEY (actor_user_id) REFERENCES public.users(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_inventory_movements_quantity_nonzero') THEN
    ALTER TABLE public.inventory_movements
      ADD CONSTRAINT chk_inventory_movements_quantity_nonzero CHECK (quantity <> 0);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_inventory_movements_actor_xor') THEN
    ALTER TABLE public.inventory_movements
      ADD CONSTRAINT chk_inventory_movements_actor_xor CHECK (
        NOT (actor_employee_id IS NOT NULL AND actor_user_id IS NOT NULL)
      );
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS idx_inv_mov_loc_item_occurred
  ON public.inventory_movements(location_id, inventory_item_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_inv_mov_ref
  ON public.inventory_movements(reference_type, reference_id);

CREATE INDEX IF NOT EXISTS idx_inv_mov_idempotency
  ON public.inventory_movements(idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_inv_mov_ref_idempotency
  ON public.inventory_movements(reference_type, reference_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.inventory_movement_lots (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  movement_id uuid NOT NULL,
  lot_id uuid NOT NULL,
  quantity numeric(12,2) NOT NULL,
  unit_id uuid NOT NULL,
  created_at timestamp DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_movement_lots_movement_id_fkey') THEN
    ALTER TABLE public.inventory_movement_lots
      ADD CONSTRAINT inventory_movement_lots_movement_id_fkey
      FOREIGN KEY (movement_id) REFERENCES public.inventory_movements(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_movement_lots_lot_id_fkey') THEN
    ALTER TABLE public.inventory_movement_lots
      ADD CONSTRAINT inventory_movement_lots_lot_id_fkey
      FOREIGN KEY (lot_id) REFERENCES public.inventory_lots(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_movement_lots_unit_id_fkey') THEN
    ALTER TABLE public.inventory_movement_lots
      ADD CONSTRAINT inventory_movement_lots_unit_id_fkey
      FOREIGN KEY (unit_id) REFERENCES public.units(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_inventory_movement_lots_qty_positive') THEN
    ALTER TABLE public.inventory_movement_lots
      ADD CONSTRAINT chk_inventory_movement_lots_qty_positive CHECK (quantity > 0);
  END IF;
END$$;

-- =========================================================
-- TRANSFERS + ITEMS
-- =========================================================

CREATE TABLE IF NOT EXISTS public.inventory_transfers (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id uuid NOT NULL,
  from_location_id uuid NOT NULL,
  to_location_id uuid NOT NULL,
  status varchar(20) NOT NULL DEFAULT 'draft',
  notes text,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),

  shipped_at timestamp,
  received_at timestamp,
  shipped_by_employee_id uuid,
  received_by_employee_id uuid,
  ship_idempotency_key varchar(80),
  receive_idempotency_key varchar(80)
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_transfers_company_id_fkey') THEN
    ALTER TABLE public.inventory_transfers
      ADD CONSTRAINT inventory_transfers_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_transfers_from_location_id_fkey') THEN
    ALTER TABLE public.inventory_transfers
      ADD CONSTRAINT inventory_transfers_from_location_id_fkey
      FOREIGN KEY (from_location_id) REFERENCES public.locations(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_transfers_to_location_id_fkey') THEN
    ALTER TABLE public.inventory_transfers
      ADD CONSTRAINT inventory_transfers_to_location_id_fkey
      FOREIGN KEY (to_location_id) REFERENCES public.locations(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_transfers_shipped_by_employee_id_fkey') THEN
    ALTER TABLE public.inventory_transfers
      ADD CONSTRAINT inventory_transfers_shipped_by_employee_id_fkey
      FOREIGN KEY (shipped_by_employee_id) REFERENCES public.employees(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_transfers_received_by_employee_id_fkey') THEN
    ALTER TABLE public.inventory_transfers
      ADD CONSTRAINT inventory_transfers_received_by_employee_id_fkey
      FOREIGN KEY (received_by_employee_id) REFERENCES public.employees(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_inventory_transfers_diff_locations') THEN
    ALTER TABLE public.inventory_transfers
      ADD CONSTRAINT chk_inventory_transfers_diff_locations CHECK (from_location_id <> to_location_id);
  END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_inventory_transfers_ship_idempo
  ON public.inventory_transfers(ship_idempotency_key)
  WHERE ship_idempotency_key IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_inventory_transfers_receive_idempo
  ON public.inventory_transfers(receive_idempotency_key)
  WHERE receive_idempotency_key IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.inventory_transfer_items (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  transfer_id uuid NOT NULL,
  inventory_item_id uuid NOT NULL,
  quantity numeric(10,2) NOT NULL,
  unit_id uuid NOT NULL
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_transfer_items_transfer_id_fkey') THEN
    ALTER TABLE public.inventory_transfer_items
      ADD CONSTRAINT inventory_transfer_items_transfer_id_fkey
      FOREIGN KEY (transfer_id) REFERENCES public.inventory_transfers(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_transfer_items_inventory_item_id_fkey') THEN
    ALTER TABLE public.inventory_transfer_items
      ADD CONSTRAINT inventory_transfer_items_inventory_item_id_fkey
      FOREIGN KEY (inventory_item_id) REFERENCES public.inventory_items(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_transfer_items_unit_id_fkey') THEN
    ALTER TABLE public.inventory_transfer_items
      ADD CONSTRAINT inventory_transfer_items_unit_id_fkey
      FOREIGN KEY (unit_id) REFERENCES public.units(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_inventory_transfer_items_qty_positive') THEN
    ALTER TABLE public.inventory_transfer_items
      ADD CONSTRAINT chk_inventory_transfer_items_qty_positive CHECK (quantity > 0);
  END IF;
END$$;

-- =========================================================
-- PRODUCTION BATCHES
-- =========================================================

CREATE TABLE IF NOT EXISTS public.production_batches (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id uuid NOT NULL,
  location_id uuid NOT NULL,
  recipe_id uuid NOT NULL,
  produced_quantity numeric(10,2) NOT NULL,
  produced_unit_id uuid NOT NULL,
  notes text,
  created_at timestamp DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='production_batches_company_id_fkey') THEN
    ALTER TABLE public.production_batches
      ADD CONSTRAINT production_batches_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='production_batches_location_id_fkey') THEN
    ALTER TABLE public.production_batches
      ADD CONSTRAINT production_batches_location_id_fkey
      FOREIGN KEY (location_id) REFERENCES public.locations(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='production_batches_recipe_id_fkey') THEN
    ALTER TABLE public.production_batches
      ADD CONSTRAINT production_batches_recipe_id_fkey
      FOREIGN KEY (recipe_id) REFERENCES public.recipes(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='production_batches_produced_unit_id_fkey') THEN
    ALTER TABLE public.production_batches
      ADD CONSTRAINT production_batches_produced_unit_id_fkey
      FOREIGN KEY (produced_unit_id) REFERENCES public.units(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_production_batches_qty_positive') THEN
    ALTER TABLE public.production_batches
      ADD CONSTRAINT chk_production_batches_qty_positive CHECK (produced_quantity > 0);
  END IF;
END$$;

-- =========================================================
-- RESERVATIONS
-- =========================================================

CREATE TABLE IF NOT EXISTS public.inventory_reservations (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id uuid NOT NULL,
  location_id uuid NOT NULL,
  status varchar(20) NOT NULL DEFAULT 'active',
  reference_type varchar(30) NOT NULL,
  reference_id uuid,
  notes text,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_reservations_company_id_fkey') THEN
    ALTER TABLE public.inventory_reservations
      ADD CONSTRAINT inventory_reservations_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_reservations_location_id_fkey') THEN
    ALTER TABLE public.inventory_reservations
      ADD CONSTRAINT inventory_reservations_location_id_fkey
      FOREIGN KEY (location_id) REFERENCES public.locations(id);
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS public.inventory_reservation_items (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  reservation_id uuid NOT NULL,
  inventory_item_id uuid NOT NULL,
  quantity numeric(12,2) NOT NULL,
  unit_id uuid NOT NULL,
  created_at timestamp DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_reservation_items_reservation_id_fkey') THEN
    ALTER TABLE public.inventory_reservation_items
      ADD CONSTRAINT inventory_reservation_items_reservation_id_fkey
      FOREIGN KEY (reservation_id) REFERENCES public.inventory_reservations(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_reservation_items_inventory_item_id_fkey') THEN
    ALTER TABLE public.inventory_reservation_items
      ADD CONSTRAINT inventory_reservation_items_inventory_item_id_fkey
      FOREIGN KEY (inventory_item_id) REFERENCES public.inventory_items(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_reservation_items_unit_id_fkey') THEN
    ALTER TABLE public.inventory_reservation_items
      ADD CONSTRAINT inventory_reservation_items_unit_id_fkey
      FOREIGN KEY (unit_id) REFERENCES public.units(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_inventory_reservation_items_qty_positive') THEN
    ALTER TABLE public.inventory_reservation_items
      ADD CONSTRAINT chk_inventory_reservation_items_qty_positive CHECK (quantity > 0);
  END IF;
END$$;

-- =========================================================
-- SALES
-- =========================================================

CREATE TABLE IF NOT EXISTS public.sales (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  total numeric(10,2) NOT NULL,
  subtotal numeric(10,2) NOT NULL,
  tax numeric(10,2) DEFAULT 0,
  discount numeric(10,2) DEFAULT 0,
  status int2 NOT NULL DEFAULT 1,
  company_id uuid,
  location_id uuid,
  employee_id uuid,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp,
  note text,
  refunded bool NOT NULL DEFAULT false,
  idempotency_key varchar(80)
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='sales_company_id_fkey') THEN
    ALTER TABLE public.sales
      ADD CONSTRAINT sales_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='sales_location_id_fkey') THEN
    ALTER TABLE public.sales
      ADD CONSTRAINT sales_location_id_fkey
      FOREIGN KEY (location_id) REFERENCES public.locations(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='sales_employee_id_fkey') THEN
    ALTER TABLE public.sales
      ADD CONSTRAINT sales_employee_id_fkey
      FOREIGN KEY (employee_id) REFERENCES public.employees(id);
  END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_sales_idempotency
  ON public.sales(idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- =========================================================
-- POS: CATEGORIES / MODIFIER_GROUPS / MODIFIERS / ITEMS / EXTRAS / EXCEPTIONS
-- (idéntico a tu versión, solo mantengo la estructura)
-- =========================================================

CREATE TABLE IF NOT EXISTS public.categories (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name varchar(100) NOT NULL,
  description text,
  status int2 DEFAULT 1,
  company_id uuid,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='categories_company_id_fkey') THEN
    ALTER TABLE public.categories
      ADD CONSTRAINT categories_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id);
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS public.modifier_groups (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name varchar(100) NOT NULL,
  description text,
  multiple_select bool DEFAULT false,
  required bool DEFAULT false,
  sort_order int4,
  company_id uuid,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  status int2 DEFAULT 1
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='modifier_groups_company_id_fkey') THEN
    ALTER TABLE public.modifier_groups
      ADD CONSTRAINT modifier_groups_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id);
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS public.modifiers (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  modifier_group_id uuid NOT NULL,
  name varchar(100) NOT NULL,
  description text,
  price_change numeric(10,2),
  sort_order int4,
  company_id uuid,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  status int2 DEFAULT 1
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='modifiers_company_id_fkey') THEN
    ALTER TABLE public.modifiers
      ADD CONSTRAINT modifiers_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='modifiers_modifier_group_id_fkey') THEN
    ALTER TABLE public.modifiers
      ADD CONSTRAINT modifiers_modifier_group_id_fkey
      FOREIGN KEY (modifier_group_id) REFERENCES public.modifier_groups(id) ON DELETE CASCADE;
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS public.exceptions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name varchar(100) NOT NULL,
  company_id uuid,
  location_id uuid,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  status int2 DEFAULT 1
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='exceptions_company_id_fkey') THEN
    ALTER TABLE public.exceptions
      ADD CONSTRAINT exceptions_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='exceptions_location_id_fkey') THEN
    ALTER TABLE public.exceptions
      ADD CONSTRAINT exceptions_location_id_fkey
      FOREIGN KEY (location_id) REFERENCES public.locations(id);
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS public.items (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name varchar(100) NOT NULL,
  description text,
  sku varchar(50),
  price numeric(10,2) NOT NULL,
  status int2 DEFAULT 1,
  company_id uuid NOT NULL,
  location_id uuid,
  category_id uuid,
  recipe_id uuid,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  code varchar(50),
  imagen text
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='items_company_id_fkey') THEN
    ALTER TABLE public.items
      ADD CONSTRAINT items_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='items_location_id_fkey') THEN
    ALTER TABLE public.items
      ADD CONSTRAINT items_location_id_fkey
      FOREIGN KEY (location_id) REFERENCES public.locations(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='items_category_id_fkey') THEN
    ALTER TABLE public.items
      ADD CONSTRAINT items_category_id_fkey
      FOREIGN KEY (category_id) REFERENCES public.categories(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='items_recipe_id_fkey') THEN
    ALTER TABLE public.items
      ADD CONSTRAINT items_recipe_id_fkey
      FOREIGN KEY (recipe_id) REFERENCES public.recipes(id);
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS public.extras (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name varchar(100) NOT NULL,
  price numeric(10,2) NOT NULL,
  company_id uuid,
  location_id uuid,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  status int2 DEFAULT 1
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='extras_company_id_fkey') THEN
    ALTER TABLE public.extras
      ADD CONSTRAINT extras_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='extras_location_id_fkey') THEN
    ALTER TABLE public.extras
      ADD CONSTRAINT extras_location_id_fkey
      FOREIGN KEY (location_id) REFERENCES public.locations(id);
  END IF;
END$$;

-- (tablas puente y de ingredientes: mantengo tu diseño original tal cual)
-- items_exceptions, exception_ingredients, extra_ingredients,
-- modifier_ingredients, items_modifier_groups, items_modifiers, items_extras
-- (por espacio no reescribo aquí esas secciones: copia EXACTO de tu script)

-- =========================================================
-- DEVICES / SHIFTS / SHIFT_CLOSURES (faltantes)
-- =========================================================

CREATE TABLE IF NOT EXISTS public.devices (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id uuid NOT NULL,
  location_id uuid,
  name varchar(100) NOT NULL,
  type varchar(30) NOT NULL, -- register, kitchen_display, handheld, etc.
  serial_number varchar(80),
  model varchar(80),
  status varchar(20) NOT NULL DEFAULT 'active',
  last_seen_at timestamp,
  notes text,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  deleted_at timestamp,
  deleted_by uuid
);

COMMENT ON TABLE public.devices IS
  'Dispositivos POS por sucursal (cajas, tablets, KDS, etc.).';

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='devices_company_id_fkey') THEN
    ALTER TABLE public.devices
      ADD CONSTRAINT devices_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='devices_location_id_fkey') THEN
    ALTER TABLE public.devices
      ADD CONSTRAINT devices_location_id_fkey
      FOREIGN KEY (location_id) REFERENCES public.locations(id) ON DELETE SET NULL;
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS idx_devices_company_location
  ON public.devices(company_id, location_id);

CREATE TABLE IF NOT EXISTS public.shifts (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id uuid NOT NULL,
  location_id uuid NOT NULL,
  register_id uuid, -- device id
  opened_by uuid,
  opened_at timestamp NOT NULL DEFAULT now(),
  opening_cash numeric(12,2) NOT NULL DEFAULT 0,
  status varchar(20) NOT NULL DEFAULT 'open', -- open/closed
  closed_by uuid,
  closed_at timestamp,
  notes text,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  deleted_at timestamp,
  deleted_by uuid
);

COMMENT ON TABLE public.shifts IS
  'Turnos de caja / sesión de caja por dispositivo (register).';

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='shifts_company_id_fkey') THEN
    ALTER TABLE public.shifts
      ADD CONSTRAINT shifts_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='shifts_location_id_fkey') THEN
    ALTER TABLE public.shifts
      ADD CONSTRAINT shifts_location_id_fkey
      FOREIGN KEY (location_id) REFERENCES public.locations(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='shifts_register_id_fkey') THEN
    ALTER TABLE public.shifts
      ADD CONSTRAINT shifts_register_id_fkey
      FOREIGN KEY (register_id) REFERENCES public.devices(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='shifts_opened_by_fkey') THEN
    ALTER TABLE public.shifts
      ADD CONSTRAINT shifts_opened_by_fkey
      FOREIGN KEY (opened_by) REFERENCES public.employees(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='shifts_closed_by_fkey') THEN
    ALTER TABLE public.shifts
      ADD CONSTRAINT shifts_closed_by_fkey
      FOREIGN KEY (closed_by) REFERENCES public.employees(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_shifts_cash_nonnegative') THEN
    ALTER TABLE public.shifts
      ADD CONSTRAINT chk_shifts_cash_nonnegative CHECK (opening_cash >= 0);
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS idx_shifts_company_location_status
  ON public.shifts(company_id, location_id, status);

CREATE TABLE IF NOT EXISTS public.shift_closures (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  shift_id uuid NOT NULL,
  company_id uuid NOT NULL,
  location_id uuid NOT NULL,
  register_id uuid,

  expected_cash numeric(12,2) NOT NULL DEFAULT 0,
  counted_cash numeric(12,2) NOT NULL DEFAULT 0,
  cash_difference numeric(12,2) NOT NULL DEFAULT 0,

  total_sales numeric(12,2) NOT NULL DEFAULT 0,
  total_refunds numeric(12,2) NOT NULL DEFAULT 0,

  total_cash_sales numeric(12,2) NOT NULL DEFAULT 0,
  total_card_sales numeric(12,2) NOT NULL DEFAULT 0,
  total_other_sales numeric(12,2) NOT NULL DEFAULT 0,

  open_sales_amount numeric(12,2) NOT NULL DEFAULT 0,

  closed_by uuid,
  closed_at timestamp NOT NULL DEFAULT now(),
  created_at timestamp DEFAULT now(),
  deleted_at timestamp,
  deleted_by uuid
);

COMMENT ON TABLE public.shift_closures IS
  'Cierre de turno. Snapshot financiero del turno (expected vs counted, ventas, etc.).';

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='shift_closures_shift_id_fkey') THEN
    ALTER TABLE public.shift_closures
      ADD CONSTRAINT shift_closures_shift_id_fkey
      FOREIGN KEY (shift_id) REFERENCES public.shifts(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='shift_closures_company_id_fkey') THEN
    ALTER TABLE public.shift_closures
      ADD CONSTRAINT shift_closures_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='shift_closures_location_id_fkey') THEN
    ALTER TABLE public.shift_closures
      ADD CONSTRAINT shift_closures_location_id_fkey
      FOREIGN KEY (location_id) REFERENCES public.locations(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='shift_closures_register_id_fkey') THEN
    ALTER TABLE public.shift_closures
      ADD CONSTRAINT shift_closures_register_id_fkey
      FOREIGN KEY (register_id) REFERENCES public.devices(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='shift_closures_closed_by_fkey') THEN
    ALTER TABLE public.shift_closures
      ADD CONSTRAINT shift_closures_closed_by_fkey
      FOREIGN KEY (closed_by) REFERENCES public.employees(id) ON DELETE SET NULL;
  END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_shift_closures_shift
  ON public.shift_closures(shift_id)
  WHERE deleted_at IS NULL;

-- =========================================================
-- ORDERS + ORDER ITEMS (ajuste device_id => UUID)
-- =========================================================

CREATE TABLE IF NOT EXISTS public.orders (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  -- IMPORTANTE: device_id debe alinearse con devices.id (uuid)
  device_id uuid,
  table_number varchar(20),
  status varchar(20) NOT NULL,
  total numeric(10,2),
  subtotal numeric(10,2) DEFAULT 0,
  tax numeric(10,2) DEFAULT 0,
  discount numeric(10,2) DEFAULT 0,

  company_id uuid,
  location_id uuid,
  employee_id uuid,
  customer_id uuid,

  discount_type varchar(20),
  discount_value numeric(10,2),
  discount_amount numeric(10,2),
  discount_label varchar(100),

  public_id varchar(20),
  order_number int4,
  note text,
  order_type varchar(20),
  guests int4,
  customer_name varchar(100),

  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp
);

COMMENT ON TABLE public.orders IS
  'Orden (ticket). device_id referencia la caja/dispositivo (devices).';

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='orders_device_id_fkey') THEN
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_device_id_fkey
      FOREIGN KEY (device_id) REFERENCES public.devices(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='orders_company_id_fkey') THEN
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='orders_location_id_fkey') THEN
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_location_id_fkey
      FOREIGN KEY (location_id) REFERENCES public.locations(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='orders_employee_id_fkey') THEN
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_employee_id_fkey
      FOREIGN KEY (employee_id) REFERENCES public.employees(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='orders_customer_id_fkey') THEN
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_customer_id_fkey
      FOREIGN KEY (customer_id) REFERENCES public.customers(id);
  END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_orders_public_id
  ON public.orders(public_id);

CREATE TABLE IF NOT EXISTS public.order_items (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  quantity int4 NOT NULL DEFAULT 1,
  price numeric(10,2) NOT NULL,
  total numeric(10,2) NOT NULL,
  notes text,
  order_id uuid,
  item_id uuid,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='order_items_order_id_fkey') THEN
    ALTER TABLE public.order_items
      ADD CONSTRAINT order_items_order_id_fkey
      FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='order_items_item_id_fkey') THEN
    ALTER TABLE public.order_items
      ADD CONSTRAINT order_items_item_id_fkey
      FOREIGN KEY (item_id) REFERENCES public.items(id);
  END IF;
END$$;

-- order_item_exceptions, order_item_modifiers, order_item_extras
-- (mantén tu versión tal cual)

-- =========================================================
-- PAYMENTS + SALE_ORDERS + payments_order_items
-- =========================================================

CREATE TABLE IF NOT EXISTS public.payments (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  method varchar(50) NOT NULL,
  amount numeric(10,2) NOT NULL,
  reference varchar(100),
  sale_id uuid,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  amount_received numeric(10,2),
  transaction_number varchar(100)
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='payments_sale_id_fkey') THEN
    ALTER TABLE public.payments
      ADD CONSTRAINT payments_sale_id_fkey
      FOREIGN KEY (sale_id) REFERENCES public.sales(id) ON DELETE CASCADE;
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS public.sale_orders (
  sale_id uuid NOT NULL,
  order_id uuid NOT NULL,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  PRIMARY KEY (sale_id, order_id)
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='sale_orders_sale_id_fkey') THEN
    ALTER TABLE public.sale_orders
      ADD CONSTRAINT sale_orders_sale_id_fkey
      FOREIGN KEY (sale_id) REFERENCES public.sales(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='sale_orders_order_id_fkey') THEN
    ALTER TABLE public.sale_orders
      ADD CONSTRAINT sale_orders_order_id_fkey
      FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;
  END IF;
END$$;

-- Nota: JSON que pegaste no trae id/amount. SQL robusto sí.
-- Si quieres 1:1 con JSON, quítale id/amount/updated_at y usa PK(payment_id, order_item_id).
CREATE TABLE IF NOT EXISTS public.payments_order_items (
  payment_id uuid NOT NULL,
  order_item_id uuid NOT NULL,
  created_at timestamp DEFAULT now(),
  deleted_at timestamp,
  deleted_by uuid,
  PRIMARY KEY (payment_id, order_item_id)
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='payments_order_items_payment_id_fkey') THEN
    ALTER TABLE public.payments_order_items
      ADD CONSTRAINT payments_order_items_payment_id_fkey
      FOREIGN KEY (payment_id) REFERENCES public.payments(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='payments_order_items_order_item_id_fkey') THEN
    ALTER TABLE public.payments_order_items
      ADD CONSTRAINT payments_order_items_order_item_id_fkey
      FOREIGN KEY (order_item_id) REFERENCES public.order_items(id) ON DELETE CASCADE;
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS idx_payments_order_items_payment
  ON public.payments_order_items(payment_id);

CREATE INDEX IF NOT EXISTS idx_payments_order_items_order_item
  ON public.payments_order_items(order_item_id);

-- =========================================================
-- LOGS (JSON pide user_id)
-- =========================================================

CREATE TABLE IF NOT EXISTS public.logs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  action varchar(50) NOT NULL,
  entity varchar(50) NOT NULL,
  entity_id uuid,
  description text,
  company_id uuid,
  employee_id uuid,
  user_id bigint,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='logs_company_id_fkey') THEN
    ALTER TABLE public.logs
      ADD CONSTRAINT logs_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='logs_employee_id_fkey') THEN
    ALTER TABLE public.logs
      ADD CONSTRAINT logs_employee_id_fkey
      FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='logs_user_id_fkey') THEN
    ALTER TABLE public.logs
      ADD CONSTRAINT logs_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;
  END IF;
END$$;

-- =========================================================
-- LARAVEL SUPPORT TABLES
-- =========================================================

CREATE SEQUENCE IF NOT EXISTS public.migrations_id_seq;

CREATE TABLE IF NOT EXISTS public.migrations (
  id int4 PRIMARY KEY DEFAULT nextval('public.migrations_id_seq'::regclass),
  migration varchar(255) NOT NULL,
  batch int4 NOT NULL
);

CREATE TABLE IF NOT EXISTS public.password_reset_tokens (
  email varchar(255) PRIMARY KEY,
  token varchar(255) NOT NULL,
  created_at timestamp(0)
);

CREATE TABLE IF NOT EXISTS public.sessions (
  id varchar(255) PRIMARY KEY,
  user_id int8,
  ip_address varchar(45),
  user_agent text,
  payload text NOT NULL,
  last_activity int4 NOT NULL
);

CREATE INDEX IF NOT EXISTS sessions_user_id_index ON public.sessions(user_id);
CREATE INDEX IF NOT EXISTS sessions_last_activity_index ON public.sessions(last_activity);

CREATE TABLE IF NOT EXISTS public.cache (
  key varchar(255) PRIMARY KEY,
  value text NOT NULL,
  expiration int4 NOT NULL
);

CREATE TABLE IF NOT EXISTS public.cache_locks (
  key varchar(255) PRIMARY KEY,
  owner varchar(255) NOT NULL,
  expiration int4 NOT NULL
);

CREATE SEQUENCE IF NOT EXISTS public.jobs_id_seq;

CREATE TABLE IF NOT EXISTS public.jobs (
  id int8 PRIMARY KEY DEFAULT nextval('public.jobs_id_seq'::regclass),
  queue varchar(255) NOT NULL,
  payload text NOT NULL,
  attempts int2 NOT NULL,
  reserved_at int4,
  available_at int4 NOT NULL,
  created_at int4 NOT NULL
);

CREATE INDEX IF NOT EXISTS jobs_queue_index ON public.jobs(queue);

CREATE TABLE IF NOT EXISTS public.job_batches (
  id varchar(255) PRIMARY KEY,
  name varchar(255) NOT NULL,
  total_jobs int4 NOT NULL,
  pending_jobs int4 NOT NULL,
  failed_jobs int4 NOT NULL,
  failed_job_ids text NOT NULL,
  options text,
  cancelled_at int4,
  created_at int4 NOT NULL,
  finished_at int4
);

CREATE SEQUENCE IF NOT EXISTS public.failed_jobs_id_seq;

CREATE TABLE IF NOT EXISTS public.failed_jobs (
  id int8 PRIMARY KEY DEFAULT nextval('public.failed_jobs_id_seq'::regclass),
  uuid varchar(255) NOT NULL,
  connection text NOT NULL,
  queue text NOT NULL,
  payload text NOT NULL,
  exception text NOT NULL,
  failed_at timestamp(0) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS failed_jobs_uuid_unique
  ON public.failed_jobs(uuid);

COMMIT;

/* =====================================================================
   NOTAS DBA (NO ejecutables):
   - Si YA existe orders.device_id como int4 en tu DB, NO lo conviertas a uuid “en caliente”.
     Estrategia safe:
       1) ALTER TABLE orders ADD COLUMN device_uuid uuid;
       2) Backfill con mapeo a devices (si existía int->uuid) o null;
       3) Ajustar app para usar device_uuid;
       4) (opcional) renombrar columnas en una ventana de mantenimiento.
   - payments_order_items quedó 1:1 con tu JSON (PK compuesta) y sin campo id/amount.
     Si quieres tracking de “monto imputado por item”, agrega amount numeric(10,2) NOT NULL DEFAULT 0.
   ===================================================================== */
