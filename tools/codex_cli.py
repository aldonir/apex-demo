#!/usr/bin/env python3
import os, sys, re, argparse
from pathlib import Path
from openai import OpenAI

# Aceita: ```<qualquer-coisa> path=algum/arquivo.ext\nconteudo```
FENCE_RE = re.compile(r"```([^\n]*)\s+path=([^\n]+)\n(.*?)```", re.DOTALL)

def extract_text(resp):
    text = getattr(resp, "output_text", None)
    if text:
        return text
    try:
        parts = []
        for item in resp.output:
            if getattr(item, "type", "") == "message":
                for c in getattr(item, "content", []):
                    t = getattr(c, "text", None)
                    if t: parts.append(t)
        return "".join(parts).strip()
    except Exception:
        return str(resp)

def save_fenced_files(text, root="."):
    saved = []
    for m in FENCE_RE.finditer(text):
        lang, path, body = m.group(1).strip(), m.group(2).strip(), m.group(3)
        dest = Path(root) / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        with open(dest, "w", encoding="utf-8") as f:
            f.write(body.rstrip() + "\n")
        saved.append(str(dest))
    return saved

def main():
    ap = argparse.ArgumentParser(description="APEX-Demo Codex CLI")
    ap.add_argument("-p", "--prompt", required=True, help="Instrução do usuário (texto)")
    ap.add_argument("-m", "--model", default=os.getenv("OPENAI_MODEL","gpt-5"))
    ap.add_argument("--system", default="prompts/codex_system_apex.md")
    ap.add_argument("--fallback", default="README.md", help="Arquivo para salvar fallback quando não houver fences")
    args = ap.parse_args()

    if not os.getenv("OPENAI_API_KEY"):
        print("ERRO: OPENAI_API_KEY não definido (source .venv/bin/activate).", file=sys.stderr)
        sys.exit(2)

    system_prompt = Path(args.system).read_text(encoding="utf-8")
    client = OpenAI()
    resp = client.responses.create(
        model=args.model,
        input=[
            {"role":"system","content": system_prompt},
            {"role":"user","content": args.prompt}
        ]
    )

    text = extract_text(resp)

    # Sempre salvar debug
    Path("artifacts").mkdir(parents=True, exist_ok=True)
    Path("artifacts/last_response.txt").write_text(text, encoding="utf-8")

    saved = save_fenced_files(text, ".")
    if not saved:
        # fallback: salva tudo em README.md (ou outro definido)
        fb = Path(args.fallback)
        fb.parent.mkdir(parents=True, exist_ok=True)
        fb.write_text(text.strip() + "\n", encoding="utf-8")
        saved = [str(fb)]
        print("[codex] AVISO: sem code fences. Salvei fallback:", fb)

    print(f"[codex] arquivos salvos: {len(saved)}")
    for s in saved: print(" -", s)

    if "END OF FILES" not in text:
        print("[codex] AVISO: resposta não finalizou com 'END OF FILES'", file=sys.stderr)

if __name__ == "__main__":
    main()
