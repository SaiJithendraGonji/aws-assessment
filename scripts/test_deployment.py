#!/usr/bin/env python3

import argparse
import json
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime

import boto3
import requests


def now() -> str:
    return datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")


def authenticate(user_pool_id: str, client_id: str, email: str, password: str) -> str:
    print(f"{now()}  Authenticating with Cognito...", end=" ", flush=True)

    client = boto3.client("cognito-idp", region_name="us-east-1")

    try:
        response = client.initiate_auth(
            AuthFlow="USER_PASSWORD_AUTH",
            AuthParameters={"USERNAME": email, "PASSWORD": password},
            ClientId=client_id,
        )
    except client.exceptions.NotAuthorizedException:
        print("FAIL")
        print(f"             invalid credentials for {email}")
        sys.exit(1)
    except client.exceptions.UserNotFoundException:
        print("FAIL")
        print(f"             user not found: {email}")
        sys.exit(1)

    print("ok")
    return response["AuthenticationResult"]["IdToken"]


def call_endpoint(label: str, url: str, method: str, token: str) -> dict:
    headers = {
        "Authorization": token,
        "Content-Type": "application/json",
    }

    start = time.perf_counter()
    try:
        if method.upper() == "GET":
            resp = requests.get(url, headers=headers, timeout=30)
        else:
            resp = requests.post(url, headers=headers, timeout=30)
    except requests.exceptions.RequestException as e:
        return {
            "label": label,
            "ok": False,
            "error": str(e),
            "latency_ms": round((time.perf_counter() - start) * 1000),
        }

    try:
        body = resp.json()
    except ValueError:
        body = {}

    return {
        "label": label,
        "ok": resp.status_code == 200,
        "status": resp.status_code,
        "region": body.get("region", "unknown"),
        "latency_ms": round((time.perf_counter() - start) * 1000),
        "error": None,
    }


def run_concurrent(calls: list) -> list:
    results = []
    with ThreadPoolExecutor(max_workers=len(calls)) as executor:
        futures = {
            executor.submit(call_endpoint, label, url, method, token): label
            for label, url, method, token in calls
        }
        for future in as_completed(futures):
            results.append(future.result())
    return sorted(results, key=lambda r: r["label"])


def print_results(label: str, results: list) -> int:
    failures = 0
    print(f"\n{now()}  {label}")

    for r in results:
        region = r["label"].split("/")[1]
        latency = f"{r['latency_ms']}ms"

        if not r["ok"]:
            failures += 1
            reason = r["error"] or f"unexpected status: {r['status']}"
            print(f"{'':23}{region:<12} {str(r.get('status', '--')):<6} {'--':<9} FAIL  {reason}")
            continue

        region_match = r["region"] == region
        result = "PASS" if region_match else f"FAIL  got region={r['region']}"
        if not region_match:
            failures += 1

        print(f"{'':23}{region:<12} {r['status']:<6} {latency:<9} {result}")

    return failures


def tf_outputs() -> dict:
    try:
        result = subprocess.run(
            ["terraform", "output", "-json"],
            capture_output=True, text=True, check=True,
        )
        raw = json.loads(result.stdout)
        return {k: v["value"] for k, v in raw.items()}
    except subprocess.CalledProcessError as e:
        print(f"terraform output failed: {e.stderr.strip()}")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Unleash Live deployment integration test")
    parser.add_argument("--from-tf-output", action="store_true")
    parser.add_argument("--user-pool-id")
    parser.add_argument("--client-id")
    parser.add_argument("--email")
    parser.add_argument("--password")
    parser.add_argument("--api-us-east-1")
    parser.add_argument("--api-eu-west-1")
    args = parser.parse_args()

    if args.from_tf_output:
        tf = tf_outputs()
        user_pool_id = tf["cognito_user_pool_id"]
        client_id = tf["cognito_client_id"]
        api_us = tf["api_endpoint_us_east_1"]
        api_eu = tf["api_endpoint_eu_west_1"]
        email = "sjgsetty@gmail.com"
        password = input("Password: ")
    else:
        user_pool_id = args.user_pool_id
        client_id = args.client_id
        email = args.email
        password = args.password
        api_us = args.api_us_east_1
        api_eu = args.api_eu_west_1

    token = authenticate(user_pool_id, client_id, email, password)

    greet_results = run_concurrent([
        ("greet/us-east-1", f"{api_us}/greet", "GET", token),
        ("greet/eu-west-1", f"{api_eu}/greet", "GET", token),
    ])

    dispatch_results = run_concurrent([
        ("dispatch/us-east-1", f"{api_us}/dispatch", "POST", token),
        ("dispatch/eu-west-1", f"{api_eu}/dispatch", "POST", token),
    ])

    failures = 0
    failures += print_results("greet", greet_results)
    failures += print_results("dispatch", dispatch_results)

    total = len(greet_results) + len(dispatch_results)
    passed = total - failures

    print(f"\n{'':23}{passed} passed, {failures} failed")
    print(f"{now()}  Done")

    if failures:
        print("exit 1")
        sys.exit(1)


if __name__ == "__main__":
    main()