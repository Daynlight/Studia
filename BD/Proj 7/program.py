from itertools import combinations
import sys

def parse_attributes(line):
    return set(attr.strip() for attr in line.strip().split(','))

def parse_fd(line):
    fd_set = set()
    parts = line.strip().split(';')
    for part in parts:
        if not part.strip():
            continue
        left, right = part.split('->')
        left_attrs = frozenset(a.strip() for a in left.split(','))
        right_attrs = frozenset(a.strip() for a in right.split(','))
        fd_set.add((left_attrs, right_attrs))
    return fd_set

def closure(attributes, fds):
    closure_set = set(attributes)
    while True:
        added = False
        for (left, right) in fds:
            if left.issubset(closure_set) and not right.issubset(closure_set):
                closure_set |= right
                added = True
        if not added:
            break
    return closure_set

def all_subsets(s):
    return [frozenset(c) for r in range(1, len(s)+1) for c in combinations(s, r)]

def find_candidate_keys(attributes, fds):
    candidate_keys = []
    all_attrs = frozenset(attributes)
    subsets = all_subsets(attributes)
    subsets.sort(key=lambda x: (len(x), sorted(x)))  # Deterministyczna kolejność
    
    for subset in subsets:
        c = closure(subset, fds)
        if c == all_attrs:
            # minimalność: nie może istnieć mniejszy klucz
            if not any(k.issubset(subset) for k in candidate_keys):
                candidate_keys.append(subset)
    return candidate_keys

def find_superkeys(attributes, candidate_keys):
    superkeys = []
    subsets = all_subsets(attributes)
    subsets.sort(key=lambda x: (len(x), sorted(x)))  # Deterministyczna kolejność
    
    for subset in subsets:
        if any(k.issubset(subset) for k in candidate_keys):
            superkeys.append(subset)
    return superkeys

def fd_to_canonical(fds):
    """
    Rozbij zależności funkcyjne do postaci kanonicznej:
    - prawa strona zawsze pojedynczy atrybut
    - usuń nadmiarowe atrybuty po lewej
    """
    canonical = set()
    for (left, right) in fds:
        for attr in right:
            # usuń nadmiarowe atrybuty z left
            left_min = set(left)
            for a in list(left):
                test_left = left_min - {a}
                if closure(test_left, fds) >= right:
                    left_min = test_left
            canonical.add((frozenset(left_min), frozenset([attr])))
    return canonical

def minimal_cover(fds):
    # 1. rozbij na postać kanoniczną
    fds = fd_to_canonical(fds)
    # 2. usuń redundantne zależności
    fds_list = list(fds)
    to_remove = []
    for i, fd in enumerate(fds_list):
        temp_fds = set(fds_list)
        temp_fds.remove(fd)
        if fd[1].issubset(closure(fd[0], temp_fds)):
            to_remove.append(fd)
    for fd in to_remove:
        fds.discard(fd)
    # 3. usuń redundantne atrybuty po lewej - powtórka
    fds_min = set()
    for (left, right) in fds:
        left_min = set(left)
        for a in list(left):
            test_left = left_min - {a}
            if closure(test_left, fds) >= right:
                left_min = test_left
        fds_min.add((frozenset(left_min), right))
    return fds_min

def is_2nf(attributes, fds, candidate_keys):
    """
    2NF: nie ma częściowych zależności funkcyjnych
    tj. żaden atrybut niekluczowy nie zależy od podzbioru klucza
    """
    all_attrs = frozenset(attributes)
    key_attrs = set()
    for key in candidate_keys:
        key_attrs |= set(key)
    non_key_attrs = all_attrs - key_attrs

    partial_fds = []
    for (left, right) in fds:
        for key in candidate_keys:
            if left.issubset(key) and not left == key:
                # częściowa zależność z podzbioru klucza
                if right & non_key_attrs:
                    partial_fds.append((left, right))
    return len(partial_fds) == 0, partial_fds

def is_3nf(attributes, fds, candidate_keys, superkeys):
    """
    3NF: dla każdej zależności X->Y:
    - Y zawiera się w X (trywialna) albo
    - X jest nadkluczem albo
    - każdy atrybut w Y jest kluczowy
    """
    all_attrs = frozenset(attributes)
    key_attrs = set()
    for key in candidate_keys:
        key_attrs |= set(key)
    violating_fds = []
    for (left, right) in fds:
        trivial = right.issubset(left)
        left_is_superkey = any(left.issuperset(sk) for sk in superkeys)
        right_all_key = right.issubset(key_attrs)
        if not (trivial or left_is_superkey or right_all_key):
            violating_fds.append((left, right))
    return len(violating_fds) == 0, violating_fds

def normalize_3nf(attributes, fds, candidate_keys):
    """
    Algorytm syntezy do 3PN
    - baza minimalna
    - dla każdej zależności X->A utwórz relację (X ∪ A)
    - jeśli żaden z utworzonych schematów nie zawiera klucza, dodaj relację zawierającą klucz
    """
    fds_min = minimal_cover(fds)
    relacje = []
    for (left, right) in fds_min:
        relacje.append(set(left | right))
    # upewnij się, że klucz jest reprezentowany
    keys_included = any(any(key.issubset(rel) for key in candidate_keys) for rel in relacje)
    if not keys_included:
        relacje.append(set(candidate_keys[0]))
    # usuń powtarzające się relacje
    relacje_unique = []
    for r in relacje:
        if not any(r == rr for rr in relacje_unique):
            relacje_unique.append(r)
    return relacje_unique, fds_min

def print_fd_set(fd_set):
    for (left, right) in sorted(fd_set, key=lambda x: (sorted(x[0]), sorted(x[1]))):
        print(f"  {','.join(sorted(left))} -> {','.join(sorted(right))}")

def main():
    # Opcjonalne wczytywanie z pliku
    if len(sys.argv) > 1:
        with open(sys.argv[1], 'r') as f:
            lines = f.read().strip().split('\n')
        attributes = parse_attributes(lines[0])
        fds = parse_fd(lines[1])
    else:
        print("Podaj atrybuty relacji (oddzielone przecinkami):")
        attrs_line = input()
        attributes = parse_attributes(attrs_line)
        
        print("Podaj zbiór zależności funkcyjnych (format: A -> B; C,D -> E):")
        fds_line = input()
        fds = parse_fd(fds_line)

    # Weryfikacja atrybutów w zależnościach
    all_attrs = attributes
    for (left, right) in fds:
        if not left.issubset(all_attrs) or not right.issubset(all_attrs):
            print("Błąd: Zależności funkcyjne zawierają atrybut spoza zbioru atrybutów relacji!")
            return

    print("\nDomknięcia:")
    candidate_keys = find_candidate_keys(attributes, fds)
    for subset in sorted(all_subsets(attributes), key=lambda x: (len(x), sorted(x))):
        c = closure(subset, fds)
        marker = ""
        # oznacz minimalne klucze kandydujące
        if c == all_attrs:
            if any(subset == k for k in candidate_keys):
                marker = "  <- Minimalny klucz kandydujący"
        print(f"  {set(subset)}+ = {c}{marker}")

    superkeys = find_superkeys(attributes, candidate_keys)

    key_attrs = set()
    for key in candidate_keys:
        key_attrs |= set(key)
    non_key_attrs = all_attrs - key_attrs

    print("\nAtrybuty kluczowe:")
    print("  " + ", ".join(sorted(key_attrs)))

    print("\nAtrybuty niekluczowe:")
    print("  " + ", ".join(sorted(non_key_attrs)))

    print("\nBaza minimalna:")
    fds_min = minimal_cover(fds)
    print_fd_set(fds_min)

    is2nf, partials = is_2nf(attributes, fds, candidate_keys)
    if is2nf:
        print("\nRelacja jest w 2 postaci normalnej.")
    else:
        print("\nRelacja nie jest w 2 postaci normalnej.")
        print("Istnieją częściowe zależności funkcyjne naruszające 2PN:")
        for (left, right) in partials:
            print(f"  {','.join(sorted(left))} -> {','.join(sorted(right))}")

    is3nf, viols = is_3nf(attributes, fds, candidate_keys, superkeys)
    if is3nf:
        print("\nRelacja jest w 3 postaci normalnej.")
    else:
        print("\nRelacja nie jest w 3 postaci normalnej.")
        print("Istnieją zależności naruszające 3PN:")
        for (left, right) in viols:
            print(f"  {','.join(sorted(left))} -> {','.join(sorted(right))}")

    if not is3nf:
        print("\nDekompozycja do 3 postaci normalnej:")
        relacje, fds_min = normalize_3nf(attributes, fds, candidate_keys)
        for i, rel in enumerate(relacje, 1):
            # Zbierz FD w tej relacji
            rel_fds = []
            for (left, right) in fds_min:
                if left.issubset(rel) and right.issubset(rel):
                    rel_fds.append((left, right))
            print(f"  R{i}({', '.join(sorted(rel))})   ", end="")
            if rel_fds:
                print("{", end="")
                print("; ".join(f"{','.join(sorted(l))} -> {','.join(sorted(r))}" for l, r in rel_fds), end="")
                print("}")
            else:
                print("{}")

if __name__ == "__main__":
    main()
