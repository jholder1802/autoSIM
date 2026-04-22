# 🧭 Grundprinzip
# feature-jh = Arbeitsbranch
# main = stabiler Stand (optional synchronisieren)

# 🔍 Status prüfen
git status

# 🔄 Start einer Session
git checkout feature-jh
git pull origin feature-jh

# Optional: main aktualisieren
git checkout main
git pull origin main
git checkout feature-jh

# 💻 Arbeiten am Feature Branch
git add .
git commit -m "Beschreibung der Änderung"

# 🔍 Überblick behalten
git status
git log --oneline --graph

# 🚀 Push
git push origin feature-jh

# 🔄 Upstream (Original-Repo) integrieren
git fetch upstream
git checkout feature-jh
git rebase upstream/main

# Danach (nur wenn nötig):
git push -f origin feature-jh

# ⚠️ WICHTIG
# Rebase NUR in autoSIM verwenden (kein Problem bei Code)

# 🧹 Nach abgeschlossenem Feature
git checkout main
git merge feature-jh
git push origin main

# 🗑️ Optional: Branch löschen
git branch -d feature-jh
git push origin --delete feature-jh

# 💡 Regeln
# - Nie direkt in main arbeiten
# - Rebase erlaubt (Code-Repo)
# - Kleine, saubere Commits