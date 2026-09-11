import uuid


def new_vendor_id() -> str:
    return f"vendor-{uuid.uuid4().hex[:8]}"


def new_product_id() -> str:
    return f"prod-{uuid.uuid4().hex[:8]}"


def new_order_id() -> str:
    return f"ORD-{uuid.uuid4().hex[:8].upper()}"


def new_review_id() -> str:
    return f"rev-{uuid.uuid4().hex[:8]}"
