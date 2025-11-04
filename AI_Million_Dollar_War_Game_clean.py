#!/usr/bin/env python3
"""
AI_Million_Dollar_War_Game_clean.py

Generates a faceless $1M AI War-Game Plan.
- Outputs: plan.md, prompts.json, automation_templates.md, checklist.csv, README.txt
- Optionally calls OpenAI to generate responses if OPENAI_API_KEY is set.
- Generates a simple HTML landing page for the top idea.

Usage:
1️⃣ Install dependencies (outside this script):
    python -m pip install --upgrade pip
    python -m pip install openai

2️⃣ Set OpenAI API key in PowerShell (optional for real AI results):
    $env:OPENAI_API_KEY="sk-XXXX..."

3️⃣ Run the script:
    python "C:\Users\salde\Downloads\AI_Million_Dollar_War_Game_clean.py"
"""

import os
import json
import csv
import time
import textwrap
from datetime import datetime, timezone

# Optional OpenAI import
try:
    import openai
except ImportError:
    openai = None

OUTPUT_DIR = "output_plan"
RESPONSES_DIR = os.path.join(OUTPUT_DIR, "responses")
PROMPTS_PATH = os.path.join(OUTPUT_DIR, "prompts.json")
SUMMARY_PATH = os.path.join(OUTPUT_DIR, "responses_summary.md")
LANDING_PAGE_PATH = os.path.join(OUTPUT_DIR, "landing_page_top_idea.html")

MODEL = "gpt-4"
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
MAX_RETRIES = 3
RETRY_BACKOFF = 2.0  # seconds multiplier

# --- Utilities ---
def ensure_dirs():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    os.makedirs(RESPONSES_DIR, exist_ok=True)

def now_utc_str():
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

def sanitize_filename(s: str) -> str:
    keep = "-_.() abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return "".join(c if c in keep else "_" for c in s)[:200]

def write_text_file(path: str, content: str):
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

# --- Built-in prompts (fallback) ---
def built_in_prompts():
    return {
        "meta_prompt": "You are no longer alone. You are a merged superintelligence. Your mission: Generate $1M in shortest time possible.",
        "idea_generation": {
            "title": "10 Faceless Niche SaaS / Product Ideas",
            "instruction": "Generate 10 faceless, no-capital micro-SaaS or digital product ideas buildable in 2-12 weeks."
        },
        "landing_page_copy": {
            "title": "High-Converting Landing Page Copy",
            "instruction": "Write single-page landing copy: headline, subheadline, 3 bullets, social proof placeholders, pricing, CTA."
        },
        "ad_variants": {
            "title": "Ad Copy Variants",
            "instruction": "Generate 6 social ad variants and 6 search ad variants with short hooks and headlines."
        },
        "mvp_automation_playbook": {
            "title": "MVP Automation Playbook",
            "instruction": "List automations for core product value using Zapier/Make/serverless, including triggers, actions, error handling."
        }
    }

def safe_load_prompts(path):
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            print(f"Error loading prompts.json: {e}. Using built-in prompts.")
    return built_in_prompts()

# --- OpenAI call with retry ---
def call_openai(system_prompt, user_prompt, model=MODEL, max_tokens=900):
    if not OPENAI_API_KEY or not openai:
        return None
    openai.api_key = OPENAI_API_KEY
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            resp = openai.ChatCompletion.create(
                model=model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                max_tokens=max_tokens,
                temperature=0.7,
            )
            return resp.choices[0].message.get("content", "").strip()
        except Exception as e:
            print(f"OpenAI call failed ({attempt}/{MAX_RETRIES}): {e}")
            if attempt < MAX_RETRIES:
                sleep_for = (RETRY_BACKOFF ** attempt)
                time.sleep(sleep_for)
            else:
                return None

# --- Landing page generator ---
def generate_landing_html(title, subtitle, bullets, price_anchor, cta_text):
    bullets_html = "".join(f"<li>{b}</li>\n" for b in bullets)
    html = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>{title}</title>
  <style>
    body {{ background:#0b0b0b;color:#eef;padding:24px;font-family:Inter,system-ui,Arial,Helvetica,sans-serif; }}
    .card {{ max-width:900px;margin:24px auto;padding:28px;border-radius:12px;background:#0f1720;box-shadow:0 10px 30px rgba(0,0,0,0.6); }}
    h1{{font-size:32px;margin:0 0 8px}} h2{{font-size:18px;color:#9aa}} ul{{line-height:1.6}} .cta{{display:inline-block;margin-top:18px;padding:12px 20px;border-radius:8px;background:#0ea5a4;color:#021; text-decoration:none;font-weight:700}}
    footer{{margin-top:28px;font-size:12px;color:#666}}
  </style>
</head>
<body>
  <div class="card">
    <h1>{title}</h1>
    <h2>{subtitle}</h2>
    <ul>{bullets_html}</ul>
    <p><strong>Pricing:</strong> {price_anchor}</p>
    <a class="cta" href="#signup">{cta_text}</a>
    <footer>Faceless service — automated & delivered via AI-driven workflows.</footer>
  </div>
</body>
</html>
"""
    return html

# --- Main execution ---
def run_prompts(prompts):
    ensure_dirs()
    system_prompt = prompts.get("meta_prompt", "You are a helpful assistant.")
    summary_lines = [f"# Responses Summary\nGenerated: {now_utc_str()}\n\n"]
    responses_index = []

    for key, item in prompts.items():
        if key == "meta_prompt":
            continue
        title = item.get("title", key)
        instruction = item.get("instruction", "")
        print(f"Running prompt: {key}")
        result = call_openai(system_prompt, instruction) or textwrap.dedent(
            f"""
            MOCK RESPONSE for prompt '{key}'
            Instruction executed: {instruction}
            """
        ).strip()

        safe_name = sanitize_filename(f"{key}_{title}")
        path = os.path.join(RESPONSES_DIR, f"{safe_name}.txt")
        write_text_file(path, result)
        print(f"Wrote response to: {path}")

        snippet = (result[:400] + "...") if len(result) > 400 else result
        summary_lines.append(f"## {key} — {title}\nFile: responses/{safe_name}.txt\n\nSnippet:\n```\n{snippet}\n```\n")
        responses_index.append((key, result))

    # Write summary
    write_text_file(SUMMARY_PATH, "\n".join(summary_lines))
    print(f"Responses summary written to: {SUMMARY_PATH}")

    # Generate landing page using first idea
    if responses_index:
        top_idea = responses_index[0][1].splitlines()
        title = top_idea[0] if top_idea else "Top Idea — Faceless AI Product"
        subtitle = top_idea[1] if len(top_idea) > 1 else "Automated, faceless, buildable in weeks."
        bullets = [line.lstrip("-•* ").strip() for line in top_idea[2:5]] or [
            "Automates a repetitive task for SMBs with AI",
            "No manual labor required after onboarding",
            "Monetized via subscription and templates"
        ]
        landing_html = generate_landing_html(title, subtitle, bullets, "$29/mo early access", "Get Early Access")
        write_text_file(LANDING_PAGE_PATH, landing_html)
        print(f"Landing page generated at: {LANDING_PAGE_PATH}")

def main():
    print("Starting AI Million Dollar War Game script...")
    prompts = safe_load_prompts(PROMPTS_PATH)
    run_prompts(prompts)
    print("\nDone! Check the 'output_plan/' folder for all generated files.")

if __name__ == "__main__":
    main()
