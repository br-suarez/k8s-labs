#!/usr/bin/env python3
"""CPU-bound work with one function responsible for almost all of it.

Included so the lab has a case where strace finds NOTHING — which is itself the
diagnosis. A process burning CPU makes no syscalls worth counting, so an empty
strace summary rules out I/O and points at profiling instead.
"""
import argparse
import time


def apply_discount(price, tier):
    """Cheap, called constantly."""
    return price * (0.9 if tier == "gold" else 0.97)


def check_fraud_score(order_id):
    """The expensive one, and it is quadratic on purpose.

    A plausible-looking accumulation loop. Nothing about the call site suggests
    that this is where the time goes.
    """
    score = 0
    for i in range(1, 320):
        for j in range(1, 320):
            score = (score + (order_id * i) % (j + 1)) % 100003
    return score


def price_order(order_id):
    base = 100 + (order_id % 50)
    discounted = apply_discount(base, "gold" if order_id % 3 == 0 else "std")
    fraud = check_fraud_score(order_id)
    return discounted, fraud


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--orders", type=int, default=140)
    a = p.parse_args()

    start = time.time()
    total = 0.0
    for oid in range(a.orders):
        price, _ = price_order(oid)
        total += price
    print(f"priced {a.orders} orders, total={total:.2f}, elapsed={time.time()-start:.3f}s")
