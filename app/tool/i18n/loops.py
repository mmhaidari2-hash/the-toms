"""Shared machine-translation loop/garbage check (used by build_tables.py and retry_loops.py)."""
import re
# A word is letters PLUS the combining marks inside it. Python's [^\W\d_] alone splits Devanagari/Bengali/Gurmukhi words
# at every vowel sign (and Arabic at harakat), so ordinary Hindi text looked like a phrase repeated ("प र फ" x4) and
# correct long translations were rejected as loops.
WORD = r'(?:[^\W\d_]|[\u0300-\u036F\u064B-\u065F\u0670\u0900-\u0DFF\u200c\u200d])+'
def looped(out, en, code=''):
    """Machine-translation loops ("before retirement already one before retirement"): a phrase repeated that the
    English does not repeat, or an output far longer than its source. Those fall back to English."""
    w = re.findall(WORD, out.lower())
    grams = [' '.join(w[i:i + 3]) for i in range(len(w) - 2)]
    ew = re.findall(WORD, (en or '').lower())
    egrams = [' '.join(ew[i:i + 3]) for i in range(len(ew) - 2)]
    if en and len(grams) != len(set(grams)) and len(egrams) == len(set(egrams)): return True
    # No English source (Persian-only lines): only a phrase repeated three times or more is a loop.
    if not en and grams and max(grams.count(g) for g in set(grams)) >= 3: return True
    if '{you}' in (en or '') and '{you}' not in out: return True  # the learner's name placeholder must survive
    # NLLB language tags leaked into the output ("societatehin_Deva") and one-token camelCase non-words ("naJehovhajke")
    # are machine garbage; the source English never has them.
    if re.search(r'[a-z]{3}_[A-Z][a-z]{3}', out): return True
    o = out.strip()
    if re.fullmatch(r'[a-z][a-z0-9]*([A-Z_][A-Za-z0-9_]*)+', o) and o.lower() not in (en or '').lower(): return True
    if en and len(en) > 25 and len(out) < (0.12 if code.startswith('zh') else 0.3) * len(en): return True  # a long sentence collapsed to a fragment
    return bool(en) and len(out) > 3 * len(en) + 25
