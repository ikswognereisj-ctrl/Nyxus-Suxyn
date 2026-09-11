#!/usr/bin/env python3
"""Safe calculator eval for Calculator.qml. Same AST allow-list as GTK."""
from __future__ import annotations

import ast
import json
import math
import operator as op
import sys

_BIN = {
    ast.Add: op.add, ast.Sub: op.sub, ast.Mult: op.mul, ast.Div: op.truediv,
    ast.Pow: op.pow, ast.Mod: op.mod, ast.FloorDiv: op.floordiv,
    ast.BitAnd: op.and_, ast.BitOr: op.or_, ast.BitXor: op.xor,
    ast.LShift: op.lshift, ast.RShift: op.rshift,
}
_UN = {ast.UAdd: op.pos, ast.USub: op.neg, ast.Invert: op.invert}
_CONSTS = {"pi": math.pi, "e": math.e, "tau": math.tau}


def _make_funcs(degrees: bool):
    if degrees:
        def _in(x):
            return math.radians(x)

        def _out(x):
            return math.degrees(x)
    else:
        def _in(x):
            return x

        def _out(x):
            return x
    return {
        "sqrt": math.sqrt, "abs": abs, "round": round, "floor": math.floor,
        "ceil": math.ceil,
        "sin": lambda x: math.sin(_in(x)),
        "cos": lambda x: math.cos(_in(x)),
        "tan": lambda x: math.tan(_in(x)),
        "asin": lambda x: _out(math.asin(x)),
        "acos": lambda x: _out(math.acos(x)),
        "atan": lambda x: _out(math.atan(x)),
        "log": math.log10, "ln": math.log, "exp": math.exp,
        "fact": math.factorial, "min": min, "max": max,
        "gcd": math.gcd, "hypot": math.hypot,
    }


def evaluate(expr: str, degrees: bool = True) -> float:
    expr = (expr.replace("×", "*").replace("÷", "/")
                .replace("−", "-").replace("^", "**").replace(",", "")
                .replace("_", ""))
    if "%" in expr:
        expr = expr.replace("%", "/100")
    funcs = _make_funcs(degrees)

    def walk(n):
        if isinstance(n, ast.Expression):
            return walk(n.body)
        if isinstance(n, ast.Constant):
            if isinstance(n.value, (int, float)):
                return n.value
            raise ValueError("only numbers")
        if isinstance(n, ast.BinOp) and type(n.op) in _BIN:
            return _BIN[type(n.op)](walk(n.left), walk(n.right))
        if isinstance(n, ast.UnaryOp) and type(n.op) in _UN:
            return _UN[type(n.op)](walk(n.operand))
        if isinstance(n, ast.Name):
            if n.id in _CONSTS:
                return _CONSTS[n.id]
            raise ValueError(f"unknown name '{n.id}'")
        if isinstance(n, ast.Call):
            if not isinstance(n.func, ast.Name) or n.func.id not in funcs:
                raise ValueError("unknown function")
            return funcs[n.func.id](*[walk(a) for a in n.args])
        raise ValueError("not allowed")

    return walk(ast.parse(expr, mode="eval"))


def _precision(req_or_n, default: int = 10) -> int:
    try:
        p = int(req_or_n)
    except (TypeError, ValueError):
        p = default
    return max(2, min(15, p))


def fmt(v, group: bool = False, precision: int = 10) -> str:
    p = _precision(precision)
    if isinstance(v, float):
        if v != v or v in (float("inf"), float("-inf")):
            return str(v)
        if abs(v) >= 1e12 or (v and abs(v) < 1e-6):
            return f"{v:.{p}g}"
        s = f"{v:.{p}f}".rstrip("0").rstrip(".")
        if group and s:
            neg = s.startswith("-")
            body = s[1:] if neg else s
            if "." in body:
                ip, fp = body.split(".", 1)
                body = f"{int(ip):,}.{fp}"
            else:
                body = f"{int(body):,}"
            s = ("-" if neg else "") + body
        return s or "0"
    if isinstance(v, int) and group:
        return f"{v:,}"
    return str(v)


def bases(v) -> list[dict]:
    try:
        i = int(v)
    except (TypeError, ValueError, OverflowError):
        return []
    if i != v or abs(i) > 2 ** 63:
        return []
    sign = "-" if i < 0 else ""
    a = abs(i)
    return [
        {"k": "HEX", "v": f"{sign}0x{a:X}"},
        {"k": "DEC", "v": f"{sign}{a:,}"},
        {"k": "OCT", "v": f"{sign}0o{a:o}"},
        {"k": "BIN", "v": f"{sign}0b{a:b}"},
    ]


def main() -> int:
    raw = sys.stdin.read() if not sys.stdin.isatty() else ""
    if raw.strip():
        req = json.loads(raw)
    else:
        req = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {}
    expr = str(req.get("expr", "") or "")
    degrees = bool(req.get("degrees", True))
    group = bool(req.get("group", True))
    precision = _precision(req.get("precision", 10))
    if not expr.strip():
        json.dump({"ok": True, "text": "0", "value": 0, "bases": []}, sys.stdout)
        return 0
    try:
        v = evaluate(expr, degrees)
        json.dump({
            "ok": True,
            "value": v,
            "text": fmt(v, group, precision),
            "bases": bases(v),
        }, sys.stdout)
        return 0
    except Exception as e:
        json.dump({"ok": False, "error": str(e), "text": "Error"}, sys.stdout)
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
