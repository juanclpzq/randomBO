/* =====================================================================
   KDS (Kitchen Display System) Schema Additions

   Adds necessary columns and tables for Order Flow tracking:
   - Timestamp columns for order lifecycle (started_at, completed_at, canceled_at)
   - order_events table for complete audit trail
   - Performance indexes for KDS queries

   Idempotent: Safe to run multiple times
   ===================================================================== */

BEGIN;

-- =========================================================
-- ORDERS TABLE: Add lifecycle timestamp columns
-- =========================================================

-- Add started_at column (when kitchen began preparation)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'orders'
      AND column_name = 'started_at'
  ) THEN
    ALTER TABLE public.orders
    ADD COLUMN started_at timestamp NULL;

    COMMENT ON COLUMN public.orders.started_at IS 'Timestamp when kitchen started preparing the order';
  END IF;
END$$;

-- Add completed_at column (when order marked ready)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'orders'
      AND column_name = 'completed_at'
  ) THEN
    ALTER TABLE public.orders
    ADD COLUMN completed_at timestamp NULL;

    COMMENT ON COLUMN public.orders.completed_at IS 'Timestamp when order was marked ready for pickup';
  END IF;
END$$;

-- Add canceled_at column (when order was canceled)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'orders'
      AND column_name = 'canceled_at'
  ) THEN
    ALTER TABLE public.orders
    ADD COLUMN canceled_at timestamp NULL;

    COMMENT ON COLUMN public.orders.canceled_at IS 'Timestamp when order was canceled';
  END IF;
END$$;

-- =========================================================
-- ORDER_EVENTS TABLE: Audit trail for order state changes
-- =========================================================

CREATE TABLE IF NOT EXISTS public.order_events (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id uuid NOT NULL,
  event_type varchar(50) NOT NULL,
  from_status varchar(50) NULL,
  to_status varchar(50) NULL,
  actor varchar(50) NOT NULL,
  actor_id uuid NULL,
  location_id uuid NOT NULL,
  company_id uuid NOT NULL,
  metadata jsonb NULL,
  created_at timestamp NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.order_events IS 'Audit trail for all order state transitions and lifecycle events';
COMMENT ON COLUMN public.order_events.event_type IS 'Type of event: order_created, order_started, order_ready, order_canceled, etc.';
COMMENT ON COLUMN public.order_events.from_status IS 'Previous order status before transition';
COMMENT ON COLUMN public.order_events.to_status IS 'New order status after transition';
COMMENT ON COLUMN public.order_events.actor IS 'Who/what triggered the event: kds, pos, system, employee';
COMMENT ON COLUMN public.order_events.actor_id IS 'ID of employee or user who triggered the event (if applicable)';
COMMENT ON COLUMN public.order_events.metadata IS 'Additional context as JSON (e.g., cancellation reason)';

-- Add foreign key constraint if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'order_events_order_id_fkey'
  ) THEN
    ALTER TABLE public.order_events
    ADD CONSTRAINT order_events_order_id_fkey
    FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'order_events_location_id_fkey'
  ) THEN
    ALTER TABLE public.order_events
    ADD CONSTRAINT order_events_location_id_fkey
    FOREIGN KEY (location_id) REFERENCES public.locations(id) ON DELETE CASCADE;
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'order_events_company_id_fkey'
  ) THEN
    ALTER TABLE public.order_events
    ADD CONSTRAINT order_events_company_id_fkey
    FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;
  END IF;
END$$;

-- =========================================================
-- INDEXES: Performance optimization for KDS queries
-- =========================================================

-- Index for KDS order listing (most common query)
CREATE INDEX IF NOT EXISTS idx_orders_kds_active
ON public.orders (location_id, status, created_at)
WHERE deleted_at IS NULL;

COMMENT ON INDEX idx_orders_kds_active IS 'Optimizes KDS active orders query filtering by location, status, and sort by created_at';

-- Index for order status filtering
CREATE INDEX IF NOT EXISTS idx_orders_status
ON public.orders (status)
WHERE deleted_at IS NULL;

-- Index for completed orders cleanup (30 minute window)
CREATE INDEX IF NOT EXISTS idx_orders_completed_at
ON public.orders (completed_at)
WHERE status = 'ready' AND deleted_at IS NULL;

COMMENT ON INDEX idx_orders_completed_at IS 'Optimizes filtering of ready orders by completion time (30 min window)';

-- Index for order events by order (audit trail queries)
CREATE INDEX IF NOT EXISTS idx_order_events_order_id
ON public.order_events (order_id, created_at DESC);

-- Index for order events by location (reporting queries)
CREATE INDEX IF NOT EXISTS idx_order_events_location_company
ON public.order_events (location_id, company_id, created_at DESC);

-- Index for order events by type (analytics queries)
CREATE INDEX IF NOT EXISTS idx_order_events_type
ON public.order_events (event_type, created_at DESC);

-- =========================================================
-- VERIFY RELATED INDEXES (from base schema)
-- =========================================================

-- Ensure order items have proper indexes for eager loading
CREATE INDEX IF NOT EXISTS idx_order_items_order_id
ON public.order_items (order_id)
WHERE deleted_at IS NULL;

-- Ensure pivot tables have indexes for modifier/exception/extra loading
CREATE INDEX IF NOT EXISTS idx_order_item_modifiers_order_item_id
ON public.order_item_modifiers (order_item_id)
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_order_item_exceptions_order_item_id
ON public.order_item_exceptions (order_item_id)
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_order_item_extras_order_item_id
ON public.order_item_extras (order_item_id)
WHERE deleted_at IS NULL;

-- =========================================================
-- FINALIZE
-- =========================================================

COMMIT;

-- Display summary
DO $$
BEGIN
  RAISE NOTICE '✓ KDS schema additions applied successfully';
  RAISE NOTICE '  - Added timestamp columns to orders table';
  RAISE NOTICE '  - Created order_events table with constraints';
  RAISE NOTICE '  - Created performance indexes for KDS queries';
END$$;
