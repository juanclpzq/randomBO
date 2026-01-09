/* =====================================================================
   POS + INVENTARIO + RECETARIO + PRODUCCIÓN (PostgreSQL)
   Script único integrado (archivo 1 + archivo 2), estilo DBA senior

   Objetivos de integración:
   - Conservar TODAS las tablas “POS” del archivo 1 (orders/items/modifiers/etc.)
   - Adoptar mejoras del archivo 2 para INVENTARIO:
       * inventory_movements con occurred_at, reference_type, unit_cost, idempotency_key, actores
       * constraints y checks (cantidades > 0, factores > 0, etc.)
       * columnas extra en transfers (shipped/received + idempotency)
       * locations.location_type
   - Mantener relaciones/índices del archivo 1 y agregar los recomendados del archivo 2
   - Evitar DROP CASCADE destructivo: uso “CREATE ... IF NOT EXISTS” + “ALTER ... ADD COLUMN IF NOT EXISTS”
     (Si necesitas modo “recreate” lo ajusto, pero aquí es “idempotente / safe-ish”)

   Requisitos:
   - Extension uuid-ossp (uuid_generate_v4)
   ===================================================================== */

BEGIN;

-- =========================================================
-- EXTENSIONS
-- =========================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =========================================================
-- ENUMS (crear si no existen)
-- Nota: PostgreSQL no soporta CREATE TYPE IF NOT EXISTS directo para ENUM
--       Así que validamos vía DO blocks.
-- =========================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
                 WHERE t.typname = 'inventory_movement_type_enum' AND n.nspname='public') THEN
    CREATE TYPE public.inventory_movement_type_enum AS ENUM (
      'sale',
      'purchase_in',
      'transfer_out',
      'transfer_in',
      'production_in',
      'production_out',
      'waste',
      'adjustment',
      'count',
      'return_in',
      'return_out'
    );
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
                 WHERE t.typname = 'customer_type_enum' AND n.nspname='public') THEN
    CREATE TYPE public.customer_type_enum AS ENUM ('individual', 'business');
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

COMMENT ON TABLE public.companies IS 'Empresa/tenant. Agrupa locations, employees, customers, proveedores e inventario.';

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
  deleted_by uuid
);

COMMENT ON TABLE public.locations IS 'Sucursal o CEDIS. Punto físico donde existe stock y ocurren movimientos de inventario.';
COMMENT ON COLUMN public.locations.company_id IS 'Empresa dueña de la sucursal/centro (multi-tenant).';

-- Mejora archivo 2 (opcional recomendado)
ALTER TABLE public.locations
  ADD COLUMN IF NOT EXISTS location_type varchar(20);

-- FK locations -> companies
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'locations_company_id_fkey'
  ) THEN
    ALTER TABLE public.locations
      ADD CONSTRAINT locations_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;
  END IF;
END$$;

-- Laravel-ish tables (archivo 1)
CREATE SEQUENCE IF NOT EXISTS public.users_id_seq;

CREATE TABLE IF NOT EXISTS public.users (
  id int8 PRIMARY KEY DEFAULT nextval('public.users_id_seq'::regclass),
  name varchar(255) NOT NULL,
  email varchar(255) NOT NULL,
  email_verified_at timestamp(0),
  password varchar(255) NOT NULL,
  remember_token varchar(100),
  created_at timestamp(0),
  updated_at timestamp(0)
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'users_email_unique'
  ) THEN
    CREATE UNIQUE INDEX users_email_unique ON public.users USING btree (email);
  END IF;
END$$;

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

-- FKs employees
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

-- unique email por company (soft delete friendly)
CREATE UNIQUE INDEX IF NOT EXISTS uq_employees_company_email
  ON public.employees (company_id, lower((email)::text))
  WHERE deleted_at IS NULL;

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

COMMENT ON TABLE public.units IS 'Catálogo de unidades (g, Kg, ml, L, pz). Se usa para compras y recetas.';

CREATE TABLE IF NOT EXISTS public.unit_conversions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  from_unit_id uuid NOT NULL,
  to_unit_id uuid NOT NULL,
  factor numeric(18,8) NOT NULL
);

COMMENT ON TABLE public.unit_conversions IS 'Conversiones entre unidades (from -> to). factor multiplica: qty_to = qty_from * factor.';
COMMENT ON COLUMN public.unit_conversions.factor IS 'Factor multiplicador para convertir de from_unit a to_unit.';

-- FKs conversions
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
END$$;

-- constraints (archivo 2)
DO $$
BEGIN
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

COMMENT ON TABLE public.suppliers IS 'Proveedor (por empresa). Se usa para compras y costos de insumos.';

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

-- Mejoras archivo 2: code + precisión numérica (no rompemos existentes: agregamos columnas)
ALTER TABLE public.inventory_items
  ADD COLUMN IF NOT EXISTS code varchar(50);

-- Ajuste de precisión a 12,4 sin perder compatibilidad:
-- (No hago ALTER TYPE automático porque puede fallar si hay dependencias/large tables; se deja opcional)
-- Si lo quieres, lo hacemos en una migración controlada.

COMMENT ON TABLE public.inventory_items IS 'Catálogo de insumos/ingredientes y también mercancía (souvenirs). Puede ser global por company o específico por location.';
COMMENT ON COLUMN public.inventory_items.company_id IS 'Empresa dueña del item (multi-tenant).';
COMMENT ON COLUMN public.inventory_items.location_id IS 'Si no es NULL, el item es exclusivo de esa sucursal/centro. Si NULL, es global de la empresa.';
COMMENT ON COLUMN public.inventory_items.name IS 'Nombre del inventory item (ej. Agua, Café molido, Leche entera).';
COMMENT ON COLUMN public.inventory_items.qty_per_purchase_unit IS 'Cantidad de recipe_unit contenida en 1 purchase_unit. Ej: 1 Litro = 1000 ml => 1000.';
COMMENT ON COLUMN public.inventory_items.minimum_limit IS 'Stock mínimo recomendado para alertas/abasto.';
COMMENT ON COLUMN public.inventory_items.purchase_unit_id IS 'Unidad en que se compra (ej. Litros, Kg, cajas).';
COMMENT ON COLUMN public.inventory_items.recipe_unit_id IS 'Unidad en que se consume en recetas (ej. ml, g).';
COMMENT ON COLUMN public.inventory_items.item_kind IS 'Clasificación del item: raw_material (insumo), finished_good (producto), packaging, etc.';
COMMENT ON COLUMN public.inventory_items.stock_policy IS 'Política de stock: stocked = maneja stock físico; virtual = no se stockea y se explota por receta producible al consumir.';
COMMENT ON COLUMN public.inventory_items.producible_recipe_id IS 'Si stock_policy = virtual, receta que representa cómo “se produce/compone” este item desde ingredientes base.';
COMMENT ON COLUMN public.inventory_items.stock_unit_id IS 'Unidad base recomendada para ledger/stock (ej. ml para líquidos, g para sólidos, pz para piezas).';
COMMENT ON COLUMN public.inventory_items.is_lot_tracked IS 'Si true, requiere lote/caducidad (perecederos). Los movimientos deben asignar lotes.';

-- FKs inventory_items
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

-- Índices inventory_items
CREATE INDEX IF NOT EXISTS idx_inventory_items_purchase_unit_id ON public.inventory_items(purchase_unit_id);
CREATE INDEX IF NOT EXISTS idx_inventory_items_recipe_unit_id ON public.inventory_items(recipe_unit_id);
CREATE INDEX IF NOT EXISTS idx_inventory_items_company ON public.inventory_items(company_id);
CREATE INDEX IF NOT EXISTS idx_inventory_items_location ON public.inventory_items(location_id);

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

COMMENT ON TABLE public.recipes IS 'Receta base o producible. Define ingredientes. Puede producir un output_inventory_item si aplica.';
COMMENT ON COLUMN public.recipes.is_base IS 'true si es receta base (ej. “Latte Base”), usada por items/ventas.';
COMMENT ON COLUMN public.recipes.output_inventory_item_id IS 'Item resultante de la receta (si aplica producción a stock).';
COMMENT ON COLUMN public.recipes.output_quantity IS 'Cantidad producida por corrida de receta (en output_unit_id).';

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

CREATE INDEX IF NOT EXISTS idx_recipes_company ON public.recipes(company_id);

-- ahora que recipes existe, FK producible_recipe_id
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

COMMENT ON TABLE public.recipe_ingredients IS 'Ingredientes requeridos por receta. quantity se expresa en unit_id (preferible recipe_unit del item).';

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
END$$;

-- constraints archivo 2 (qty > 0)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_recipe_ingredients_qty_positive') THEN
    ALTER TABLE public.recipe_ingredients
      ADD CONSTRAINT chk_recipe_ingredients_qty_positive CHECK (quantity > 0);
  END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS recipe_ingredients_recipe_id_inventory_item_id_key
  ON public.recipe_ingredients(recipe_id, inventory_item_id);

CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_recipe_id
  ON public.recipe_ingredients(recipe_id);

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
-- SUPPLIER COSTS PER ITEM
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

COMMENT ON TABLE public.inventory_item_suppliers IS 'Relación item-proveedor con costo (último o contrato). Apoya compras y costeo.';
COMMENT ON COLUMN public.inventory_item_suppliers.cost IS 'Costo del item según el proveedor (en purchase_unit o regla definida por negocio).';
COMMENT ON COLUMN public.inventory_item_suppliers.last_purchase_date IS 'Última fecha de compra registrada para ese proveedor-item.';

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
-- PURCHASE ORDERS
-- =========================================================

CREATE TABLE IF NOT EXISTS public.purchase_orders (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id uuid NOT NULL,
  location_id uuid,
  supplier_id uuid,
  status varchar(50) DEFAULT 'pending',
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
);

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

CREATE TABLE IF NOT EXISTS public.purchase_order_items (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  purchase_order_id uuid NOT NULL,
  inventory_item_id uuid NOT NULL,
  quantity numeric(10,2) NOT NULL,
  unit_id uuid,
  cost numeric(10,2),
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='purchase_order_items_purchase_order_id_fkey') THEN
    ALTER TABLE public.purchase_order_items
      ADD CONSTRAINT purchase_order_items_purchase_order_id_fkey
      FOREIGN KEY (purchase_order_id) REFERENCES public.purchase_orders(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='purchase_order_items_inventory_item_id_fkey') THEN
    ALTER TABLE public.purchase_order_items
      ADD CONSTRAINT purchase_order_items_inventory_item_id_fkey
      FOREIGN KEY (inventory_item_id) REFERENCES public.inventory_items(id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='purchase_order_items_unit_id_fkey') THEN
    ALTER TABLE public.purchase_order_items
      ADD CONSTRAINT purchase_order_items_unit_id_fkey
      FOREIGN KEY (unit_id) REFERENCES public.units(id);
  END IF;
END$$;

-- archivo 2: qty > 0
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_purchase_order_items_qty_positive') THEN
    ALTER TABLE public.purchase_order_items
      ADD CONSTRAINT chk_purchase_order_items_qty_positive CHECK (quantity > 0);
  END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS purchase_order_items_purchase_order_id_inventory_item_id_key
  ON public.purchase_order_items(purchase_order_id, inventory_item_id);

-- =========================================================
-- STOCK SNAPSHOTS
-- =========================================================

CREATE TABLE IF NOT EXISTS public.inventory_stocks (
  location_id uuid NOT NULL,
  inventory_item_id uuid NOT NULL,
  on_hand numeric(10,2) NOT NULL DEFAULT 0,
  reserved numeric(10,2) NOT NULL DEFAULT 0,
  updated_at timestamp DEFAULT now(),
  PRIMARY KEY (location_id, inventory_item_id)
);

COMMENT ON TABLE public.inventory_stocks IS 'Stock agregado por ubicación e item. on_hand = disponible físico; reserved = comprometido por reservas.';
COMMENT ON COLUMN public.inventory_stocks.on_hand IS 'Existencia física actual (en stock_unit del item idealmente).';
COMMENT ON COLUMN public.inventory_stocks.reserved IS 'Cantidad reservada/comprometida (órdenes futuras/producción planeada).';

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
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_inventory_stocks_nonnegative_reserved') THEN
    ALTER TABLE public.inventory_stocks
      ADD CONSTRAINT chk_inventory_stocks_nonnegative_reserved CHECK (reserved >= 0);
  END IF;
END$$;

-- =========================================================
-- COST SNAPSHOTS
-- =========================================================

CREATE TABLE IF NOT EXISTS public.inventory_item_costs (
  location_id uuid NOT NULL,
  inventory_item_id uuid NOT NULL,
  avg_unit_cost numeric(12,4) NOT NULL DEFAULT 0,
  last_unit_cost numeric(12,4) NOT NULL DEFAULT 0,
  updated_at timestamp DEFAULT now(),
  PRIMARY KEY (location_id, inventory_item_id)
);

COMMENT ON TABLE public.inventory_item_costs IS 'Costo agregado por ubicación e item (promedio y último). Útil para margen simple.';
COMMENT ON COLUMN public.inventory_item_costs.avg_unit_cost IS 'Costo promedio unitario (en unidad base/stock_unit) calculado con entradas.';
COMMENT ON COLUMN public.inventory_item_costs.last_unit_cost IS 'Último costo unitario (última entrada) en unidad base/stock_unit.';

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
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_inventory_item_costs_nonnegative') THEN
    ALTER TABLE public.inventory_item_costs
      ADD CONSTRAINT chk_inventory_item_costs_nonnegative CHECK (avg_unit_cost >= 0 AND last_unit_cost >= 0);
  END IF;
END$$;

-- =========================================================
-- LOTS
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

COMMENT ON TABLE public.inventory_lots IS 'Lotes por item (y empresa). Permite caducidad, trazabilidad y costos por lote.';
COMMENT ON COLUMN public.inventory_lots.lot_code IS 'Código visible del lote (etiqueta/proveedor). Debe ser único por company+item.';
COMMENT ON COLUMN public.inventory_lots.expiry_date IS 'Fecha de caducidad del lote (si aplica).';
COMMENT ON COLUMN public.inventory_lots.source_type IS 'Origen del lote: purchase_order, transfer, production, manual, etc.';

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

CREATE INDEX IF NOT EXISTS idx_inventory_lots_item_expiry
  ON public.inventory_lots(inventory_item_id, expiry_date);

CREATE TABLE IF NOT EXISTS public.inventory_lot_stocks (
  location_id uuid NOT NULL,
  lot_id uuid NOT NULL,
  on_hand numeric(12,2) NOT NULL DEFAULT 0,
  reserved numeric(12,2) NOT NULL DEFAULT 0,
  updated_at timestamp DEFAULT now(),
  PRIMARY KEY (location_id, lot_id)
);

COMMENT ON TABLE public.inventory_lot_stocks IS 'Stock por lote y ubicación. Se usa si inventory_items.is_lot_tracked = true.';

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
END$$;

CREATE INDEX IF NOT EXISTS idx_inventory_lot_stocks_lot
  ON public.inventory_lot_stocks(lot_id);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_inventory_lot_stocks_reserved_nonnegative') THEN
    ALTER TABLE public.inventory_lot_stocks
      ADD CONSTRAINT chk_inventory_lot_stocks_reserved_nonnegative CHECK (reserved >= 0);
  END IF;
END$$;

-- =========================================================
-- INVENTORY MOVEMENTS (integrado con mejoras archivo 2)
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
  movement_type public.inventory_movement_type_enum NOT NULL
);

COMMENT ON TABLE public.inventory_movements IS 'Ledger (kardex) de movimientos de inventario. quantity positiva entra, negativa sale.';
COMMENT ON COLUMN public.inventory_movements.quantity IS 'Cantidad del movimiento. Convención: salida negativa, entrada positiva (misma unidad indicada por unit_id).';
COMMENT ON COLUMN public.inventory_movements.unit_id IS 'Unidad en la que se registra quantity. Recomendado: unit_id = stock_unit_id del item.';
COMMENT ON COLUMN public.inventory_movements.reference_id IS 'ID del documento origen (sale_id, purchase_order_id, transfer_id, production_batch_id, etc).';
COMMENT ON COLUMN public.inventory_movements.notes IS 'Texto libre para auditoría (ej. “Venta Latte Mediano”).';
COMMENT ON COLUMN public.inventory_movements.movement_type IS 'Tipo normalizado de movimiento (ENUM) para evitar typos: sale, purchase_in, transfer_out/in, production_out/in, waste, adjustment, etc.';

-- Añadimos columnas del archivo 2 (sin romper archivo 1)
ALTER TABLE public.inventory_movements
  ADD COLUMN IF NOT EXISTS reference_type varchar(30),
  ADD COLUMN IF NOT EXISTS occurred_at timestamp NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS unit_cost numeric(12,4),
  ADD COLUMN IF NOT EXISTS idempotency_key varchar(80),
  ADD COLUMN IF NOT EXISTS actor_employee_id uuid,
  ADD COLUMN IF NOT EXISTS actor_user_id bigint;

-- FKs inventory_movements
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
END$$;

-- constraints archivo 2
DO $$
BEGIN
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

-- Índices kardex (con occurred_at preferente)
CREATE INDEX IF NOT EXISTS idx_inv_mov_loc_item_occurred
  ON public.inventory_movements(location_id, inventory_item_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_inv_mov_item_occurred
  ON public.inventory_movements(inventory_item_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_inv_mov_ref
  ON public.inventory_movements(reference_type, reference_id);

CREATE INDEX IF NOT EXISTS idx_inv_mov_idempotency
  ON public.inventory_movements(idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_inv_mov_ref_idempotency
  ON public.inventory_movements(reference_type, reference_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- Mantener índices del archivo 1 (compat)
CREATE INDEX IF NOT EXISTS idx_inventory_movements_loc_item_created
  ON public.inventory_movements(location_id, inventory_item_id, created_at);

CREATE INDEX IF NOT EXISTS idx_inventory_movements_ref
  ON public.inventory_movements(reference_id);

CREATE INDEX IF NOT EXISTS idx_inventory_movements_item_created
  ON public.inventory_movements(inventory_item_id, created_at);

-- =========================================================
-- MOVEMENT LOTS
-- =========================================================

CREATE TABLE IF NOT EXISTS public.inventory_movement_lots (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  movement_id uuid NOT NULL,
  lot_id uuid NOT NULL,
  quantity numeric(12,2) NOT NULL,
  unit_id uuid NOT NULL,
  created_at timestamp DEFAULT now()
);

COMMENT ON TABLE public.inventory_movement_lots IS 'Asignación del movimiento a uno o más lotes (para FIFO por lote y auditoría). quantity aquí es la porción del movimiento tomada de ese lote.';

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
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_inventory_movement_lots_qty_positive') THEN
    ALTER TABLE public.inventory_movement_lots
      ADD CONSTRAINT chk_inventory_movement_lots_qty_positive CHECK (quantity > 0);
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS idx_inventory_movement_lots_movement
  ON public.inventory_movement_lots(movement_id);

CREATE INDEX IF NOT EXISTS idx_inventory_movement_lots_lot
  ON public.inventory_movement_lots(lot_id);

-- =========================================================
-- TRANSFERS + ITEMS (integrado)
-- =========================================================

CREATE TABLE IF NOT EXISTS public.inventory_transfers (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id uuid NOT NULL,
  from_location_id uuid NOT NULL,
  to_location_id uuid NOT NULL,
  status varchar(20) NOT NULL DEFAULT 'draft',
  notes text,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
);

COMMENT ON TABLE public.inventory_transfers IS 'Traspaso entre ubicaciones (CEDIS <-> sucursales o sucursal <-> sucursal).';
COMMENT ON COLUMN public.inventory_transfers.from_location_id IS 'Origen del traspaso (sale del stock de aquí).';
COMMENT ON COLUMN public.inventory_transfers.to_location_id IS 'Destino del traspaso (entra al stock de aquí).';
COMMENT ON COLUMN public.inventory_transfers.status IS 'Estado del traspaso: draft, in_transit, completed, cancelled (según tu flujo).';

-- mejoras archivo 2
ALTER TABLE public.inventory_transfers
  ADD COLUMN IF NOT EXISTS shipped_at timestamp,
  ADD COLUMN IF NOT EXISTS received_at timestamp,
  ADD COLUMN IF NOT EXISTS shipped_by_employee_id uuid,
  ADD COLUMN IF NOT EXISTS received_by_employee_id uuid,
  ADD COLUMN IF NOT EXISTS ship_idempotency_key varchar(80),
  ADD COLUMN IF NOT EXISTS receive_idempotency_key varchar(80);

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
END$$;

DO $$
BEGIN
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

COMMENT ON TABLE public.inventory_transfer_items IS 'Detalle del traspaso: qué items y cantidades se mueven.';
COMMENT ON COLUMN public.inventory_transfer_items.unit_id IS 'Unidad en la que se traspasa (recomendado: stock_unit del item).';

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
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_inventory_transfer_items_qty_positive') THEN
    ALTER TABLE public.inventory_transfer_items
      ADD CONSTRAINT chk_inventory_transfer_items_qty_positive CHECK (quantity > 0);
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS idx_inventory_transfer_items_transfer_id
  ON public.inventory_transfer_items(transfer_id);

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

COMMENT ON TABLE public.production_batches IS 'Lote/orden de producción basada en una receta (ej. CEDIS produce pasteles o sucursal produce mezcla).';
COMMENT ON COLUMN public.production_batches.location_id IS 'Ubicación donde se ejecuta la producción (CEDIS o sucursal).';
COMMENT ON COLUMN public.production_batches.recipe_id IS 'Receta usada para producir (define insumos a consumir y opcionalmente output).';
COMMENT ON COLUMN public.production_batches.produced_quantity IS 'Cantidad producida del output del batch (en produced_unit_id).';

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
END$$;

DO $$
BEGIN
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

COMMENT ON TABLE public.inventory_reservations IS 'Reserva de inventario a futuro: aparta stock para órdenes, producción planeada o transferencias.';
COMMENT ON COLUMN public.inventory_reservations.reference_type IS 'Tipo de documento origen (order, production, transfer, manual).';
COMMENT ON COLUMN public.inventory_reservations.reference_id IS 'ID del documento origen para rastreo.';

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

CREATE INDEX IF NOT EXISTS idx_inventory_reservations_ref
  ON public.inventory_reservations(reference_type, reference_id);

CREATE TABLE IF NOT EXISTS public.inventory_reservation_items (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  reservation_id uuid NOT NULL,
  inventory_item_id uuid NOT NULL,
  quantity numeric(12,2) NOT NULL,
  unit_id uuid NOT NULL,
  created_at timestamp DEFAULT now()
);

COMMENT ON TABLE public.inventory_reservation_items IS 'Detalle de reserva: items y cantidades reservadas (en unit_id).';

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
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_inventory_reservation_items_qty_positive') THEN
    ALTER TABLE public.inventory_reservation_items
      ADD CONSTRAINT chk_inventory_reservation_items_qty_positive CHECK (quantity > 0);
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS idx_inventory_reservation_items_reservation
  ON public.inventory_reservation_items(reservation_id);

CREATE INDEX IF NOT EXISTS idx_inventory_reservation_items_item
  ON public.inventory_reservation_items(inventory_item_id);

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
  refunded bool NOT NULL DEFAULT false
);

-- Mejora archivo 2: idempotency_key
ALTER TABLE public.sales
  ADD COLUMN IF NOT EXISTS idempotency_key varchar(80);

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
-- =========================
-- POS TABLES (archivo 1)
-- =========================
-- categories, modifier_groups, modifiers, exceptions,
-- items, extras, orders, order_items, etc.
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

CREATE TABLE IF NOT EXISTS public.modifier_ingredients (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  modifier_id uuid NOT NULL,
  inventory_item_id uuid NOT NULL,
  quantity_change numeric(10,2),
  unit_id uuid,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='modifier_ingredients_modifier_id_fkey') THEN
    ALTER TABLE public.modifier_ingredients
      ADD CONSTRAINT modifier_ingredients_modifier_id_fkey
      FOREIGN KEY (modifier_id) REFERENCES public.modifiers(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='modifier_ingredients_inventory_item_id_fkey') THEN
    ALTER TABLE public.modifier_ingredients
      ADD CONSTRAINT modifier_ingredients_inventory_item_id_fkey
      FOREIGN KEY (inventory_item_id) REFERENCES public.inventory_items(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='modifier_ingredients_unit_id_fkey') THEN
    ALTER TABLE public.modifier_ingredients
      ADD CONSTRAINT modifier_ingredients_unit_id_fkey
      FOREIGN KEY (unit_id) REFERENCES public.units(id);
  END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS modifier_ingredients_modifier_id_inventory_item_id_key
  ON public.modifier_ingredients(modifier_id, inventory_item_id);

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
  code varchar(50)
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

CREATE UNIQUE INDEX IF NOT EXISTS uq_items_company_sku
  ON public.items(company_id, sku)
  WHERE deleted_at IS NULL AND sku IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.items_exceptions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  item_id uuid NOT NULL,
  exception_id uuid NOT NULL,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='items_exceptions_item_id_fkey') THEN
    ALTER TABLE public.items_exceptions
      ADD CONSTRAINT items_exceptions_item_id_fkey
      FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='items_exceptions_exception_id_fkey') THEN
    ALTER TABLE public.items_exceptions
      ADD CONSTRAINT items_exceptions_exception_id_fkey
      FOREIGN KEY (exception_id) REFERENCES public.exceptions(id) ON DELETE CASCADE;
  END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS items_exceptions_item_id_exception_id_key
  ON public.items_exceptions(item_id, exception_id);

CREATE TABLE IF NOT EXISTS public.exception_ingredients (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  exception_id uuid NOT NULL,
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
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='exception_ingredients_exception_id_fkey') THEN
    ALTER TABLE public.exception_ingredients
      ADD CONSTRAINT exception_ingredients_exception_id_fkey
      FOREIGN KEY (exception_id) REFERENCES public.exceptions(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='exception_ingredients_inventory_item_id_fkey') THEN
    ALTER TABLE public.exception_ingredients
      ADD CONSTRAINT exception_ingredients_inventory_item_id_fkey
      FOREIGN KEY (inventory_item_id) REFERENCES public.inventory_items(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='exception_ingredients_unit_id_fkey') THEN
    ALTER TABLE public.exception_ingredients
      ADD CONSTRAINT exception_ingredients_unit_id_fkey
      FOREIGN KEY (unit_id) REFERENCES public.units(id);
  END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS exception_ingredients_exception_id_inventory_item_id_key
  ON public.exception_ingredients(exception_id, inventory_item_id);

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

CREATE TABLE IF NOT EXISTS public.extra_ingredients (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  extra_id uuid NOT NULL,
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
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='extra_ingredients_extra_id_fkey') THEN
    ALTER TABLE public.extra_ingredients
      ADD CONSTRAINT extra_ingredients_extra_id_fkey
      FOREIGN KEY (extra_id) REFERENCES public.extras(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='extra_ingredients_inventory_item_id_fkey') THEN
    ALTER TABLE public.extra_ingredients
      ADD CONSTRAINT extra_ingredients_inventory_item_id_fkey
      FOREIGN KEY (inventory_item_id) REFERENCES public.inventory_items(id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='extra_ingredients_unit_id_fkey') THEN
    ALTER TABLE public.extra_ingredients
      ADD CONSTRAINT extra_ingredients_unit_id_fkey
      FOREIGN KEY (unit_id) REFERENCES public.units(id);
  END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS extra_ingredients_extra_id_inventory_item_id_key
  ON public.extra_ingredients(extra_id, inventory_item_id);

CREATE TABLE IF NOT EXISTS public.items_modifier_groups (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  item_id uuid NOT NULL,
  modifier_group_id uuid NOT NULL,
  required bool DEFAULT false,
  sort_order int4,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='items_modifier_groups_item_id_fkey') THEN
    ALTER TABLE public.items_modifier_groups
      ADD CONSTRAINT items_modifier_groups_item_id_fkey
      FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='items_modifier_groups_modifier_group_id_fkey') THEN
    ALTER TABLE public.items_modifier_groups
      ADD CONSTRAINT items_modifier_groups_modifier_group_id_fkey
      FOREIGN KEY (modifier_group_id) REFERENCES public.modifier_groups(id);
  END IF;
END$$;

-- archivo 1 traía un índice redundante con id pkey; el pkey ya existe.

CREATE TABLE IF NOT EXISTS public.items_modifiers (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  item_id uuid NOT NULL,
  modifier_id uuid NOT NULL,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='items_modifiers_item_id_fkey') THEN
    ALTER TABLE public.items_modifiers
      ADD CONSTRAINT items_modifiers_item_id_fkey
      FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='items_modifiers_modifier_id_fkey') THEN
    ALTER TABLE public.items_modifiers
      ADD CONSTRAINT items_modifiers_modifier_id_fkey
      FOREIGN KEY (modifier_id) REFERENCES public.modifiers(id);
  END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS item_modifiers_item_id_modifier_id_key
  ON public.items_modifiers(item_id, modifier_id);

CREATE TABLE IF NOT EXISTS public.items_extras (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  item_id uuid NOT NULL,
  extra_id uuid NOT NULL,
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='items_extras_item_id_fkey') THEN
    ALTER TABLE public.items_extras
      ADD CONSTRAINT items_extras_item_id_fkey
      FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='items_extras_extra_id_fkey') THEN
    ALTER TABLE public.items_extras
      ADD CONSTRAINT items_extras_extra_id_fkey
      FOREIGN KEY (extra_id) REFERENCES public.extras(id) ON DELETE CASCADE;
  END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS items_extras_item_id_extra_id_key
  ON public.items_extras(item_id, extra_id);

-- =========================================================
-- ORDERS + ORDER ITEMS + DETAIL TABLES
-- =========================================================

CREATE TABLE IF NOT EXISTS public.orders (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  device_id int4,
  table_number varchar(20),
  status varchar(20) NOT NULL,
  total numeric(10,2),
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
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp,
  guests int4,
  customer_name varchar(100)
);

DO $$
BEGIN
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

CREATE TABLE IF NOT EXISTS public.order_item_exceptions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_item_id uuid,
  exception_id uuid,
  exception_name varchar(100),
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  updated_at timestamp
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='order_item_exceptions_order_item_id_fkey') THEN
    ALTER TABLE public.order_item_exceptions
      ADD CONSTRAINT order_item_exceptions_order_item_id_fkey
      FOREIGN KEY (order_item_id) REFERENCES public.order_items(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='order_item_exceptions_exception_id_fkey') THEN
    ALTER TABLE public.order_item_exceptions
      ADD CONSTRAINT order_item_exceptions_exception_id_fkey
      FOREIGN KEY (exception_id) REFERENCES public.exceptions(id);
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS public.order_item_modifiers (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_item_id uuid NOT NULL,
  modifier_id uuid,
  modifier_name varchar(100),
  price_change numeric(10,2),
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  quantity int4 DEFAULT 1,
  updated_at timestamp
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='order_item_modifiers_order_item_id_fkey') THEN
    ALTER TABLE public.order_item_modifiers
      ADD CONSTRAINT order_item_modifiers_order_item_id_fkey
      FOREIGN KEY (order_item_id) REFERENCES public.order_items(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='order_item_modifiers_modifier_id_fkey') THEN
    ALTER TABLE public.order_item_modifiers
      ADD CONSTRAINT order_item_modifiers_modifier_id_fkey
      FOREIGN KEY (modifier_id) REFERENCES public.modifiers(id);
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS public.order_item_extras (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_item_id uuid,
  extra_id uuid,
  extra_name varchar(100),
  price numeric(10,2),
  deleted_at timestamp,
  deleted_by uuid,
  created_at timestamp DEFAULT now(),
  quantity int4 DEFAULT 1,
  updated_at timestamp
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='order_item_extras_order_item_id_fkey') THEN
    ALTER TABLE public.order_item_extras
      ADD CONSTRAINT order_item_extras_order_item_id_fkey
      FOREIGN KEY (order_item_id) REFERENCES public.order_items(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='order_item_extras_extra_id_fkey') THEN
    ALTER TABLE public.order_item_extras
      ADD CONSTRAINT order_item_extras_extra_id_fkey
      FOREIGN KEY (extra_id) REFERENCES public.extras(id);
  END IF;
END$$;

-- =========================================================
-- PAYMENTS + SALE_ORDERS
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

-- =========================================================
-- LOGS
-- =========================================================

CREATE TABLE IF NOT EXISTS public.logs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  action varchar(50) NOT NULL,
  entity varchar(50) NOT NULL,
  entity_id uuid,
  description text,
  company_id uuid,
  employee_id uuid,
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
END$$;

-- =========================================================
-- LARAVEL SUPPORT TABLES (archivo 1)
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

CREATE UNIQUE INDEX IF NOT EXISTS failed_jobs_uuid_unique ON public.failed_jobs(uuid);

-- =========================================================
-- FINAL: sanity indexes that archivo 1 had but weren’t created earlier
-- =========================================================

-- (Ya existen los importantes; este bloque queda por si faltara alguno)
-- No-op.

COMMIT;
