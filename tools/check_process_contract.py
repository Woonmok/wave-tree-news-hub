#!/usr/bin/env python3
"""news_hub.py 오케스트레이션 계약 자동 점검 스크립트.

검증 항목
1) 필수 심볼 존재
2) REQUIRED_KEYS 값 일치
3) process_news 구조(순서-only) 유지
4) 스키마 검증 함수 동작 샘플
"""

from __future__ import annotations

import ast
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NEWS_HUB_PATH = ROOT / "news_hub.py"

EXPECTED_REQUIRED_KEYS = {"id", "category", "title", "summary"}
EXPECTED_CALL_ORDER = [
    "fetch_news",
    "filter_and_analyze",
    "persist",
    "publish",
    "summary",
]
REQUIRED_FUNCS = {
    "fetch_news",
    "filter_and_analyze",
    "persist",
    "publish",
    "summary",
    "process_news",
    "validate_news_items_schema",
}


def fail(msg: str) -> None:
    raise SystemExit(f"❌ CONTRACT FAILED: {msg}")


def pass_msg(msg: str) -> None:
    print(f"✅ {msg}")


def load_module_ast() -> ast.Module:
    if not NEWS_HUB_PATH.exists():
        fail(f"news_hub.py 파일이 없습니다: {NEWS_HUB_PATH}")
    source = NEWS_HUB_PATH.read_text(encoding="utf-8")
    return ast.parse(source)


def find_function(module: ast.Module, name: str) -> ast.FunctionDef | None:
    for node in module.body:
        if isinstance(node, ast.FunctionDef) and node.name == name:
            return node
    return None


def validate_required_symbols(module: ast.Module) -> None:
    func_names = {n.name for n in module.body if isinstance(n, ast.FunctionDef)}
    missing = REQUIRED_FUNCS - func_names
    if missing:
        fail(f"필수 함수 누락: {sorted(missing)}")

    required_keys_value = None
    for node in module.body:
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if isinstance(target, ast.Name) and target.id == "REQUIRED_KEYS":
                    try:
                        required_keys_value = ast.literal_eval(node.value)
                    except Exception as exc:  # pragma: no cover
                        fail(f"REQUIRED_KEYS 파싱 실패: {exc}")

    if required_keys_value is None:
        fail("REQUIRED_KEYS 상수가 없습니다")

    if set(required_keys_value) != EXPECTED_REQUIRED_KEYS:
        fail(
            f"REQUIRED_KEYS 불일치: expected={sorted(EXPECTED_REQUIRED_KEYS)}, got={sorted(set(required_keys_value))}"
        )

    pass_msg("필수 심볼/REQUIRED_KEYS 검증 통과")


def _call_name(node: ast.AST) -> str | None:
    if isinstance(node, ast.Call):
        func = node.func
        if isinstance(func, ast.Name):
            return func.id
        if isinstance(func, ast.Attribute):
            return func.attr
    return None


def validate_process_news_shape(module: ast.Module) -> None:
    fn = find_function(module, "process_news")
    if not fn:
        fail("process_news 함수가 없습니다")

    body = list(fn.body)
    if body and isinstance(body[0], ast.Expr):
        expr_value = body[0].value
        if isinstance(expr_value, ast.Constant) and isinstance(expr_value.value, str):
            body = body[1:]

    if len(body) != 5:
        fail(f"process_news 문장 수가 5가 아님: {len(body)}")

    call_order = []

    # 1) news_list = fetch_news()
    stmt0 = body[0]
    if not isinstance(stmt0, ast.Assign) or len(stmt0.targets) != 1:
        fail("1단계는 news_list 할당이어야 합니다")
    if not isinstance(stmt0.targets[0], ast.Name) or stmt0.targets[0].id != "news_list":
        fail("1단계 대상 변수는 news_list 이어야 합니다")
    c0 = _call_name(stmt0.value)
    if c0 != "fetch_news":
        fail("1단계 호출은 fetch_news 여야 합니다")
    call_order.append(c0)

    # 2) processed_news_data, skipped_count = filter_and_analyze(news_list, ...)
    stmt1 = body[1]
    if not isinstance(stmt1, ast.Assign) or len(stmt1.targets) != 1:
        fail("2단계는 tuple 할당이어야 합니다")
    if not isinstance(stmt1.targets[0], ast.Tuple) or len(stmt1.targets[0].elts) != 2:
        fail("2단계 대상은 (processed_news_data, skipped_count) 이어야 합니다")
    names = [elt.id for elt in stmt1.targets[0].elts if isinstance(elt, ast.Name)]
    if names != ["processed_news_data", "skipped_count"]:
        fail("2단계 대상 변수명이 계약과 다릅니다")
    c1 = _call_name(stmt1.value)
    if c1 != "filter_and_analyze":
        fail("2단계 호출은 filter_and_analyze 여야 합니다")
    call_order.append(c1)

    # 3) artifacts = persist(processed_news_data)
    stmt2 = body[2]
    if not isinstance(stmt2, ast.Assign) or len(stmt2.targets) != 1:
        fail("3단계는 artifacts 할당이어야 합니다")
    if not isinstance(stmt2.targets[0], ast.Name) or stmt2.targets[0].id != "artifacts":
        fail("3단계 대상 변수는 artifacts 이어야 합니다")
    c2 = _call_name(stmt2.value)
    if c2 != "persist":
        fail("3단계 호출은 persist 여야 합니다")
    call_order.append(c2)

    # 4) publish(processed_news_data, artifacts)
    stmt3 = body[3]
    if not isinstance(stmt3, ast.Expr):
        fail("4단계는 publish 호출이어야 합니다")
    c3 = _call_name(stmt3.value)
    if c3 != "publish":
        fail("4단계 호출은 publish 여야 합니다")
    call_order.append(c3)

    # 5) summary(processed_news_data, skipped_count, artifacts)
    stmt4 = body[4]
    if not isinstance(stmt4, ast.Expr):
        fail("5단계는 summary 호출이어야 합니다")
    c4 = _call_name(stmt4.value)
    if c4 != "summary":
        fail("5단계 호출은 summary 여야 합니다")
    call_order.append(c4)

    if call_order != EXPECTED_CALL_ORDER:
        fail(f"호출 순서 불일치: expected={EXPECTED_CALL_ORDER}, got={call_order}")

    pass_msg("process_news 오케스트레이터 구조 검증 통과")


def validate_schema_function_runtime() -> None:
    namespace = {"__file__": str(NEWS_HUB_PATH), "__name__": "contract_check__"}
    source = NEWS_HUB_PATH.read_text(encoding="utf-8")
    code = compile(source, str(NEWS_HUB_PATH), "exec")
    exec(code, namespace)

    validate_fn = namespace.get("validate_news_items_schema")
    if not callable(validate_fn):
        fail("validate_news_items_schema를 로드하지 못했습니다")

    sample = [
        {"id": "1", "category": "global_biz", "title": "t", "summary": "s"},
        {"id": "2", "title": "t2", "summary": "s2"},
        "not-a-dict",
    ]
    valid, invalid_count = validate_fn(sample, context="contract-test")
    if invalid_count != 2:
        fail(f"스키마 샘플 invalid_count 예상=2, 실제={invalid_count}")
    if len(valid) != 1:
        fail(f"스키마 샘플 valid 예상=1, 실제={len(valid)}")

    pass_msg("스키마 검증 함수 샘플 동작 통과")


def main() -> None:
    module = load_module_ast()
    validate_required_symbols(module)
    validate_process_news_shape(module)
    validate_schema_function_runtime()
    print("\n🎉 ALL CONTRACT CHECKS PASSED")


if __name__ == "__main__":
    main()
