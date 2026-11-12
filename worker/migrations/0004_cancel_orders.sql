-- BIORYX: запускать только на отдельной базе BIORYX, после бэкапа.
-- Запрещаем возврат к активному состоянию: иначе повторная отмена удвоит остаток.
CREATE TRIGGER IF NOT EXISTS bioryx_cancel_guard
BEFORE UPDATE OF status ON orders
WHEN (OLD.status = 'cancelled' AND NEW.status != 'cancelled')
  OR (NEW.status = 'cancelled' AND OLD.status != 'cancelled'
      AND (OLD.status NOT IN ('new','confirmed','packing') OR OLD.payment_status != 'unpaid'))
BEGIN
  SELECT RAISE(ABORT, 'invalid_cancellation_or_refund_required');
END;

-- Возврат только один раз, в рамках той же транзакции что смена статуса.
CREATE TRIGGER IF NOT EXISTS bioryx_cancel_restock
AFTER UPDATE OF status ON orders
WHEN OLD.status != 'cancelled' AND NEW.status = 'cancelled'
BEGIN
  UPDATE products SET stock = stock + COALESCE((
    SELECT SUM(qty) FROM order_items
    WHERE order_id = NEW.id AND product_id = products.id
  ), 0)
  WHERE id IN (SELECT product_id FROM order_items WHERE order_id = NEW.id);
END;
