"""The learner's name in authored lines ({you}). Audio never says a name: vocatives are
dropped and other mentions become a neutral form. Mirrors lib/core/i18n/you.dart (keep the two in step)."""
import re
N = r'\{you\}'
GREET = r'(Hi|Hello|Hiya|Morning|Evening|Thanks|Thank you|Cheers|Night|Bye|Welcome|Oi|Ta|Well done|Come on|Sorry|Lovely|Right|Hey|Oh)'
def neutral(t):
    t = re.sub(r"\bI'm " + N + r"(?!['\w])", "I'm your new neighbour", t)
    t = re.sub(r"\bIt's " + N + r"(?!['\w])", "It's me", t)
    t = re.sub(r"\bThis is " + N + r"(?!['\w])", "This is your neighbour", t)
    t = re.sub(r',\s*' + N + r'(?=\s*[!?.,;:—–)"”]|$)', '', t)
    t = re.sub(r'(^|(?<=[.!?…]\s)|(?<=["“]))' + N + r'\s*[,!]\s*', r'\1', t)
    t = re.sub(r'\b' + GREET + r'\s+' + N + r"(?!['\w])", r'\1', t)
    t = re.sub(r'\s+' + N + r'(?=[!?.])', '', t)
    t = re.sub(N + "'s", "our neighbour's", t)
    t = re.sub(r'(^|(?<=[.!?…]\s)|(?<=["“]))' + N, 'Our neighbour', t)
    t = re.sub(N, 'our neighbour', t)
    t = re.sub(r'(^|(?<=[.!?…]\s)|(?<=["“]))([a-z])', lambda m: m.group(1) + m.group(2).upper(), t)
    return t
