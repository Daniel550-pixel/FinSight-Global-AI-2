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
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Run AI $1M Script",
            "type": "shell",
            "command": "python \"${workspaceFolder}\\AI_Million_Dollar_War_Game_clean.py\"; Start-Process \"${workspaceFolder}\\output_plan\"",
            "group": {
                "kind": "build",
                "isDefault": true
            },
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": true,
                "panel": "shared"
            }
        }
    ]
}
#!/usr/bin/env python3
"""
AI Million Dollar War Game v3

Full automation: runs all prompts via OpenAI and generates landing page.
Usage:
1. Ensure openai package installed: pip install openai
2. Set environment variable OPENAI_API_KEY in PowerShell:
   $env:OPENAI_API_KEY="sk-XXXX..."
3. Run in VS Code integrated terminal or PowerShell:
   python AI_Million_Dollar_War_Game_v3.py
"""

import os, json, time, textwrap
from datetime import datetime, timezone

try:
    import openai
except ImportError:
    openai = None

# -------------------------
# Config
# -------------------------
OUTPUT_DIR = "output_plan"
RESPONSES_DIR = os.path.join(OUTPUT_DIR, "responses")
PROMPTS_PATH = os.path.join(OUTPUT_DIR, "prompts.json")
LANDING_PAGE_PATH = os.path.join(OUTPUT_DIR, "landing_page_top_idea.html")
MODEL = "gpt-4"
MAX_RETRIES = 3

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if OPENAI_API_KEY:
    openai.api_key = OPENAI_API_KEY

# -------------------------
# Helpers
# -------------------------
def ensure_dirs():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    os.makedirs(RESPONSES_DIR, exist_ok=True)

def sanitize_filename(s: str) -> str:
    keep = "-_.() abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return "".join(c if c in keep else "_" for c in s)[:200]

def call_openai(system_prompt, user_prompt, max_tokens=900):
    if not openai:
        return f"[MOCK MODE] Prompt: {user_prompt[:50]}..."
    for attempt in range(1, MAX_RETRIES+1):
        try:
            resp = openai.ChatCompletion.create(
                model=MODEL,
                messages=[{"role":"system","content":system_prompt},
                          {"role":"user","content":user_prompt}],
                max_tokens=max_tokens,
                temperature=0.7
            )
            return resp.choices[0].message.get("content","").strip()
        except Exception as e:
            print(f"OpenAI call failed attempt {attempt}: {e}")
            time.sleep(attempt*2)
    return f"[FAILED after retries] Prompt: {user_prompt[:50]}..."

def generate_landing_html(title, subtitle, bullets, price_anchor, cta_text):
    bullets_html = "".join(f"<li>{b}</li>\n" for b in bullets)
    return f"""<!doctype html>
<html lang="en">
<head><meta charset="utf-8"/>
<title>{title}</title>
<style>
body{{background:#0b0b0b;color:#eef;padding:24px;font-family:Inter,Arial,sans-serif;}}
.card{{max-width:900px;margin:24px auto;padding:28px;border-radius:12px;background:#0f1720;box-shadow:0 10px 30px rgba(0,0,0,0.6);}}
h1{{font-size:32px}} h2{{font-size:18px;color:#9aa}} ul{{line-height:1.6}} .cta{{display:inline-block;margin-top:18px;padding:12px 20px;border-radius:8px;background:#0ea5a4;color:#021;text-decoration:none;font-weight:700}}
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
<footer>Faceless service — automated & delivered via AI workflows.</footer>
</div>
</body>
</html>"""

# -------------------------
# Main
# -------------------------
def main():
    ensure_dirs()
    # Load prompts
    if os.path.exists(PROMPTS_PATH):
        with open(PROMPTS_PATH,"r",encoding="utf-8") as f:
            prompts = json.load(f)
    else:
        prompts = {
            "meta_prompt": "You are a superintelligent AI merged from ChatGPT, Gemini, Claude, Mistral...",
            "idea_generation": {"title":"10 Faceless Niche SaaS Ideas",
                                "instruction":"Generate 10 faceless micro-SaaS or digital product ideas buildable in 2-12 weeks."},
            "landing_page_copy":{"title":"Landing Page Copy","instruction":"Write a concise single-page landing page for top idea."}
        }

    system_prompt = prompts.get("meta_prompt") or "You are a helpful assistant."
    responses_index = []

    # Generate responses
    for key, item in prompts.items():
        if key=="meta_prompt": continue
        user_instruction = item.get("instruction") if isinstance(item, dict) else item
        print(f"Running prompt: {key}")
        result = call_openai(system_prompt, user_instruction)
        filename = f"{sanitize_filename(key)}.txt"
        path = os.path.join(RESPONSES_DIR, filename)
        with open(path,"w",encoding="utf-8") as f:
            f.write(result)
        responses_index.append((key, result))
        print(f"Saved {key} -> {path}")

    # Generate landing page from top idea
    if responses_index:
        top_idea_text = responses_index[0][1]
        lines = [l.strip() for l in top_idea_text.splitlines() if l.strip()]
        title = lines[0] if lines else "Top AI Idea"
        subtitle = lines[1] if len(lines)>1 else "Automated, faceless, buildable in weeks."
        bullets = [ln.lstrip("-•* ").strip() for ln in lines[2:] if ln.startswith(("-", "•", "*"))][:3]
        if not bullets:
            bullets = ["Automates repetitive tasks for SMBs","No manual labor after onboarding","Subscription + templates monetization"]
        price_anchor="$29/mo or $79 one-time"
        cta_text="Get Early Access"
        html = generate_landing_html(title, subtitle, bullets, price_anchor, cta_text)
        with open(LANDING_PAGE_PATH,"w",encoding="utf-8") as f:
            f.write(html)
        print(f"Landing page generated: {LANDING_PAGE_PATH}")

    print("\nAll done! Open output_plan/ folder in VS Code to view results.")

if __name__=="__main__":
    main()
#!/usr/bin/env python3
"""
AI Million Dollar War Game v4

Full automation:
- Generate 10 faceless micro-SaaS/digital product ideas
- Create individual landing pages
- Generate master index page for preview
Usage:
1. Ensure openai package installed: pip install openai
2. Set environment variable OPENAI_API_KEY in PowerShell:
   $env:OPENAI_API_KEY="sk-XXXX..."
3. Run in VS Code integrated terminal:
   python AI_Million_Dollar_War_Game_v4.py
"""

import os, json, time
from pathlib import Path

try:
    import openai
except ImportError:
    openai = None

# -------------------------
# Config
# -------------------------
OUTPUT_DIR = Path("output_plan")
IDEAS_DIR = OUTPUT_DIR / "ideas"
MASTER_PAGE = OUTPUT_DIR / "landing_page_index.html"
MODEL = "gpt-4"
MAX_RETRIES = 3

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if OPENAI_API_KEY:
    openai.api_key = OPENAI_API_KEY

# -------------------------
# Helpers
# -------------------------
def ensure_dirs():
    IDEAS_DIR.mkdir(parents=True, exist_ok=True)

def sanitize_filename(s: str) -> str:
    keep = "-_.() abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return "".join(c if c in keep else "_" for c in s)[:200]

def call_openai(system_prompt, user_prompt, max_tokens=900):
    if not openai:
        return f"[MOCK MODE] Prompt: {user_prompt[:50]}..."
    for attempt in range(1, MAX_RETRIES+1):
        try:
            resp = openai.ChatCompletion.create(
                model=MODEL,
                messages=[{"role":"system","content":system_prompt},
                          {"role":"user","content":user_prompt}],
                max_tokens=max_tokens,
                temperature=0.7
            )
            return resp.choices[0].message.get("content","").strip()
        except Exception as e:
            print(f"OpenAI call failed attempt {attempt}: {e}")
            time.sleep(attempt*2)
    return f"[FAILED after retries] Prompt: {user_prompt[:50]}..."

def generate_landing_html(title, subtitle, bullets, price_anchor, cta_text):
    bullets_html = "".join(f"<li>{b}</li>\n" for b in bullets)
    return f"""<!doctype html>
<html lang="en">
<head><meta charset="utf-8"/>
<title>{title}</title>
<style>
body{{background:#0b0b0b;color:#eef;padding:24px;font-family:Inter,Arial,sans-serif;}}
.card{{max-width:900px;margin:24px auto;padding:28px;border-radius:12px;background:#0f1720;box-shadow:0 10px 30px rgba(0,0,0,0.6);}}
h1{{font-size:32px}} h2{{font-size:18px;color:#9aa}} ul{{line-height:1.6}} .cta{{display:inline-block;margin-top:18px;padding:12px 20px;border-radius:8px;background:#0ea5a4;color:#021;text-decoration:none;font-weight:700}}
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
<footer>Faceless service — automated & delivered via AI workflows.</footer>
</div>
</body>
</html>"""

# -------------------------
# Main
# -------------------------
def main():
    ensure_dirs()
    system_prompt = "You are a superintelligent AI merged from ChatGPT, Gemini, Claude, Mistral. You generate profitable faceless SaaS/digital product ideas and create concise landing page copy."
    
    # 1️⃣ Generate 10 ideas
    idea_prompt = "Generate 10 faceless micro-SaaS or digital product ideas that can be built in 2-12 weeks. Include 1-2 sentence description per idea."
    ideas_text = call_openai(system_prompt, idea_prompt, max_tokens=1200)
    
    idea_lines = [line.strip() for line in ideas_text.splitlines() if line.strip()]
    ideas = []
    for line in idea_lines:
        if "." in line:
            try:
                idx = line.index(".")
                title_desc = line[idx+1:].strip()
                if "-" in title_desc:
                    title, desc = title_desc.split("-",1)
                else:
                    parts = title_desc.split(":",1)
                    if len(parts)==2:
                        title, desc = parts
                    else:
                        title = title_desc
                        desc = "Automated, faceless SaaS solution."
                ideas.append((title.strip(), desc.strip()))
            except Exception:
                continue
        if len(ideas)>=10:
            break

    print(f"Generated {len(ideas)} ideas.")

    master_links = []
    # 2️⃣ Create landing pages
    for idx, (title, desc) in enumerate(ideas, start=1):
        print(f"Creating landing page for: {title}")
        landing_prompt = f"Write a concise single-page landing page for this idea:\nTitle: {title}\nDescription: {desc}\nInclude 3 main bullet points, pricing, and CTA."
        landing_text = call_openai(system_prompt, landing_prompt, max_tokens=700)
        
        bullets = [ln.lstrip("-•* ").strip() for ln in landing_text.splitlines() if ln.startswith(("-", "•", "*"))][:3]
        if not bullets:
            bullets = ["Automates repetitive tasks","No manual labor after onboarding","Subscription + templates monetization"]
        price = "$29/mo or $79 one-time"
        cta = "Get Early Access"
        
        html_content = generate_landing_html(title, desc, bullets, price, cta)
        filename = f"{sanitize_filename(title)}.html"
        filepath = IDEAS_DIR / filename
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(html_content)
        master_links.append((title, filepath.name))

    # 3️⃣ Generate master index page
    index_items = "".join(f'<li><a href="ideas/{fname}">{title}</a></li>\n' for title,fname in master_links)
    master_html = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"/>
<title>All AI Ideas</title></head>
<body style="background:#111;color:#eef;font-family:sans-serif;padding:24px;">
<h1>All 10 AI-generated Faceless SaaS Ideas</h1>
<ul>{index_items}</ul>
<p>Open each link to preview the landing page.</p>
</body></html>"""
    with open(MASTER_PAGE,"w",encoding="utf-8") as f:
        f.write(master_html)

    print(f"Master index page generated: {MASTER_PAGE}")
    print("All landing pages generated in:", IDEAS_DIR)

if __name__=="__main__":
    main()
python --version
