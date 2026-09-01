#!/usr/bin/env bash
# Ce que `oftempus-setup` doit faire, vu de DEHORS.
#
# Le script touche exactement deux choses hors de lui : le Trousseau et le
# réseau. On les remplace par des doublures, et on lui donne un $HOME jetable —
# de sorte que le test ne peut ni lire le vrai token, ni écrire la vraie config,
# ni appeler la vraie instance.
#
#   ./tests/setup.test.sh
#
# Ce qui est éprouvé ici n'est pas « le script s'exécute » mais les trois
# comportements dont dépend l'alignement d'un parc de machines :
#   1. une machine neuve n'a pas besoin de connaître l'URL par cœur,
#   2. une machine déjà configurée ne se fait JAMAIS écraser sa valeur,
#   3. quand la conf change, le script dit de REDÉMARRER — car un daemon déjà
#      lancé garde l'ancienne URL en mémoire, et `start` ne fait rien sur un
#      service qui tourne déjà. C'est le seul écart qui ne se voit nulle part.
set -uo pipefail

RACINE="$(cd "$(dirname "$0")/.." && pwd)"
SETUP="$RACINE/bin/oftempus-setup"
VERTS=0; ROUGES=0; ECHECS=()

# Un bac à sable neuf par cas : rien ne fuit d'un cas au suivant.
bac () {
  BAC=$(mktemp -d)
  HOME="$BAC/home"; mkdir -p "$HOME/.config/oftempus"
  mkdir -p "$BAC/bin"
  BAC_TROUSSEAU="$BAC/trousseau"; BAC_CURLLOG="$BAC/curl.log"
  : > "$BAC_CURLLOG"

  cat > "$BAC/bin/security" <<'DOUBLURE'
#!/usr/bin/env bash
case "$1" in
  add-generic-password)
    shift
    while [ $# -gt 0 ]; do
      [ "$1" = "-w" ] && { printf '%s' "${2:-}" > "$BAC_TROUSSEAU"; }
      shift
    done
    exit 0 ;;
  find-generic-password)
    [ -s "$BAC_TROUSSEAU" ] || exit 44
    cat "$BAC_TROUSSEAU"; exit 0 ;;
esac
exit 1
DOUBLURE

  # Note l'URL réellement sondée : c'est elle qui dit quelle valeur le script a
  # retenue, indépendamment de ce qu'il affiche.
  cat > "$BAC/bin/curl" <<'DOUBLURE'
#!/usr/bin/env bash
for a in "$@"; do
  case "$a" in https://*|http://*) printf '%s\n' "$a" >> "$BAC_CURLLOG" ;; esac
done
printf '%s' "${BAC_CODE_HTTP:-200}"
DOUBLURE

  chmod +x "$BAC/bin/security" "$BAC/bin/curl"
  export HOME BAC_TROUSSEAU BAC_CURLLOG
  export PATH="$BAC/bin:$PATH"
  unset TEMPUS_BASE_URL BAC_CODE_HTTP 2>/dev/null || true
}

conf_existante () {  # conf_existante <url> <workspace>
  jq -n --arg u "$1" --arg w "$2" '{tempus_base_url:$u, workspace:$w}' \
    > "$HOME/.config/oftempus/config.json"
}
trousseau_amorce () { printf 'jeton-de-test' > "$BAC_TROUSSEAU"; }

lance () {  # lance <url> <workspace> <token> ; chaînes vides = « Entrée »
  printf '%s\n%s\n%s\n' "$1" "$2" "$3" | "$SETUP" 2>&1
}

url_retenue () { jq -r '.tempus_base_url // ""' "$HOME/.config/oftempus/config.json" 2>/dev/null; }

verdict () {  # verdict <ok:0|1> <titre> <pourquoi> <constate>
  if [ "$1" -eq 0 ]; then
    VERTS=$((VERTS+1)); printf '  ok    %s\n' "$2"
  else
    ROUGES=$((ROUGES+1)); ECHECS+=("$2")
    printf '  FAIL  %s\n' "$2"
    printf '        %s\n' "$3"
    printf '        constaté : %s\n' "$4"
  fi
}

DEFAUT="https://tempus.ephais.eu"

echo "== une machine neuve n'a pas à connaître l'URL par cœur =="

bac; trousseau_amorce
sortie=$(lance "" "Ephais" "")
u=$(url_retenue)
[ "$u" = "$DEFAUT" ] && ok=0 || ok=1
verdict $ok "URL laissée vide sur une machine neuve → le défaut est retenu" \
  "sans défaut, chaque nouvelle machine exige de retrouver l'URL de l'instance ailleurs" \
  "url retenue : « ${u:-aucune} » ; sortie : $(printf '%s' "$sortie" | tr '\n' ' ' | head -c 120)"

bac; trousseau_amorce
export TEMPUS_BASE_URL="https://depuis-env.example.com"
sortie=$(lance "" "Ephais" "")
u=$(url_retenue)
[ "$u" = "https://depuis-env.example.com" ] && ok=0 || ok=1
verdict $ok "TEMPUS_BASE_URL prime sur le défaut codé" \
  "l'instance est une donnée de déploiement : elle doit pouvoir venir de l'environnement, \
sans quoi le défaut codé en dur devient une impasse pour qui a une autre instance" \
  "url retenue : « ${u:-aucune} »"

echo
echo "== une machine déjà configurée ne se fait jamais écraser =="

bac; trousseau_amorce; conf_existante "https://ancienne.example.com" "Ephais"
sortie=$(lance "" "" "")
u=$(url_retenue)
[ "$u" = "https://ancienne.example.com" ] && ok=0 || ok=1
verdict $ok "URL laissée vide sur une machine configurée → l'existante est gardée" \
  "le défaut ne doit JAMAIS passer devant une valeur déjà choisie, sinon une simple \
reconfiguration déplacerait silencieusement une machine d'instance" \
  "url retenue : « ${u:-aucune} »"

echo
echo "== quand la conf change, le script doit dire de REDÉMARRER =="

bac; trousseau_amorce; conf_existante "https://ancienne.example.com" "Ephais"
sortie=$(lance "$DEFAUT" "" "")
printf '%s' "$sortie" | grep -q 'services restart of-tempus' && ok=0 || ok=1
verdict $ok "URL changée → la sortie réclame « brew services restart »" \
  "le daemon lit tempus_base_url une seule fois, au démarrage : sans redémarrage il \
continue de taper l'ancienne instance, et « start » ne fait rien sur un service déjà lancé" \
  "sortie : $(printf '%s' "$sortie" | tr '\n' ' ' | head -c 160)"

bac; trousseau_amorce; conf_existante "https://ancienne.example.com" "Ephais"
sortie=$(lance "" "Autre Workspace" "")
printf '%s' "$sortie" | grep -q 'services restart of-tempus' && ok=0 || ok=1
verdict $ok "workspace changé → la sortie réclame « brew services restart »" \
  "le workspace est lu au même moment que l'URL ; le changer sans redémarrer laisse le \
daemon pointer l'ancien" \
  "sortie : $(printf '%s' "$sortie" | tr '\n' ' ' | head -c 160)"

bac; trousseau_amorce; conf_existante "$DEFAUT" "Ephais"
sortie=$(lance "" "" "")
printf '%s' "$sortie" | grep -q 'services restart of-tempus' && ok=1 || ok=0
verdict $ok "conf inchangée → pas de consigne de redémarrage" \
  "réclamer un redémarrage quand rien n'a bougé apprend à ignorer le message, et c'est \
précisément le message qui compte le jour où quelque chose change" \
  "sortie : $(printf '%s' "$sortie" | tr '\n' ' ' | head -c 160)"

echo
echo "== l'URL retenue est bien celle qui est éprouvée sur le réseau =="

bac; trousseau_amorce
sortie=$(lance "" "Ephais" "")
sonde=$(head -1 "$BAC_CURLLOG" 2>/dev/null)
case "$sonde" in "$DEFAUT"/api/v9/me) ok=0 ;; *) ok=1 ;; esac
verdict $ok "la vérification de connexion porte sur l'URL retenue" \
  "un setup qui valide une autre adresse que celle qu'il écrit rendrait un « OK » mensonger" \
  "sondé : « ${sonde:-rien} »"

echo
echo "$((VERTS+ROUGES)) sondes : $VERTS vertes, $ROUGES échec(s)"
if [ "$ROUGES" -gt 0 ]; then
  printf '  - %s\n' "${ECHECS[@]}"
  exit 1
fi
echo "oftempus-setup se comporte comme un parc de machines l'exige"
